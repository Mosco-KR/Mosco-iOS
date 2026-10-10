import Foundation

/// 알림을 **다시 걸어야 하는지** 판단하는 열쇠.
///
/// 앱 뿌리(`RootTabView`)가 이 문자열을 `.task(id:)`에 물려두고, 값이 달라질 때만
/// 통째로 다시 예약한다. 색이나 메모처럼 알림과 무관한 변경으로 매번 64개를 다시
/// 까는 것은 낭비라서 이렇게 한다.
///
/// 그래서 **여기 빠진 것은 "바뀌어도 알림이 안 바뀌는 것"이 된다.** 이 앱에서
/// 알림이 안 온다는 신고는 지금까지 세 번 다 같은 모양이었다 — 예약 계산은
/// 멀쩡한데, 다시 계산할 이유를 못 만든 것이다. 세 번 다 적어둔다.
///
/// - **권한 상태가 빠졌을 때**(~1.4.1): 실행 직후 재예약이 한 번 도는데 그때는
///   아직 권한을 안 물어본 상태라 "권한 없음"으로 돌아나가고, 그 뒤에 허용해도
///   키가 그대로라 다시 돌지 않았다. 앱을 뒤로 보냈다 돌아오기 전까지 알림이
///   하나도 안 걸려 있었다. 거부한 쪽은 전체 스위치가 함께 내려가며 키가 바뀌어서,
///   **허용한 사람만** 조용히 비어 있었다.
/// - **완료 여부가 빠졌을 때**(~1.4.1): 10시 일정을 9시 30분에 끝내도 9시 50분에
///   알림이 울렸다.
/// - **하루 요약 설정이 빠졌을 때**(~1.5.0): 받을 시각을 바꾸거나 꺼도, 할 일을
///   하나라도 손대기 전까지는 그대로였다. 설정 화면은 "닫으면 뿌리가 다시 건다"고
///   적어뒀지만 키에 그 값이 없어서 실제로는 돌지 않았다.
///
/// 계산을 `Shared/`로 꺼낸 것은 그래서다. 화면 구조체 안에 두면 테스트가 닿지
/// 않고, 닿지 않는 자리에서 같은 실수가 세 번 났다. 이제 "무엇이 키에 들어가야
/// 하는가"는 테스트가 지킨다(`ReminderScheduleKeyTests`).
nonisolated enum ReminderScheduleKey {

    /// 알림에 영향을 주는 것 전부를 문자열 하나로. 값 자체에는 뜻이 없고,
    /// **달라졌는지만** 본다.
    static func make(
        notificationsEnabled: Bool,
        authorizationStatus: Int,
        summaryEnabled: Bool,
        summaryHour: Int,
        summaryMinute: Int,
        todoFingerprints: [String]
    ) -> String {
        var parts: [String] = []
        parts.append(String(notificationsEnabled))
        parts.append(String(authorizationStatus))
        parts.append(String(summaryEnabled))
        parts.append("\(summaryHour):\(summaryMinute)")
        parts.append(todoFingerprints.joined(separator: ";"))
        return parts.joined(separator: "|")
    }

    /// 할 일 하나가 알림에 미치는 것들만 추린다.
    ///
    /// 한 줄짜리 배열 리터럴을 쓰지 않는 이유는 컴파일러다 — 항목이 늘어나면
    /// 타입 추론을 포기한다("unable to type-check this expression in reasonable
    /// time"). 하나씩 append하면 그 일이 없다.
    @MainActor
    static func fingerprint(of todo: TodoItem) -> String {
        var parts: [String] = []
        parts.append(todo.id.uuidString)
        parts.append(todo.title)
        parts.append(timeKey(todo.startTime))
        parts.append(timeKey(todo.date))
        parts.append(todo.repeatRule.rawValue)
        parts.append(timeKey(todo.repeatEndDate))
        parts.append(String(todo.isCompleted))
        parts.append(todo.completedDayKeys?.joined(separator: ",") ?? "-")
        if let category = todo.category {
            parts.append("\(category.notifiesBeforeStart)-\(category.notificationLeadMinutes)")
        } else {
            parts.append("-")
        }
        return parts.joined(separator: "|")
    }

    /// 날짜를 키에 넣을 수 있는 모양으로. 라이브 액티비티 열쇠도 같이 쓴다 —
    /// 두 열쇠가 묻는 것이 "이 값이 달라졌나"로 같아서, 표기가 갈리면 한쪽만
    /// 고치는 일이 생긴다.
    static func timeKey(_ date: Date?) -> String {
        guard let date else { return "-" }
        return String(date.timeIntervalSince1970)
    }
}
