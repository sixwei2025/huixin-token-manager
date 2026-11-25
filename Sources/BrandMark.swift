import AppKit

enum BrandMark {
    static func image(size: CGFloat, template: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        if !template {
            NSColor(calibratedRed: 0.77, green: 0.06, blue: 0.18, alpha: 1).setFill()
            NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: size * 0.23, yRadius: size * 0.23).fill()
        }
        (template ? NSColor.labelColor : NSColor.white).setFill()
        for (index, height) in [0.27, 0.46, 0.65].enumerated() {
            NSBezierPath(roundedRect: NSRect(x: size * (0.20 + Double(index) * 0.22), y: size * 0.18,
                width: size * 0.145, height: size * height), xRadius: size * 0.045, yRadius: size * 0.045).fill()
        }
        image.unlockFocus()
        image.isTemplate = template
        image.accessibilityDescription = "汇芯 token 管家"
        return image
    }

    static func menuBarImage() -> NSImage {
        Self.image(size: 16, template: true)
    }
}
