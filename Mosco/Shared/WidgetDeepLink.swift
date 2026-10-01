import Foundation

/// 위젯을 눌렀을 때 앱이 열리며 받는 URL.
///
/// 위젯은 원래 탭하면 그냥 앱이 열릴 뿐이라, **어느 위젯을 눌러서 들어왔는지**
/// 앱이 알 수 없었다. `widgetURL`로 표시를 달아 보내면 앱이 그걸 읽어
/// `widget_tapped`를 남길 수 있다 — 위젯이 보기용으로만 쓰이는지, 앱 진입로로도
/// 쓰이는지가 갈린다.
///
/// 스킴은 `Info.plist`의 `CFBundleURLTypes`에도 등록돼 있어야 한다.
enum WidgetDeepLink {
    static let scheme = "mosco"
    private static let host = "widget"

    /// 라이브 액티비티를 눌러 들어왔을 때.
    static let liveActivityKind = "live_activity"

    /// 위젯이 자기 URL을 만들 때.
    static func url(kind: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/\(kind)"
        return components.url
    }

    /// 이 위젯으로 들어오면 오늘 페이지를 바로 열어야 하는가.
    ///
    /// '오늘 할 일' 위젯과 라이브 액티비티는 오늘 할 일을 보여주던 것이라, 눌렀는데
    /// 달력만 뜨면 한 번 더 눌러야 한다. 달력 위젯들은 달력(홈)으로 들어오는 게 맞다.
    static func opensTodayPage(kind: String) -> Bool {
        kind == "today_todo" || kind == liveActivityKind
    }

    /// 앱이 받은 URL에서 위젯 종류를 꺼낸다. 우리 위젯이 보낸 게 아니면 nil.
    static func kind(from url: URL) -> String? {
        guard url.scheme == scheme, url.host == host else { return nil }
        let kind = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return kind.isEmpty ? nil : kind
    }
}
