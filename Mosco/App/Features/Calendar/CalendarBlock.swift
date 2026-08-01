import Foundation

/// 캘린더 그리드에 그릴 블록 하나(제목 + 우선순위 색 + 시작/종료일).
/// TodoItem을 직접 넘기지 않고 이 구조체로 축약해서, 그리드는 SwiftData를 몰라도 된다.
/// 반복 인스턴스도 블록으로 펼쳐지므로, id는 "할일ID-시작일" 형태의 문자열이다
/// (같은 할 일의 반복끼리 id가 겹치면 렌더링이 깨진다).
struct CalendarBlock: Equatable, Identifiable {
    let id: String
    let title: String
    let category: TodoCategory?
    /// 반복 일정에서 나온 블록인지(원본 포함) — 캘린더에서 한 번짜리와 구분해
    /// 표시하는 데 쓴다.
    var isRepeating: Bool = false
    /// 시작/종료일(하루 단위, startOfDay 기준). 하루짜리면 start == end.
    let start: Date
    let end: Date
    /// 완료된 항목은 그리드에서도 흐리게 + 취소선으로 구분한다(TodoRow와 같은 표현).
    let isCompleted: Bool
    /// 같은 날 새 할 일이 끼어들 때 행 배정의 최종 타이브레이커로 쓴다 — 먼저
    /// 만든 할 일이 원래 자리(행)를 지키고, 나중에 추가된 쪽이 새 행으로 밀리게.
    let createdAt: Date
}
