import SwiftData
import SwiftUI

/// '할 일' 탭 — 날짜를 가로지르는 목록.
///
/// ## 왜 셋째 탭인가
///
/// 달력은 "언제"에 답한다. 거기에만 기대면 **날짜를 아직 안 정한 일이 설 자리가
/// 없다.** 지금까지는 오늘 페이지 맨 아래 '날짜를 안 정한 할 일' 칸에 들어 있었는데 —
/// 적어는 뒀는데 오늘을 열어야만 보이고, 그것도 오늘 할 일들 **아래**에 있었다.
/// 할 일 앱으로 쓰려는 사람에게는 그게 본진인데 부속으로 놓여 있던 셈이다.
///
/// 이 탭이 생기고 나서 오늘 탭을 없앴다(1.4.4). 탭 바에 비슷한 목록이 둘 서 있으면
/// 어느 쪽을 눌러야 하는지 매번 생각해야 하고, "지금 뭐부터 하지"에는 이쪽이 더
/// 잘 답한다. 오늘 하루만 보고 싶으면 달력에서 오늘 칸을 누르면 된다.
///
/// 이 탭은 날짜가 아니라 **급한 순서**로 묶는다. 어느 할 일이 어디에 들어가는지는
/// 화면이 아니라 `TodoListPage`가 정하고 테스트로 묶여 있다.
///
/// ## 입력창이 여기에도 있다
///
/// 1.4.0에서 탭을 없앴던 이유가 "입력창을 못 찾아서"였다 — 9월 데이터에서 셋 중
/// 하나가 할 일을 한 번도 안 만들었다. 새 탭을 만들면서 같은 실수를 되풀이하지
/// 않는다. 여기서 적으면 **날짜 없이** 저장되고, 그게 이 화면의 기본값이다.
struct TodoListScreen: View {
    @State private var editingTodo: TodoItem?

    var body: some View {
        NavigationStack {
            TodoListContent(editingTodo: $editingTodo)
        }
    }
}

private struct TodoListContent: View {
    @Binding var editingTodo: TodoItem?

    @Environment(\.modelContext) private var modelContext
    @Query private var allTodos: [TodoItem]
    /// 달력에서 꺼둔 캘린더는 여기서도 안 보인다 — 한쪽에만 나오면 어느 쪽이
    /// 맞는지 알 수 없다(하루 페이지와 같은 규칙).
    @AppStorage(CalendarSelection.storageKey) private var hiddenCalendarIDs = ""

    /// 보고 있는 "오늘". 탭은 앱이 떠 있는 동안 계속 살아 있어서, 이 값을 body에서
    /// 그때그때 계산하면 자정을 넘긴 뒤에도 어제가 오늘인 척 남는다(`TodayScreen`과
    /// 같은 이유).
    @State private var today = Calendar.current.startOfDay(for: .now)
    @Environment(\.scenePhase) private var scenePhase

    private var visibleTodos: [TodoItem] {
        let hidden = CalendarSelection.hidden(from: hiddenCalendarIDs)
        return allTodos.filter { CalendarSelection.matches($0, hidden: hidden) }
    }

    private var sections: [(section: TodoListPage.Section, todos: [TodoItem])] {
        TodoListPage.sections(in: visibleTodos, today: today)
    }

    var body: some View {
        list
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // **날짜를 안 넘긴다.** 여기서 적은 것은 날짜 없는 할 일이 된다 —
                // 이 화면이 날짜를 가로지르는 목록이라, 오늘로 밀어넣으면 오늘
                // 할 일이 적지도 않은 것으로 늘어난다.
                QuickAddView(date: nil, editingTodo: $editingTodo, analyticsSource: "todo_list")
            }
            .background(MoscoPalette.canvas.ignoresSafeArea())
            .navigationTitle("할 일")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                let now = Calendar.current.startOfDay(for: .now)
                guard now != today else { return }
                today = now
            }
    }

    private var dDayTodos: [TodoItem] {
        TodoListPage.dDays(in: visibleTodos, today: today)
    }

    @ViewBuilder
    private var list: some View {
        if sections.isEmpty && dDayTodos.isEmpty {
            emptyState
        } else {
            List {
                if !dDayTodos.isEmpty { dDaySection }
                ForEach(sections, id: \.section) { group in
                    Section {
                        ForEach(group.todos) { todo in
                            row(todo, in: group.section)
                        }
                    } header: {
                        header(group.section, count: group.todos.count)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            // **제목과 첫 묶음 사이가 비는 것을 막는다.** plain 리스트는 첫 섹션
            // 머리 위에 제 여백을 또 넣어서, 내비게이션 제목 아래로 손가락 두 마디쯤
            // 되는 빈 칸이 생긴다 — 화면을 열자마자 보이는 것이 빈 공간이면
            // 목록이 짧아 보인다.
            .contentMargins(.top, Metrics.spacingSM, for: .scrollContent)
        }
    }

    /// 맨 위 디데이 줄. **세로로 쌓지 않고 가로로 넘겨 본다** — 세로로 쌓으면
    /// 디데이 몇 개만으로 정작 할 일이 화면 밖으로 밀려난다.
    private var dDaySection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(dDayTodos) { todo in
                        dDayCard(todo, isNearest: todo.id == dDayTodos.first?.id)
                    }
                }
                .padding(.horizontal, Metrics.spacingMD)
            }
            .scrollClipDisabled()
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 0, trailing: 0))
        } header: {
            header(title: String(localized: "디데이"), count: nil, tinted: false)
        }
    }

    /// 가장 가까운 하나만 채운다 — 나머지는 옅게. 그래야 "다음은 이것"이 한눈에 선다.
    private func dDayCard(_ todo: TodoItem, isNearest: Bool) -> some View {
        let day = Calendar.current.startOfDay(for: todo.date ?? today)
        let left = Calendar.current.dateComponents([.day], from: today, to: day).day ?? 0
        return VStack(alignment: .leading, spacing: 0) {
            Text(dDayLabel(left))
                .font(.system(size: 27, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(isNearest ? .white : MoscoPalette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 6)
            Text(todo.title)
                .font(.moscoCaption().weight(.semibold))
                .foregroundStyle(isNearest ? .white : MoscoPalette.textPrimary)
                .lineLimit(1)
            Text(day.localizedMonthDayWeekday)
                .font(.system(size: 11))
                .foregroundStyle(isNearest ? .white.opacity(0.75) : MoscoPalette.textSecondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(width: 138, height: 112, alignment: .topLeading)
        // 유리도 그림자도 쓰지 않는다 — 셀과 같은 이유로 단색 채우기만 쓴다.
        .background(
            isNearest ? MoscoPalette.accent : MoscoPalette.accent.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .contentShape(Rectangle())
        .onTapGesture { editingTodo = todo }
        .accessibilityElement(children: .combine)
    }

    /// `D-7` · `D-DAY` · `D+3`. 지난 디데이도 센다 — 지났다고 숨기면 왜 사라졌는지
    /// 알 수 없고, 지난 디데이야말로 눈에 띄어야 하는 것이다.
    private func dDayLabel(_ days: Int) -> String {
        switch days {
        case 0: String(localized: "D-DAY")
        case 1...: String(localized: "D-\(days)")
        default: String(localized: "D+\(-days)")
        }
    }

    private func row(_ todo: TodoItem, in section: TodoListPage.Section) -> some View {
        HStack(spacing: 8) {
            TodoRow(
                todo: todo,
                // 날짜를 가로지르는 목록이라 **날짜가 보여야 한다.** 하루 페이지는
                // 날짜가 이미 머리에 있어서 끄고 쓴다.
                showsDate: true,
                // 오늘 칸의 반복 일정은 오늘 회차를 체크해야 한다. 다른 칸은
                // 원본을 그대로 뒤집는다 — 앞날 회차를 미리 체크할 일은 없다.
                occurrenceDate: section == .today ? today : nil,
                onTap: { editingTodo = todo },
                onDelete: { modelContext.delete(todo) },
                showsCalendarTag: showsCalendarTag,
                memoDisplay: .compact
            )

            // 지난 것과 날짜 없는 것에만 붙인다. 앞날 일정은 당길 이유가 없고,
            // 오늘 것은 이미 오늘이다.
            if section == .overdue || section == .noDate {
                pullIntoTodayButton(todo)
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(
            EdgeInsets(
                top: Metrics.listRowGap,
                leading: Metrics.spacingMD,
                bottom: Metrics.listRowGap,
                trailing: Metrics.spacingMD
            )
        )
    }

    /// **글자로 쓴다.** 예전엔 위를 가리키는 화살표 동그라미였는데, 그 화살표가
    /// 무엇을 뜻하는지 알 수가 없었다 — 위로 올린다는 건지, 순서를 바꾼다는 건지,
    /// 접는다는 건지. 날짜를 오늘로 바꾸는 일에는 가리킬 방향이 애초에 없다.
    /// 아이콘이 뜻을 못 나르면 글자가 낫다. 셀의 다른 칩과 같은 모양이라 줄에
    /// 섞여도 튀지 않는다.
    private func pullIntoTodayButton(_ todo: TodoItem) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                todo.pullIntoToday(today)
            }
        } label: {
            Text("오늘로")
                .font(.moscoCaption().weight(.semibold))
                .foregroundStyle(MoscoPalette.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(MoscoPalette.accent.opacity(0.12), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("오늘로 가져오기")
        .accessibilityHint("날짜를 오늘로 바꿉니다")
    }

    /// 화면에 두 개 이상의 캘린더가 섞여 있을 때만 소속을 밝힌다.
    private var showsCalendarTag: Bool {
        Set(visibleTodos.compactMap { $0.calendar?.id }).count > 1
    }

    private func header(_ section: TodoListPage.Section, count: Int) -> some View {
        header(title: title(for: section), count: count, tinted: section == .overdue)
    }

    /// `tinted`는 지난 할 일에만 쓴다. **한 화면에 경고색이 여러 번 나오면 아무것도
    /// 경고가 아니게 된다**(DesignSystem/README.md의 "색은 한 행에 한 번").
    private func header(title: String, count: Int?, tinted: Bool) -> some View {
        HStack(spacing: 6) {
            Text(title)
            if let count {
                Text("\(count)").foregroundStyle(MoscoPalette.textSecondary.opacity(0.6))
            }
            Spacer()
        }
        .font(.moscoCaption())
        .foregroundStyle(tinted ? MoscoPalette.must : MoscoPalette.textSecondary)
    }

    private func title(for section: TodoListPage.Section) -> String {
        switch section {
        case .overdue: String(localized: "지난 할 일")
        case .today: String(localized: "오늘")
        case .thisWeek: String(localized: "이번 주")
        case .later: String(localized: "나중")
        case .noDate: String(localized: "날짜를 안 정한 할 일")
        }
    }

    private var emptyState: some View {
        VStack(spacing: Metrics.spacingSM) {
            Spacer()
            Text("할 일이 없어요")
                .font(.moscoBody())
                .foregroundStyle(MoscoPalette.textSecondary)
            Text("아래에 한 줄 적으면 여기에 쌓여요")
                .font(.moscoCaption())
                .foregroundStyle(MoscoPalette.textSecondary.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
