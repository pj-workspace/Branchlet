import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("Branchlet-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let shape = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 206, yRadius: 206)
NSGradient(starting: NSColor(red: 0.31, green: 0.60, blue: 0.89, alpha: 1), ending: NSColor(red: 0.12, green: 0.28, blue: 0.52, alpha: 1))!.draw(in: shape, angle: -65)
NSColor.white.withAlphaComponent(0.5).setStroke(); shape.lineWidth = 3; shape.stroke()
let branch = NSBezierPath()
branch.move(to: NSPoint(x: 387, y: 282)); branch.line(to: NSPoint(x: 387, y: 740))
branch.move(to: NSPoint(x: 387, y: 440))
branch.curve(to: NSPoint(x: 652, y: 660), controlPoint1: NSPoint(x: 620, y: 440), controlPoint2: NSPoint(x: 652, y: 535))
branch.lineWidth = 43; branch.lineCapStyle = .round
NSColor.white.withAlphaComponent(0.94).setStroke(); branch.stroke()
for point in [NSPoint(x: 387, y: 282), NSPoint(x: 387, y: 740), NSPoint(x: 652, y: 660)] {
    let circle = NSBezierPath(ovalIn: NSRect(x: point.x - 58, y: point.y - 58, width: 116, height: 116))
    NSColor.white.setFill(); circle.fill()
    let center = NSBezierPath(ovalIn: NSRect(x: point.x - 26, y: point.y - 26, width: 52, height: 52))
    NSColor(red: 0.22, green: 0.44, blue: 0.69, alpha: 1).setFill(); center.fill()
}
image.unlockFocus()
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let filename = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(filename))
    }
}
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", destination.path]
try process.run(); process.waitUntilExit()
if process.terminationStatus != 0 { exit(process.terminationStatus) }
