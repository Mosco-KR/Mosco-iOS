import SwiftUI

/// Priority(도메인 모델)의 색상/라벨 매핑. 위젯 등 다른 타깃이 생기면
/// 이 매핑만 공유 패키지로 이식하면 된다.
extension Priority {
    var color: Color {
        switch self {
        case .must: MoscoPalette.must
        case .should: MoscoPalette.should
        case .could: MoscoPalette.could
        case .wont: MoscoPalette.wont
        }
    }

    /// 캘린더 등 공간이 좁은 곳에서 쓰는 짧은 표기.
    var label: String {
        switch self {
        case .must: "Must"
        case .should: "Should"
        case .could: "Could"
        case .wont: "Won't"
        }
    }

    /// "할 일" 탭처럼 공간 여유가 있는 화면에서 쓰는 표기.
    var fullLabel: String {
        switch self {
        case .must: "Must Do"
        case .should: "Should Do"
        case .could: "Could Do"
        case .wont: "Won't Do"
        }
    }

    var hex: String {
        switch self {
        case .must: "#EF4444"
        case .should: "#F59E0B"
        case .could: "#3B82F6"
        case .wont: "#94A3B8"
        }
    }
}
