import Foundation

/// 앱이 지금 어느 언어로 보이고 있는가.
///
/// 문구는 문자열 카탈로그(`Localizable.xcstrings`)가 알아서 고르지만, **날짜·시각
/// 표기와 안내 예시는 코드가 직접 만든다** — "오후 7시"를 "7 PM"이나 "午後7時"로
/// 바꾸는 건 번역이 아니라 조립이라서다. 그 조립이 어느 언어로 할지 묻는 곳이 여기다.
///
/// 시스템 로케일이 아니라 **번들이 실제로 고른 언어**를 본다. 기기는 프랑스어인데
/// 앱은 영어로 뜨는 경우, 문구는 영어인데 날짜만 프랑스어로 나오면 안 된다.
nonisolated enum AppLanguage: String, CaseIterable, Sendable {
    case ko, en, ja

    static let current = resolve(
        bundleLocalizations: Bundle.main.localizations,
        preferred: Bundle.main.preferredLocalizations.first
    )

    /// 번들에 한국어가 없으면 앱도 위젯도 아니다 — 호스트 앱 없이 도는 테스트 러너다.
    /// 그때는 원문 언어인 한국어로 둔다. 카탈로그를 못 찾은 `String(localized:)`가
    /// 키(한국어)를 그대로 돌려주는 것과 맞춰야 날짜와 문구가 한 언어로 나온다.
    static func resolve(bundleLocalizations: [String], preferred: String?) -> AppLanguage {
        guard bundleLocalizations.contains(AppLanguage.ko.rawValue) else { return .ko }
        guard let code = preferred?.prefix(2) else { return .en }
        return AppLanguage(rawValue: String(code)) ?? .en
    }
}

extension Calendar {
    /// 한 주를 일요일부터 세는 달력.
    ///
    /// 이 앱의 달력은 **일~토 일곱 칸으로 고정**이다. 요일 머리도, 일요일 빨강·토요일
    /// 파랑도 칸 순서에 맞춰져 있다. 그런데 기기 달력은 지역에 따라 월요일부터 세서
    /// (영국·프랑스·독일 등), 주의 시작을 기기에 물으면 머리는 "일"인데 그 아래에
    /// 월요일이 오는 한 칸 밀린 달력이 된다. 한국·미국·일본은 일요일 시작이라 한국어만
    /// 낼 때는 드러나지 않았다. 주의 경계를 구하는 곳은 전부 이걸 거친다.
    nonisolated var startingSunday: Calendar {
        var calendar = self
        calendar.firstWeekday = 1
        return calendar
    }
}
