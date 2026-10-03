import Foundation

/// 이 앱이 "화면"으로 세는 것들. **여기 없는 화면은 안 보낸다** — 이벤트 목록과
/// 같은 규칙이다(`AnalyticsEvent`).
///
/// ## 왜 손으로 넣어야 하나
///
/// Firebase는 화면 전환을 자동으로 잡아주지만 그건 **UIKit의 뷰 컨트롤러가 뜰 때**다.
/// 이 앱은 SwiftUI라 그 자동 수집에 아무것도 안 걸린다. 2026년 9월 한 달 동안
/// GA4의 "페이지 및 화면" 보고서에 잡힌 것은 `UIColorPickerViewController`(설정의
/// 색 선택기)와 `PlatformAlertController`(알림창) 둘뿐이었다 — 시스템이 UIKit으로
/// 띄워주는 것만 잡힌 것이다. 전체 이벤트의 81%가 화면 이름 없이 `(not set)`으로
/// 묶였다. 그래서 주요 화면은 앱이 직접 알린다.
///
/// ## 이름 규칙
///
/// `snake_case`로 고정한다. 화면 이름은 한번 정하면 바꾸기 어렵다 — 바꾸는 순간
/// 그 전 데이터와 이어지지 않아서, 보고서에 같은 화면이 두 줄로 나온다.
///
/// ## 무엇을 화면으로 세고 무엇을 안 세나
///
/// **사람이 "다른 곳에 왔다"고 느끼는 자리만** 센다. 전체를 덮는 시트와 밀려 들어오는
/// 페이지가 거기 해당한다. 반대로 이런 것은 세지 않는다.
///
/// - 확인창·메뉴(`confirmationDialog`, 길게 누르기 메뉴) — 머물지 않고 바로 답한다
/// - 안내 오버레이(`TutorialOverlay`) — 그 흐름은 `tutorial_step`이 이미 더 자세히 센다
/// - 입력창(`QuickAddView`) — 달력 화면의 일부지 따로 간 곳이 아니다
nonisolated enum AnalyticsScreen: String, CaseIterable, Sendable {
    /// 달력 홈. 앱이 열리면 여기다.
    case calendar
    /// 하루 페이지(오늘 포함). **어디서 왔는지는 `day_opened`가 따로 센다** —
    /// 이쪽은 "얼마나 자주 보나", 저쪽은 "어느 문으로 들어오나"에 답한다.
    case day
    /// 설정.
    case settings
    /// 설정 > 캘린더 목록.
    case calendarList = "calendar_list"
    /// 설정 > 카테고리 목록.
    case categoryList = "category_list"
    /// 검색 시트. 닫을 때의 결과는 `search_closed`가 센다.
    case search
    /// 달 고르기 시트.
    case monthPicker = "month_picker"
    /// 카테고리 만들기·고치기 시트.
    case categoryEditor = "category_editor"
    /// 캘린더 만들기·고치기 시트.
    case calendarEditor = "calendar_editor"
    /// 메모 시트.
    case memo
    /// 날짜와 시간 고르기 시트.
    case eventSchedule = "event_schedule"
}
