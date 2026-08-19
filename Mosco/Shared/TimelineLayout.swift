import Foundation

/// 시간표에 놓을 항목 하나 — 화면 타입(`TodoItem`)을 모르는 값이다.
/// 그래야 배치 계산을 SwiftUI 없이 테스트할 수 있다.
nonisolated struct TimelineItem: Equatable, Identifiable {
    let id: String
    /// 자정으로부터 몇 분. 24시간을 넘기는 값은 들어오지 않는다(하루 단위로 자른다).
    let startMinute: Int
    let endMinute: Int

    /// 시각이 없는 항목은 시간축에 놓을 자리가 없다 — 상단에 따로 모은다.
    var isTimed: Bool { startMinute >= 0 }
}

/// 배치 결과. 세로 위치는 분으로 주고, 실제 픽셀 변환은 화면이 한다 —
/// 그래야 같은 계산을 확대·축소와 무관하게 쓸 수 있다.
nonisolated struct TimelinePlacement: Equatable, Identifiable {
    let id: String
    let startMinute: Int
    let endMinute: Int
    /// 같은 시간대에 여러 개가 겹칠 때 몇 번째 열인가 (0부터).
    let column: Int
    /// 그 시간대에 몇 개가 나란히 서는가. 폭은 `1 / columnCount`다.
    let columnCount: Int

    var durationMinutes: Int { endMinute - startMinute }
}

/// 하루치 일정을 세로 시간축에 놓는다.
///
/// 겹치는 일정을 어떻게 다루느냐가 전부다. 그냥 겹쳐 그리면 뒤엣것이 앞엣것에
/// 가려서 **있는데 안 보이는** 일정이 생긴다. 그래서 겹치는 무리를 찾아 나란히
/// 세우고 폭을 나눈다 — 구글 캘린더 일간 뷰와 같은 방식이다.
///
/// 픽셀을 계산하지 않는다. 분 단위 위치와 열 정보만 내고 실제 크기는 화면이
/// 정한다 — 확대·축소를 화면 쪽에서 바꿔도 이 계산은 그대로다.
nonisolated enum TimelineLayout {
    /// 시각이 없는 항목이 갖는 `startMinute`.
    static let untimed = -1

    /// 너무 짧은 일정도 최소한 읽을 수 있게 — 1분짜리를 1분 높이로 그리면
    /// 제목이 한 글자도 안 들어간다. 배치 계산에서만 늘리고 실제 시각은 안 바꾼다.
    static let minimumDurationMinutes = 30

    /// 시각 있는 항목만 배치한다. 시각 없는 항목은 호출부가 따로 다룬다.
    ///
    /// 결과는 **시작 시각 순**이다. 같은 시각이면 id 순 — 입력 순서가 달라도
    /// 같은 화면이 나와야 하기 때문이다.
    static func place(_ items: [TimelineItem]) -> [TimelinePlacement] {
        let timed = items
            .filter(\.isTimed)
            .sorted { $0.startMinute != $1.startMinute ? $0.startMinute < $1.startMinute : $0.id < $1.id }
        guard !timed.isEmpty else { return [] }

        // 표시상의 끝 — 너무 짧으면 읽을 수 있는 만큼 늘린다.
        func displayEnd(_ item: TimelineItem) -> Int {
            max(item.endMinute, item.startMinute + minimumDurationMinutes)
        }

        var result: [TimelinePlacement] = []

        // 서로 겹치는 것끼리 무리를 짓는다. 무리 안에서만 폭을 나누면 되므로,
        // 하루 전체를 한 번에 볼 필요가 없다 — 아침 회의 때문에 저녁 운동이
        // 좁아지면 안 된다.
        var group: [TimelineItem] = []
        var groupEnd = Int.min

        func flush() {
            guard !group.isEmpty else { return }
            // 무리 안에서 열을 배정한다. 앞 열이 비었으면 재사용 —
            // 겹치지 않는데 새 열을 만들면 폭만 좁아진다.
            var columnEnds: [Int] = []
            var columns: [Int] = []
            for item in group {
                if let free = columnEnds.firstIndex(where: { $0 <= item.startMinute }) {
                    columnEnds[free] = displayEnd(item)
                    columns.append(free)
                } else {
                    columnEnds.append(displayEnd(item))
                    columns.append(columnEnds.count - 1)
                }
            }
            let width = columnEnds.count
            for (item, column) in zip(group, columns) {
                result.append(TimelinePlacement(
                    id: item.id,
                    startMinute: item.startMinute,
                    endMinute: displayEnd(item),
                    column: column,
                    columnCount: width
                ))
            }
            group = []
            groupEnd = Int.min
        }

        for item in timed {
            if !group.isEmpty && item.startMinute >= groupEnd {
                flush()
            }
            group.append(item)
            groupEnd = max(groupEnd, displayEnd(item))
        }
        flush()

        return result.sorted {
            $0.startMinute != $1.startMinute ? $0.startMinute < $1.startMinute : $0.id < $1.id
        }
    }

    /// 시작·종료 시각을 시간축이 쓰는 분 단위로 바꾼다.
    ///
    /// 규칙 셋이다.
    /// - 시작 시각이 없으면 축에 못 놓는다(`untimed`).
    /// - 종료 시각이 없거나 시작보다 앞서면 기본 길이를 준다. 시작만 적어둔 할 일이
    ///   대부분이라 이 경우가 흔하다.
    /// - 자정을 넘기면 그날 끝(24시)에서 자른다. 하루치 화면이므로 다음 날까지
    ///   이어 그리면 축이 어긋난다.
    static func minutes(
        start: Date?,
        end: Date?,
        calendar: Calendar = .current,
        defaultDurationMinutes: Int = 60
    ) -> (start: Int, end: Int) {
        guard let start else { return (untimed, untimed) }
        let s = minuteOfDay(start, calendar: calendar)

        guard let end else { return (s, min(s + defaultDurationMinutes, 24 * 60)) }
        let e = minuteOfDay(end, calendar: calendar)
        // 종료가 시작보다 앞이면 다음 날로 넘어간 것이다 — 그날 끝에서 자른다.
        guard e > s else { return (s, min(s + defaultDurationMinutes, 24 * 60)) }
        return (s, min(e, 24 * 60))
    }

    private static func minuteOfDay(_ date: Date, calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// 축 눈금에 적는 글자 — `오전 01`, `오전 12`, `오후 01`, `오후 11`.
    ///
    /// **앱의 다른 시각 표기와 일부러 다르다.** 다른 곳은 `오전 9시`처럼 읽는
    /// 말이지만 축 눈금은 문장이 아니라 자(ruler)다. `오전 9시`와 `오후 12시`가
    /// 섞이면 글자 수가 달라 눈금이 들쭉날쭉해지고, 세로로 훑을 때 기준선이
    /// 흔들린다. 두 자리로 맞춰 고정한다.
    ///
    /// 12시 처리는 다른 곳과 같다 — 오전 12시가 자정, 오후 12시가 정오다.
    static func axisLabel(hour: Int) -> String {
        // 24시는 다음 날 0시다. 축의 마지막 눈금으로만 나온다.
        let normalized = hour % 24
        let period = normalized >= 12 ? "오후" : "오전"
        var hour12 = normalized % 12
        if hour12 == 0 { hour12 = 12 }
        return String(format: "%@ %02d", period, hour12)
    }

    /// 시간축을 어디부터 어디까지 그릴지.
    ///
    /// 늘 0시~24시를 그리면 새벽 여섯 시간이 늘 비어 있고, 정작 일정이 몰린
    /// 시간대는 좁아진다. 그래서 **일정이 있는 범위**를 한 시간씩 여유를 두고 낸다.
    /// 일정이 없으면 하루 일과에 해당하는 기본 범위를 쓴다.
    static func visibleHourRange(
        _ items: [TimelineItem],
        fallback: ClosedRange<Int> = 8...22
    ) -> ClosedRange<Int> {
        let timed = items.filter(\.isTimed)
        guard !timed.isEmpty else { return fallback }

        let first = timed.map(\.startMinute).min()! / 60
        let last = timed.map { max($0.endMinute, $0.startMinute + minimumDurationMinutes) }.max()!
        // 끝나는 시각이 정각이면 그 시간대는 이미 끝난 것이라 한 칸 더 그리지 않는다.
        let lastHour = last % 60 == 0 ? last / 60 : last / 60 + 1

        return max(0, first - 1)...min(24, max(lastHour + 1, first + 2))
    }
}
