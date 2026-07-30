import Foundation

/// 캘린더 그리드에 그릴 블록 하나(제목 + 우선순위 색 + 시작/종료일).
/// TodoItem을 직접 넘기지 않고 이 구조체로 축약해서, 그리드는 SwiftData를 몰라도 된다.
/// 반복 인스턴스도 블록으로 펼쳐지므로, id는 "할일ID-시작일" 형태의 문자열이다
/// (같은 할 일의 반복끼리 id가 겹치면 렌더링이 깨진다).
struct CalendarBlock: Equatable, Identifiable {
    let id: String
    let title: String
    let priority: Priority
    /// 시작/종료일(하루 단위, startOfDay 기준). 하루짜리면 start == end.
    let start: Date
    let end: Date
    /// 완료된 항목은 그리드에서도 흐리게 + 취소선으로 구분한다(TodoRow와 같은 표현).
    let isCompleted: Bool
}
