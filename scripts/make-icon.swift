import AppKit
import Foundation

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let rect = NSRect(x: 55, y: 55, width: 914, height: 914)
let background = NSBezierPath(roundedRect: rect, xRadius: 210, yRadius: 210)
NSColor(calibratedRed: 0.94, green: 0.93, blue: 0.87, alpha: 1).setFill()
background.fill()
NSColor(calibratedRed: 0.23, green: 0.36, blue: 0.27, alpha: 1).setFill()
for x in [270.0, 478.0] {
    NSBezierPath(roundedRect: NSRect(x: x, y: 570, width: 135, height: 155), xRadius: 32, yRadius: 32).fill()
    let tail = NSBezierPath()
    tail.move(to: NSPoint(x: x + 134, y: 596))
    tail.curve(to: NSPoint(x: x + 20, y: 465), controlPoint1: NSPoint(x: x + 150, y: 513), controlPoint2: NSPoint(x: x + 66, y: 468))
    tail.line(to: NSPoint(x: x + 20, y: 506))
    tail.curve(to: NSPoint(x: x + 73, y: 583), controlPoint1: NSPoint(x: x + 60, y: 524), controlPoint2: NSPoint(x: x + 77, y: 548))
    tail.close(); tail.fill()
}
for (y, width) in [(380.0, 470.0), (285.0, 310.0)] {
    NSBezierPath(roundedRect: NSRect(x: 270, y: y, width: width, height: 36), xRadius: 18, yRadius: 18).fill()
}
NSColor(calibratedRed: 0.70, green: 0.48, blue: 0.27, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 665, y: 580, width: 85, height: 85)).fill()
image.unlockFocus()
let data = image.tiffRepresentation!
let bitmap = NSBitmapImageRep(data: data)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
