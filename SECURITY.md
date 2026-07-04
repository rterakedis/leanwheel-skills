# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in leanwheel-skills, please report it privately rather than opening a public issue.

Open a [GitHub private security advisory](https://github.com/rterakedis/leanwheel-skills/security/advisories/new) for this repository with a description of the issue and reproduction steps.

Please do not disclose the issue publicly until it has been addressed.

## What Counts as a Vulnerability Here

This repository ships Claude Code skills, agents, and helper shell scripts — not a running service. Relevant concerns include:

- A skill or stub that could cause Claude Code to execute attacker-controlled shell commands unsafely (e.g. unsanitized input passed to `scripts/commit-push.sh` or `scripts/gh-track.sh`).
- A deterministic hook (`.claude/skills/setup/stubs/hooks/*.sh`) that fails to block a secret/credential it claims to block, or that can be bypassed.
- Guidance in a skill that would lead generated code to introduce a vulnerability class (e.g. recommending insecure defaults).
- Any committed secret, token, or credential in this repository's history.

General "the AI gave bad advice" issues that aren't security-relevant should go through normal GitHub issues instead.

## Supported Versions

This project does not maintain release branches; the `main` branch is the only supported version. Security fixes are applied to `main` and consumers should track it via `/upgrade-project` or the plugin marketplace update flow.

## Response

This is a personal/community project maintained on a best-effort basis. There is no guaranteed SLA, but reports will be acknowledged and triaged as soon as reasonably possible.
