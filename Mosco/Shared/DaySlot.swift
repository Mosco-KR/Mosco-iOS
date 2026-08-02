import Foundation

/// 하루를 나누는 거친 시간대. "오늘 이걸 **언제** 할 것인가"에 답하는 단위다.
///
/// 분 단위로 정하게 하지 않는 게 의도다. 사람은 소요 시간을 일관되게 과소평가하고
/// (계획 오류), 정확한 시각을 요구할수록 그 오차가 그대로 실패로 돌아온다. 반면
/// "언제·어디서 할지"를 정하는 것만으로도 실행률이 크게 오른다는 연구 결과가 있다
/// (Gollwitzer & Sheeran의 94개 연구 메타분석에서 d = 0.65). 그래서 부담은 없고
/// 효과는 남는 지점으로 오전/오후/저녁 셋만 둔다.
///
/// 시각이 이미 정해진 일정(`startTime`)은 이 슬롯을 쓰지 않는다 — 그건 "고정된 일"로
/// 따로 보여준다.
enum DaySlot: String, CaseIterable, Identifiable, Codable, Sendable {
    case morning
    case afternoon
    case evening

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morning: "오전"
        case .afternoon: "오후"
        case .evening: "저녁"
        }
    }

    var symbolName: String {
        switch self {
        case .morning: "sunrise.fill"
        case .afternoon: "sun.max.fill"
        case .evening: "moon.fill"
        }
    }

    /// 시각이 있는 일정을 슬롯에 끼워 넣을 때 쓰는 경계(시).
    static func containing(hour: Int) -> DaySlot {
        switch hour {
        case ..<12: .morning
        case ..<18: .afternoon
        default: .evening
        }
    }
}
