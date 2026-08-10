import Foundation
import SwiftData

/// 모든 저장 속성에 인라인 기본값이 있는 건 **CloudKit 미러링 요구사항**이다 —
/// 옵셔널이거나 기본값을 가져야 하고, 관계는 전부 옵셔널이어야 하며,
/// `@Attribute(.unique)`는 쓸 수 없다. 기본값을 지우면 앱이 저장소를 아예 못 연다.
@Model
final class TodoItem {
    var id: UUID = UUID()
    var title: String = ""
    /// 할 일이 시작하는 날짜(하루 단위). nil이면 날짜 없는 백로그 항목 — 캘린더엔
    /// 안 나오고 "할 일" 탭에만 있는다("할 일" 탭에서 바로 만들면 기본값이 없다).
    var date: Date?
    /// 여러 날에 걸치면 값, 하루짜리면 nil(= date와 동일하다고 취급).
    var endDate: Date?
    /// 특정 시작 시간이 있으면 값, 종일(시간 없음)이면 nil. hour/minute만 의미 있다.
    var startTime: Date?
    /// 종료 시간(선택). startTime 없이는 의미 없음.
    var endTime: Date?
    /// 카테고리가 삭제되면 그 안의 할 일들은 기본 카테고리로 먼저 옮겨진다
    /// (TodoCategory.delete 참고). deleteRule .nullify는 혹시 못 옮긴 경우를
    /// 위한 안전망일 뿐, 정상 경로에서는 category가 nil이 되는 일이 없다.
    @Relationship(deleteRule: .nullify) var category: TodoCategory?
    /// 어느 캘린더 묶음에 속하는지("개인"/"업무" 등). 카테고리와 별개의 층이다 —
    /// 카테고리가 성격이라면 이건 "지금 보고 있는 묶음"을 가른다.
    /// nil이면 어느 묶음에도 안 넣은 상태로, 통합에서만 보인다.
    @Relationship(deleteRule: .nullify) var calendar: TodoCalendar?
    /// enum을 raw String으로 저장 (순서/정수 기반 저장 금지 원칙)
    private var repeatRuleRawValue: String = RepeatRule.none.rawValue
    /// 반복이 끝나는 날짜. nil이면 무기한 반복(반복 안 함이면 의미 없음).
    var repeatEndDate: Date?
    /// 매주 반복 시 어느 요일들에 반복할지 (1=일요일...7=토요일, Calendar.component(.weekday) 규칙).
    ///
    /// CloudKit은 Swift 배열 속성을 그대로 못 다룬다 — 켜자마자 콘솔에
    /// `Could not materialize Objective-C class named "Array" ... Array<Int>` fault가
    /// 뜨고 동기화가 안 된다. 그래서 쉼표로 이은 문자열로 저장하고, 쓰는 쪽에는
    /// 지금까지와 똑같이 배열로 보여준다(호출부는 하나도 안 바뀐다).
    private var repeatWeekdaysRaw: String = ""

    var repeatWeekdays: [Int] {
        get { repeatWeekdaysRaw.split(separator: ",").compactMap { Int($0) } }
        set { repeatWeekdaysRaw = newValue.map(String.init).joined(separator: ",") }
    }
    /// everyNDays 반복의 간격(N). 기존 데이터 호환을 위해 옵셔널로 두고 읽을 때 보정한다.
    var repeatInterval: Int?
    /// 반복 일정에서 완료 처리된 인스턴스들의 시작일 키(dayKey) — 반복은 날마다
    /// 따로 완료할 수 있어야 해서, 전체 isCompleted와 별개로 날짜별로 기록한다.
    /// `repeatWeekdays`와 같은 이유로 문자열에 이어 붙여 저장한다(dayKey는 숫자
    /// 문자열이라 쉼표가 들어갈 일이 없다).
    private var completedDayKeysRaw: String = ""

    var completedDayKeys: [String]? {
        get {
            guard !completedDayKeysRaw.isEmpty else { return nil }
            return completedDayKeysRaw.split(separator: ",").map(String.init)
        }
        set { completedDayKeysRaw = (newValue ?? []).joined(separator: ",") }
    }
    var isCompleted: Bool = false
    var createdAt: Date = Date.now
    /// 제목만으로 부족할 때 덧붙이는 자유 메모. 앞으로 알림·첨부처럼 "할 일에
    /// 붙는 부가 정보"가 더 생길 자리의 첫 번째다(TodoDetailSheet 참고).
    /// 안 쓴 상태와 빈 문자열을 한 가지로 다루려고 옵셔널로 둔다(빈 값은 nil로 저장).
    var memo: String?
    /// **이제 쓰지 않는다.** 예전엔 "오늘 이걸 언제 할 것인가"를 오전/오후/저녁으로
    /// 나눠 담았는데, 시간대를 고르는 일 자체가 할 일을 적는 것보다 손이 많이 가서
    /// 걷어냈다. 오늘 할 일은 이제 사용자가 끌어서 정한 순서(`sortIndex`) 하나로만
    /// 줄을 선다.
    ///
    /// 속성을 지우지 않고 남겨두는 건 **CloudKit 스키마를 건드리지 않기 위해서**다.
    /// 지금 이 앱은 동기화가 제대로 붙었는지부터 확인하는 중이라(설정 > 백업),
    /// 그 위에 스키마 변경을 얹으면 문제가 생겼을 때 원인을 가릴 수 없다.
    /// 이름도 그대로 둬야 한다 — 바꾸면 CloudKit에는 다른 필드가 된다.
    private var daySlotRawValue: String?

    /// 손꼽아 기다리는 일 하나에 표시해두면, "다가오는" 화면 맨 위에 남은 날짜가
    /// 크게 고정된다. 탭을 새로 만들지 않은 건 탭 구성이 상황에 따라 늘었다 줄었다
    /// 하면 길 찾기가 어려워지기 때문이다.
    var isDDay: Bool = false

    /// 사용자가 직접 끌어서 정한 순서. 같은 묶음(시간대/백로그) 안에서만 의미가
    /// 있고, 아직 손대지 않았으면 전부 0이라 만든 순서(`createdAt`)를 따른다.
    var sortIndex: Int = 0

    init(
        title: String,
        date: Date? = nil,
        endDate: Date? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        category: TodoCategory? = nil,
        repeatRule: RepeatRule = .none,
        repeatEndDate: Date? = nil,
        repeatWeekdays: [Int] = [],
        repeatInterval: Int? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.endDate = endDate
        self.startTime = startTime
        self.endTime = endTime
        self.category = category
        self.repeatRuleRawValue = repeatRule.rawValue
        self.repeatEndDate = repeatEndDate
        // 계산 프로퍼티가 아니라 저장 프로퍼티에 바로 넣는다 — 모든 저장
        // 프로퍼티가 초기화되기 전에는 계산 setter를 부를 수 없다.
        self.repeatWeekdaysRaw = repeatWeekdays.map(String.init).joined(separator: ",")
        self.completedDayKeysRaw = ""
        self.repeatInterval = repeatInterval
        self.isCompleted = false
        self.createdAt = .now
    }

    var repeatRule: RepeatRule {
        get { RepeatRule(rawValue: repeatRuleRawValue) ?? .none }
        set { repeatRuleRawValue = newValue.rawValue }
    }

    /// 실제 종료일. 하루짜리면 date와 동일, 날짜 자체가 없으면 nil.
    var effectiveEndDate: Date? {
        endDate ?? date
    }

    var isMultiDay: Bool {
        guard let date, let endDate else { return false }
        return !Calendar.current.isDate(endDate, inSameDayAs: date)
    }

    /// 정렬용 키: 시작 시간 없는(종일) 항목은 -1로 취급해 항상 먼저 오고,
    /// 있으면 자정 기준 분(0~1439) 오름차순.
    var sortableMinutes: Int {
        guard let startTime else { return -1 }
        let components = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
