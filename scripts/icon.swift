import AppKit
let output = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(calibratedRed: 0.77, green: 0.06, blue: 0.18, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: 920, height: 920), xRadius: 205, yRadius: 205).fill()
NSColor.white.setFill()
for (i, h) in [240, 410, 580].enumerated() {
 NSBezierPath(roundedRect: NSRect(x: 230 + 200 * i, y: 235, width: 130, height: h), xRadius: 42, yRadius: 42).fill()
}
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
