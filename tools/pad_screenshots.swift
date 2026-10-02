import AppKit
// 캔버스 비율(1320:2868)과 스토어 규격(1242:2688)이 0.4% 달라서 내보내면 폭이 1237로
// 나온다. 늘리면 글자가 찌그러지므로, 모서리 색으로 좌우를 채워 정확한 크기로 만든다.
for path in CommandLine.arguments.dropFirst() {
    guard let src = NSImage(contentsOfFile: path)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
    let W = 1242, H = 2688
    if src.width == W && src.height == H { continue }
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // 왼쪽 위 1픽셀로 배경색을 읽는다.
    let probe = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    probe.draw(src, in: CGRect(x: 0, y: -CGFloat(src.height - 1), width: CGFloat(src.width), height: CGFloat(src.height)))
    let px = probe.data!.assumingMemoryBound(to: UInt8.self)
    ctx.setFillColor(CGColor(red: CGFloat(px[0])/255, green: CGFloat(px[1])/255, blue: CGFloat(px[2])/255, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    let scale = CGFloat(H) / CGFloat(src.height)
    let w = CGFloat(src.width) * scale
    ctx.draw(src, in: CGRect(x: (CGFloat(W) - w) / 2, y: 0, width: w, height: CGFloat(H)))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
