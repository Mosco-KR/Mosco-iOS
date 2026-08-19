import Foundation
import Testing

/// 앱 강조색 — 시스템 색 고르기는 흰색도 고를 수 있다. 그 색이 그대로 버튼
/// 글자에 들어가면 **흰 배경에 흰 글자**가 되고, 심지어 '기본으로 되돌리기'
/// 버튼조차 안 보여서 빠져나올 수 없다.
@Suite("앱 강조색")
struct ThemeColorTests {

    // MARK: 읽을 수 있는가

    @Test("흰색을_고르면_읽을_수_있게_눌러_쓴다")
    func 흰색() {
        let result = ThemeColor.readableHex("FFFFFF")
        #expect(result != "FFFFFF", "흰 배경에 흰 글자가 된다")
        #expect(ThemeColor.contrastWithWhite(rgb(result)) >= ThemeColor.minimumContrast)
    }

    @Test("아주_연한_색도_눌러_쓴다", arguments: ["FFFF00", "FFFACD", "E0FFFF", "F5F5DC"])
    func 연한_색(hex: String) {
        let result = ThemeColor.readableHex(hex)
        #expect(
            ThemeColor.contrastWithWhite(rgb(result)) >= ThemeColor.minimumContrast,
            "\(hex) → \(result)이 여전히 안 읽힌다"
        )
    }

    @Test("이미_충분히_어두운_색은_그대로_쓴다", arguments: ["8B5CF6", "1D4ED8", "000000", "7F1D1D"])
    func 어두운_색은_그대로(hex: String) {
        // 고른 색을 함부로 바꾸면 "내가 고른 게 아닌데"가 된다.
        #expect(ThemeColor.readableHex(hex) == hex)
    }

    @Test("기본색은_손대지_않는다")
    func 기본색() {
        #expect(ThemeColor.readableHex(ThemeColor.defaultHex) == ThemeColor.defaultHex)
    }

    @Test("조정했는지_알려준다")
    func 조정_여부() {
        // 말없이 바꿔놓으면 색을 잘못 고른 줄 안다.
        #expect(ThemeColor.isAdjusted("FFFFFF") == true)
        #expect(ThemeColor.isAdjusted("8B5CF6") == false)
    }

    // MARK: 값 다듬기

    @Test("샵과_공백과_소문자를_받아준다", arguments: [
        "#8b5cf6", " 8B5CF6 ", "8b5cf6", "#8B5CF6",
    ])
    func 정규화(input: String) {
        #expect(ThemeColor.normalize(input) == "8B5CF6")
    }

    @Test("잘못된_값은_거른다", arguments: ["", "xyz", "8B5CF", "8B5CF66", "GGGGGG"])
    func 잘못된_값(input: String) {
        #expect(ThemeColor.normalize(input) == nil)
    }

    @Test("읽을_수_없는_값이_오면_기본색으로_돌아간다", arguments: ["", "깨진값", "12345"])
    func 깨진_저장값(stored: String) {
        // 저장된 값이 깨졌다고 앱이 색 없이 뜨면 안 된다.
        #expect(ThemeColor.readableHex(stored) == ThemeColor.defaultHex)
    }

    @Test("값이_없으면_기본색이다")
    func 값_없음() {
        #expect(ThemeColor.readableHex(nil) == ThemeColor.defaultHex)
    }

    // MARK: 되돌리기

    @Test("기본색인지_알려준다")
    func 기본색_판정() {
        #expect(ThemeColor.isDefault(nil) == true)
        #expect(ThemeColor.isDefault("8B5CF6") == true)
        #expect(ThemeColor.isDefault("#8b5cf6") == true, "표기가 달라도 같은 색이다")
        #expect(ThemeColor.isDefault("1D4ED8") == false)
    }

    // MARK: 대비 계산

    @Test("흰색은_흰_배경에서_대비가_1이다")
    func 대비_바닥() {
        #expect(abs(ThemeColor.contrastWithWhite((1, 1, 1)) - 1.0) < 0.01)
    }

    @Test("검정은_흰_배경에서_대비가_21이다")
    func 대비_천장() {
        #expect(abs(ThemeColor.contrastWithWhite((0, 0, 0)) - 21.0) < 0.1)
    }

    @Test("눌러도_같은_색_계열로_남는다")
    func 색상_유지() {
        // 노랑을 골랐는데 회색이 되면 고른 의미가 없다. 세 채널 비율이 유지되는지 본다.
        let result = rgb(ThemeColor.readableHex("FFFF00"))
        #expect(result.r > result.b, "노랑 계열이 아니게 됐다")
        #expect(abs(result.r - result.g) < 0.02, "빨강과 초록이 갈라졌다")
    }

    private func rgb(_ hex: String) -> (r: Double, g: Double, b: Double) {
        let value = UInt64(hex, radix: 16) ?? 0
        return (
            Double((value >> 16) & 0xFF) / 255,
            Double((value >> 8) & 0xFF) / 255,
            Double(value & 0xFF) / 255
        )
    }
}
