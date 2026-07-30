import Foundation

/// 한국 공휴일. 양력 고정 공휴일은 그대로 계산하고, 설날/추석/부처님오신날처럼
/// 음력 기준인 날은 그레고리력 날짜를 하루씩 `.chinese` 캘린더로 변환해 목표
/// 음력 월/일과 일치하는 날을 찾는 방식으로 구한다 — `DateComponents(year:)`를
/// `.chinese` 캘린더에 바로 넣으면 연호(era) 기준 연도라 전혀 다른 날짜가 나와서
/// (검증 결과 서기 연도와 안 맞음), 그레고리력 → 음력 순방향 변환만 신뢰해서 쓴다.
/// 대체공휴일 규정은 다루지 않는다 — 참고용 표시가 목적.
enum KoreanHoliday {
    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return cal
    }()

    private static var lunarCalendar: Calendar {
        var cal = Calendar(identifier: .chinese)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return cal
    }

    private static var cache: [Int: [String: String]] = [:]

    static func name(for date: Date) -> String? {
        let year = calendar.component(.year, from: date)
        let key = date.dayKey
        for candidateYear in [year, year - 1, year + 1] {
            if let name = holidays(forYear: candidateYear)[key] {
                return name
            }
        }
        return nil
    }

    static func holidays(forYear year: Int) -> [String: String] {
        if let cached = cache[year] { return cached }

        var result: [String: String] = [:]

        func addSolar(_ month: Int, _ day: Int, _ name: String) {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            guard let date = calendar.date(from: components) else { return }
            result[date.dayKey] = name
        }

        addSolar(1, 1, "신정")
        addSolar(3, 1, "삼일절")
        addSolar(5, 5, "어린이날")
        addSolar(6, 6, "현충일")
        addSolar(8, 15, "광복절")
        addSolar(10, 3, "개천절")
        addSolar(10, 9, "한글날")
        addSolar(12, 25, "크리스마스")

        func addLunarSpan(searchFrom: (Int, Int), searchTo: (Int, Int), lunarMonth: Int, lunarDay: Int, name: String) {
            guard let base = findLunarDate(
                gregorianYear: year, lunarMonth: lunarMonth, lunarDay: lunarDay,
                searchStart: searchFrom, searchEnd: searchTo
            ) else { return }
            if let dayBefore = calendar.date(byAdding: .day, value: -1, to: base) {
                result[dayBefore.dayKey] = "\(name) 연휴"
            }
            result[base.dayKey] = name
            if let dayAfter = calendar.date(byAdding: .day, value: 1, to: base) {
                result[dayAfter.dayKey] = "\(name) 연휴"
            }
        }

        addLunarSpan(searchFrom: (1, 15), searchTo: (2, 25), lunarMonth: 1, lunarDay: 1, name: "설날")
        addLunarSpan(searchFrom: (8, 25), searchTo: (10, 15), lunarMonth: 8, lunarDay: 15, name: "추석")

        if let buddha = findLunarDate(gregorianYear: year, lunarMonth: 4, lunarDay: 8, searchStart: (4, 20), searchEnd: (6, 10)) {
            result[buddha.dayKey] = "부처님오신날"
        }

        cache[year] = result
        return result
    }

    /// 주어진 그레고리력 연도의 탐색 구간 안에서, 음력 월/일이 일치하는 첫 날짜를 찾는다.
    private static func findLunarDate(
        gregorianYear: Int,
        lunarMonth: Int,
        lunarDay: Int,
        searchStart: (month: Int, day: Int),
        searchEnd: (month: Int, day: Int)
    ) -> Date? {
        var startComponents = DateComponents()
        startComponents.year = gregorianYear
        startComponents.month = searchStart.month
        startComponents.day = searchStart.day
        var endComponents = DateComponents()
        endComponents.year = gregorianYear
        endComponents.month = searchEnd.month
        endComponents.day = searchEnd.day

        guard var cursor = calendar.date(from: startComponents),
              let end = calendar.date(from: endComponents)
        else { return nil }

        let lunar = lunarCalendar
        while cursor <= end {
            if lunar.component(.month, from: cursor) == lunarMonth,
               lunar.component(.day, from: cursor) == lunarDay {
                return cursor
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return nil
    }
}
