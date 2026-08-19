import Foundation

/// 하루치를 어떤 모양으로 볼 것인가.
///
/// 두 화면(캘린더 하루치, 오늘 할 일)이 **같은 값을 공유한다.** 화면마다 따로
/// 기억하면 같은 하루를 두 곳에서 다르게 보게 되고, "내가 시간표로 바꿨는데
/// 저기는 왜 목록이지"가 된다.
nonisolated enum DayViewMode: String, CaseIterable, Identifiable {
    /// 사용자가 정한 순서대로 세운 목록. 지금까지의 유일한 모양이자 기본값이다.
    case list
    /// 세로 시간축. 시각이 있는 할 일만 축에 놓이고, 없는 것은 위에 모인다.
    case timeline

    var id: String { rawValue }

    /// `@AppStorage` 키. 마지막으로 고른 모양이 다음에도 그대로 열린다.
    static let storageKey = "dayViewMode"

    var label: String {
        switch self {
        case .list: "목록"
        case .timeline: "시간표"
        }
    }

    /// 탭 하나로 오가는 토글이라 아이콘만으로 무엇인지 알아야 한다.
    var symbol: String {
        switch self {
        case .list: "list.bullet"
        case .timeline: "calendar.day.timeline.left"
        }
    }

    /// 저장된 문자열이 깨졌거나 예전 값이면 목록으로 돌아간다 —
    /// 못 읽는 값 때문에 화면이 안 뜨는 것이 제일 나쁘다.
    static func from(_ raw: String) -> DayViewMode {
        DayViewMode(rawValue: raw) ?? .list
    }
}
