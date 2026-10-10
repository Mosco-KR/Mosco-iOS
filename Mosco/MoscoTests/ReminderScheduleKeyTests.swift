import Foundation
import SwiftData
import Testing

/// 재예약 열쇠. **이 앱에서 "알림이 안 온다"는 신고는 세 번 다 여기서 났다** —
/// 예약 계산은 멀쩡한데 다시 계산할 이유를 못 만든 것이다. 계산에는 테스트가
/// 스무 건 넘게 붙어 있었고, 정작 계산을 깨우는 쪽에는 한 건도 없었다.
///
/// 그래서 여기서 묻는 것은 하나뿐이다. **알림에 영향을 주는 값이 바뀌면 키도
/// 바뀌는가, 그렇지 않은 값에는 가만히 있는가.**
@Suite("알림 재예약 열쇠")
struct ReminderScheduleKeyTests {

    /// 아무것도 안 바꾼 기준값. 테스트마다 한 군데씩만 달리해서 비교한다.
    private func key(
        notificationsEnabled: Bool = true,
        authorizationStatus: Int = 2,
        summaryEnabled: Bool = true,
        summaryHour: Int = 21,
        summaryMinute: Int = 0,
        todoFingerprints: [String] = ["a", "b"]
    ) -> String {
        ReminderScheduleKey.make(
            notificationsEnabled: notificationsEnabled,
            authorizationStatus: authorizationStatus,
            summaryEnabled: summaryEnabled,
            summaryHour: summaryHour,
            summaryMinute: summaryMinute,
            todoFingerprints: todoFingerprints
        )
    }

    @Test("같은_입력이면_같은_키다")
    func 결정적() {
        #expect(key() == key())
    }

    // MARK: - 세 번 난 사고

    /// 실행 직후 재예약이 한 번 도는데 그때는 아직 권한을 안 물어본 상태다.
    /// 그 뒤에 허용해도 키가 그대로면 다시 돌지 않아서, 허용한 그 실행에서는
    /// 알림이 하나도 안 걸린다.
    @Test("권한_상태가_바뀌면_키가_바뀐다")
    func 권한() {
        #expect(key(authorizationStatus: 0) != key(authorizationStatus: 2))
    }

    @Test("전체_스위치가_바뀌면_키가_바뀐다")
    func 전체_스위치() {
        #expect(key(notificationsEnabled: false) != key(notificationsEnabled: true))
    }

    /// 1.5.0에서 고친 것. 설정 화면이 `UserDefaults`에 적기만 하고 뿌리가 그 값을
    /// 안 보고 있어서, 받을 시각을 옮겨도 할 일을 하나 손대기 전까지 옛 시각
    /// 그대로였다.
    @Test("하루_요약을_껐다_켜면_키가_바뀐다")
    func 요약_스위치() {
        #expect(key(summaryEnabled: false) != key(summaryEnabled: true))
    }

    @Test("하루_요약_시각을_옮기면_키가_바뀐다")
    func 요약_시각() {
        #expect(key(summaryHour: 21) != key(summaryHour: 9))
        #expect(key(summaryMinute: 0) != key(summaryMinute: 30))
    }

    /// 9시 0분과 90분 0초처럼, 시와 분을 붙여 쓰면 서로 다른 설정이 같은 키가
    /// 되는 짝이 생긴다. 구분자가 그걸 막는다.
    @Test("시와_분의_경계가_뭉개지지_않는다")
    func 시_분_경계() {
        #expect(key(summaryHour: 1, summaryMinute: 0) != key(summaryHour: 10, summaryMinute: 0))
        #expect(key(summaryHour: 2, summaryMinute: 11) != key(summaryHour: 21, summaryMinute: 1))
    }

    // MARK: - 할 일 쪽

    @Test("할_일이_늘거나_줄면_키가_바뀐다")
    func 할_일_개수() {
        #expect(key(todoFingerprints: ["a"]) != key(todoFingerprints: ["a", "b"]))
        #expect(key(todoFingerprints: []) != key(todoFingerprints: ["a"]))
    }

    @Test("할_일_하나만_달라져도_키가_바뀐다")
    func 할_일_내용() {
        #expect(key(todoFingerprints: ["a", "b"]) != key(todoFingerprints: ["a", "c"]))
    }

    /// 순서가 바뀐 것만으로 다시 예약하지는 않아도 되지만, **같은 집합을 다르게
    /// 읽어서는 안 된다.** 여기서 묻는 것은 "합쳐진 뒤에도 경계가 남아 있는가"다 —
    /// `["ab", "c"]`와 `["a", "bc"]`가 같은 키가 되면 바뀐 걸 놓친다.
    @Test("합칠_때_할_일_경계가_뭉개지지_않는다")
    func 할_일_경계() {
        #expect(key(todoFingerprints: ["ab", "c"]) != key(todoFingerprints: ["a", "bc"]))
    }
}

/// 할 일 하나에서 무엇을 추려야 하는가. 저장소의 실제 객체로 확인한다 —
/// 값으로 손수 만든 것만 보면, 베껴오는 자리가 틀렸을 때 잡히지 않는다.
@Suite("알림 열쇠에 들어가는 것")
@MainActor
struct ReminderFingerprintTests {

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try SharedModelContainer.inMemory()
    }

    @discardableResult
    private func make(category: TodoCategory? = nil) -> TodoItem {
        let today = Calendar.current.startOfDay(for: .now)
        let todo = TodoItem(
            title: "회의",
            date: today,
            startTime: Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: today),
            category: category
        )
        context.insert(todo)
        return todo
    }

    @Test("아무것도_안_바꾸면_같은_값이다")
    func 결정적() {
        let todo = make()
        #expect(ReminderScheduleKey.fingerprint(of: todo) == ReminderScheduleKey.fingerprint(of: todo))
    }

    @Test("시작_시각을_옮기면_달라진다")
    func 시각() {
        let todo = make()
        let before = ReminderScheduleKey.fingerprint(of: todo)
        todo.startTime = Calendar.current.date(byAdding: .hour, value: 1, to: todo.startTime!)
        #expect(ReminderScheduleKey.fingerprint(of: todo) != before)
    }

    /// 10시 일정을 9시 30분에 끝내도 9시 50분에 알림이 울리던 것 — 완료 여부가
    /// 열쇠에 없어서 걷히는 시점이 "앱을 뒤로 보냈다 돌아올 때"였다.
    @Test("완료하면_달라진다")
    func 완료() {
        let todo = make()
        let before = ReminderScheduleKey.fingerprint(of: todo)
        todo.isCompleted = true
        #expect(ReminderScheduleKey.fingerprint(of: todo) != before)
    }

    @Test("반복_일정은_끝낸_날이_늘면_달라진다")
    func 반복_완료() {
        let todo = make()
        todo.repeatRule = .daily
        let before = ReminderScheduleKey.fingerprint(of: todo)
        todo.completedDayKeys = [Calendar.current.startOfDay(for: .now).dayKey]
        #expect(ReminderScheduleKey.fingerprint(of: todo) != before)
    }

    @Test("카테고리_알림을_끄면_달라진다")
    func 카테고리_스위치() {
        let category = TodoCategory(name: "업무", colorHex: "8B5CF6", sortOrder: 0)
        context.insert(category)
        let todo = make(category: category)
        let before = ReminderScheduleKey.fingerprint(of: todo)
        category.notifiesBeforeStart = false
        #expect(ReminderScheduleKey.fingerprint(of: todo) != before)
    }

    @Test("리드타임을_바꾸면_달라진다")
    func 리드타임() {
        let category = TodoCategory(name: "업무", colorHex: "8B5CF6", sortOrder: 0)
        context.insert(category)
        let todo = make(category: category)
        let before = ReminderScheduleKey.fingerprint(of: todo)
        category.notificationLeadMinutes = 30
        #expect(ReminderScheduleKey.fingerprint(of: todo) != before)
    }

    /// 색이나 메모는 잠금화면에만 그려진다. 그것 때문에 64개를 다시 까는 것은
    /// 낭비라, **안 바뀌는 쪽도 확인한다.**
    @Test("메모만_고치면_그대로다")
    func 메모() {
        let todo = make()
        let before = ReminderScheduleKey.fingerprint(of: todo)
        todo.memo = "자료 챙기기"
        #expect(ReminderScheduleKey.fingerprint(of: todo) == before)
    }
}
