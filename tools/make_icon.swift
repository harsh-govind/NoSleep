// Renders NoSleep's app icon into an .iconset folder. Usage: swift make_icon.swift <out.iconset>
import Cocoa

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS-style rounded square with margin
    let inset = s * 0.1
    let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let bg = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    NSGradient(colors: [NSColor(red: 0.08, green: 0.10, blue: 0.28, alpha: 1),
                        NSColor(red: 0.30, green: 0.18, blue: 0.55, alpha: 1)])!.draw(in: bg, angle: 90)

    // stars
    NSColor(white: 1, alpha: 0.85).setFill()
    for (x, y, r) in [(0.25, 0.78, 0.012), (0.36, 0.70, 0.008), (0.72, 0.30, 0.009), (0.80, 0.52, 0.007), (0.22, 0.45, 0.007)] {
        NSBezierPath(ovalIn: NSRect(x: s*x - s*r, y: s*y - s*r, width: s*r*2, height: s*r*2)).fill()
    }

    // crescent moon (circle minus offset circle)
    let moon = NSRect(x: s*0.56, y: s*0.60, width: s*0.20, height: s*0.20)
    let cut = NSRect(x: s*0.61, y: s*0.64, width: s*0.20, height: s*0.20)
    NSGraphicsContext.saveGraphicsState()
    let clip = NSBezierPath(rect: NSRect(x: 0, y: 0, width: s, height: s))
    clip.append(NSBezierPath(ovalIn: cut)); clip.windingRule = .evenOdd; clip.addClip()
    NSColor(red: 1, green: 0.85, blue: 0.4, alpha: 1).setFill()
    NSBezierPath(ovalIn: moon).fill()
    NSGraphicsContext.restoreGraphicsState()

    // coffee cup
    let cream = NSColor(red: 0.98, green: 0.95, blue: 0.90, alpha: 1)
    let cup = NSBezierPath()
    cup.move(to: NSPoint(x: s*0.28, y: s*0.52))
    cup.line(to: NSPoint(x: s*0.62, y: s*0.52))
    cup.curve(to: NSPoint(x: s*0.45, y: s*0.27), controlPoint1: NSPoint(x: s*0.62, y: s*0.36), controlPoint2: NSPoint(x: s*0.56, y: s*0.27))
    cup.curve(to: NSPoint(x: s*0.28, y: s*0.52), controlPoint1: NSPoint(x: s*0.34, y: s*0.27), controlPoint2: NSPoint(x: s*0.28, y: s*0.36))
    cream.setFill(); cup.fill()
    // handle
    let handle = NSBezierPath(ovalIn: NSRect(x: s*0.565, y: s*0.36, width: s*0.13, height: s*0.12))
    handle.lineWidth = s*0.028; cream.setStroke(); handle.stroke()
    // coffee surface
    NSColor(red: 0.45, green: 0.27, blue: 0.15, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: s*0.29, y: s*0.495, width: s*0.32, height: s*0.05)).fill()
    // saucer
    cream.setFill()
    NSBezierPath(ovalIn: NSRect(x: s*0.22, y: s*0.23, width: s*0.46, height: s*0.06)).fill()
    // steam
    let steam = NSBezierPath(); steam.lineWidth = s*0.022; steam.lineCapStyle = .round
    for x in [0.38, 0.45, 0.52] {
        steam.move(to: NSPoint(x: s*x, y: s*0.57))
        steam.curve(to: NSPoint(x: s*x, y: s*0.70), controlPoint1: NSPoint(x: s*(x+0.04), y: s*0.61), controlPoint2: NSPoint(x: s*(x-0.04), y: s*0.66))
    }
    NSColor(white: 1, alpha: 0.7).setStroke(); steam.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: URL(fileURLWithPath: "\(out)/icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: URL(fileURLWithPath: "\(out)/icon_\(base)x\(base)@2x.png"))
}
