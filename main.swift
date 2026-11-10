import AppKit
enum Mode { case off, awake, lid }
let s: CGFloat = 8
let out = NSImage(size: NSSize(width: 20*s*3+40, height: 18*s+20), flipped: false) { _ in
  NSColor.white.setFill(); NSRect(x:0,y:0,width:1000,height:300).fill()
  for (i,m) in [Mode.off,.awake,.lid].enumerated() {
    let x = 10+CGFloat(i)*(20*s+10)
    NSColor(white:0.93,alpha:1).setFill(); NSRect(x:x,y:10,width:20*s,height:18*s).fill()
    Icons.image(for: m).draw(in: NSRect(x: x, y: 10, width: 20*s, height: 18*s))
  }
  return true }
let r = NSBitmapImageRep(data: out.tiffRepresentation!)!
try! r.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "/tmp/ic/o5.png"))
