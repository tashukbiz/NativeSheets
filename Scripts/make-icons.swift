#!/usr/bin/env swift
//
// Regenerates every derived icon from icon.png at the repository root.
//
// The source art is a macOS-style rounded square drawn on an opaque white
// background with a soft drop shadow. Both of those have to go: an opaque icon
// shows up as a white tile in the Dock, and a baked shadow doubles up with the
// one the system draws. So the art is measured, clipped to its own rounded
// square, and re-laid out on a transparent canvas.
//
// Run it after replacing icon.png:
//
//     swift Scripts/make-icons.swift
//
// Nothing runs this in CI, the same way nothing builds the app in CI: the
// outputs are committed, and pushing them is what ships them.

import AppKit

// #filePath, not CommandLine.arguments[0]: the interpreter's argv[0] is
// whatever path the caller typed, which is not the script's own location.
let repo = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let source = repo.appendingPathComponent("icon.png")

/// Apple's macOS icon grid: the rounded square covers 824 of a 1024pt canvas,
/// and its corner radius is 185.4 of that 824.
let appIconBodyRatio = 824.0 / 1024.0
let cornerRadiusRatio = 185.4 / 824.0

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("make-icons: \(message)\n".utf8))
    exit(1)
}

func load(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { fail("could not read \(url.path)") }
    return image
}

func context(_ size: Int) -> CGContext {
    guard let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fail("could not allocate a \(size)x\(size) canvas") }
    context.interpolationQuality = .high
    return context
}

func write(_ image: CGImage, to url: URL) {
    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, "public.png" as CFString, 1, nil)
    else { fail("could not write \(url.path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("could not encode \(url.path)") }
}

/// The bounds of the rounded square inside the art, ignoring the white surround
/// and the shadow. In image coordinates: y grows downwards.
///
/// The shadow is neutral grey and the body is blue-tinted, so a blue-over-red
/// bias separates the two where a brightness threshold cannot.
func bodyBounds(of image: CGImage) -> CGRect {
    let width = image.width, height = image.height
    // A bitmap context draws y-up but stores its rows top-down, so the first
    // row of this buffer is the top of the art, not the bottom.
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    pixels.withUnsafeMutableBytes { buffer in
        let context = CGContext(
            data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }

    func isBody(_ x: Int, _ y: Int) -> Bool {
        let offset = (y * width + x) * 4
        return Int(pixels[offset + 2]) - Int(pixels[offset]) >= 6
    }

    // The widest and tallest points of a rounded square are on its centre lines.
    let midX = width / 2, midY = height / 2
    guard let minX = (0..<width).first(where: { isBody($0, midY) }),
          let maxX = (0..<width).reversed().first(where: { isBody($0, midY) }),
          let minY = (0..<height).first(where: { isBody(midX, $0) }),
          let maxY = (0..<height).reversed().first(where: { isBody(midX, $0) })
    else { fail("could not find the icon body in \(source.path)") }

    // Square, because the shape is: a specular rim along one edge can read as
    // white and cost the measurement a few pixels there but not opposite it.
    let side = CGFloat(max(maxX - minX, maxY - minY) + 1)
    let centre = CGPoint(x: CGFloat(minX + maxX + 1) / 2, y: CGFloat(minY + maxY + 1) / 2)
    return CGRect(x: centre.x - side / 2, y: centre.y - side / 2, width: side, height: side)
}

/// The art's rounded square, redrawn at `size` with `margin` of transparency on
/// every side and corners cut to Apple's continuous curve.
func render(_ image: CGImage, bounds: CGRect, size: Int, margin: CGFloat) -> CGImage {
    let canvas = CGFloat(size)
    let body = (canvas - margin * 2).rounded()
    let frame = CGRect(x: (canvas - body) / 2, y: (canvas - body) / 2, width: body, height: body)

    let shape = CALayer()
    shape.frame = frame
    shape.backgroundColor = NSColor.black.cgColor
    shape.cornerRadius = body * cornerRadiusRatio
    shape.cornerCurve = .continuous
    let root = CALayer()
    root.frame = CGRect(x: 0, y: 0, width: canvas, height: canvas)
    root.addSublayer(shape)

    let maskContext = context(size)
    root.render(in: maskContext)
    guard let mask = maskContext.makeImage() else { fail("could not build the corner mask") }

    // The art is drawn through a window the size of its own body, which crops
    // the white surround and the shadow along with it. Drawing is y-up, so the
    // measured top becomes a distance from the bottom of the canvas.
    let scale = body / bounds.width
    let output = context(size)
    output.draw(image, in: CGRect(
        x: frame.minX - bounds.minX * scale,
        y: frame.minY - (CGFloat(image.height) - bounds.maxY) * scale,
        width: CGFloat(image.width) * scale,
        height: CGFloat(image.height) * scale))
    output.setBlendMode(.destinationIn)
    output.draw(mask, in: CGRect(x: 0, y: 0, width: canvas, height: canvas))

    guard let result = output.makeImage() else { fail("could not render a \(size)pt icon") }
    return result
}

/// The art as-is, on white. iOS applies its own mask to a home screen icon, so
/// this one keeps the surround and stays opaque.
func renderOpaque(_ image: CGImage, size: Int) -> CGImage {
    let context = context(size)
    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    guard let result = context.makeImage() else { fail("could not render a \(size)pt icon") }
    return result
}

let art = load(source)
let bounds = bodyBounds(of: art)
print("body \(Int(bounds.width))x\(Int(bounds.height)) at (\(Int(bounds.minX)), \(Int(bounds.minY))) of \(art.width)x\(art.height)")

let iconset = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("NativeSheets-\(ProcessInfo.processInfo.processIdentifier).iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for point in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = point * scale
        let suffix = scale == 1 ? "" : "@2x"
        let icon = render(art, bounds: bounds, size: size,
                          margin: CGFloat(size) * (1 - appIconBodyRatio) / 2)
        write(icon, to: iconset.appendingPathComponent("icon_\(point)x\(point)\(suffix).png"))
    }
}

let icns = repo.appendingPathComponent("native-sheets/Resources/AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try! iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fail("iconutil failed") }
try? FileManager.default.removeItem(at: iconset)
print("Wrote \(icns.path)")

// A favicon is read at 16pt in a tab, so it trades the app icon's margin for
// legibility and keeps only enough to let the corners breathe.
let favicon = repo.appendingPathComponent("landing/public/icon.png")
write(render(art, bounds: bounds, size: 256, margin: 6), to: favicon)
print("Wrote \(favicon.path)")

let touchIcon = repo.appendingPathComponent("landing/public/apple-touch-icon.png")
write(renderOpaque(art, size: 180), to: touchIcon)
print("Wrote \(touchIcon.path)")
