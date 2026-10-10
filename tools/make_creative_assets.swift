import AppKit
import CoreText

// App Store 크리에이티브 자산(헤더·검색 결과).
//
// 앱 아이콘에서 뽑은 그림 — 보라 그라데이션 위에 유리 막대 셋, 왼쪽에 색 눈금.
// 미리보기 스크린샷이 아직 없으니 화면을 쓰지 않고 브랜드 그림만으로 만든다.
//
// **가운데로 몰아 넣는다.** 애플 가이드가 "focal point artwork를 구도 가운데에 둬서
// 잘리지 않게 하라"고 못박고 있다. 같은 자산이 제품 페이지 헤더와 검색 결과에서
// 서로 다른 비율로 잘려 쓰이기 때문이다. 첫 판은 막대를 맨 왼쪽, 워드마크를 맨
// 오른쪽에 뒀는데 그러면 좁은 크롭에서 양쪽이 다 날아간다.
//
// 그래서 글자와 막대는 전부 가운데 SAFE_RATIO 폭 안에 넣고, 가장자리까지 가는 것은
// 그라데이션뿐이다. 맨 아래에서 16:9와 1:1로 잘라 본 증명 이미지도 같이 뽑는다.
let OUT = FileManager.default.currentDirectoryPath + "/store/creative/"

/// 안전 영역 — **긴 변이 아니라 짧은 변을 기준으로 잡는다.** 가장 좁게 잘리는
/// 경우가 정사각(1:1)이고, 그때 남는 폭은 높이와 같기 때문이다. 폭의 절반으로
/// 잡았다가 1:1 크롭에서 막대 왼쪽이 통째로 날아갔다.
let SAFE_RATIO: CGFloat = 0.88
func safeWidth(_ w: CGFloat, _ h: CGFloat) -> CGFloat { min(w, h) * SAFE_RATIO }

func C(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r/255, green: g/255, blue: b/255, alpha: a)
}
let TOP = C(178, 146, 248)
let BOT = C(104, 40, 217)
let TICKS = [C(239, 68, 68), C(245, 158, 11), C(34, 197, 94)]

struct Copy {
    let bars: [(String, String?)]
    let tagline: String
    let title: String
    let body: String
}
let COPY: [String: Copy] = [
    "ko": Copy(bars: [("저녁 약속", "오후 7시"), ("러닝", "운동"), ("장보기", nil)],
               tagline: "한 줄 적으면 일정이 돼요",
               title: "AppleSDGothicNeo-ExtraBold", body: "AppleSDGothicNeo-SemiBold"),
    "en": Copy(bars: [("Dinner", "7 PM"), ("Run", "Exercise"), ("Groceries", nil)],
               tagline: "One line becomes a plan",
               title: "AvenirNext-Bold", body: "AvenirNext-Medium"),
    "ja": Copy(bars: [("夕食", "午後7時"), ("ランニング", "運動"), ("買い物", nil)],
               tagline: "一行書けば予定になる",
               title: "HiraginoSans-W7", body: "HiraginoSans-W5"),
]
/// 워드마크는 어느 언어에서나 로마자라 라틴 전용 서체를 쓴다 — 한글 서체의
/// 로마자는 M만 유난히 커서 워드마크로 안 읽힌다.
let MARK_FONT = "AvenirNext-Bold"

func newCtx(_ w: CGFloat, _ h: CGFloat) -> CGContext {
    let ctx = CGContext(data: nil, width: Int(w), height: Int(h), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: h); ctx.scaleBy(x: 1, y: -1)
    ctx.interpolationQuality = .high
    return ctx
}
func rounded(_ r: CGRect, _ rad: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
}
func measure(_ s: String, _ fontName: String, _ size: CGFloat) -> CGFloat {
    let font = CTFontCreateWithName(fontName as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: font]))
    return CTLineGetBoundsWithOptions(line, .useOpticalBounds).width
}
@discardableResult
func text(_ ctx: CGContext, _ s: String, font fontName: String, size: CGFloat,
          x: CGFloat, y: CGFloat, color: CGColor, center: CGFloat? = nil) -> CGFloat {
    let font = CTFontCreateWithName(fontName as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(
        string: s, attributes: [.font: font, .foregroundColor: color, .kern: -size * 0.02]))
    let b = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    ctx.saveGState()
    ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
    ctx.textPosition = CGPoint(x: center.map { $0 - b.width/2 - b.minX } ?? x, y: y + CTFontGetAscent(font))
    CTLineDraw(line, ctx)
    ctx.restoreGState()
    return b.width
}

func background(_ ctx: CGContext, _ w: CGFloat, _ h: CGFloat) {
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [TOP, BOT] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: w, y: h), options: [])
}

/// 아이콘의 유리 막대. 흰 반투명 면 + 밝은 테두리 + 왼쪽 색 눈금.
func glassBar(_ ctx: CGContext, _ r: CGRect, tick: CGColor,
              title: String, chip: String?, copy: Copy, scale: CGFloat) {
    let rad = r.height * 0.34
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14 * scale), blur: 46 * scale, color: C(40, 10, 90, 0.28))
    ctx.setFillColor(C(255, 255, 255, 0.22)); ctx.addPath(rounded(r, rad)); ctx.fillPath()
    ctx.restoreGState()
    ctx.setStrokeColor(C(255, 255, 255, 0.45)); ctx.setLineWidth(4 * scale)
    ctx.addPath(rounded(r, rad)); ctx.strokePath()

    let tickW = 22 * scale, tickH = r.height * 0.42
    let tr = CGRect(x: r.minX + 46 * scale, y: r.midY - tickH/2, width: tickW, height: tickH)
    ctx.setFillColor(tick); ctx.addPath(rounded(tr, tickW/2)); ctx.fillPath()

    let titleSize = r.height * 0.40
    var cursor = tr.maxX + 44 * scale
    cursor += text(ctx, title, font: copy.title, size: titleSize,
                   x: cursor, y: r.midY - titleSize * 0.62, color: .white)

    if let chip {
        let chipSize = r.height * 0.26
        let cw = measure(chip, copy.body, chipSize)
        let pad = 30 * scale
        let cr = CGRect(x: cursor + 36 * scale, y: r.midY - chipSize * 0.92,
                        width: cw + pad * 2, height: chipSize * 1.85)
        ctx.setFillColor(C(255, 255, 255, 0.30)); ctx.addPath(rounded(cr, cr.height/2)); ctx.fillPath()
        text(ctx, chip, font: copy.body, size: chipSize,
             x: 0, y: cr.midY - chipSize * 0.66, color: .white, center: cr.midX)
    }
}

/// 가운데 한 열 — 워드마크, 한 줄, 막대 셋. 전부 안전 영역 안이다.
func compose(_ lang: String, _ w: CGFloat, _ h: CGFloat, showMark: Bool) -> CGContext {
    let copy = COPY[lang]!
    let ctx = newCtx(w, h)
    background(ctx, w, h)

    let safeW = safeWidth(w, h)
    let cx = w / 2
    let scale = safeW / 1450

    let markSize = showMark ? h * 0.125 : 0
    let tagSize = h * (showMark ? 0.052 : 0.060)
    let barH = h * 0.125, gap = h * 0.034

    // 태그라인이 안전 영역보다 넓어지면 글자를 줄인다 — 잘리느니 작은 게 낫다.
    var tag = tagSize
    while measure(copy.tagline, copy.body, tag) > safeW && tag > 10 { tag -= 2 }

    let blockH = (showMark ? markSize * 1.08 + h * 0.020 + tag * 1.3 + h * 0.055 : tag * 1.3 + h * 0.050)
        + barH * 3 + gap * 2
    var y = (h - blockH) / 2

    if showMark {
        text(ctx, "Mosco", font: MARK_FONT, size: markSize, x: 0, y: y, color: .white, center: cx)
        y += markSize * 1.08 + h * 0.020
    }
    text(ctx, copy.tagline, font: copy.body, size: tag,
         x: 0, y: y, color: C(255, 255, 255, 0.90), center: cx)
    y += tag * 1.3 + h * (showMark ? 0.055 : 0.050)

    for (i, bar) in copy.bars.enumerated() {
        let bw = safeW * (1.0 - CGFloat(i) * 0.085)
        glassBar(ctx, CGRect(x: cx - safeW/2, y: y, width: bw, height: barH),
                 tick: TICKS[i], title: bar.0, chip: bar.1, copy: copy, scale: scale)
        y += barH + gap
    }
    return ctx
}

func write(_ ctx: CGContext, _ name: String) {
    try? FileManager.default.createDirectory(atPath: OUT, withIntermediateDirectories: true)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: OUT + name))
    print("wrote \(name)")
}

/// 좁게 잘렸을 때 무엇이 남는지 눈으로 보려고 뽑는 증명 이미지.
func cropProof(_ img: CGImage, _ ratio: CGFloat, _ name: String) {
    let h = CGFloat(img.height), w = min(CGFloat(img.width), h * ratio)
    let crop = img.cropping(to: CGRect(x: (CGFloat(img.width) - w)/2, y: 0, width: w, height: h))!
    let ctx = newCtx(w, h)
    ctx.saveGState()
    ctx.translateBy(x: 0, y: h); ctx.scaleBy(x: 1, y: -1)
    ctx.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
    ctx.restoreGState()
    write(ctx, name)
}

for lang in ["ko", "en", "ja"] {
    // 헤더 칸은 PNG만 받는다. 5244×2950 PNG는 13MB라 업로드 한도를 넘으므로
    // 허용 크기 중 작은 쪽(3840×1646)으로 간다.
    let header = compose(lang, 3840, 1646, showMark: true)
    write(header, "\(lang)_header_3840x1646.png")
    // 검색 결과는 작게 보이는 자리라 워드마크를 빼고 막대를 키운다 —
    // 이름은 시스템이 옆에 따로 쓴다.
    write(compose(lang, 1920, 1280, showMark: false), "\(lang)_search_1920x1280.png")

    if lang == "ko" {
        cropProof(header.makeImage()!, 16.0/9.0, "proof_ko_16x9.png")
        cropProof(header.makeImage()!, 1.0, "proof_ko_1x1.png")
    }
}
