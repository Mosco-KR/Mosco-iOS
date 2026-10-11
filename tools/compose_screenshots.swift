import AppKit
import CoreText

// store/raw/ 의 원본 캡처에 문구와 기기 틀을 입혀 스토어에 올릴 미리보기를 만든다.
//
// **액자는 일부러 단순하다.** 한국 스토어 상위 앱들(투두메이트·플래닛·minical·심플
// 캘린더·Structured)의 미리보기를 받아서 봤는데, 잘 보이는 쪽의 액자가 오히려 더
// 단순했다. 거의 흰 배경에 검은 고딕 헤드라인, 그 아래 회색 보조 한 줄, 그리고
// 기기가 캔버스 밖으로 흘러나간다. 다섯 중 다섯이 기기를 잘라 썼다. 색과 밀도는
// 전부 **화면 안**에서 나온다 — 배경에 그라데이션을 깔거나 특별한 서체를 쓰는 앱은
// 하나도 없었다.
//
// 그래서 여기서 하는 일은 셋뿐이다: 밝은 배경, 왼쪽 정렬 헤드라인 두 줄, 기기를
// 크게 넣고 아래로 흘려보내기.
//
//   swift tools/compose_screenshots.swift
//
// 원본은 `tools/capture_screenshots.sh`가 만든다. 결과는 store/screenshots/.

let ROOT = FileManager.default.currentDirectoryPath
let RAW = ROOT + "/store/raw/"
let OUT = ROOT + "/store/screenshots/"

// 스토어 규격. **1242×2688이 아니다.** 예전에는 그 크기(6.5형)를 받았는데, 애플이
// 칸을 'iPhone 15.5cm/15.9cm 디스플레이' 하나로 합치면서 받는 크기가 바뀌었다.
// 지금 받는 것은 1179×2556과 1206×2622 둘뿐이다. 큰 쪽을 쓴다.
let W: CGFloat = 1206, H: CGFloat = 2622

func C(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r/255, green: g/255, blue: b/255, alpha: a)
}
let BG = C(247, 246, 251)
let INK = C(22, 21, 31)
let SUB = C(107, 104, 128)

struct Shot {
    let file: String          // store/raw/ 의 원본 이름 (언어 접두사 뺀 것)
    let head: [String: String]
    let sub: [String: String]
}

let SHOTS: [Shot] = [
    Shot(file: "1_compose",
         head: ["ko": "한 줄이면 끝나요", "en": "One line. Done.", "ja": "一行で完了"],
         sub: ["ko": "“저녁 약속 오후 7시”라고 치면 시간이 알아서 붙어요",
               "en": "Type “Dinner 7pm” and the time attaches itself",
               "ja": "「夕食 午後7時」と書けば時間が入ります"]),
    Shot(file: "2_todos",
         head: ["ko": "무엇부터 할지\n한 화면에", "en": "What to do\nfirst", "ja": "何からやるか、\nひと画面で"],
         sub: ["ko": "지난 일, 날짜를 안 정한 일, 디데이까지 급한 순서로",
               "en": "Overdue, undated, and D-Days, in the order they need you",
               "ja": "過ぎたもの、日付なし、Dデーまで急ぐ順に"]),
    Shot(file: "3_month",
         head: ["ko": "한 달치가\n한 화면에", "en": "Your whole month\nat a glance", "ja": "ひと月分が\nひと画面に"],
         sub: ["ko": "며칠짜리 일정도 이어서 보여요",
               "en": "Multi-day plans stretch across the days",
               "ja": "数日にわたる予定もつながって見えます"]),
    Shot(file: "4_timeline",
         head: ["ko": "오늘 하루가\n시간순으로", "en": "Your whole day,\nhour by hour", "ja": "今日一日が\n時間順に"],
         sub: ["ko": "시간을 적은 일은 제자리에 놓여요",
               "en": "Timed to-dos fall into place",
               "ja": "時間を書いたやることは定位置に"]),
]

func font(_ lang: String, bold: Bool) -> String {
    switch lang {
    case "ja": return bold ? "HiraginoSans-W7" : "HiraginoSans-W4"
    default: return bold ? "AppleSDGothicNeo-ExtraBold" : "AppleSDGothicNeo-Medium"
    }
}

func newCtx(_ w: CGFloat, _ h: CGFloat) -> CGContext {
    let ctx = CGContext(data: nil, width: Int(w), height: Int(h), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: h); ctx.scaleBy(x: 1, y: -1)
    ctx.interpolationQuality = .high
    return ctx
}
func put(_ ctx: CGContext, _ img: CGImage, _ r: CGRect) {
    ctx.saveGState()
    ctx.translateBy(x: r.minX, y: r.minY + r.height); ctx.scaleBy(x: 1, y: -1)
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: r.width, height: r.height))
    ctx.restoreGState()
}
func rounded(_ r: CGRect, _ rad: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
}
func measure(_ s: String, _ f: String, _ size: CGFloat) -> CGFloat {
    let ft = CTFontCreateWithName(f as CFString, size, nil)
    return CTLineGetBoundsWithOptions(
        CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: ft])),
        .useOpticalBounds).width
}
func draw(_ ctx: CGContext, _ s: String, _ f: String, _ size: CGFloat,
          x: CGFloat, y: CGFloat, color: CGColor) {
    let ft = CTFontCreateWithName(f as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(
        string: s, attributes: [.font: ft, .foregroundColor: color, .kern: -size * 0.025]))
    ctx.saveGState()
    ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
    ctx.textPosition = CGPoint(x: x, y: y + CTFontGetAscent(ft))
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

/// 폭에 맞게 접는다.
///
/// **문구에 직접 넣은 줄바꿈이 먼저다.** 자동 줄바꿈은 띄어쓰기가 드문 한국어·일본어에서
/// 낱말을 쪼갠다 — 「ひと画/面で」처럼 한 단어가 두 줄에 걸치면 읽다 걸린다. 끊을 자리가
/// 중요한 문구는 표에서 `\n`으로 직접 끊는다.
func wrap(_ s: String, _ f: String, _ size: CGFloat, _ maxW: CGFloat) -> [String] {
    if s.contains("\n") {
        return s.split(separator: "\n", omittingEmptySubsequences: false)
            .flatMap { wrap(String($0), f, size, maxW) }
    }
    if measure(s, f, size) <= maxW { return [s] }
    var lines: [String] = []
    var current = ""
    let hasSpace = s.contains(" ")
    let units: [String] = hasSpace ? s.split(separator: " ").map(String.init) : s.map(String.init)
    let joiner = hasSpace ? " " : ""
    for unit in units {
        let candidate = current.isEmpty ? unit : current + joiner + unit
        if measure(candidate, f, size) <= maxW {
            current = candidate
        } else {
            if !current.isEmpty { lines.append(current) }
            current = unit
        }
    }
    if !current.isEmpty { lines.append(current) }
    return lines
}

/// 기기 틀. 원본 캡처에는 베젤도 다이나믹 아일랜드도 없다 — 화면 버퍼만 들어 있어서
/// 여기서 그려 넣는다.
func device(_ ctx: CGContext, _ screen: CGImage, outerW: CGFloat, top: CGFloat) {
    let bezel = outerW * 0.0235
    let screenW = outerW - bezel * 2
    let screenH = screenW * CGFloat(screen.height) / CGFloat(screen.width)
    let outerH = screenH + bezel * 2
    let x = (W - outerW) / 2
    let body = CGRect(x: x, y: top, width: outerW, height: outerH)
    let radius = outerW * 0.125

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -20), blur: 56, color: C(40, 30, 80, 0.26))
    ctx.setFillColor(C(12, 12, 16)); ctx.addPath(rounded(body, radius)); ctx.fillPath()
    ctx.restoreGState()

    let screenRect = CGRect(x: x + bezel, y: top + bezel, width: screenW, height: screenH)
    ctx.saveGState()
    ctx.addPath(rounded(screenRect, radius - bezel)); ctx.clip()
    put(ctx, screen, screenRect)

    // 다이나믹 아일랜드 — 하드웨어라 캡처에 안 들어온다.
    let islandW = screenW * 0.288, islandH = screenW * 0.082
    let island = CGRect(x: screenRect.midX - islandW/2, y: screenRect.minY + screenW * 0.026,
                        width: islandW, height: islandH)
    ctx.setFillColor(C(0, 0, 0)); ctx.addPath(rounded(island, islandH/2)); ctx.fillPath()
    ctx.restoreGState()
}

func compose(_ lang: String, _ shot: Shot) {
    let path = RAW + "\(lang)_\(shot.file).png"
    guard let img = NSImage(contentsOfFile: path)?
        .cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("✗ 원본 없음: \(lang)_\(shot.file).png"); return
    }
    let ctx = newCtx(W, H)
    ctx.setFillColor(BG); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

    let margin: CGFloat = 92
    let textW = W - margin * 2
    let headFont = font(lang, bold: true), subFont = font(lang, bold: false)

    // 헤드라인이 길면 줄여서라도 두 줄 안에 넣는다. 세 줄이 되면 기기가 밀린다.
    var headSize: CGFloat = 104
    var headLines = wrap(shot.head[lang]!, headFont, headSize, textW)
    while headLines.count > 2 && headSize > 68 {
        headSize -= 4
        headLines = wrap(shot.head[lang]!, headFont, headSize, textW)
    }
    var y: CGFloat = 148
    for line in headLines {
        draw(ctx, line, headFont, headSize, x: margin, y: y, color: INK)
        y += headSize * 1.2
    }

    y += 18
    let subSize: CGFloat = 46
    for line in wrap(shot.sub[lang]!, subFont, subSize, textW) {
        draw(ctx, line, subFont, subSize, x: margin, y: y, color: SUB)
        y += subSize * 1.38
    }

    // 기기는 남은 자리를 다 쓰고 아래로 흘러나간다.
    device(ctx, img, outerW: W - margin * 2 + 44, top: y + 86)

    try? FileManager.default.createDirectory(atPath: OUT, withIntermediateDirectories: true)
    let name = "\(lang)_\(shot.file).png"
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: OUT + name))
    print("✓ \(name)")
}

for lang in ["ko", "en", "ja"] {
    for shot in SHOTS { compose(lang, shot) }
}
