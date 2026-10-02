#if DEBUG
import Foundation
import SwiftData

/// 스토어 미리보기를 찍기 위한 디버그 전용 길. 릴리스 빌드에는 들어가지 않는다.
///
/// 미리보기는 언어마다 다시 찍어야 하고, 화면이 바뀔 때마다 또 찍어야 한다. 그때마다
/// 손으로 할 일 열일곱 개를 세 언어로 쳐 넣는 건 한 번은 해도 두 번은 안 하게 된다.
/// 그래서 실행 인자 하나로 **예시 할 일을 채우고 찍을 화면까지 바로 연다.**
///
/// ```bash
/// xcrun simctl launch 'iPhone 17 Pro' com.Mosco.App \
///   -MoscoResetStore -MoscoScreenshot today -AppleLanguages "(ja)" -AppleLocale ja_JP
/// ```
///
/// `-MoscoResetStore`와 같이 쓴다 — 빈 저장소에서만 채우므로, 안 붙이면 전에 찍은
/// 언어의 할 일이 그대로 남는다. 안내와 권한 창은 이 모드에서 뜨지 않는다.
@MainActor
enum ScreenshotDemo {
    static let argument = "-MoscoScreenshot"

    enum Scene: String {
        /// 달력 홈. 한 달에 할 일 막대가 찬 모습.
        case month
        /// 달력 홈에서 한 줄을 막 친 순간. 시간 칩이 떠 있다.
        case compose
        /// 오늘 페이지. 목록이냐 시간표냐는 `-dayViewMode timeline`으로 고른다.
        case today
    }

    static let scene: Scene? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: argument), index + 1 < arguments.count else { return nil }
        return Scene(rawValue: arguments[index + 1])
    }()

    static var isActive: Bool { scene != nil }

    /// 입력창에 미리 쳐 둘 한 줄. 시간 칩이 하나만 뜨는 문장이어야 한다.
    static var composeText: String {
        switch AppLanguage.current {
        case .ko: "저녁 약속 오후 7시"
        case .en: "Dinner 7pm"
        case .ja: "夕食 午後7時"
        }
    }

    private struct Sample {
        let offset: Int
        var length = 1
        var hour: Int?
        var minute = 0
        let category: Int
        let ko: String
        let en: String
        let ja: String
        var isCompleted = false
    }

    /// 0은 기본 카테고리, 1~3은 아래에서 만드는 일·운동·약속.
    private static let samples: [Sample] = [
        Sample(offset: 0, hour: 10, category: 1, ko: "팀 회의", en: "Standup", ja: "チーム会議"),
        Sample(offset: 0, hour: 12, minute: 30, category: 3, ko: "점심 약속", en: "Lunch with Sam", ja: "ランチ"),
        Sample(offset: 0, hour: 19, category: 2, ko: "러닝", en: "Run", ja: "ランニング"),
        Sample(offset: 0, category: 0, ko: "장보기", en: "Groceries", ja: "買い物"),
        Sample(offset: 0, category: 0, ko: "세탁소 들르기", en: "Dry cleaning", ja: "クリーニング", isCompleted: true),
        Sample(offset: 1, category: 1, ko: "보고서 마감", en: "Report due", ja: "レポート締切"),
        Sample(offset: 3, length: 3, category: 3, ko: "제주 여행", en: "Beach trip", ja: "京都旅行"),
        Sample(offset: 7, hour: 19, category: 2, ko: "필라테스", en: "Pilates", ja: "ピラティス"),
        Sample(offset: 9, hour: 15, category: 0, ko: "치과", en: "Dentist", ja: "歯医者"),
        Sample(offset: 12, length: 2, category: 1, ko: "출장", en: "Business trip", ja: "出張"),
        Sample(offset: 14, hour: 7, category: 2, ko: "러닝", en: "Run", ja: "ランニング"),
        Sample(offset: 16, category: 3, ko: "생일 파티", en: "Birthday", ja: "誕生日会"),
        Sample(offset: 19, hour: 14, category: 1, ko: "분기 리뷰", en: "Review", ja: "レビュー"),
        Sample(offset: 21, category: 2, ko: "등산", en: "Hiking", ja: "登山"),
        Sample(offset: 24, hour: 18, category: 3, ko: "가족 모임", en: "Family", ja: "家族で食事"),
        Sample(offset: 27, hour: 10, category: 1, ko: "발표", en: "Demo day", ja: "発表"),
        Sample(offset: 29, category: 0, ko: "건강검진", en: "Checkup", ja: "健康診断"),
    ]

    /// 기본 카테고리가 만들어진 뒤에 부른다. 할 일이 하나라도 있으면 아무것도 하지 않는다.
    static func seedIfNeeded(in context: ModelContext) {
        guard isActive else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<TodoItem>())) ?? 0
        guard existing == 0 else { return }

        let language = AppLanguage.current
        func pick(_ ko: String, _ en: String, _ ja: String) -> String {
            switch language {
            case .ko: ko
            case .en: en
            case .ja: ja
            }
        }

        let defaultCategory = (try? context.fetch(FetchDescriptor<TodoCategory>()))?.first(where: \.isDefault)
        let extras = [
            TodoCategory(name: pick("일", "Work", "仕事"), colorHex: "3B82F6", sortOrder: 1),
            TodoCategory(name: pick("운동", "Exercise", "運動"), colorHex: "22C55E", sortOrder: 2),
            TodoCategory(name: pick("약속", "Plans", "予定"), colorHex: "F59E0B", sortOrder: 3),
        ]
        extras.forEach(context.insert)
        let categories: [TodoCategory?] = [defaultCategory] + extras

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        for sample in samples {
            guard let day = calendar.date(byAdding: .day, value: sample.offset, to: today) else { continue }
            let end = sample.length > 1 ? calendar.date(byAdding: .day, value: sample.length - 1, to: day) : nil
            let start = sample.hour.flatMap {
                calendar.date(bySettingHour: $0, minute: sample.minute, second: 0, of: day)
            }
            let todo = TodoItem(
                title: pick(sample.ko, sample.en, sample.ja),
                date: day,
                endDate: end,
                startTime: start,
                category: categories[sample.category]
            )
            todo.isCompleted = sample.isCompleted
            context.insert(todo)
        }
    }
}
#endif
