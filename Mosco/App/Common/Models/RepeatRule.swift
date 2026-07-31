import Foundation

/// 반복 설정. 반복 인스턴스는 저장소에 실제로 복제하지 않고, 표시할 때(캘린더
/// 블록/하루치 리스트) 규칙으로부터 계산해서 보여준다 — 원본 하나만 고치면
/// 모든 반복에 함께 반영되는 구조.
enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekly, monthly, yearly
    /// 특정 일수 간격 반복(N일마다). 간격은 TodoItem.repeatInterval에 저장.
    case everyNDays

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "안 함"
        case .daily: "매일"
        case .weekly: "매주"
        case .monthly: "매월"
        case .yearly: "매년"
        case .everyNDays: "며칠마다"
        }
    }
}
