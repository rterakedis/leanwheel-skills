#!/usr/bin/env swift
//
//  compose.swift — App Store screenshot compositor (leanwheel /appstore-connect)
//
//  WHAT IT IS
//    A single-file Swift script (Foundation + CoreGraphics + CoreText + ImageIO only —
//    no Package.swift, no third-party code) that turns raw simulator captures into
//    App Store Connect-ready marketing screenshots: caption band + device bezel +
//    the capture composited inside the bezel's screen cutout.
//
//  USAGE
//    swift compose.swift --locale en-US [--store-dir docs/store]
//                        [--captures .leanwheel/sim/store] [--only id[,id]]
//                        [--dry-run] [--help]
//
//    Relative paths resolve against the current working directory, so run it from
//    the project root:  swift .claude/skills/appstore-connect/compose.swift --locale en-US
//
//  ARTIFACT CONTRACT
//    in : {store}/screenshots.md                       plan table (# id route seed appearance orientation devices)
//         {store}/metadata/{locale}/screenshot-captions.txt   `id: Caption [| Subtitle]` lines, `#` comments
//         {store}/frames/{class}.png                   portrait bezel  (user-supplied)
//         {store}/frames/{class}-landscape.png         landscape bezel (user-supplied)
//         {store}/frames/frames.json (optional)        {"iphone69": {"screen": [x,y,w,h]}, ...}
//         {store}/template.json (optional)             per-project styling; see STYLING below
//         {captures}/{locale}/{id}/{id}-{class}-{appearance}[-{orientation}].png
//           (the -{orientation} suffix exists only for landscape rows — sim.sh adds it
//            only when --orientation was passed)
//    out: {store}/screenshots/{locale}/{#}_{class}_{id}.png  — sRGB, no alpha, exact store size
//
//  FRAMES ARE USER-SUPPLIED. This script never draws a bezel itself. Export a device
//  bezel PNG *with a transparent screen cutout* from Apple Design Resources
//  (https://developer.apple.com/design/resources/) and save it as
//  docs/store/frames/{class}.png. The transparent interior is how the screen rect is
//  auto-detected; frames.json can override it.
//
//  STYLING — {store}/template.json is OPTIONAL
//    Absent (or present-but-empty) => the built-in plain style renders, byte for byte
//    identical to what this script produced before templating existed. That is the
//    contract every existing project depends on, and it is enforced by making the
//    defaults below *be* the old code path rather than a re-derivation of it.
//
//    Present => every key is merged over the defaults INDIVIDUALLY, so a project may
//    override `colors.light.background` alone without restating the geometry table.
//    Several geometry keys default to *nil* rather than to a number, because their
//    absence selects the old behaviour and no number can express it:
//      captionLeading/subtitleLeading  nil => line height from font metrics * 1.12
//                                      set => line height = fontSize * value
//      deviceTop + deviceWidth         nil => device is FIT into the space left below
//                                             the caption (old behaviour)
//                                      set => device is PINNED at deviceTop, scaled to
//                                             deviceWidth, and allowed to bleed off the
//                                             bottom canvas edge and clip
//      textBlockTop + textBlockBottom  nil => caption flows from captionTop (old)
//                                      set => caption and subtitle occupy FIXED slots;
//                                             the subtitle does not move up when the
//                                             caption is one line, so the device sits at
//                                             the same height across a whole set
//    panel / lockup / shadow are all `enabled: false` by default — pure additions.
//
//    A MALFORMED template.json is a hard, named error, never a silent fallback:
//    an unknown key (i.e. a typo), a bad type, an out-of-range fraction, a malformed
//    hex colour or a missing icon file each name their own dotted path and abort the
//    run. "It rendered plain because your JSON had a typo" is exactly the quiet wrong
//    output this pipeline exists to prevent. Keys beginning with `_` are comments.
//
//    Every geometry value is a FRACTION of the output canvas (W or H as the name says),
//    never a pixel: iPhone 6.9" is 1320x2868 (aspect 0.46) and iPad 13" is 2064x2752
//    (aspect 0.75), and absolute values do not carry between them. Leading and tracking
//    are multiples of the font size. Icon paths resolve against the store dir.
//
//  Validation is ALL-OR-NOTHING: every input is checked before a single byte is
//  written, and every problem is reported in one list. A half-composited screenshot
//  set is worse than none — you would ship the missing ones without noticing.
//

import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

// MARK: - Device classes

struct DeviceClass {
    let name: String
    let portraitSize: CGSize      // exact App Store output size, portrait
    let frameWidthFraction: CGFloat
    let captionSizeFraction: CGFloat

    func outputSize(landscape: Bool) -> CGSize {
        landscape ? CGSize(width: portraitSize.height, height: portraitSize.width) : portraitSize
    }
}

// The only two classes App Store Connect requires today; smaller sizes scale down.
let deviceClasses: [String: DeviceClass] = [
    "iphone69": DeviceClass(name: "iphone69", portraitSize: CGSize(width: 1320, height: 2868),
                            frameWidthFraction: 0.84, captionSizeFraction: 0.065),
    "ipadPro13": DeviceClass(name: "ipadPro13", portraitSize: CGSize(width: 2064, height: 2752),
                             frameWidthFraction: 0.86, captionSizeFraction: 0.045),
]

// MARK: - Small utilities

func die(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("compose: " + message + "\n").utf8))
    exit(1)
}

let usageText = """
compose.swift — build App Store screenshots from simulator captures + device bezels

usage: swift compose.swift --locale <ll-RR> [options]

  --locale <ll-RR>      locale to compose (required), e.g. en-US
  --store-dir <path>    store artifact tree           (default: docs/store)
  --captures <path>     simulator capture root        (default: .leanwheel/sim/store)
  --only <id[,id]>      restrict to these plan ids
  --dry-run             validate and print the plan expansion, write nothing
  --help                show this help

reads  {store-dir}/screenshots.md, {store-dir}/metadata/{locale}/screenshot-captions.txt,
       {store-dir}/frames/{class}[-landscape].png (+ optional frames.json),
       {store-dir}/template.json (optional per-project styling),
       {captures}/{locale}/{id}/{id}-{class}-{appearance}[-landscape].png
writes {store-dir}/screenshots/{locale}/{#}_{class}_{id}.png (sRGB, no alpha, exact store size)

Device bezels are user-supplied: export one with a transparent screen cutout from
Apple Design Resources (https://developer.apple.com/design/resources/).

Styling is optional: with no {store-dir}/template.json the built-in plain style renders.
A template.json overrides it per key (colors, lockup, panel, shadow, per-class geometry);
any unknown key, bad type or out-of-range fraction is a named error and nothing is written.
Caption lines may carry a subtitle:  id: Caption text | Subtitle text
"""

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0, alpha: 1.0)
}

/// `#RRGGBB` / `RRGGBB` (case-insensitive) → opaque sRGB. Store output has no alpha
/// channel, so an 8-digit `#RRGGBBAA` is rejected rather than silently flattened.
func parseHexColor(_ raw: String) -> CGColor? {
    var s = raw.trimmingCharacters(in: .whitespaces)
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
    return rgb(v)
}

// MARK: - template.json
//
// The template is kept as the raw parsed JSON plus keypath accessors that fall back
// per key, rather than being decoded into a struct of concrete values. That is what
// makes partial overrides work without a merge function: a key the file does not
// mention is simply never read, so it keeps whatever default the call site passes.
//
// Correctness therefore rests entirely on validation, which runs over the *file's*
// keys (not the schema's) so that a typo'd key is an unknown key and an unknown key
// is a hard error.

/// What a leaf key is allowed to hold. The distinction between `.fraction` and
/// `.number` is real: canvas fractions are 0...1, but tracking is negative and leading
/// is > 1, so range-checking those as fractions would reject valid templates.
indirect enum Spec {
    case fraction                       // number, 0...1 — a fraction of canvas W or H
    case number                         // any finite number — tracking, leading
    case positiveInt                    // >= 1
    case hexColor
    case bool
    case string
    case oneOf([String])
    case relativePath                   // string; the file must exist under the store dir
    case object([String: Spec])
}

let geometrySpec: [String: Spec] = [
    "sideInset": .fraction,
    "lockupTop": .fraction,
    "lockupIconSize": .fraction,
    "lockupIconTextGap": .fraction,
    "lockupTextSize": .fraction,
    "lockupTextTracking": .number,
    "captionTop": .fraction,
    "captionSize": .fraction,
    "captionLeading": .number,
    "captionTracking": .number,
    "captionColumnWidth": .fraction,
    "gapCaptionToSubtitle": .fraction,
    "subtitleSize": .fraction,
    "subtitleLeading": .number,
    "subtitleTracking": .number,
    "subtitleColumnWidth": .fraction,
    "textBlockTop": .fraction,
    "textBlockBottom": .fraction,
    "panelX": .fraction,
    "panelWidth": .fraction,
    "panelTop": .fraction,
    "panelTopCornerRadius": .fraction,
    "deviceWidth": .fraction,
    "deviceTop": .fraction,
    "shadowOffsetY": .fraction,
    "shadowBlur": .fraction,
]

let appearanceColorsSpec: Spec = .object([
    "background": .hexColor, "caption": .hexColor, "subtitle": .hexColor,
    "panel": .hexColor, "lockup": .hexColor,
])

let alignments = ["left", "center", "right"]
let weights = ["regular", "medium", "semibold", "bold", "heavy"]
let textFieldSpec: Spec = .object([
    "align": .oneOf(alignments), "maxLines": .positiveInt,
    "maxChars": .positiveInt, "weight": .oneOf(weights),
])

/// The whole of template.json. `geometry` is keyed by device class, and the known
/// classes are exactly `deviceClasses`, so an unknown class name is a typo too.
var templateSpec: [String: Spec] {
    var geo: [String: Spec] = [:]
    for name in deviceClasses.keys { geo[name] = .object(geometrySpec) }
    return [
        "colors": .object(["light": appearanceColorsSpec, "dark": appearanceColorsSpec]),
        "lockup": .object([
            "enabled": .bool, "text": .string,
            "icon": .object(["light": .relativePath, "dark": .relativePath]),
            "iconCornerRadiusFraction": .fraction,
        ]),
        "caption": textFieldSpec,
        "subtitle": textFieldSpec,
        "autoShrink": .object(["step": .fraction, "floor": .fraction]),
        "panel": .object(["enabled": .bool, "bleedsToBottom": .bool]),
        "device": .object(["bleedsOffBottom": .bool, "clipCaptureToBezel": .bool]),
        "shadow": .object(["enabled": .bool, "opacityLight": .fraction, "opacityDark": .fraction]),
        "geometry": .object(geo),
    ]
}

struct Template {
    let present: Bool
    let root: [String: Any]
    /// Directory that relative paths (icons) resolve against.
    let baseDir: String

    static let empty = Template(present: false, root: [:], baseDir: ".")

    // --- keypath accessors: absent key => caller's default, always ---

    private func node(_ path: [String]) -> Any? {
        var cur: Any = root
        for key in path {
            guard let dict = cur as? [String: Any], let next = dict[key] else { return nil }
            cur = next
        }
        return cur
    }
    func num(_ path: [String], _ fallback: CGFloat) -> CGFloat { optNum(path) ?? fallback }
    func optNum(_ path: [String]) -> CGFloat? { (node(path) as? NSNumber).map { CGFloat($0.doubleValue) } }
    func int(_ path: [String], _ fallback: Int) -> Int { (node(path) as? NSNumber)?.intValue ?? fallback }
    func bool(_ path: [String], _ fallback: Bool) -> Bool { (node(path) as? NSNumber)?.boolValue ?? fallback }
    func str(_ path: [String], _ fallback: String) -> String { (node(path) as? String) ?? fallback }
    func optStr(_ path: [String]) -> String? { node(path) as? String }
    func color(_ path: [String], _ fallback: CGColor) -> CGColor {
        guard let s = node(path) as? String, let c = parseHexColor(s) else { return fallback }
        return c
    }
}

/// Load and fully validate `{store}/template.json`.
///
/// Absent => `.empty` and not an error: the plain default is a supported configuration,
/// not a degraded one. Present-but-unreadable/malformed => errors, and the caller
/// aborts before writing anything (compose is all-or-nothing), which is the whole
/// point: a typo must never silently downgrade a branded set to the plain style.
func loadTemplate(path: String, errors: inout [String]) -> Template {
    guard FileManager.default.fileExists(atPath: path) else { return .empty }
    guard let data = FileManager.default.contents(atPath: path) else {
        errors.append("\(path): could not be read")
        return .empty
    }
    // An empty (or whitespace-only) file is treated as "no template", matching the
    // documented contract that absent-or-empty renders the plain default.
    if String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? false {
        return .empty
    }
    let parsed: Any
    do {
        parsed = try JSONSerialization.jsonObject(with: data)
    } catch {
        errors.append("\(path): not valid JSON — \(error.localizedDescription)")
        return .empty
    }
    guard let root = parsed as? [String: Any] else {
        errors.append("\(path): top level must be a JSON object")
        return .empty
    }
    let baseDir = (path as NSString).deletingLastPathComponent
    validate(node: root, against: templateSpec, at: [], path: path, baseDir: baseDir, errors: &errors)
    return Template(present: true, root: root, baseDir: baseDir.isEmpty ? "." : baseDir)
}

/// Walk the FILE's keys against the schema. Unknown keys are errors — that is what
/// turns `"backgronud"` into a named failure instead of a value that silently keeps
/// its default. Keys beginning with `_` are comments and are skipped at every level
/// (`_comment` at the root is the documented way to annotate a template).
func validate(node: [String: Any], against spec: [String: Spec], at trail: [String],
              path: String, baseDir: String, errors: inout [String]) {
    for (key, value) in node.sorted(by: { $0.key < $1.key }) {
        if key.hasPrefix("_") { continue }
        let dotted = (trail + [key]).joined(separator: ".")
        guard let keySpec = spec[key] else {
            let known = spec.keys.sorted().joined(separator: ", ")
            errors.append("\(path): unknown key '\(dotted)'\(known.isEmpty ? "" : " (known keys here: \(known))")")
            continue
        }
        switch keySpec {
        case .object(let childSpec):
            guard let child = value as? [String: Any] else {
                errors.append("\(path): '\(dotted)' must be an object")
                continue
            }
            validate(node: child, against: childSpec, at: trail + [key],
                     path: path, baseDir: baseDir, errors: &errors)
        case .fraction:
            guard let n = value as? NSNumber else {
                errors.append("\(path): '\(dotted)' must be a number"); continue
            }
            let v = n.doubleValue
            guard v.isFinite, v >= 0, v <= 1 else {
                errors.append("\(path): '\(dotted)' must be a fraction of the canvas in 0...1 (got \(v))")
                continue
            }
        case .number:
            guard let n = value as? NSNumber, n.doubleValue.isFinite else {
                errors.append("\(path): '\(dotted)' must be a number"); continue
            }
        case .positiveInt:
            guard let n = value as? NSNumber, n.intValue >= 1 else {
                errors.append("\(path): '\(dotted)' must be an integer >= 1"); continue
            }
        case .bool:
            guard value is NSNumber else { errors.append("\(path): '\(dotted)' must be true or false"); continue }
        case .hexColor:
            guard let s = value as? String else {
                errors.append("\(path): '\(dotted)' must be a \"#RRGGBB\" string"); continue
            }
            if parseHexColor(s) == nil {
                errors.append("\(path): '\(dotted)' must be an opaque 6-digit hex colour like \"#26803D\" (got \"\(s)\")")
            }
        case .string:
            if !(value is String) {
                errors.append("\(path): '\(dotted)' must be a string")
            }
        case .oneOf(let allowed):
            guard let s = value as? String else {
                errors.append("\(path): '\(dotted)' must be a string"); continue
            }
            if !allowed.contains(s) {
                errors.append("\(path): '\(dotted)' must be one of \(allowed.joined(separator: "|")) (got \"\(s)\")")
            }
        case .relativePath:
            guard let s = value as? String else {
                errors.append("\(path): '\(dotted)' must be a path string"); continue
            }
            let resolved = s.hasPrefix("/") ? s : (baseDir.isEmpty ? s : baseDir + "/" + s)
            if !FileManager.default.fileExists(atPath: resolved) {
                errors.append("\(path): '\(dotted)' points at a file that does not exist: \(resolved) (paths are relative to the store dir)")
            }
        }
    }
}

/// Cross-key checks that the per-key schema cannot express. Kept separate so the
/// messages can name the *relationship* that is wrong rather than a single key.
func validateTemplateCoherence(_ t: Template, path: String, errors: inout [String]) {
    guard t.present else { return }
    if t.bool(["lockup", "enabled"], false) {
        if t.optStr(["lockup", "text"]) == nil && t.optStr(["lockup", "icon", "light"]) == nil {
            errors.append("\(path): 'lockup.enabled' is true but neither 'lockup.text' nor 'lockup.icon' is set — the lockup would draw nothing")
        }
    }
    if let step = t.optNum(["autoShrink", "step"]), step <= 0 || step >= 1 {
        errors.append("\(path): 'autoShrink.step' must be > 0 and < 1 (got \(step))")
    }
    if let floor = t.optNum(["autoShrink", "floor"]), floor <= 0 || floor > 1 {
        errors.append("\(path): 'autoShrink.floor' must be > 0 and <= 1 (got \(floor))")
    }
    for className in deviceClasses.keys.sorted() {
        let g = ["geometry", className]
        let top = t.optNum(g + ["textBlockTop"]), bottom = t.optNum(g + ["textBlockBottom"])
        if let a = top, let b = bottom, b <= a {
            errors.append("\(path): 'geometry.\(className).textBlockBottom' (\(b)) must be greater than 'textBlockTop' (\(a))")
        }
        if (top == nil) != (bottom == nil) {
            errors.append("\(path): 'geometry.\(className)' sets only one of textBlockTop/textBlockBottom — the fixed text block needs both, or neither (neither = the caption flows from captionTop)")
        }
        let dTop = t.optNum(g + ["deviceTop"]), dWidth = t.optNum(g + ["deviceWidth"])
        if (dTop == nil) != (dWidth == nil) {
            errors.append("\(path): 'geometry.\(className)' sets only one of deviceTop/deviceWidth — pinning the device needs both, or neither (neither = the device is fitted below the caption)")
        }
        if let x = t.optNum(g + ["panelX"]), let w = t.optNum(g + ["panelWidth"]), x + w > 1.0001 {
            errors.append("\(path): 'geometry.\(className)' panelX + panelWidth = \(x + w) — the panel would run off the right edge")
        }
    }
}

// MARK: - CLI parsing

struct Options {
    var locale: String?
    var storeDir = "docs/store"
    var captures = ".leanwheel/sim/store"
    var only: [String] = []
    var dryRun = false
}

func parseArgs(_ argv: [String]) -> Options {
    var o = Options()
    var i = 0
    func value(_ flag: String) -> String {
        i += 1
        guard i < argv.count else { die("\(flag) requires a value") }
        return argv[i]
    }
    while i < argv.count {
        switch argv[i] {
        case "--help", "-h":
            print(usageText); exit(0)
        case "--locale": o.locale = value("--locale")
        case "--store-dir": o.storeDir = value("--store-dir")
        case "--captures": o.captures = value("--captures")
        case "--only":
            o.only = value("--only").split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty }
        case "--dry-run": o.dryRun = true
        default:
            FileHandle.standardError.write(Data(("compose: unknown flag '\(argv[i])'\n\n" + usageText + "\n").utf8))
            exit(2)
        }
        i += 1
    }
    return o
}

// MARK: - Plan parsing

struct PlanRow {
    let order: Int
    let id: String
    let appearance: String     // light | dark
    let orientation: String    // portrait | landscape
    let devices: [String]
    var isLandscape: Bool { orientation == "landscape" }
}

/// Split a markdown table row into trimmed cells, tolerating leading/trailing pipes.
func tableCells(_ line: String) -> [String] {
    var s = line.trimmingCharacters(in: .whitespaces)
    if s.hasPrefix("|") { s.removeFirst() }
    if s.hasSuffix("|") { s.removeLast() }
    return s.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
}

func isSeparatorRow(_ cells: [String]) -> Bool {
    !cells.isEmpty && cells.allSatisfy { c in
        !c.isEmpty && c.allSatisfy { ":-= ".contains($0) }
    }
}

let requiredColumns = ["#", "id", "route", "seed", "appearance", "orientation", "devices"]

/// Find the first markdown table whose header carries all the required columns and
/// parse its body. Bad rows become validation errors (with line numbers) rather than
/// silent skips — a typo'd plan row would otherwise vanish from the store listing.
func parsePlan(path: String, errors: inout [String]) -> [PlanRow] {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        errors.append("missing plan: \(path)")
        return []
    }
    let lines = text.components(separatedBy: .newlines)

    var headerIndex: Int?
    var columnIndex: [String: Int] = [:]
    for (n, line) in lines.enumerated() {
        guard line.contains("|") else { continue }
        let cells = tableCells(line)
        guard cells.count >= requiredColumns.count else { continue }
        var map: [String: Int] = [:]
        for (c, cell) in cells.enumerated() { map[cell.lowercased()] = c }
        if requiredColumns.allSatisfy({ map[$0.lowercased()] != nil }) {
            headerIndex = n
            columnIndex = map
            break
        }
    }
    guard let start = headerIndex else {
        errors.append("\(path): no plan table found (need a markdown table with columns: \(requiredColumns.joined(separator: ", ")))")
        return []
    }

    var rows: [PlanRow] = []
    var seenIDs = Set<String>()
    for n in (start + 1)..<lines.count {
        let line = lines[n]
        if !line.contains("|") {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            break   // prose after the table ends it
        }
        let cells = tableCells(line)
        if isSeparatorRow(cells) { continue }
        let lineNo = n + 1
        func cell(_ key: String) -> String {
            guard let c = columnIndex[key], c < cells.count else { return "" }
            return cells[c]
        }
        let rawOrder = cell("#"), id = cell("id")
        if rawOrder.isEmpty && id.isEmpty { continue }

        var rowErrors: [String] = []
        guard let order = Int(rawOrder), order >= 1 else {
            errors.append("\(path):\(lineNo): '#' must be a positive integer (got '\(rawOrder)')")
            continue
        }
        if id.isEmpty { rowErrors.append("'id' is empty") }
        else if id.contains(" ") || id.contains("/") { rowErrors.append("'id' must be a kebab slug (got '\(id)')") }
        else if !seenIDs.insert(id).inserted { rowErrors.append("duplicate id '\(id)'") }

        let appearance = cell("appearance").lowercased()
        if !["light", "dark"].contains(appearance) {
            rowErrors.append("'appearance' must be light|dark (got '\(cell("appearance"))')")
        }
        var orientation = cell("orientation").lowercased()
        if orientation.isEmpty { orientation = "portrait" }
        if !["portrait", "landscape"].contains(orientation) {
            rowErrors.append("'orientation' must be portrait|landscape (got '\(cell("orientation"))')")
        }
        let devices = cell("devices").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if devices.isEmpty { rowErrors.append("'devices' is empty") }
        for d in devices where deviceClasses[d] == nil {
            rowErrors.append("unknown device class '\(d)' (known: \(deviceClasses.keys.sorted().joined(separator: ", ")))")
        }

        if rowErrors.isEmpty {
            rows.append(PlanRow(order: order, id: id, appearance: appearance,
                                orientation: orientation, devices: devices))
        } else {
            for e in rowErrors { errors.append("\(path):\(lineNo): \(e)") }
        }
    }
    if rows.isEmpty && errors.isEmpty { errors.append("\(path): plan table has no rows") }
    return rows
}

// MARK: - Captions

/// One caption line's text. The subtitle only renders when the project's template
/// gives it a slot; with no template it is parsed, validated and ignored — which is
/// what keeps this format change backward compatible for the plain style.
struct CaptionText {
    let caption: String
    let subtitle: String?
}

/// `id: Caption text` or `id: Caption text | Subtitle text` — `#` comments and blank
/// lines ignored. The caption may itself contain colons, so only the FIRST colon
/// separates the id; the subtitle is split at the FIRST `|` after that colon, so a
/// caption cannot contain a literal pipe. A missing subtitle is legal (it simply
/// leaves its slot empty); a missing caption is an error.
func parseCaptions(path: String, errors: inout [String]) -> [String: CaptionText] {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        errors.append("missing captions file: \(path)")
        return [:]
    }
    var out: [String: CaptionText] = [:]
    for (n, raw) in text.components(separatedBy: .newlines).enumerated() {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") { continue }
        guard let colon = line.firstIndex(of: ":") else {
            errors.append("\(path):\(n + 1): expected 'id: Caption text [| Subtitle text]'")
            continue
        }
        let id = String(line[line.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
        let rest = String(line[line.index(after: colon)...])

        var caption = rest, subtitle: String? = nil
        if let bar = rest.firstIndex(of: "|") {
            caption = String(rest[rest.startIndex..<bar])
            let tail = String(rest[rest.index(after: bar)...]).trimmingCharacters(in: .whitespaces)
            // `id: Caption |` with nothing after the bar means "no subtitle", not "".
            subtitle = tail.isEmpty ? nil : tail
        }
        caption = caption.trimmingCharacters(in: .whitespaces)

        if id.isEmpty || caption.isEmpty {
            errors.append("\(path):\(n + 1): expected 'id: Caption text [| Subtitle text]'")
            continue
        }
        out[id] = CaptionText(caption: caption, subtitle: subtitle)
    }
    return out
}

// MARK: - Image loading

func loadImage(_ path: String) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          CGImageSourceGetCount(src) > 0 else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

// MARK: - Screen-rect detection

/// Bounding box (top-left origin, pixels) of the interior transparent region of a bezel.
///
/// Transparent pixels that touch the image border are the *outside* of the device
/// (rounded corner bleed, drop-shadow padding). We flood-fill from every border pixel
/// over transparent pixels to mark those, and whatever transparent pixels remain are
/// the screen cutout. The fill is an explicit stack, not recursion — frames are ~3000px
/// tall and a recursive fill blows the stack.
///
/// Returns the bounding box AND a coverage mask of the cutout's true shape. The two are
/// not interchangeable: the box is a rectangle, but a bezel's screen cutout usually is
/// not (rounded corners), and the difference is real. Filling the whole box leaves the
/// capture showing in the corner slivers the bezel does not cover — invisible for years
/// against the plain style's near-white background, glaring the moment a project puts a
/// coloured panel behind the device. Templated renders clip to the mask; the untemplated
/// path keeps using the box so its output stays byte-identical.
struct FrameAnalysis {
    let screenRect: CGRect?
    /// Grayscale, frame-sized, white where the cutout is — aligned to the frame image,
    /// so clipping with it over the frame's draw rect lines up exactly.
    let cutoutMask: CGImage?
}

func detectScreenRect(_ image: CGImage) -> CGRect? { analyzeFrame(image).screenRect }

func analyzeFrame(_ image: CGImage) -> FrameAnalysis {
    let w = image.width, h = image.height
    guard w > 0, h > 0 else { return FrameAnalysis(screenRect: nil, cutoutMask: nil) }

    // RGBA8 rather than an alpha-only context: CGContext's Swift signature requires a
    // non-nil colour space, and alphaOnly requires a nil one. We just read every 4th byte.
    var rgba = [UInt8](repeating: 0, count: w * h * 4)
    let ok: Bool = rgba.withUnsafeMutableBytes { buf -> Bool in
        guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return true
    }
    guard ok else { return FrameAnalysis(screenRect: nil, cutoutMask: nil) }
    var alpha = [UInt8](repeating: 0, count: w * h)
    for i in 0..<(w * h) { alpha[i] = rgba[i * 4 + 3] }
    // The alpha-only context is bottom-up like all CG contexts; row 0 of `alpha`
    // is the BOTTOM of the image. We work in that space and flip at the end.

    let threshold: UInt8 = 8
    var outside = [Bool](repeating: false, count: w * h)
    var stack: [Int] = []
    stack.reserveCapacity(4096)

    func push(_ x: Int, _ y: Int) {
        let i = y * w + x
        if !outside[i] && alpha[i] < threshold { outside[i] = true; stack.append(i) }
    }
    for x in 0..<w { push(x, 0); push(x, h - 1) }
    for y in 0..<h { push(0, y); push(w - 1, y) }
    while let i = stack.popLast() {
        let x = i % w, y = i / w
        if x > 0 { push(x - 1, y) }
        if x < w - 1 { push(x + 1, y) }
        if y > 0 { push(x, y - 1) }
        if y < h - 1 { push(x, y + 1) }
    }

    var minX = w, minY = h, maxX = -1, maxY = -1
    for y in 0..<h {
        let row = y * w
        for x in 0..<w where alpha[row + x] < threshold && !outside[row + x] {
            if x < minX { minX = x }
            if x > maxX { maxX = x }
            if y < minY { minY = y }
            if y > maxY { maxY = y }
        }
    }
    guard maxX >= minX, maxY >= minY else { return FrameAnalysis(screenRect: nil, cutoutMask: nil) }

    // Coverage mask of the DEVICE SILHOUETTE — everything not reachable from the border,
    // which is the bezel body plus the cutout it encloses.
    //
    // Deliberately not just the cutout: bezels carry semi-transparent interior details
    // (a home indicator, a speaker slot) whose alpha is meant to composite OVER the
    // capture. Masking to the cutout alone would exclude those pixels, letting the
    // background show through them instead of the screen — the panel colour bleeding
    // through the home indicator. Masking to the silhouette keeps the capture behind
    // every interior pixel, and still excludes the corner slivers outside the device,
    // which is the whole point. The capture is clipped to the screen rect as well, so
    // this only ever subtracts.
    //
    // Built top-down (row 0 = top) because a CGImage made from a buffer is read that
    // way, while the CGContext above filled `alpha` bottom-up — hence the row flip.
    var maskBytes = [UInt8](repeating: 0, count: w * h)
    for y in 0..<h {
        let srcRow = (h - 1 - y) * w, dstRow = y * w
        for x in 0..<w where !outside[srcRow + x] {
            maskBytes[dstRow + x] = 255
        }
    }
    var mask: CGImage? = nil
    if let provider = CGDataProvider(data: Data(maskBytes) as CFData) {
        mask = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: w,
                       space: CGColorSpaceCreateDeviceGray(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)
    }

    // Flip to top-left origin for the frames.json / caller convention.
    let topY = h - 1 - maxY
    let rect = CGRect(x: CGFloat(minX), y: CGFloat(topY),
                      width: CGFloat(maxX - minX + 1), height: CGFloat(maxY - minY + 1))
    return FrameAnalysis(screenRect: rect, cutoutMask: mask)
}

/// frames.json: {"iphone69": {"screen": [x, y, w, h]}, ...} — key is the frame file's
/// basename without extension, so "iphone69-landscape" is a distinct entry.
func loadFramesJSON(path: String, errors: inout [String]) -> [String: CGRect] {
    guard FileManager.default.fileExists(atPath: path) else { return [:] }
    guard let data = FileManager.default.contents(atPath: path),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        errors.append("\(path): not valid JSON")
        return [:]
    }
    var out: [String: CGRect] = [:]
    for (key, value) in root {
        guard let entry = value as? [String: Any], let nums = entry["screen"] as? [NSNumber], nums.count == 4 else {
            errors.append("\(path): entry '\(key)' must be {\"screen\": [x, y, w, h]}")
            continue
        }
        let v = nums.map { CGFloat($0.doubleValue) }
        guard v[2] > 0, v[3] > 0 else {
            errors.append("\(path): entry '\(key)' screen width/height must be > 0")
            continue
        }
        out[key] = CGRect(x: v[0], y: v[1], width: v[2], height: v[3])
    }
    return out
}

// MARK: - Caption typesetting

/// Weight names accepted by `caption.weight` / `subtitle.weight`, mapped onto the
/// CoreText weight axis (-1...1, 0 = regular). The plain default is `bold`, which
/// takes the symbolic-trait path below rather than the weight axis so that untemplated
/// output keeps rendering with exactly the font instance it always did.
let weightAxis: [String: CGFloat] = [
    "regular": 0.0, "medium": 0.23, "semibold": 0.3, "bold": 0.4, "heavy": 0.56,
]

func systemFont(size: CGFloat, bold: Bool) -> CTFont {
    let base = CTFontCreateUIFontForLanguage(.system, size, nil)
        ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
    guard bold else { return base }
    // Bold via symbolic traits; some system font instances refuse the copy, in which
    // case the regular face is a perfectly acceptable fallback.
    return CTFontCreateCopyWithSymbolicTraits(base, size, nil, .boldTrait, .boldTrait) ?? base
}

/// `bold` and `regular` reuse the original two code paths verbatim; the intermediate
/// weights go through the variation axis, and fall back to the nearest of the two if
/// the running system font has no such instance.
func systemFont(size: CGFloat, weight: String) -> CTFont {
    switch weight {
    case "bold": return systemFont(size: size, bold: true)
    case "regular": return systemFont(size: size, bold: false)
    default:
        let axis = weightAxis[weight] ?? 0
        let traits: [CFString: Any] = [kCTFontWeightTrait: axis]
        let desc = CTFontDescriptorCreateWithAttributes([kCTFontTraitsAttribute: traits] as CFDictionary)
        let base = CTFontCreateUIFontForLanguage(.system, size, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        // Non-optional: if the running system font has no instance at this weight,
        // CoreText returns the nearest one it does have rather than failing.
        return CTFontCreateCopyWithAttributes(base, size, nil, desc)
    }
}

/// `tracking` is a multiple of the font size (the template's unit), converted here to
/// the absolute per-character kern CoreText wants. Zero tracking omits the attribute
/// entirely rather than setting it to 0 — an attribute that is present at all can
/// perturb line breaking, and the untemplated path must not change.
func attributed(_ text: String, font: CTFont, color: CGColor, tracking: CGFloat = 0) -> CFAttributedString {
    // CoreText attribute keys, not AppKit's NSAttributedString.Key extensions — this is
    // a Foundation-only script with no AppKit link.
    var attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(rawValue: kCTFontAttributeName as String): font,
        NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String): color,
    ]
    if tracking != 0 {
        attrs[NSAttributedString.Key(rawValue: kCTKernAttributeName as String)] =
            tracking * CTFontGetSize(font)
    }
    // Alignment is done by hand when the lines are drawn, so no paragraph style is needed.
    return NSAttributedString(string: text, attributes: attrs) as CFAttributedString
}

/// Break `text` into typeset lines that fit `width` at `font`.
func breakLines(_ text: String, font: CTFont, color: CGColor, width: CGFloat,
                tracking: CGFloat = 0) -> [CTLine] {
    let attr = attributed(text, font: font, color: color, tracking: tracking)
    let typesetter = CTTypesetterCreateWithAttributedString(attr)
    let length = CFAttributedStringGetLength(attr)
    var lines: [CTLine] = []
    var start = 0
    while start < length {
        let count = CTTypesetterSuggestLineBreak(typesetter, start, Double(width))
        if count <= 0 { break }
        lines.append(CTTypesetterCreateLine(typesetter, CFRangeMake(start, count)))
        start += count
    }
    return lines
}

struct CaptionLayout {
    let lines: [CTLine]
    let font: CTFont
    let lineHeight: CGFloat
    var height: CGFloat { CGFloat(lines.count) * lineHeight }
}

/// How one text field (caption or subtitle) is set. The defaults spell out the plain
/// style exactly, so `TextStyle()` is the untemplated caption.
struct TextStyle {
    var weight = "bold"
    var align = "center"
    var tracking: CGFloat = 0
    /// nil => line height from font metrics (the original formula); set => size * value.
    var leading: CGFloat? = nil
    var maxLines = 2
    /// The per-step multiplier, NOT the step. `autoShrink.step` is converted by the
    /// caller as `1 - step`; the default is the literal 0.94 the original code used,
    /// because `1 - 0.06` is a different double from `0.94` and would walk a different
    /// shrink sequence — enough to change output bytes on any caption that shrinks.
    var shrinkMultiplier: CGFloat = 0.94
    var shrinkFloor: CGFloat = 0.60
}

/// Line height for a field set at `size`, independent of how much text it holds.
///
/// The fixed reserved text block sizes its caption slot with this at the BASE size, not
/// at the auto-shrunk size a particular caption ended up with. Reserving the shrunken
/// height would let a long, shrunken caption pull the subtitle upward — the very reflow
/// the fixed block exists to prevent, and it would show up as the subtitle sitting at a
/// different height on different screenshots in the same set.
func lineHeight(size: CGFloat, style: TextStyle) -> CGFloat {
    if let leading = style.leading { return size * leading }
    let font = systemFont(size: size, weight: style.weight)
    return (CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)) * 1.12
}

/// Fit `text` into at most `style.maxLines` lines: shrink in `shrinkStep` steps down to
/// `shrinkFloor` of the base size, then truncate the last line with an ellipsis as a
/// last resort. Caption and subtitle are laid out by separate calls, so they shrink
/// INDEPENDENTLY — a long caption never shrinks the subtitle with it.
func layoutText(_ text: String, baseSize: CGFloat, width: CGFloat, color: CGColor,
                style: TextStyle, label: String, outputName: String) -> CaptionLayout {
    var size = baseSize
    let minSize = baseSize * style.shrinkFloor
    let maxLines = max(style.maxLines, 1)
    while true {
        let font = systemFont(size: size, weight: style.weight)
        let lines = breakLines(text, font: font, color: color, width: width, tracking: style.tracking)
        let lineHeight = style.leading.map { size * $0 }
            ?? (CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)) * 1.12
        if lines.count <= maxLines || size <= minSize {
            if lines.count <= maxLines {
                return CaptionLayout(lines: lines, font: font, lineHeight: lineHeight)
            }
            // Truncate: keep the first maxLines-1 lines, truncate the remainder into the last.
            let attr = attributed(text, font: font, color: color, tracking: style.tracking)
            let full = NSAttributedString(attributedString: attr as NSAttributedString)
            let kept = Array(lines.prefix(maxLines - 1))
            // maxLines == 1 keeps nothing, so the truncated line is the whole string.
            var cut = 0
            if maxLines >= 2 {
                let lastKept = CTLineGetStringRange(lines[maxLines - 2])
                cut = lastKept.location + lastKept.length
            }
            let rest = full.attributedSubstring(from: NSRange(location: cut, length: full.length - cut))
            let ellipsis = CTLineCreateWithAttributedString(
                attributed("\u{2026}", font: font, color: color, tracking: style.tracking))
            let restLine = CTLineCreateWithAttributedString(rest as CFAttributedString)
            let truncated = CTLineCreateTruncatedLine(restLine, Double(width), .end, ellipsis) ?? lines[maxLines - 1]
            print("WARN \(outputName): \(label) too long for \(maxLines) line\(maxLines == 1 ? "" : "s") even at minimum size — truncated")
            return CaptionLayout(lines: kept + [truncated], font: font, lineHeight: lineHeight)
        }
        size *= style.shrinkMultiplier
        if size < minSize { size = minSize }
    }
}

// MARK: - Job model

struct Job {
    let order: Int
    let id: String
    let deviceClass: DeviceClass
    let appearance: String
    let orientation: String
    let text: CaptionText
    let capturePath: String
    let framePath: String
    let frameKey: String
    let outputPath: String
    var isLandscape: Bool { orientation == "landscape" }
}

// MARK: - Rendering

func aspectFillRect(source: CGSize, into target: CGRect) -> CGRect {
    let scale = max(target.width / source.width, target.height / source.height)
    let w = source.width * scale, h = source.height * scale
    return CGRect(x: target.midX - w / 2, y: target.midY - h / 2, width: w, height: h)
}

/// All four corners rounded. CG coordinates (bottom-left origin) in, path out.
func roundedRectPath(_ r: CGRect, radius: CGFloat) -> CGPath {
    let rad = min(radius, min(r.width, r.height) / 2)
    let p = CGMutablePath()
    p.move(to: CGPoint(x: r.minX + rad, y: r.minY))
    p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.maxY), radius: rad)
    p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY), radius: rad)
    p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.minY), radius: rad)
    p.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY), radius: rad)
    p.closeSubpath()
    return p
}

/// The panel shape: TOP corners rounded, bottom corners square — because the panel is
/// meant to run off the bottom of the canvas, where a rounded corner would read as a
/// floating card that got cropped rather than as a ground the device stands on.
/// CG coordinates, so `maxY` is the visual top.
func topRoundedRectPath(_ r: CGRect, radius: CGFloat) -> CGPath {
    let rad = min(radius, min(r.width / 2, r.height))
    let p = CGMutablePath()
    p.move(to: CGPoint(x: r.minX, y: r.minY))
    p.addLine(to: CGPoint(x: r.minX, y: r.maxY - rad))
    p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX + rad, y: r.maxY), radius: rad)
    p.addLine(to: CGPoint(x: r.maxX - rad, y: r.maxY))
    p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.maxX, y: r.maxY - rad), radius: rad)
    p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
    p.closeSubpath()
    return p
}

func compose(job: Job, frame: CGImage, screenRect: CGRect, capture: CGImage,
             cutoutMask: CGImage?, template t: Template, lockupIcons: [String: CGImage]) throws {
    let size = job.deviceClass.outputSize(landscape: job.isLandscape)
    let W = size.width, H = size.height
    let isDark = job.appearance == "dark"
    let mode = isDark ? "dark" : "light"
    let dc = job.deviceClass
    let g = ["geometry", dc.name]                  // per-class geometry keypath prefix
    let c = ["colors", mode]                       // per-appearance colour keypath prefix
    let outputName = (job.outputPath as NSString).lastPathComponent

    // Every default below is the plain style's original value, so an absent template
    // walks the same arithmetic the pre-templating script did.
    let bg = t.color(c + ["background"], isDark ? rgb(0x1C1C1E) : rgb(0xF5F5F7))
    let fg = t.color(c + ["caption"], isDark ? rgb(0xF5F5F7) : rgb(0x1D1D1F))
    let subtitleColor = t.color(c + ["subtitle"], fg)
    let panelColor = t.color(c + ["panel"], fg)
    let lockupColor = t.color(c + ["lockup"], fg)

    // noneSkipFirst → an opaque sRGB canvas; App Store screenshots must not carry alpha.
    guard let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
        throw NSError(domain: "compose", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "could not create canvas for \(job.outputPath)"])
    }
    ctx.setFillColor(bg)
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

    let inset = t.num(g + ["sideInset"], 0.08) * W
    let shrinkFloor = t.num(["autoShrink", "floor"], 0.60)
    // `1 - step` only when the template actually sets a step; see TextStyle.shrinkMultiplier.
    let shrinkMultiplier = t.optNum(["autoShrink", "step"]).map { 1 - $0 } ?? 0.94

    ctx.textMatrix = .identity

    /// Draw one laid-out block at `top` (top-left origin) inside a column.
    func draw(_ layout: CaptionLayout, top: CGFloat, align: String,
              columnLeft: CGFloat, columnWidth: CGFloat) {
        let ascent = CTFontGetAscent(layout.font)
        for (n, line) in layout.lines.enumerated() {
            let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            let baselineFromTop = top + CGFloat(n) * layout.lineHeight + ascent
            let x: CGFloat
            switch align {
            case "left":  x = columnLeft
            case "right": x = columnLeft + columnWidth - lineWidth
            default:      x = columnLeft + (columnWidth - lineWidth) / 2
            }
            ctx.textPosition = CGPoint(x: x, y: H - baselineFromTop)
            CTLineDraw(line, ctx)
        }
    }

    // --- panel (behind everything: the ground the device stands on) ---
    if t.bool(["panel", "enabled"], false) {
        let px = t.num(g + ["panelX"], 0) * W
        let pw = t.num(g + ["panelWidth"], 0) * W
        let panelTop = t.num(g + ["panelTop"], 0) * H
        // Bleeding to the bottom is the point of the panel; when it is turned off the
        // panel closes with the same margin it carries on the sides.
        let panelBottom = t.bool(["panel", "bleedsToBottom"], true) ? H : H - px
        if pw > 0, panelBottom > panelTop {
            let rect = CGRect(x: px, y: H - panelBottom, width: pw, height: panelBottom - panelTop)
            ctx.setFillColor(panelColor)
            ctx.addPath(topRoundedRectPath(rect, radius: t.num(g + ["panelTopCornerRadius"], 0) * W))
            ctx.fillPath()
        }
    }

    // --- lockup (icon + wordmark, above the caption) ---
    if t.bool(["lockup", "enabled"], false) {
        let iconSize = t.num(g + ["lockupIconSize"], 0) * W
        let lockupTop = t.num(g + ["lockupTop"], 0) * H
        var penX = inset
        if let icon = lockupIcons[mode], iconSize > 0 {
            let rect = CGRect(x: penX, y: H - lockupTop - iconSize, width: iconSize, height: iconSize)
            ctx.saveGState()
            ctx.addPath(roundedRectPath(rect, radius: iconSize * t.num(["lockup", "iconCornerRadiusFraction"], 0.225)))
            ctx.clip()
            ctx.draw(icon, in: rect)
            ctx.restoreGState()
            penX += iconSize + t.num(g + ["lockupIconTextGap"], 0) * W
        }
        let word = t.str(["lockup", "text"], "")
        if !word.isEmpty {
            let fontSize = t.num(g + ["lockupTextSize"], 0) * W
            if fontSize > 0 {
                let font = systemFont(size: fontSize, weight: "bold")
                let line = CTLineCreateWithAttributedString(
                    attributed(word, font: font, color: lockupColor,
                               tracking: t.num(g + ["lockupTextTracking"], 0)))
                // Optically centre the wordmark on the icon: centre the ascender-to-
                // descender span, not the em box.
                let baselineFromTop = lockupTop + iconSize / 2
                    + (CTFontGetAscent(font) - CTFontGetDescent(font)) / 2
                ctx.textPosition = CGPoint(x: penX, y: H - baselineFromTop)
                CTLineDraw(line, ctx)
            }
        }
    }

    // --- caption ---
    var captionStyle = TextStyle()
    captionStyle.weight = t.str(["caption", "weight"], "bold")
    captionStyle.align = t.str(["caption", "align"], "center")
    captionStyle.tracking = t.num(g + ["captionTracking"], 0)
    captionStyle.leading = t.optNum(g + ["captionLeading"])
    captionStyle.maxLines = t.int(["caption", "maxLines"], 2)
    captionStyle.shrinkMultiplier = shrinkMultiplier
    captionStyle.shrinkFloor = shrinkFloor

    let captionColumn = t.optNum(g + ["captionColumnWidth"]).map { $0 * W } ?? (W - inset * 2)
    let captionBase = t.num(g + ["captionSize"], dc.captionSizeFraction) * W
    let layout = layoutText(job.text.caption, baseSize: captionBase, width: captionColumn,
                            color: fg, style: captionStyle, label: "caption", outputName: outputName)

    let topMargin = t.num(g + ["captionTop"], 0.05) * H

    // The FIXED reserved text block: caption and subtitle sit in slots derived from
    // textBlockTop, with the caption always reserving its full maxLines whether or not
    // it uses them. That is what holds the subtitle — and therefore the panel and the
    // device — at the same height across a whole set. Without these keys the caption
    // flows from captionTop exactly as it always did.
    let blockTop = t.optNum(g + ["textBlockTop"])
    let captionOrigin = blockTop.map { $0 * H } ?? topMargin
    draw(layout, top: captionOrigin, align: captionStyle.align,
         columnLeft: inset, columnWidth: captionColumn)

    // --- subtitle (only when a template is present; the plain style has no slot) ---
    var subtitleBottom = captionOrigin + layout.height
    if t.present, let subtitleText = job.text.subtitle {
        var subStyle = TextStyle()
        subStyle.weight = t.str(["subtitle", "weight"], "regular")
        subStyle.align = t.str(["subtitle", "align"], captionStyle.align)
        subStyle.tracking = t.num(g + ["subtitleTracking"], 0)
        subStyle.leading = t.optNum(g + ["subtitleLeading"])
        subStyle.maxLines = t.int(["subtitle", "maxLines"], 2)
        subStyle.shrinkMultiplier = shrinkMultiplier
        subStyle.shrinkFloor = shrinkFloor

        let subColumn = t.optNum(g + ["subtitleColumnWidth"]).map { $0 * W } ?? captionColumn
        let subBase = t.num(g + ["subtitleSize"], dc.captionSizeFraction * 0.5) * W
        let subLayout = layoutText(subtitleText, baseSize: subBase, width: subColumn,
                                   color: subtitleColor, style: subStyle,
                                   label: "subtitle", outputName: outputName)
        let gapToSubtitle = t.num(g + ["gapCaptionToSubtitle"], 0) * H
        // Reserve maxLines of caption at the BASE size in the fixed case, so neither a
        // one-line caption nor an auto-shrunk one moves the subtitle; flow directly
        // after the caption otherwise.
        let reservedCaption = blockTop != nil
            ? CGFloat(captionStyle.maxLines) * lineHeight(size: captionBase, style: captionStyle)
            : layout.height
        let subOrigin = captionOrigin + reservedCaption + gapToSubtitle
        draw(subLayout, top: subOrigin, align: subStyle.align,
             columnLeft: inset, columnWidth: subColumn)
        subtitleBottom = subOrigin + subLayout.height
        if let blockBottom = t.optNum(g + ["textBlockBottom"]).map({ $0 * H }),
           subtitleBottom > blockBottom + 1 {
            print("WARN \(outputName): subtitle overflows the reserved text block "
                + "(ends at \(Int(subtitleBottom))px, textBlockBottom is \(Int(blockBottom))px) "
                + "— raise textBlockBottom, or lower subtitleSize/maxLines")
        }
    }

    // --- device placement ---
    let fw = CGFloat(frame.width), fh = CGFloat(frame.height)
    let frameRect: CGRect
    let scale: CGFloat
    if let deviceTop = t.optNum(g + ["deviceTop"]), let deviceWidth = t.optNum(g + ["deviceWidth"]) {
        // PINNED: fixed top and width. The device may run past the bottom canvas edge
        // and clip — deliberately, so it reads as continuing beyond the frame. Clipping
        // is done by the canvas alone; the capture is never scaled non-uniformly.
        let drawW = deviceWidth * W
        scale = drawW / fw
        let drawH = fh * scale
        let originYTop = deviceTop * H
        frameRect = CGRect(x: (W - drawW) / 2, y: H - originYTop - drawH, width: drawW, height: drawH)
    } else {
        // FITTED (the original behaviour): the device takes the space left below the
        // caption, shrinking to fit rather than bleeding.
        let gap = H * 0.04
        let bottomMargin = H * 0.03
        // With a fixed text block the device starts below the block's fixed bottom, so
        // it too stays put across a set; otherwise it follows the flowed text as before.
        let textBottom = t.optNum(g + ["textBlockBottom"]).map { $0 * H }
            ?? (blockTop != nil ? subtitleBottom : topMargin + layout.height)
        let frameTop = textBottom + gap
        let availableHeight = max(H - frameTop - bottomMargin, 1)
        let widthBudget = W * dc.frameWidthFraction
        scale = min(widthBudget / fw, availableHeight / fh)
        let drawW = fw * scale, drawH = fh * scale
        let originX = (W - drawW) / 2
        let originYTop = frameTop + (availableHeight - drawH) / 2
        // CoreGraphics is bottom-left origin; convert from our top-left layout maths.
        frameRect = CGRect(x: originX, y: H - originYTop - drawH, width: drawW, height: drawH)
    }

    // --- drop shadow ---
    // Cast from the bezel's own silhouette by drawing the frame once with a shadow set,
    // before the capture goes down. The frame is drawn again at the end without the
    // shadow, so this pass contributes only the shadow that falls outside it.
    if t.bool(["shadow", "enabled"], false) {
        let opacity = isDark ? t.num(["shadow", "opacityDark"], 0.50)
                             : t.num(["shadow", "opacityLight"], 0.28)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -t.num(g + ["shadowOffsetY"], 0) * H),
                      blur: t.num(g + ["shadowBlur"], 0) * W,
                      color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: opacity))
        ctx.draw(frame, in: frameRect)
        ctx.restoreGState()
    }

    // Screen rect (frame pixels, top-left origin) → canvas coordinates.
    let screenOnCanvas = CGRect(
        x: frameRect.minX + screenRect.minX * scale,
        y: frameRect.maxY - (screenRect.minY + screenRect.height) * scale,
        width: screenRect.width * scale,
        height: screenRect.height * scale)

    // The capture goes BENEATH the bezel: the bezel PNG's own alpha (rounded corners,
    // notch/island) then masks the capture's edges for free, and any 1px seam is
    // covered by the bezel rather than showing as a gap.
    ctx.saveGState()
    // Clip to the cutout's real shape so the capture cannot show in the corner slivers
    // the bezel does not cover (see FrameAnalysis). Defaults to whether a panel is
    // drawn: that is exactly when a coloured ground sits behind the device and makes
    // the spill visible. With no panel — including every untemplated render — the
    // default is off, which is what keeps the plain style byte-identical.
    let clipToBezel = t.bool(["device", "clipCaptureToBezel"], t.bool(["panel", "enabled"], false))
    ctx.clip(to: screenOnCanvas)
    if clipToBezel, let mask = cutoutMask {
        ctx.clip(to: frameRect, mask: mask)   // intersects with the screen rect above
    }
    let captureSize = CGSize(width: capture.width, height: capture.height)
    ctx.draw(capture, in: aspectFillRect(source: captureSize, into: screenOnCanvas))
    ctx.restoreGState()

    ctx.draw(frame, in: frameRect)

    guard let image = ctx.makeImage() else {
        throw NSError(domain: "compose", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "could not render \(job.outputPath)"])
    }
    let dir = (job.outputPath as NSString).deletingLastPathComponent
    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let type = (UTType.png.identifier as CFString)
    guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: job.outputPath) as CFURL, type, 1, nil) else {
        throw NSError(domain: "compose", code: 3,
                      userInfo: [NSLocalizedDescriptionKey: "could not open \(job.outputPath) for writing"])
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        throw NSError(domain: "compose", code: 4,
                      userInfo: [NSLocalizedDescriptionKey: "could not write \(job.outputPath)"])
    }
    print("wrote \(job.outputPath) (\(Int(W))x\(Int(H)))")
}

// MARK: - Stale-output pruning
//
// The output path is fully deterministic ({order}_{class}_{id}.png), so re-composing an
// UNCHANGED plan is a clean in-place overwrite. But any plan edit that changes a FILENAME
// — reordering a row, renaming an id, deleting a row, narrowing `devices` — used to leave
// the old file behind forever. Since docs/store/screenshots/ is committed, an orphan is a
// tracked, unmodified file: invisible in `git status` and in PR diffs, so nothing ever
// surfaces it, and whoever uploads to App Store Connect has to guess which files are current.
//
// Three constraints make this safe rather than destructive:
//   * Runs strictly AFTER validation succeeds. compose is all-or-nothing; delete-then-fail
//     would leave the user with no screenshots at all, which is worse than the orphans.
//   * SKIPPED under --dry-run (side-effect-free validation probe) and under --only (which
//     composes a deliberate subset — wiping the locale there would delete rows the user
//     chose not to recompose). Skipping under --only is the safer of the two options; a
//     full `--only`-less run afterwards still prunes everything.
//   * Only removes files matching compose's OWN output pattern, {digits}_{knownclass}_*.png.
//     screenshots/{locale}/ lives in the user's git repo and may hold something a human put
//     there; a tool that deletes files it did not create is one bad assumption from
//     destroying work.
/// Remove previously-composed screenshots in `dir` that the current plan will not rewrite.
/// Returns the number of files removed.
@discardableResult
func pruneStaleOutputs(dir: String, keeping expected: Set<String>) -> Int {
    let fm = FileManager.default
    guard let names = try? fm.contentsOfDirectory(atPath: dir) else { return 0 }  // nothing composed yet
    var removed = 0
    for name in names.sorted() {
        guard name.hasSuffix(".png"), !expected.contains(name) else { continue }
        // Ours only: "{order}_{class}_{id}.png" with a positive integer order and a class we know.
        let parts = name.dropLast(4).split(separator: "_", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3,
              let order = Int(parts[0]), order >= 1,
              deviceClasses[String(parts[1])] != nil,
              !parts[2].isEmpty else { continue }
        do {
            try fm.removeItem(atPath: dir + "/" + name)
            removed += 1
        } catch {
            die("could not remove stale screenshot \(dir)/\(name): \(error.localizedDescription)")
        }
    }
    return removed
}

// MARK: - Main

let opts = parseArgs(Array(CommandLine.arguments.dropFirst()))
guard let locale = opts.locale, !locale.isEmpty else {
    FileHandle.standardError.write(Data(("compose: --locale is required\n\n" + usageText + "\n").utf8))
    exit(2)
}

let storeDir = opts.storeDir
let planPath = "\(storeDir)/screenshots.md"
let captionsPath = "\(storeDir)/metadata/\(locale)/screenshot-captions.txt"
let framesDir = "\(storeDir)/frames"
let outputDir = "\(storeDir)/screenshots/\(locale)"

let templatePath = "\(storeDir)/template.json"

var errors: [String] = []
var rows = parsePlan(path: planPath, errors: &errors)
let captions = parseCaptions(path: captionsPath, errors: &errors)
let frameOverrides = loadFramesJSON(path: "\(framesDir)/frames.json", errors: &errors)
let template = loadTemplate(path: templatePath, errors: &errors)
validateTemplateCoherence(template, path: templatePath, errors: &errors)

// Lockup icons are loaded up front so a corrupt PNG is a validation error like any
// other, rather than a surprise partway through writing the set.
var lockupIcons: [String: CGImage] = [:]
if template.bool(["lockup", "enabled"], false) {
    for mode in ["light", "dark"] {
        guard let rel = template.optStr(["lockup", "icon", mode]) else { continue }
        let path = rel.hasPrefix("/") ? rel : "\(template.baseDir)/\(rel)"
        if let img = loadImage(path) {
            lockupIcons[mode] = img
        } else if FileManager.default.fileExists(atPath: path) {
            // Missing-file is already reported by schema validation; this is the
            // present-but-undecodable case.
            errors.append("\(templatePath): 'lockup.icon.\(mode)' could not be decoded as an image: \(path)")
        }
    }
}

if !opts.only.isEmpty {
    let wanted = Set(opts.only)
    let known = Set(rows.map(\.id))
    for id in wanted where !known.contains(id) {
        errors.append("--only: no plan row with id '\(id)'")
    }
    rows = rows.filter { wanted.contains($0.id) }
}

// Build the job list; every missing input is collected, never thrown at first sight.
var jobs: [Job] = []
var frameCache: [String: CGImage] = [:]
var screenCache: [String: CGRect] = [:]
var maskCache: [String: CGImage] = [:]

// maxChars is an authoring budget, not a rendering constraint (the auto-shrink already
// guarantees the text fits), so exceeding it warns rather than failing the run.
let captionMaxChars = template.int(["caption", "maxChars"], 0)
let subtitleMaxChars = template.int(["subtitle", "maxChars"], 0)

for row in rows {
    guard let caption = captions[row.id] else {
        errors.append("missing caption for id '\(row.id)' in \(captionsPath)")
        continue
    }
    if captionMaxChars > 0 && caption.caption.count > captionMaxChars {
        print("WARN \(captionsPath): caption for '\(row.id)' is \(caption.caption.count) chars, over the template's caption.maxChars of \(captionMaxChars) — it will be shrunk to fit")
    }
    if let sub = caption.subtitle, subtitleMaxChars > 0, sub.count > subtitleMaxChars {
        print("WARN \(captionsPath): subtitle for '\(row.id)' is \(sub.count) chars, over the template's subtitle.maxChars of \(subtitleMaxChars) — it will be shrunk to fit")
    }
    for className in row.devices {
        guard let dc = deviceClasses[className] else { continue }
        let frameKey = row.isLandscape ? "\(className)-landscape" : className
        let framePath = "\(framesDir)/\(frameKey).png"
        let suffix = row.isLandscape ? "-\(row.orientation)" : ""
        let capturePath = "\(opts.captures)/\(locale)/\(row.id)/\(row.id)-\(className)-\(row.appearance)\(suffix).png"
        let outputPath = "\(outputDir)/\(row.order)_\(className)_\(row.id).png"

        if !FileManager.default.fileExists(atPath: capturePath) {
            errors.append("missing capture: \(capturePath) — run: scripts/sim.sh shots \(row.id) --store --locale \(locale)")
        }
        if frameCache[frameKey] == nil {
            if let img = loadImage(framePath) {
                frameCache[frameKey] = img
                let analysis = analyzeFrame(img)
                // A frames.json override replaces the detected BOX; the shape mask still
                // comes from the bezel's own alpha, which is what it was always derived from.
                maskCache[frameKey] = analysis.cutoutMask
                if let override = frameOverrides[frameKey] {
                    screenCache[frameKey] = override
                } else if let detected = analysis.screenRect {
                    screenCache[frameKey] = detected
                } else {
                    errors.append("\(framePath): no interior transparent screen cutout found — the bezel PNG needs a fully transparent screen area, or add a frames.json entry: {\"\(frameKey)\": {\"screen\": [x, y, w, h]}}")
                }
            } else {
                errors.append("missing frame: \(framePath) — Export a bezel PNG with a transparent screen cutout from Apple Design Resources (https://developer.apple.com/design/resources/) as docs/store/frames/\(className).png")
            }
        }

        jobs.append(Job(order: row.order, id: row.id, deviceClass: dc, appearance: row.appearance,
                        orientation: row.orientation, text: caption, capturePath: capturePath,
                        framePath: framePath, frameKey: frameKey, outputPath: outputPath))
    }
}

if !errors.isEmpty {
    FileHandle.standardError.write(Data("compose: validation failed (\(errors.count) problem\(errors.count == 1 ? "" : "s")); nothing was written\n".utf8))
    for e in errors { FileHandle.standardError.write(Data("  ERROR \(e)\n".utf8)) }
    exit(1)
}

let ordered = jobs.sorted { ($0.order, $0.deviceClass.name, $0.id) < ($1.order, $1.deviceClass.name, $1.id) }

if opts.dryRun {
    for job in ordered {
        print("\(job.order) \(job.id) \(job.deviceClass.name) \(job.appearance) \(job.orientation): \(job.capturePath) + \(job.framePath) -> \(job.outputPath)")
    }
    print("compose: plan valid — \(ordered.count) screenshot\(ordered.count == 1 ? "" : "s") would be written to \(outputDir)")
    exit(0)
}

// Clear stale output BEFORE writing, so the composed set always matches the plan exactly.
// Never under --dry-run (must stay side-effect free) or --only (a deliberate subset).
if opts.only.isEmpty {
    let expected = Set(ordered.map { ($0.outputPath as NSString).lastPathComponent })
    let removed = pruneStaleOutputs(dir: outputDir, keeping: expected)
    if removed > 0 {
        print("compose: removed \(removed) stale screenshot\(removed == 1 ? "" : "s") (plan changed)")
    }
}

for job in ordered {
    guard let frame = frameCache[job.frameKey], let screen = screenCache[job.frameKey] else {
        die("internal: frame '\(job.frameKey)' not loaded")
    }
    guard let capture = loadImage(job.capturePath) else {
        die("could not decode capture: \(job.capturePath)")
    }
    do {
        try compose(job: job, frame: frame, screenRect: screen, capture: capture,
                    cutoutMask: maskCache[job.frameKey],
                    template: template, lockupIcons: lockupIcons)
    } catch {
        die(error.localizedDescription)
    }
}
print("compose: \(ordered.count) screenshots -> \(outputDir)")
