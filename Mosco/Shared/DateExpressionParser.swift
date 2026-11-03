import Foundation

/// 한 줄에서 찾아낸 날짜 표현.
nonisolated struct DateSuggestion: Equatable, Sendable {
    /// 제목에서 들어낼 말("내일", "다음 주 금요일", "10/21").
    let matched: String
    /// 그 말이 가리키는 날(하루 단위).
    let date: Date
}

/// 한 줄 입력에서 **날짜**를 읽어낸다. 시각을 읽는 `TimeExpressionParser`의 짝이다.
///
/// ## 왜 필요한가
///
/// 이 앱의 전제는 한 줄 자연어인데 정작 날짜만 빠져 있었다 — "7시"는 읽으면서
/// "내일"은 못 읽으니, 날짜를 정하려면 칩을 눌러 시트를 열고 피커를 돌려야 했다.
/// 적는 길이 제일 짧아야 하는 앱에서 가장 자주 하는 일이 가장 긴 길이었다.
///
/// ## 어디까지 읽나
///
/// **되묻지 않아도 되는 것만 읽는다.** 틀리게 읽느니 안 읽는 편이 낫다 —
/// 안 읽으면 사람이 칩을 눌러 고르면 그만이지만, 엉뚱한 날로 저장되면 그게
/// 어디 갔는지부터 찾아야 한다. 그래서 "다음 달쯤", "주말에" 같은 흐릿한 말은
/// 일부러 안 다룬다.
nonisolated enum DateExpressionParser {

    /// 가장 먼저 걸리는 표현 하나. 없으면 nil.
    ///
    /// 찾는 순서가 곧 우선순위다 — 긴 말("다음 주 금요일")을 짧은 말("금요일")보다
    /// 먼저 본다. 안 그러면 "다음 주 금요일"에서 "금요일"만 떼어 이번 주로 읽는다.
    static func suggestion(in text: String, today: Date, calendar: Calendar = .current) -> DateSuggestion? {
        let start = calendar.startOfDay(for: today)

        for rule in rules {
            guard let found = rule(text, start, calendar) else { continue }
            return found
        }
        return nil
    }

    private typealias Rule = (String, Date, Calendar) -> DateSuggestion?

    private static let rules: [Rule] = [
        relativeDay,
        weekdayWithWeek,
        bareWeekday,
        monthAndDay,
        slashDate,
        dayOfMonth,
    ]

    // MARK: - 오늘 / 내일 / 모레 / 글피

    private static func relativeDay(_ text: String, _ today: Date, _ calendar: Calendar) -> DateSuggestion? {
        let words: [(String, Int)] = [("오늘", 0), ("내일", 1), ("낼", 1), ("모레", 2), ("글피", 3)]
        for (word, offset) in words where text.contains(word) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            return DateSuggestion(matched: word, date: date)
        }
        return nil
    }

    // MARK: - 요일

    /// 1=일 … 7=토. `Calendar.component(.weekday)`와 같은 규칙이다.
    private static let weekdayNames: [(String, Int)] = [
        ("일요일", 1), ("월요일", 2), ("화요일", 3), ("수요일", 4),
        ("목요일", 5), ("금요일", 6), ("토요일", 7),
    ]

    /// "이번 주 금요일" · "다음 주 월요일" · "담주 화요일".
    private static func weekdayWithWeek(_ text: String, _ today: Date, _ calendar: Calendar) -> DateSuggestion? {
        let prefixes: [(String, Int)] = [
            ("이번 주 ", 0), ("이번주 ", 0),
            ("다음 주 ", 1), ("다음주 ", 1), ("담주 ", 1),
        ]
        for (prefix, weekOffset) in prefixes {
            for (name, weekday) in weekdayNames {
                let phrase = prefix + name
                guard text.contains(phrase) else { continue }
                guard let date = next(weekday: weekday, from: today, weekOffset: weekOffset, calendar: calendar)
                else { continue }
                return DateSuggestion(matched: phrase, date: date)
            }
        }
        return nil
    }

    /// 요일만 적었으면 **다가오는 그 요일**이다. 오늘과 같은 요일이면 오늘로 본다 —
    /// "금요일에 하기"를 금요일에 적었다면 그건 오늘 이야기다.
    private static func bareWeekday(_ text: String, _ today: Date, _ calendar: Calendar) -> DateSuggestion? {
        for (name, weekday) in weekdayNames where text.contains(name) {
            guard let date = next(weekday: weekday, from: today, weekOffset: 0, calendar: calendar) else { continue }
            return DateSuggestion(matched: name, date: date)
        }
        return nil
    }

    private static func next(weekday: Int, from today: Date, weekOffset: Int, calendar: Calendar) -> Date? {
        let current = calendar.component(.weekday, from: today)
        var delta = weekday - current
        if delta < 0 { delta += 7 }
        let base = calendar.date(byAdding: .day, value: delta, to: today)
        guard weekOffset != 0 else { return base }
        return base.flatMap { calendar.date(byAdding: .day, value: 7 * weekOffset, to: $0) }
    }

    // MARK: - 날짜를 숫자로 적은 것

    /// "10월 21일" · "10월 21". 올해로 읽고, **이미 지났으면 내년**이다.
    private static func monthAndDay(_ text: String, _ today: Date, _ calendar: Calendar) -> DateSuggestion? {
        let pattern = #"(\d{1,2})\s*월\s*(\d{1,2})\s*일?"#
        guard let match = firstMatch(pattern, in: text), match.values.count == 2 else { return nil }
        let month = match.values[0], day = match.values[1]
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        return resolve(month: month, day: day, today: today, calendar: calendar)
            .map { DateSuggestion(matched: match.text, date: $0) }
    }

    /// "10/21". 날짜로만 읽는다 — "3/4쯤"처럼 분수로 쓰는 경우가 있어
    /// **달과 날이 둘 다 말이 될 때만** 받는다.
    private static func slashDate(_ text: String, _ today: Date, _ calendar: Calendar) -> DateSuggestion? {
        let pattern = #"(\d{1,2})/(\d{1,2})"#
        guard let match = firstMatch(pattern, in: text), match.values.count == 2 else { return nil }
        let month = match.values[0], day = match.values[1]
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        return resolve(month: month, day: day, today: today, calendar: calendar)
            .map { DateSuggestion(matched: match.text, date: $0) }
    }

    /// "21일". 이번 달 그 날로 읽고, **이미 지났으면 다음 달**이다.
    private static func dayOfMonth(_ text: String, _ today: Date, _ calendar: Calendar) -> DateSuggestion? {
        // 앞에 달이 적혀 있으면 그건 `monthAndDay`가 맡는다. 거기서 퇴짜 맞은 것
        // ("13월 1일")을 여기서 주워 "1일"로 읽으면, 말이 안 되는 입력이 **조용히
        // 그럴듯한 날짜**가 된다 — 안 읽는 편이 낫다.
        if firstMatch(#"\d{1,2}\s*월\s*\d{1,2}\s*일?"#, in: text) != nil { return nil }

        let pattern = #"(\d{1,2})\s*일"#
        guard let match = firstMatch(pattern, in: text), match.values.count == 1 else { return nil }
        let day = match.values[0]
        guard (1...31).contains(day) else { return nil }

        var components = calendar.dateComponents([.year, .month], from: today)
        components.day = day
        guard let candidate = calendar.date(from: components) else { return nil }
        if candidate >= today {
            return DateSuggestion(matched: match.text, date: candidate)
        }
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: candidate) else { return nil }
        return DateSuggestion(matched: match.text, date: nextMonth)
    }

    private static func resolve(month: Int, day: Int, today: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year], from: today)
        components.month = month
        components.day = day
        guard let candidate = calendar.date(from: components) else { return nil }
        if candidate >= today { return candidate }
        return calendar.date(byAdding: .year, value: 1, to: candidate)
    }

    // MARK: - 정규식

    private struct Match {
        let text: String
        let values: [Int]
    }

    private static func firstMatch(_ pattern: String, in text: String) -> Match? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let result = regex.firstMatch(in: text, range: range),
              let whole = Range(result.range, in: text)
        else { return nil }

        var values: [Int] = []
        for index in 1..<result.numberOfRanges {
            guard let captured = Range(result.range(at: index), in: text),
                  let value = Int(text[captured])
            else { continue }
            values.append(value)
        }
        return Match(text: String(text[whole]), values: values)
    }
}
