import Foundation

/// 케이스 선언 순서가 곧 중요도 순서(Must > Should > Could > Wont).
enum Priority: String, Codable, CaseIterable, Identifiable, Comparable {
    case must, should, could, wont

    var id: String { rawValue }

    static func < (lhs: Priority, rhs: Priority) -> Bool {
        (allCases.firstIndex(of: lhs) ?? 0) < (allCases.firstIndex(of: rhs) ?? 0)
    }
}
