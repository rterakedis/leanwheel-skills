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
//         {store}/metadata/{locale}/screenshot-captions.txt   `id: Caption text` lines, `#` comments
//         {store}/frames/{class}.png                   portrait bezel  (user-supplied)
//         {store}/frames/{class}-landscape.png         landscape bezel (user-supplied)
//         {store}/frames/frames.json (optional)        {"iphone69": {"screen": [x,y,w,h]}, ...}
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
       {captures}/{locale}/{id}/{id}-{class}-{appearance}[-landscape].png
writes {store-dir}/screenshots/{locale}/{#}_{class}_{id}.png (sRGB, no alpha, exact store size)

Device bezels are user-supplied: export one with a transparent screen cutout from
Apple Design Resources (https://developer.apple.com/design/resources/).
"""

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0, alpha: 1.0)
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

/// `id: Caption text` — `#` comments and blank lines ignored; the caption may itself
/// contain colons, so only the first colon separates.
func parseCaptions(path: String, errors: inout [String]) -> [String: String] {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        errors.append("missing captions file: \(path)")
        return [:]
    }
    var out: [String: String] = [:]
    for (n, raw) in text.components(separatedBy: .newlines).enumerated() {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line.isEmpty || line.hasPrefix("#") { continue }
        guard let colon = line.firstIndex(of: ":") else {
            errors.append("\(path):\(n + 1): expected 'id: Caption text'")
            continue
        }
        let id = String(line[line.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
        let caption = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        if id.isEmpty || caption.isEmpty {
            errors.append("\(path):\(n + 1): expected 'id: Caption text'")
            continue
        }
        out[id] = caption
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
func detectScreenRect(_ image: CGImage) -> CGRect? {
    let w = image.width, h = image.height
    guard w > 0, h > 0 else { return nil }

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
    guard ok else { return nil }
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
    guard maxX >= minX, maxY >= minY else { return nil }
    // Flip to top-left origin for the frames.json / caller convention.
    let topY = h - 1 - maxY
    return CGRect(x: CGFloat(minX), y: CGFloat(topY),
                  width: CGFloat(maxX - minX + 1), height: CGFloat(maxY - minY + 1))
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

func systemFont(size: CGFloat, bold: Bool) -> CTFont {
    let base = CTFontCreateUIFontForLanguage(.system, size, nil)
        ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
    guard bold else { return base }
    // Bold via symbolic traits; some system font instances refuse the copy, in which
    // case the regular face is a perfectly acceptable fallback.
    return CTFontCreateCopyWithSymbolicTraits(base, size, nil, .boldTrait, .boldTrait) ?? base
}

func attributed(_ text: String, font: CTFont, color: CGColor) -> CFAttributedString {
    // CoreText attribute keys, not AppKit's NSAttributedString.Key extensions — this is
    // a Foundation-only script with no AppKit link.
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(rawValue: kCTFontAttributeName as String): font,
        NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String): color,
    ]
    // Centring is done by hand when the lines are drawn, so no paragraph style is needed.
    return NSAttributedString(string: text, attributes: attrs) as CFAttributedString
}

/// Break `text` into typeset lines that fit `width` at `font`.
func breakLines(_ text: String, font: CTFont, color: CGColor, width: CGFloat) -> [CTLine] {
    let attr = attributed(text, font: font, color: color)
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

/// Fit the caption to at most 2 lines: shrink in 6% steps down to 60% of the base
/// size, then truncate the second line with an ellipsis as a last resort.
func layoutCaption(_ text: String, baseSize: CGFloat, width: CGFloat, color: CGColor,
                   outputName: String) -> CaptionLayout {
    var size = baseSize
    let minSize = baseSize * 0.6
    while true {
        let font = systemFont(size: size, bold: true)
        let lines = breakLines(text, font: font, color: color, width: width)
        let lineHeight = (CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)) * 1.12
        if lines.count <= 2 || size <= minSize {
            if lines.count <= 2 {
                return CaptionLayout(lines: lines, font: font, lineHeight: lineHeight)
            }
            // Truncate: keep line 1, truncate the remainder into line 2.
            let attr = attributed(text, font: font, color: color)
            let full = NSAttributedString(attributedString: attr as NSAttributedString)
            let firstRange = CTLineGetStringRange(lines[0])
            let rest = full.attributedSubstring(from: NSRange(location: firstRange.location + firstRange.length,
                                                             length: full.length - (firstRange.location + firstRange.length)))
            let ellipsis = CTLineCreateWithAttributedString(attributed("\u{2026}", font: font, color: color))
            let restLine = CTLineCreateWithAttributedString(rest as CFAttributedString)
            let truncated = CTLineCreateTruncatedLine(restLine, Double(width), .end, ellipsis) ?? lines[1]
            print("WARN \(outputName): caption too long for 2 lines even at minimum size — truncated")
            return CaptionLayout(lines: [lines[0], truncated], font: font, lineHeight: lineHeight)
        }
        size *= 0.94
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
    let caption: String
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

func compose(job: Job, frame: CGImage, screenRect: CGRect, capture: CGImage) throws {
    let size = job.deviceClass.outputSize(landscape: job.isLandscape)
    let W = size.width, H = size.height
    let isDark = job.appearance == "dark"
    let bg = isDark ? rgb(0x1C1C1E) : rgb(0xF5F5F7)
    let fg = isDark ? rgb(0xF5F5F7) : rgb(0x1D1D1F)

    // noneSkipFirst → an opaque sRGB canvas; App Store screenshots must not carry alpha.
    guard let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
        throw NSError(domain: "compose", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "could not create canvas for \(job.outputPath)"])
    }
    ctx.setFillColor(bg)
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

    // --- caption ---
    let inset = W * 0.08
    let textWidth = W - inset * 2
    let baseSize = W * job.deviceClass.captionSizeFraction
    let layout = layoutCaption(job.caption, baseSize: baseSize, width: textWidth,
                               color: fg, outputName: (job.outputPath as NSString).lastPathComponent)
    let topMargin = H * 0.05
    let ascent = CTFontGetAscent(layout.font)
    ctx.textMatrix = .identity
    for (n, line) in layout.lines.enumerated() {
        let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let baselineFromTop = topMargin + CGFloat(n) * layout.lineHeight + ascent
        ctx.textPosition = CGPoint(x: (W - lineWidth) / 2, y: H - baselineFromTop)
        CTLineDraw(line, ctx)
    }

    // --- frame placement ---
    let gap = H * 0.04
    let bottomMargin = H * 0.03
    let frameTop = topMargin + layout.height + gap
    let availableHeight = max(H - frameTop - bottomMargin, 1)
    let widthBudget = W * job.deviceClass.frameWidthFraction
    let fw = CGFloat(frame.width), fh = CGFloat(frame.height)
    let scale = min(widthBudget / fw, availableHeight / fh)
    let drawW = fw * scale, drawH = fh * scale
    let originX = (W - drawW) / 2
    let originYTop = frameTop + (availableHeight - drawH) / 2
    // CoreGraphics is bottom-left origin; convert from our top-left layout maths.
    let frameRect = CGRect(x: originX, y: H - originYTop - drawH, width: drawW, height: drawH)

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
    ctx.clip(to: screenOnCanvas)
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

var errors: [String] = []
var rows = parsePlan(path: planPath, errors: &errors)
let captions = parseCaptions(path: captionsPath, errors: &errors)
let frameOverrides = loadFramesJSON(path: "\(framesDir)/frames.json", errors: &errors)

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

for row in rows {
    guard let caption = captions[row.id] else {
        errors.append("missing caption for id '\(row.id)' in \(captionsPath)")
        continue
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
                if let override = frameOverrides[frameKey] {
                    screenCache[frameKey] = override
                } else if let detected = detectScreenRect(img) {
                    screenCache[frameKey] = detected
                } else {
                    errors.append("\(framePath): no interior transparent screen cutout found — the bezel PNG needs a fully transparent screen area, or add a frames.json entry: {\"\(frameKey)\": {\"screen\": [x, y, w, h]}}")
                }
            } else {
                errors.append("missing frame: \(framePath) — Export a bezel PNG with a transparent screen cutout from Apple Design Resources (https://developer.apple.com/design/resources/) as docs/store/frames/\(className).png")
            }
        }

        jobs.append(Job(order: row.order, id: row.id, deviceClass: dc, appearance: row.appearance,
                        orientation: row.orientation, caption: caption, capturePath: capturePath,
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

for job in ordered {
    guard let frame = frameCache[job.frameKey], let screen = screenCache[job.frameKey] else {
        die("internal: frame '\(job.frameKey)' not loaded")
    }
    guard let capture = loadImage(job.capturePath) else {
        die("could not decode capture: \(job.capturePath)")
    }
    do {
        try compose(job: job, frame: frame, screenRect: screen, capture: capture)
    } catch {
        die(error.localizedDescription)
    }
}
print("compose: \(ordered.count) screenshots -> \(outputDir)")
