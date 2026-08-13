import Foundation

/// 한국 공휴일. 양력 고정 공휴일은 그대로 계산하고, 설날/추석/부처님오신날처럼
/// 음력 기준인 날은 그레고리력 날짜를 하루씩 `.chinese` 캘린더로 변환해 목표
/// 음력 월/일과 일치하는 날을 찾는 방식으로 구한다 — `DateComponents(year:)`를
/// `.chinese` 캘린더에 바로 넣으면 연호(era) 기준 연도라 전혀 다른 날짜가 나와서
/// (검증 결과 서기 연도와 안 맞음), 그레고리력 → 음력 순방향 변환만 신뢰해서 쓴다.
///
/// 대체공휴일도 함께 계산한다. 달력에 빨갛게 칠할 날을 정하는 게 이 타입의 일인데,
/// 요즘은 쉬는 날의 상당수가 대체공휴일이라 그걸 빼면 "쉬는 날 보는 달력"으로서
/// 절반만 맞는 셈이 된다.
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

        // 대체공휴일을 붙이려면 "이미 쉬는 날이 어디인가"를 날짜로 따져야 해서,
        // 바로 dayKey 사전에 넣지 않고 날짜를 든 채로 모았다가 마지막에 옮긴다.
        var holidays: [Holiday] = []

        func addSolar(_ month: Int, _ day: Int, _ name: String, substitution: Substitution) {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            guard let date = calendar.date(from: components) else { return }
            holidays.append(Holiday(date: date, name: name, substitution: substitution))
        }

        // 신정과 현충일만 대체공휴일이 없다 — 규정에서 빠져 있다.
        addSolar(1, 1, "신정", substitution: .none)
        addSolar(3, 1, "삼일절", substitution: .weekend)
        addSolar(5, 5, "어린이날", substitution: .childrensDay)
        addSolar(6, 6, "현충일", substitution: .none)
        addSolar(8, 15, "광복절", substitution: .weekend)
        addSolar(10, 3, "개천절", substitution: .weekend)
        addSolar(10, 9, "한글날", substitution: .weekend)
        addSolar(12, 25, "크리스마스", substitution: .weekend)

        func addLunarSpan(searchFrom: (Int, Int), searchTo: (Int, Int), lunarMonth: Int, lunarDay: Int, name: String) {
            guard let base = findLunarDate(
                gregorianYear: year, lunarMonth: lunarMonth, lunarDay: lunarDay,
                searchStart: searchFrom, searchEnd: searchTo
            ) else { return }
            for offset in -1...1 {
                guard let date = calendar.date(byAdding: .day, value: offset, to: base) else { continue }
                holidays.append(
                    Holiday(
                        date: date,
                        name: offset == 0 ? name : "\(name) 연휴",
                        substitution: .sundayOnly
                    )
                )
            }
        }

        addLunarSpan(searchFrom: (1, 15), searchTo: (2, 25), lunarMonth: 1, lunarDay: 1, name: "설날")
        addLunarSpan(searchFrom: (8, 25), searchTo: (10, 15), lunarMonth: 8, lunarDay: 15, name: "추석")

        if let buddha = findLunarDate(gregorianYear: year, lunarMonth: 4, lunarDay: 8, searchStart: (4, 20), searchEnd: (6, 10)) {
            holidays.append(Holiday(date: buddha, name: "부처님오신날", substitution: .weekend))
        }

        holidays.append(contentsOf: substitutes(for: holidays))

        // 한 날에 둘이 겹치면(2025년의 어린이날·부처님오신날) 먼저 넣은 쪽을 남긴다 —
        // 칸이 한 줄뿐이라 둘 다는 못 쓰고, 나중 것이 덮어쓰면 더 익숙한 이름이 밀린다.
        var result: [String: String] = [:]
        for holiday in holidays where result[holiday.date.dayKey] == nil {
            result[holiday.date.dayKey] = holiday.name
        }

        cache[year] = result
        return result
    }

    private struct Holiday {
        let date: Date
        let name: String
        let substitution: Substitution
    }

    /// 이 공휴일이 어떤 날과 겹칠 때 대체공휴일이 붙는지.
    private enum Substitution {
        /// 신정·현충일 — 겹쳐도 밀어주지 않는다.
        case none
        /// 설날·추석 연휴 — **일요일과 겹칠 때만**. 토요일은 애초에 공휴일이 아니라
        /// 규정에서 말하는 "다른 공휴일과 겹침"에 해당하지 않는다.
        case sundayOnly
        /// 삼일절·부처님오신날·광복절·개천절·한글날·크리스마스 —
        /// 토·일 어느 쪽과 겹쳐도 붙는다.
        case weekend
        /// 어린이날만 조건이 하나 더 있다 — 토·일뿐 아니라 **다른 공휴일과 겹쳐도**
        /// 붙는다. 2025년 어린이날이 부처님오신날과 같은 날이라 5월 6일이 쉬는 날이
        /// 된 게 이 조항이다.
        case childrensDay
    }

    /// 주말과 겹친 공휴일을 뒤로 밀어 만든 대체공휴일들.
    ///
    /// 밀어놓을 자리는 **뒤로 가며 처음 만나는, 평일이면서 아직 공휴일이 아닌 날**이다.
    /// 연휴가 통째로 주말에 걸리면 대체공휴일이 둘 이상 생기는데, 앞서 잡아둔 자리까지
    /// 함께 피해야 두 날이 한 날에 겹쳐 하나로 사라지지 않는다 — 그래서 날짜순으로
    /// 훑으면서 `occupied`를 채워 나간다.
    private static func substitutes(for holidays: [Holiday]) -> [Holiday] {
        var occupied = Set(holidays.map(\.date.dayKey))
        var result: [Holiday] = []

        // 같은 날에 공휴일이 둘 이상 앉아 있는지 — 어린이날 조항에만 쓴다.
        var namesByDay: [String: Int] = [:]
        for holiday in holidays {
            namesByDay[holiday.date.dayKey, default: 0] += 1
        }

        for holiday in holidays.sorted(by: { $0.date < $1.date }) {
            let weekday = calendar.component(.weekday, from: holiday.date)
            let isWeekend = weekday == 1 || weekday == 7
            let overlaps: Bool
            switch holiday.substitution {
            case .none: overlaps = false
            case .sundayOnly: overlaps = weekday == 1
            case .weekend: overlaps = isWeekend
            case .childrensDay: overlaps = isWeekend || (namesByDay[holiday.date.dayKey] ?? 0) > 1
            }
            guard overlaps else { continue }

            // 연휴가 아무리 길어도 이 안에서 평일이 나온다.
            var cursor = holiday.date
            for _ in 0..<14 {
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
                let nextWeekday = calendar.component(.weekday, from: cursor)
                guard nextWeekday != 1, nextWeekday != 7, !occupied.contains(cursor.dayKey) else { continue }
                occupied.insert(cursor.dayKey)
                result.append(Holiday(date: cursor, name: "대체공휴일", substitution: .none))
                break
            }
        }

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
