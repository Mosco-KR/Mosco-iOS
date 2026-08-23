import Foundation
import Testing

/// `ThemeStore`는 App Group을 직접 열던 싱글턴이라 한 줄도 테스트할 수 없었다.
/// 저장소를 받도록 바꾼 뒤에 붙인 것들이다 (2026-08-22).
@MainActor
struct ThemeStoreTests {

    /// 테스트마다 깨끗한 저장소. `UserDefaults.standard`를 쓰면 테스트끼리
    /// 서로의 값을 본다.
    private func store() -> (ThemeStore, UserDefaults) {
        let suite = "theme-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (ThemeStore(defaults: defaults, notifyWidgets: {}), defaults)
    }

    @Test("처음_열면_기본색이다")
    func 기본색() {
        let (theme, _) = store()
        #expect(theme.selectedHex == ThemeColor.defaultHex)
        #expect(theme.isDefault)
    }

    @Test("저장해둔_색을_다시_열면_그대로_나온다")
    func 되읽기() {
        let suite = "theme-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set("FF0000", forKey: ThemeColor.storageKey)

        let theme = ThemeStore(defaults: defaults, notifyWidgets: {})
        #expect(theme.selectedHex == "FF0000")
        #expect(!theme.isDefault)
    }

    @Test("기본색으로_되돌리면_저장소에도_기록된다")
    func 되돌리기() {
        let suite = "theme-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set("FF0000", forKey: ThemeColor.storageKey)
        let theme = ThemeStore(defaults: defaults, notifyWidgets: {})

        theme.resetToDefault()

        #expect(theme.selectedHex == ThemeColor.defaultHex)
        #expect(defaults.string(forKey: ThemeColor.storageKey) == ThemeColor.defaultHex)
    }

    /// 색을 바꾸면 위젯에 다시 그리라고 알려야 한다. 안 알리면 홈 화면이 자정까지
    /// 예전 색으로 남는다 — 실제로 겪었던 일이라 규범 문서에도 적혀 있다.
    @Test("색이_바뀌면_위젯에_알린다")
    func 위젯_알림() {
        let suite = "theme-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        var notified = 0
        let theme = ThemeStore(defaults: defaults, notifyWidgets: { notified += 1 })

        theme.resetToDefault()          // 이미 기본색이므로 안 바뀐다
        #expect(notified == 0, "같은 색으로 바꾸면 위젯을 깨우지 않는다")

        defaults.set("112233", forKey: ThemeColor.storageKey)
        let other = ThemeStore(defaults: defaults, notifyWidgets: { notified += 1 })
        other.resetToDefault()          // 이번엔 실제로 바뀐다
        #expect(notified == 1)
    }
}
