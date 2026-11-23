import AppKit
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let red = NSColor(calibratedRed: 0.77, green: 0.06, blue: 0.18, alpha: 1)
func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ color: NSColor = .labelColor, bold: Bool = false) {
    (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular), .foregroundColor: color])
}
func render(_ name: String, height: CGFloat, drawing: () -> Void) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1600, pixelsHigh: Int(height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSColor(calibratedWhite: 0.975, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: 1600, height: height).fill()
    drawing()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.94])!.write(to: root.appendingPathComponent(name))
}
try render("hero-banner.jpg", height: 700) {
    red.setFill(); NSBezierPath(roundedRect: NSRect(x: 85, y: 440, width: 110, height: 110), xRadius: 26, yRadius: 26).fill()
    NSColor.white.setFill()
    for (i,h) in [30.0,50,72].enumerated() { NSBezierPath(roundedRect: NSRect(x: 106 + Double(i)*24, y: 460, width: 16, height: h), xRadius: 5, yRadius: 5).fill() }
    text("汇芯 token 管家", 230, 464, 62, bold: true)
    text("只看额度与预测", 85, 300, 82, bold: true)
    text("Codex   /   Antigravity   /   WorkBuddy", 90, 210, 32, .secondaryLabelColor)
    text("原创三栏界面    ·    独立自动同步    ·    可解释的用量预测", 90, 140, 26, red)
    text("致敬与感谢 Peter Steinberger / CodexBar 社区 · CodexBarCore v0.85.0 / MIT", 90, 52, 20, .secondaryLabelColor)
}
try render("pipeline-architecture.jpg", height: 680) {
    text("三个服务独立运行，一眼看清额度与节奏", 70, 560, 46, bold: true)
    let titles = ["本机登录", "常驻读取", "独立刷新", "即时展示", "用量预测", "原创面板"]
    let notes = ["本人账号与系统授权", "CodexBarCore v0.85.0", "超时 · 去重 · 失败退避", "先看数据，再后台同步", "真实周期 + 近期趋势", "汇芯 token 管家"]
    for i in 0..<6 {
        let x = CGFloat(70 + i*250)
        NSColor.white.setFill(); NSBezierPath(roundedRect: NSRect(x: x, y: 230, width: 220, height: 220), xRadius: 22, yRadius: 22).fill()
        text(String(format: "%02d", i+1), x+22, 390, 26, red, bold: true)
        text(titles[i], x+22, 322, 30, bold: true)
        text(notes[i], x+20, 270, 13, .secondaryLabelColor)
        if i<5 { text("→", x+225, 325, 20, red) }
    }
    text("读取、会话保护与周期均速预测复用 CodexBar（MIT），保留版权与许可；不复制上游 UI。", 70, 130, 24, .secondaryLabelColor)
    text("袁六伟 · 台州汇芯（公众号 / 视频号：袁六伟）", 70, 65, 20, red)
}
