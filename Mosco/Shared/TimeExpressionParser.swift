import Foundation

/// 제목 안에서 찾아낸 시간 표현 하나("토큰").
/// `hour24`가 있으면 오전/오후가 확정된 것이고, `hour12`만 있으면 모호해서 물어봐야 한다.
nonisolated struct TimeToken: Equatable {
    let range: Range<String.Index>
    let hour24: Int?
    let hour12: Int?
    let minute: Int
}

/// 제목 하나에 담긴 시간 표현 — 두 개가 `~`나 `-`로 이어지면 시작~종료 범위
/// (예: `4시~7시`)로, 하나뿐이면 단일 시간으로 다룬다.
nonisolated struct TimeSuggestion: Equatable {
    let matched: String
    let startHour24: Int?
    let startHour12: Int?
    let startMinute: Int
    /// 범위로 인식됐을 때만 채워진다.
    let endHour24: Int?
    let endHour12: Int?
    let endMinute: Int?
}

/// 한 줄 입력에서 시각을 읽어내는 순수 함수 모음.
///
/// 예전엔 `QuickAddView` 안의 `private static`이었다 — 즉 화면 구조체를 띄우지
/// 않으면 부를 수 없었고, `private`이라 `@testable import`로도 안 뚫려서
/// **테스트가 한 줄도 닿지 못했다.** `4시~7시`의 종료 시각과 오전/오후 해석은
/// 반복해서 깨진 자리인데(`CLAUDE.md` R7 표), 확인할 방법이 사람이 앱을 켜서
/// 한 줄씩 쳐보는 것뿐이었다. 그래서 밖으로 꺼냈다.
///
/// 화면에 대한 의존은 없다. 문자열을 받아 값을 낸다.
nonisolated enum TimeExpressionParser {

    /// 지원 표현: `오후 7시`, `오전 7시 30분`, `7시`, `7시 반`, `19:30`, `7:30`,
    /// `7pm`, `7 PM`, `7:30pm`, `noon`, `午後7時`, `7時半`, `19時`, 그리고 이들의
    /// 범위(`4시~7시`, `4:00-19:00`, `2pm~5pm`, `14時〜17時`).
    ///
    /// **앱 언어와 무관하게 세 언어를 다 읽는다.** 한국어로 쓰는 사람도 `7pm`이라고
    /// 치고, 일본어 사용자도 `19:30`이라고 친다. 언어별로 갈라 읽으면 그게 막힌다.
    static func suggestion(in text: String) -> TimeSuggestion? {
        let tokens = tokens(in: text)
        guard let first = tokens.first else { return nil }

        if tokens.count >= 2 {
            let second = tokens[1]
            let between = text[first.range.upperBound..<second.range.lowerBound]
                .trimmingCharacters(in: .whitespaces)
            if between.isEmpty || Self.rangeSeparators.contains(between) {
                return TimeSuggestion(
                    matched: String(text[first.range.lowerBound..<second.range.upperBound]),
                    startHour24: first.hour24, startHour12: first.hour12, startMinute: first.minute,
                    endHour24: second.hour24, endHour12: second.hour12, endMinute: second.minute
                )
            }
        }

        return TimeSuggestion(
            matched: String(text[first.range]),
            startHour24: first.hour24, startHour12: first.hour12, startMinute: first.minute,
            endHour24: nil, endHour12: nil, endMinute: nil
        )
    }

    /// 두 시각을 범위로 잇는 기호. 일본어 물결표(`〜`, `～`)와 영어 `to`까지 받는다.
    private static let rangeSeparators: Set<String> = ["~", "-", "–", "〜", "～", "to", "から"]

    /// 제목 안의 모든 시간 표현을 위치 순서대로 찾는다. 같은 자리를 여러 패턴이
    /// 동시에 매칭하면(예: `오후 7시`가 `N시` 패턴에도 걸림) 더 구체적인(긴) 쪽만 남긴다.
    static func tokens(in text: String) -> [TimeToken] {
        var found: [TimeToken] = []

        for match in text.matches(of: /(오전|오후)\s*(\d{1,2})\s*시(?:\s*(반|\d{1,2}\s*분))?/) {
            guard let hour = Int(match.2), (1...12).contains(hour) else { continue }
            let isPM = match.1 == "오후"
            found.append(TimeToken(
                range: match.range,
                hour24: isPM ? (hour == 12 ? 12 : hour + 12) : (hour == 12 ? 0 : hour),
                hour12: nil,
                minute: parseMinute(match.3.map(String.init))
            ))
        }
        // `7pm`, `7 PM`, `7:30pm`, `7 p.m.` — 뒤에 글자가 이어지면 시각이 아니다
        // (`5 amazing things`의 `5 am`).
        for match in text.matches(of: /(\d{1,2})(?::(\d{2}))?\s*(?:(am|pm)\b|(a\.m\.|p\.m\.))/.ignoresCase()) {
            guard let hour = Int(match.1), (1...12).contains(hour) else { continue }
            let minute = match.2.flatMap { Int($0) } ?? 0
            guard minute <= 59 else { continue }
            let period = (match.3 ?? match.4).map { $0.lowercased() } ?? ""
            found.append(TimeToken(
                range: match.range,
                hour24: resolvedHour24(hour12: hour, isPM: period.hasPrefix("p")),
                hour12: nil,
                minute: minute
            ))
        }
        for match in text.matches(of: /\b(noon|midnight)\b/.ignoresCase()) {
            found.append(TimeToken(
                range: match.range,
                hour24: match.1.lowercased() == "noon" ? 12 : 0,
                hour12: nil,
                minute: 0
            ))
        }
        for match in text.matches(of: /(午前|午後)\s*(\d{1,2})\s*時(?:\s*(半|\d{1,2}\s*分))?/) {
            guard let hour = number(match.2), (1...12).contains(hour) else { continue }
            found.append(TimeToken(
                range: match.range,
                hour24: resolvedHour24(hour12: hour, isPM: match.1 == "午後"),
                hour12: nil,
                minute: parseMinute(match.3.map(String.init))
            ))
        }
        // 일본어는 `19時`처럼 24시간제로도 흔히 쓴다. 13시부터는 오전/오후를 물을 것이 없다.
        for match in text.matches(of: /(\d{1,2})\s*時(?:\s*(半|\d{1,2}\s*分))?/) {
            guard let hour = number(match.1), hour <= 23 else { continue }
            let minute = parseMinute(match.2.map(String.init))
            if hour >= 13 || hour == 0 {
                found.append(TimeToken(range: match.range, hour24: hour, hour12: nil, minute: minute))
            } else {
                found.append(TimeToken(range: match.range, hour24: nil, hour12: hour, minute: minute))
            }
        }
        for match in text.matches(of: /(\d{1,2}):(\d{2})/) {
            guard let hour = Int(match.1), let minute = Int(match.2), hour <= 23, minute <= 59 else { continue }
            if hour >= 13 || hour == 0 {
                found.append(TimeToken(range: match.range, hour24: hour, hour12: nil, minute: minute))
            } else {
                found.append(TimeToken(range: match.range, hour24: nil, hour12: hour, minute: minute))
            }
        }
        for match in text.matches(of: /(\d{1,2})\s*시(?:\s*(반|\d{1,2}\s*분))?/) {
            guard let hour = Int(match.1), (1...12).contains(hour) else { continue }
            found.append(TimeToken(range: match.range, hour24: nil, hour12: hour, minute: parseMinute(match.2.map(String.init))))
        }

        // 시작 위치 오름차순, 같은 시작이면 더 긴(구체적인) 것 먼저 오도록 정렬한 뒤,
        // 이미 고른 토큰과 겹치는 뒷것들은 버린다.
        found.sort {
            $0.range.lowerBound != $1.range.lowerBound
                ? $0.range.lowerBound < $1.range.lowerBound
                : $0.range.upperBound > $1.range.upperBound
        }
        var deduped: [TimeToken] = []
        for token in found {
            if let last = deduped.last, last.range.overlaps(token.range) { continue }
            deduped.append(token)
        }
        return deduped
    }

    static func parseMinute(_ text: String?) -> Int {
        guard let text else { return 0 }
        if text == "반" || text == "半" { return 30 }
        return number(text.filter(\.isNumber)) ?? 0
    }

    /// 전각 숫자(`７`)도 읽는다. 일본어 자판은 숫자를 전각으로 내는 일이 잦고,
    /// 정규식의 `\d`는 전각을 숫자로 잡지만 `Int()`는 못 읽는다.
    static func number(_ text: some StringProtocol) -> Int? {
        Int(String(text).applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? String(text))
    }

    /// `hour12`를 주어진 오전/오후로 확정한 24시간제 값.
    /// 12시가 특이하다 — 오전 12시는 0시(자정), 오후 12시는 12시(정오)다.
    static func resolvedHour24(hour12: Int, isPM: Bool) -> Int {
        isPM ? (hour12 == 12 ? 12 : hour12 + 12) : (hour12 == 12 ? 0 : hour12)
    }
}
