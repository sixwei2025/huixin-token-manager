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
        let iconSize: CGFloat = 16
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let text = "token" as NSString
        let textSize = text.size(withAttributes: attrs)
        let spacing: CGFloat = 4
        let height: CGFloat = 18
        let width = ceil(iconSize + spacing + textSize.width)
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        let icon = Self.image(size: iconSize, template: true)
        icon.draw(in: NSRect(x: 0, y: (height - iconSize) / 2, width: iconSize, height: iconSize))
        text.draw(at: NSPoint(x: iconSize + spacing, y: (height - textSize.height) / 2), withAttributes: attrs)
        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = "汇芯 token 管家"
        return image
    }
}
