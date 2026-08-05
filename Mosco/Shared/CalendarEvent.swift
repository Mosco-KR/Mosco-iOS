import Foundation

/// 캘린더 격자에 그릴 일정 하나(제목 + 카테고리 색 + 시작/종료일).
/// `TodoItem`을 직접 넘기지 않고 이 구조체로 축약해서, 격자는 SwiftData를 모른다.
/// 반복 인스턴스도 각각 하나의 이벤트로 펼쳐지므로, id는 "할일ID-시작일" 형태다
/// (같은 할 일의 반복끼리 id가 겹치면 렌더링이 깨진다).
nonisolated struct CalendarEvent: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    /// 카테고리 객체가 아니라 색만 값으로 들고 온다. 예전엔 `TodoCategory?`를
    /// 그대로 담았는데, 그러면 이 구조체의 == 가 SwiftData @Model 동등성 비교가
    /// 된다 — 값 타입만 담으면 비교가 문자열 비교라 사실상 공짜다.
    let categoryColorHex: String?
    /// 소속 캘린더 색 — 여러 캘린더를 함께 볼 때만 표시에 쓴다.
    let calendarColorHex: String?
    /// 반복 일정에서 나온 이벤트인지(원본 포함) — 한 번짜리와 구분해 표시한다.
    let isRepeating: Bool
    /// 시작/종료일(하루 단위, startOfDay 기준). 하루짜리면 start == end.
    let start: Date
    let end: Date
    /// 완료된 항목은 격자에서도 흐리게 + 취소선으로 구분한다(TodoRow와 같은 표현).
    let isCompleted: Bool
    /// 같은 날 새 할 일이 끼어들 때 행 배정의 최종 타이브레이커 — 먼저 만든 할 일이
    /// 원래 자리(행)를 지키고, 나중에 추가된 쪽이 새 행으로 밀리게.
    let createdAt: Date
}
