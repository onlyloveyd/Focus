// 生成 Focus 的应用图标：深色圆角矩形底 + 青色靶心。
// 用法: swift Scripts/generate-icon.swift <输出iconset目录>
import AppKit

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"

func draw(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.1807

    // macOS 风格的圆角矩形（squircle 比例）
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()

    // 深色对角渐变底
    let colors = [
        NSColor(srgbRed: 0.16, green: 0.17, blue: 0.28, alpha: 1).cgColor,
        NSColor(srgbRed: 0.05, green: 0.05, blue: 0.11, alpha: 1).cgColor,
    ] as CFArray
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: [])

    // 内描边，一点立体感
    let inset = rect.insetBy(dx: size * 0.012, dy: size * 0.012)
    let border = NSBezierPath(
        roundedRect: inset,
        xRadius: radius - size * 0.012,
        yRadius: radius - size * 0.012)
    border.lineWidth = size * 0.008
    NSColor.white.withAlphaComponent(0.08).setStroke()
    border.stroke()

    // 靶心：由外到内透明度递增，中心白色圆点
    let cyan = NSColor(srgbRed: 0.20, green: 0.82, blue: 1.0, alpha: 1)
    let center = CGPoint(x: size / 2, y: size / 2)

    func ring(radiusFactor: CGFloat, alpha: CGFloat, lineWidthFactor: CGFloat, filled: Bool) {
        let r = radiusFactor * size
        let path = NSBezierPath(ovalIn: CGRect(
            x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        let color = cyan.withAlphaComponent(alpha)
        if filled {
            color.setFill()
            path.fill()
        } else {
            path.lineWidth = lineWidthFactor * size
            color.setStroke()
            path.stroke()
        }
    }

    ring(radiusFactor: 0.295, alpha: 0.35, lineWidthFactor: 0.042, filled: false)
    ring(radiusFactor: 0.195, alpha: 0.60, lineWidthFactor: 0.042, filled: false)
    ring(radiusFactor: 0.100, alpha: 0.95, lineWidthFactor: 0, filled: true)
    let r = 0.032 * size
    NSColor.white.setFill()
    NSBezierPath(ovalIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)).fill()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, pixelSize: Int, name: String) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize, pixelsHigh: pixelSize,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixelSize, height: pixelSize)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: URL(fileURLWithPath: outputDir).appendingPathComponent(name))
}

try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
let entries: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, px) in entries {
    try writePNG(draw(size: CGFloat(px)), pixelSize: px, name: name)
}
print("iconset 已生成: \(outputDir)")
