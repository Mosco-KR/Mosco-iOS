import Foundation

/// 하루 요약 알림 하나.
nonisolated struct PlannedSummary: Equatable, Sendable {
    let id: String
    let fireDate: Date
    /// 그날 남아 있을 할 일의 수. **nil이면 "아직 모른다"** — 그날이 되기 전에
    /// 앱을 열면 다시 계산되므로, 먼 날은 숫자 없이 중립 문구로 간다.
    let remaining: Int?
}

/// "오늘 남은 것" 하루 요약 알림을 언제 몇 개 걸 것인가.
///
/// ## 왜 이게 필요한가
///
/// 지금까지 이 앱의 알림은 **전부 시작 전 한 번**이었다(`ReminderPlan`). 시작 시각이
/// 지나면 그 할 일은 알림 세계에서 사라진다. 그래서 네 종류가 알림을 영영 못 받았다 —
/// 날짜 없는 백로그, **시간을 안 적은 할 일**, 지난 할 일, 카테고리 알림을 꺼둔 것.
///
/// 두 번째가 특히 아팠다. "장보기"라고 한 줄 적는 것이 이 앱의 대표 입력인데,
/// 그 입력으로는 알림을 못 받았다.
///
/// 요약 하나가 그 넷을 **한꺼번에 덮는다.** 그리고 알림 예산을 거의 안 쓴다.
///
/// ## 왜 항목마다 안 보내나
///
/// 할 일 20개면 알림 20개다. iOS가 앱당 허용하는 대기 알림 64개를 금세 먹고,
/// 무엇보다 **사람이 알림을 통째로 끈다.** 한 번 끄면 돌아오지 않고, 그러면 정작
/// 중요한 시작 전 알림까지 같이 잃는다. 할 일 앱이 죽는 가장 흔한 길이다.
///
/// ## 숫자를 미리 박아야 하는 문제
///
/// 로컬 알림은 **내용을 예약할 때 정해야** 한다. 저녁 9시에 몇 개가 남았는지는
/// 그때 알 수 있는데 예약은 지금 해야 한다. 그래서 둘로 나눈다.
///
/// - **오늘과 내일**은 지금 계산한 숫자를 넣는다. 그 사이에 앱을 한 번이라도 열면
///   다시 계산되므로 거의 맞고, 틀려도 하루치다.
/// - **그 뒤**는 숫자 없이 중립 문구로 간다. 틀린 숫자를 보여주느니 안 보여준다.
///
/// 그리고 **남은 게 없으면 아예 안 건다.** 할 일이 0개인 날 저녁에 울리는 알림은
/// 그 자체로 끄고 싶은 이유가 된다. 먼 날(숫자를 모르는 날)은 지금 **지난 할 일이나
/// 날짜 없는 할 일이 있을 때만** 건다 — 그 둘은 가만히 둬도 사라지지 않는 것이라,
/// 일주일 뒤에도 뭔가 남아 있으리라고 보는 편이 맞다. 지금 아무것도 안 밀려 있으면
/// 일주일치 알림을 미리 깔아둘 이유가 없다.
nonisolated enum DailySummaryPlan {
    /// 며칠치를 걸어두나. 앱을 한동안 안 열어도 알림이 끊기지 않을 만큼이면 된다.
    static let horizonDays = 7
    /// 숫자를 넣는 날 수 — 오늘과 내일. 그보다 먼 날의 숫자는 맞을 가능성이 낮다.
    static let countedDays = 2

    static func make(
        from todos: [TodoSnapshot],
        backlogCount: Int,
        at time: DateComponents,
        now: Date,
        calendar: Calendar = .current,
        horizonDays: Int = horizonDays,
        countedDays: Int = countedDays
    ) -> [PlannedSummary] {
        guard let hour = time.hour, let minute = time.minute, horizonDays > 0 else { return [] }

        let today = calendar.startOfDay(for: now)
        // 가만히 둬도 사라지지 않는 것 — 먼 날까지 걸어둘지 정하는 근거다.
        let hasLingering = backlogCount > 0 || overdueCount(in: todos, on: today, calendar: calendar) > 0

        var planned: [PlannedSummary] = []
        for offset in 0..<horizonDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
            else { continue }
            // 이미 지난 시각은 예약할 수 없다 — 시스템이 조용히 버린다.
            guard fire > now else { continue }

            if offset < countedDays {
                let remaining = remainingCount(
                    in: todos, backlogCount: backlogCount, on: day, calendar: calendar
                )
                // 남은 게 없는 날은 안 건다. 0개짜리 저녁 알림은 그 자체로
                // 알림을 끄고 싶은 이유가 된다.
                guard remaining > 0 else { continue }
                planned.append(PlannedSummary(id: id(for: day), fireDate: fire, remaining: remaining))
            } else {
                guard hasLingering else { continue }
                planned.append(PlannedSummary(id: id(for: day), fireDate: fire, remaining: nil))
            }
        }
        return planned
    }

    /// 알림 식별자. 날짜를 넣어야 같은 요약끼리 덮어쓰지 않고, **접두사로 가를 수
    /// 있어야** 할 일별 알림과 섞이지 않는다(`TodoNotificationScheduler`가 걷어낼 때 쓴다).
    static let idPrefix = "daily-summary-"

    static func id(for day: Date) -> String { "\(idPrefix)\(day.dayKey)" }

    static func isSummary(id: String) -> Bool { id.hasPrefix(idPrefix) }

    /// 그날 저녁에 남아 있을 것 — 그날 걸치는 안 끝낸 일 + 그날 기준 지난 일 +
    /// 날짜를 안 정한 일. **셋을 함께 세는 것이 이 알림의 요점이다.**
    static func remainingCount(
        in todos: [TodoSnapshot],
        backlogCount: Int,
        on day: Date,
        calendar: Calendar
    ) -> Int {
        let dayStart = calendar.startOfDay(for: day)
        let onDay = todos.filter {
            $0.occurrenceStart(covering: dayStart, calendar: calendar) != nil
                && !$0.isCompleted(on: dayStart, calendar: calendar)
        }
        return onDay.count + overdueCount(in: todos, on: dayStart, calendar: calendar) + backlogCount
    }

    /// 그날 기준으로 지난 일. 반복은 "지난 것"이라는 개념이 없다 — 다음 회차가 또
    /// 온다(`TodoItem.isOverdue`와 같은 규칙).
    private static func overdueCount(in todos: [TodoSnapshot], on day: Date, calendar: Calendar) -> Int {
        let dayStart = calendar.startOfDay(for: day)
        return todos.count {
            $0.repeatRule == .none && !$0.isCompleted && calendar.startOfDay(for: $0.end) < dayStart
        }
    }
}

/// 요약 알림을 켤지와 몇 시에 받을지.
///
/// **기본은 켜짐, 저녁 9시다.** 끌 수 있게 두되 기본으로 켜는 이유는, 이 알림이
/// 없으면 시간을 안 적은 할 일은 알림을 한 번도 못 받기 때문이다 — 그게 이 앱의
/// 대표 입력이다. 남은 게 없는 날은 애초에 안 울리므로 조용한 사람에게는 조용하다.
nonisolated enum DailySummarySettings {
    static let enabledKey = "dailySummaryEnabled"
    static let hourKey = "dailySummaryHour"
    static let minuteKey = "dailySummaryMinute"

    static let defaultHour = 21
    static let defaultMinute = 0

    static func isEnabled(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? true
    }

    static func time(in defaults: UserDefaults) -> DateComponents {
        DateComponents(
            hour: defaults.object(forKey: hourKey) as? Int ?? defaultHour,
            minute: defaults.object(forKey: minuteKey) as? Int ?? defaultMinute
        )
    }

    /// 설정 화면의 `DatePicker`가 `Date`만 받는다. 날짜 부분은 쓰지 않는다.
    static func timeAsDate(in defaults: UserDefaults, calendar: Calendar = .current) -> Date {
        let components = time(in: defaults)
        return calendar.date(
            bySettingHour: components.hour ?? defaultHour,
            minute: components.minute ?? defaultMinute,
            second: 0,
            of: .now
        ) ?? .now
    }

    static func setTime(_ components: DateComponents, in defaults: UserDefaults) {
        defaults.set(components.hour ?? defaultHour, forKey: hourKey)
        defaults.set(components.minute ?? defaultMinute, forKey: minuteKey)
    }
}
