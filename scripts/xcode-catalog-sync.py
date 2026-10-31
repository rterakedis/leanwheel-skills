#!/usr/bin/env python3
"""Usage: xcode-catalog-sync.py [--check] [--keep-open] [--project PATH] [--catalog PATH]...
                             [--timeout SECONDS] [checkout-root]

Has the running Xcode build this checkout so it rewrites the String Catalog(s).

`xcodebuild` extracts strings (.stringsdata) but never merges them into an `.xcstrings`
catalog; only a build inside the Xcode IDE does. So every agent build leaves the catalog
stale — new keys missing, translator comments out of date — and the drift surfaces later as
an unexplained diff on `main`. This drives Xcode's own MCP server (`xcrun mcpbridge`,
Xcode 26.3+) to open *this* checkout's project — a worktree, not `main` — build it, and
report what the build changed in each catalog.

Needs Xcode running with its MCP server enabled (Settings → Intelligence). The first
XcodeOpenWorkspace from a new agent raises an Xcode approval prompt the operator must allow.

Xcode only rewrites a catalog when the extracted strings differ from it — a clean build of an
in-sync tree leaves the file untouched, so "in-sync" is a real answer, not a no-op.

Configuration (no project paths are hard-coded):
  project    --project, else `container` in .leanwheel/sim.json (the simulator harness
             writes it, PROJECT-relative), else the first *.xcworkspace / *.xcodeproj
             found within 3 levels of the checkout root (hidden dirs skipped)
  catalogs   --catalog (repeatable), else every git-tracked *.xcstrings under the root

  checkout-root  defaults to the git root of the current directory
  --check        exit 1 if, after the build, any catalog differs from HEAD — i.e. the committed
                 catalog is out of sync with the source (for a gate). The rewrite is left in
                 place so it can be reviewed and committed. Never commits anything.
  --keep-open    leave the project open in Xcode afterward (default: close it if we opened it)
  --timeout N    seconds to wait for one MCP reply (default 900; the first open may wait on
                 the approval prompt, and a build can be long)

Output: human-readable progress, then one machine-readable last line:
  CATALOG: in-sync | CATALOG: drift <n> catalog(s) | CATALOG: none | CATALOG: unavailable — <why>

Exit: 0 in sync (or drift without --check, or no catalog tracked) · 1 drift under --check ·
      2 could not run (no Xcode, MCP off, not approved, build failed, timeout) — a gate must
      treat 2 as BLOCKED, never as a pass.
"""
import json
import select
import subprocess
import sys
import time
from pathlib import Path

MAX_BUILDS = 4
DEFAULT_TIMEOUT = 900


def fail(why):
    print(f"xcode-catalog-sync: {why}", file=sys.stderr)
    print(f"CATALOG: unavailable — {why}")
    return 2


class Bridge:
    """Minimal MCP stdio client for `xcrun mcpbridge` — one request in flight at a time."""

    def __init__(self, timeout):
        self.timeout = timeout
        self.proc = subprocess.Popen(
            ["xcrun", "mcpbridge"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, text=True, bufsize=1,
        )
        self.next_id = 0
        self.request("initialize", {
            "protocolVersion": "2025-06-18", "capabilities": {},
            "clientInfo": {"name": "leanwheel-xcode-catalog-sync", "version": "1"},
        })
        self.send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def send(self, msg):
        self.proc.stdin.write(json.dumps(msg) + "\n")
        self.proc.stdin.flush()

    def readline(self, deadline):
        # select() so a reply that never comes (approval prompt left unanswered, Xcode hung)
        # ends in a clear exit 2 instead of a silent hang that a gate would wait on forever.
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise RuntimeError(f"no reply from mcpbridge within {self.timeout}s — "
                                   "was Xcode's approval prompt answered?")
            ready, _, _ = select.select([self.proc.stdout], [], [], min(remaining, 1.0))
            if ready:
                line = self.proc.stdout.readline()
                if line == "":
                    err = self.proc.stderr.read().strip()[:400]
                    raise RuntimeError(f"mcpbridge exited — {err or 'no stderr'}")
                if line.strip():
                    return line
            elif self.proc.poll() is not None:
                err = self.proc.stderr.read().strip()[:400]
                raise RuntimeError(f"mcpbridge exited — {err or 'no stderr'}")

    def request(self, method, params):
        self.next_id += 1
        self.send({"jsonrpc": "2.0", "id": self.next_id, "method": method, "params": params})
        deadline = time.monotonic() + self.timeout
        while True:
            try:
                msg = json.loads(self.readline(deadline))
            except json.JSONDecodeError:
                continue  # mcpbridge occasionally logs non-JSON to stdout
            if msg.get("id") != self.next_id:
                continue  # notifications / progress
            if "error" in msg:
                raise RuntimeError(f"{method}: {msg['error'].get('message', msg['error'])}")
            return msg["result"]

    def tool(self, name, **args):
        result = self.request("tools/call", {"name": name, "arguments": args})
        # mcpbridge fills `content` but not always `structuredContent`; read either.
        data = result.get("structuredContent")
        if data is None:
            text = "".join(c.get("text", "") for c in result.get("content", []))
            try:
                data = json.loads(text)
            except ValueError:
                data = {"message": text}
        if result.get("isError"):
            raise RuntimeError(f"{name}: {data.get('message', data)}")
        return data

    def close(self):
        try:
            self.proc.stdin.close()
        except OSError:
            pass
        self.proc.terminate()


def git(root, *args):
    return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True)


def find_project(root, explicit):
    """--project, else sim.json's container, else discovery (workspace before project,
    mirroring Xcode's own resolution order; hidden dirs skipped, so .build/.git stay out)."""
    if explicit:
        return (root / explicit).resolve() if not Path(explicit).is_absolute() else Path(explicit)
    sim = root / ".leanwheel" / "sim.json"
    if sim.exists():
        try:
            container = json.loads(sim.read_text()).get("container")
        except (ValueError, OSError):
            container = None
        if container:
            p = Path(container)
            return p if p.is_absolute() else (root / p).resolve()
    for pattern in ("*.xcworkspace", "*.xcodeproj"):
        hits = sorted(
            p for p in root.glob(f"**/{pattern}")
            if len(p.relative_to(root).parts) <= 3
            and not any(part.startswith(".") for part in p.relative_to(root).parts)
            and ".xcodeproj" not in str(p.parent)  # skip the workspace nested in every xcodeproj
        )
        if hits:
            return hits[0]
    return None


def find_catalogs(root, explicit):
    if explicit:
        return [Path(c) if Path(c).is_absolute() else (root / c).resolve() for c in explicit]
    out = git(root, "ls-files", "-z", "--", "*.xcstrings").stdout
    return [(root / rel).resolve() for rel in out.split("\0") if rel]


def rel(root, path):
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def catalog_diff(root, catalog):
    """Working file vs the committed one — staged edits count as uncommitted drift."""
    return git(root, "diff", "HEAD", "--stat", "--", rel(root, catalog)).stdout.strip()


def semantic_summary(root, catalog):
    """Added / removed / changed keys against HEAD, ignoring key order — Xcode re-sorts keys a
    hand edit inserted out of place, which inflates the line diff without changing anything."""
    head = git(root, "show", f"HEAD:{rel(root, catalog)}").stdout
    try:
        old = json.loads(head).get("strings", {}) if head else {}
    except ValueError:
        old = {}
    new = json.loads(catalog.read_text()).get("strings", {})
    lines = [f"  + {k!r}" for k in new if k not in old]
    lines += [f"  - {k!r}" for k in old if k not in new]
    lines += [f"  ~ {k!r}" for k in old if k in new and old[k] != new[k]]
    return "\n".join(lines) or "  (key order only — no string or comment changed; commit the re-sorted file)"


def parse_args(argv):
    opts = {"check": False, "keep_open": False, "project": None, "catalogs": [],
            "timeout": DEFAULT_TIMEOUT, "root": None}
    it = iter(argv)
    for a in it:
        if a == "--check":
            opts["check"] = True
        elif a == "--keep-open":
            opts["keep_open"] = True
        elif a == "--project":
            opts["project"] = next(it, None)
        elif a == "--catalog":
            opts["catalogs"].append(next(it, None))
        elif a == "--timeout":
            opts["timeout"] = int(next(it, DEFAULT_TIMEOUT))
        elif a in ("-h", "--help"):
            print(__doc__)
            sys.exit(0)
        elif a.startswith("--"):
            print(f"xcode-catalog-sync: unknown option {a}", file=sys.stderr)
            sys.exit(2)
        else:
            opts["root"] = a
    return opts


def main(argv):
    o = parse_args(argv)
    if o["root"]:
        root = Path(o["root"]).resolve()
    else:
        top = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
        if top.returncode != 0:
            return fail("not inside a git checkout and no checkout-root given")
        root = Path(top.stdout.strip()).resolve()

    catalogs = find_catalogs(root, o["catalogs"])
    if not catalogs:
        print("no git-tracked *.xcstrings under the checkout — nothing to sync")
        print("CATALOG: none")
        return 0
    missing = [c for c in catalogs if not c.exists()]
    if missing:
        return fail(f"catalog not found: {', '.join(rel(root, c) for c in missing)}")

    project = find_project(root, o["project"])
    if project is None or not project.exists():
        return fail(f"no .xcworkspace/.xcodeproj under {root} — pass --project or set "
                    "`container` in .leanwheel/sim.json")
    if sys.platform != "darwin":
        return fail("not macOS — Xcode's MCP server is unavailable here")
    if subprocess.run(["pgrep", "-x", "Xcode"], capture_output=True).returncode != 0:
        return fail("Xcode is not running — open Xcode (MCP enabled in Settings → Intelligence) first")

    bridge = None
    try:
        bridge = Bridge(o["timeout"])
        try:
            already_open = str(project) in bridge.tool("XcodeListWorkspaces").get("message", "")
        except RuntimeError:
            # Not yet approved: only XcodeOpenWorkspace may run, and it raises the approval prompt.
            already_open = False
        ws = bridge.tool("XcodeOpenWorkspace", path=str(project))
        ws_id = ws["workspaceIdentifier"]
        print(f"building {rel(root, project)} in Xcode ({ws_id}, scheme {ws.get('activeScheme')}) …")
        # One build is not always enough: after a source revert the catalog kept the old value
        # through the build that compiled the revert and only caught up on the next (measured
        # 2026-10-30, Xcode 27.0). So build until two consecutive builds leave every catalog
        # byte-identical — an in-sync tree costs one extra no-op build (~0s).
        previous = None
        for attempt in range(1, MAX_BUILDS + 1):
            build = bridge.tool("BuildProject", workspaceIdentifier=ws_id)
            errors = [e for e in build.get("errors", []) if e.get("classification") == "error"]
            print(f"  build {attempt}: {build.get('buildResult', '?')} in {build.get('elapsedTime', 0):.0f}s")
            if errors:
                for e in errors[:10]:
                    print(f"  {e.get('filePath')}:{e.get('lineNumber')}: {e.get('message')}", file=sys.stderr)
                return fail("build failed — catalog not trusted")
            current = [c.read_bytes() for c in catalogs]
            if current == previous:
                break
            previous = current
        else:
            return fail(f"catalog still changing after {MAX_BUILDS} builds")
        if not o["keep_open"] and not already_open:
            bridge.tool("XcodeCloseWorkspace", workspaceIdentifier=ws_id)
    except (RuntimeError, OSError, KeyError, json.JSONDecodeError) as exc:
        print("  Is Xcode running with MCP enabled (Settings → Intelligence), and was its approval prompt allowed?",
              file=sys.stderr)
        return fail(str(exc))
    finally:
        if bridge:
            bridge.close()

    drifted = 0
    for catalog in catalogs:
        drift = catalog_diff(root, catalog)
        if not drift:
            print(f"{rel(root, catalog)}: matches HEAD — in sync with the source")
            continue
        drifted += 1
        print(f"{rel(root, catalog)}: differs from HEAD after the Xcode build:\n{drift}\n{semantic_summary(root, catalog)}")
    if not drifted:
        print("CATALOG: in-sync")
        return 0
    print(f"CATALOG: drift {drifted} catalog(s) — review the keys above, then commit the catalog on this branch")
    return 1 if o["check"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
