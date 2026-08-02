import SwiftUI
import SwiftData
import UIKit

/// 오늘 **계획을 세우는** 화면.
///
/// 예전엔 "오늘 걸치는 항목을 카테고리로 묶은 목록"이었는데, 그건 캘린더에서 오늘을
/// 눌렀을 때와 같은 질문("무엇이 있는가")에 두 번 답하는 것이었다. 항목을 더 보여줘도
/// 그 겹침은 안 풀린다 — 질문을 바꿔야 한다. 여기서는 "오늘 그걸 **어떻게 해낼
/// 것인가**"에 답한다.
///
/// 근거:
/// - 할 일 목록의 41%는 끝내 완료되지 않는다. 적어두는 행위 자체는 실행을 못 만든다.
/// - 실행 의도(언제·어디서 할지를 미리 정하기)는 목표 달성을 d = 0.65만큼 끌어올린다
///   (Gollwitzer & Sheeran, 94개 연구 메타분석).
/// - 미완료 과제가 만드는 침투적 사고는, 완료하지 않아도 **구체적 계획을 세우기만
///   하면** 사라진다(Masicampo & Baumeister, 2011).
/// - 사람은 소요 시간을 일관되게 과소평가한다(계획 오류) — 그래서 개수 경고를 둔다.
///
/// 화면은 세 덩어리다: 이미 시각이 박힌 **고정된 일**, 슬롯을 붙여 계획하는 **오늘
/// 하기로 한 일**, 그리고 이 탭에만 있는 데이터인 **백로그**(여기서 오늘로 끌어올린다).
struct TodayTodoScreen: View {
    @Query private var allTodos: [TodoItem]
    /// 캘린더 탭에서 고른 보기 설정을 여기서도 그대로 따른다.
    @AppStorage(CalendarSelection.storageKey) private var hiddenCalendarIDs = ""
    @Environment(\.modelContext) private var modelContext
    /// 기존 항목을 누르면 여기 채워지고, 하단 입력창이 새로 만들기 대신 그 항목을
    /// 고치는 채팅형 입력창으로 바뀐다(DayTodosContentView와 같은 패턴).
    @State private var editingTodo: TodoItem?
    /// 완료 섹션은 기본으로 접혀 있다 — 평소엔 안 보이지만, 잘못 체크했거나
    /// 되돌리고 싶을 때 펼쳐서 체크를 풀 수 있어야 한다.
    @State private var showsCompleted = false
    @State private var showsBacklog = true
    /// 끌어서 순서를 바꾸는 동안만 켜진다.
    @State private var isEditing = false
    /// "다른 날" 칩으로 날짜를 옮기는 중인 항목.
    @State private var reschedulingTodo: TodoItem?
    @State private var rescheduleDate = Date()
    @Environment(TutorialManager.self) private var tutorialManager

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }

    /// 이만큼 넘으면 "정말 다 하실 건가요?"라고 한 번 묻는다. 막지는 않는다 —
    /// 계획 오류는 알아도 잘 안 고쳐지므로, 눈에 보이게 만드는 것까지가 앱의 몫이다.
    private static let overloadThreshold = 8

    // MARK: - 분류

    private var visibleTodos: [TodoItem] {
        let hidden = CalendarSelection.hidden(from: hiddenCalendarIDs)
        return allTodos.filter { CalendarSelection.matches($0, hidden: hidden) }
    }

    /// 오늘 걸치는(반복 포함) 항목. 날짜 없는 백로그는 여기 안 들어간다 —
    /// 예전엔 섞여 있었는데, 그래서 "오늘 할 일"이 실제보다 늘 많아 보였다.
    private var todayTodos: [TodoItem] {
        visibleTodos.filter { $0.date != nil && $0.occurs(on: today) }
    }

    /// 지난 날짜에 남은 미완료. 그냥 사라지게 두면 "그때 못 한 일"이 조용히
    /// 묻히고, 자동으로 오늘로 끌고 오면 오늘 목록이 끝없이 불어난다 —
    /// 맨 위에 모아 보여주고 옮길지 말지는 사용자가 정하게 한다.
    private var overdueTodos: [TodoItem] {
        visibleTodos.filter { todo in
            guard let date = todo.date else { return false }
            guard calendar.startOfDay(for: date) < today else { return false }
            // 반복 일정은 "지난 것"이라는 개념이 없다 — 다음 회차가 또 온다.
            guard todo.repeatRule == .none else { return false }
            return !todo.isCompleted
        }
        .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    private var backlogTodos: [TodoItem] {
        visibleTodos.filter { $0.date == nil && !$0.isCompleted }
    }

    private func isDone(_ todo: TodoItem) -> Bool { todo.isCompleted(on: today) }

    private var incompleteToday: [TodoItem] {
        todayTodos.filter { !isDone($0) }
    }

    private var completedToday: [TodoItem] {
        todayTodos.filter(isDone)
    }

    /// 시각이 이미 정해진 일 — 계획할 게 없으므로 맥락으로만 보여준다.
    private var fixedTodos: [TodoItem] {
        incompleteToday
            .filter { $0.startTime != nil }
            .sorted { $0.sortableMinutes < $1.sortableMinutes }
    }

    /// 시각이 없는 오늘 항목 — 이 화면의 주인공이다.
    private var flexibleTodos: [TodoItem] {
        incompleteToday.filter { $0.startTime == nil }
    }

    private var unplannedTodos: [TodoItem] {
        ordered(flexibleTodos.filter { $0.daySlot == nil })
    }

    private func todos(in slot: DaySlot) -> [TodoItem] {
        ordered(flexibleTodos.filter { $0.daySlot == slot })
    }

    /// 사용자가 끌어서 정한 순서를 먼저 보고, 아직 안 건드린 것들은 만든 순서로.
    private func ordered(_ items: [TodoItem]) -> [TodoItem] {
        items.sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private var isOverloaded: Bool {
        incompleteToday.count > Self.overloadThreshold
    }

    // MARK: - 본문

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                planList
            }
            .background(MoscoPalette.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .safeAreaInset(edge: .bottom) {
                // 이 탭에서 만드는 건 "오늘 할 일"이다 — 날짜 없이 만들면 방금 적은
                // 게 백로그로 떨어져 다시 끌어올려야 한다.
                QuickAddView(date: today, editingTodo: $editingTodo)
            }
            .sheet(item: $reschedulingTodo) { todo in
                rescheduleSheet(for: todo)
            }
        }
    }

    /// 오늘이 며칠인지 늘 보이게 — 예전엔 "오늘 할 일"이라면서 정작 날짜가 어디에도
    /// 없었다. 순서 변경(편집)과 도움말도 여기 둔다.
    private var header: some View {
        // 왼쪽은 두 줄(날짜 + 남은 개수), 오른쪽은 작은 버튼 하나다. 베이스라인을
        // 맞추면 22pt 글자와 12pt 버튼이 같은 선에 앉아 버튼이 아래로 처져 보인다 —
        // 두 줄 덩어리의 세로 가운데에 맞추는 편이 정렬돼 보인다.
        HStack(alignment: .center, spacing: Metrics.spacingSM) {
            VStack(alignment: .leading, spacing: 1) {
                Text(today.koreanMonthDayWeekday)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MoscoPalette.textPrimary)
                if !incompleteToday.isEmpty {
                    Text("할 일 \(incompleteToday.count)개 남음")
                        .font(.moscoCaption())
                        .foregroundStyle(MoscoPalette.textSecondary)
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isEditing.toggle() }
            } label: {
                Text(isEditing ? "완료" : "편집")
                    .font(.moscoCaption().weight(.semibold))
                    .foregroundStyle(MoscoPalette.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Metrics.spacingMD)
        .padding(.top, Metrics.spacingSM)
        .padding(.bottom, Metrics.spacingSM)
    }

    private var planList: some View {
            List {
                if isOverloaded { overloadNotice }
                if !overdueTodos.isEmpty { overdueSection }

                if incompleteToday.isEmpty && backlogTodos.isEmpty {
                    emptyState
                }

                if !fixedTodos.isEmpty {
                    section("시간이 정해진 할 일", subtitle: "시작 시간이 정해져 있어요", items: fixedTodos)
                }

                if !unplannedTodos.isEmpty {
                    unplannedSection
                }

                ForEach(DaySlot.allCases) { slot in
                    let items = todos(in: slot)
                    if !items.isEmpty {
                        slotSection(slot, items: items)
                    }
                }

                if !backlogTodos.isEmpty { backlogSection }
                if !completedToday.isEmpty { completedSection }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            .simultaneousGesture(
                TapGesture().onEnded {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            )
    }

    // MARK: - 섹션

    private var emptyState: some View {
        ContentUnavailableView(
            "오늘은 비어 있어요",
            systemImage: "checkmark.circle",
            description: Text("아래에 적으면 오늘 할 일이 돼요")
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    /// 막지 않고 알리기만 한다 — 결정은 사용자 몫이다.
    private var overloadNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(MoscoPalette.must)
            VStack(alignment: .leading, spacing: 2) {
                Text("하루에 하기엔 많아 보여요")
                    .font(.moscoCaption().weight(.semibold))
                    .foregroundStyle(MoscoPalette.textPrimary)
                Text("몇 개는 다른 날로 옮길 수 있어요.")
                    .font(.moscoCaption())
                    .foregroundStyle(MoscoPalette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Metrics.spacingMD)
        .background(MoscoPalette.must.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: Metrics.spacingMD, bottom: 6, trailing: Metrics.spacingMD))
    }

    /// 시각 순으로 늘어놓는 섹션이라 순서를 손으로 바꿀 수 없다 — 삭제만 연다.
    private func section(_ title: String, subtitle: String?, items: [TodoItem]) -> some View {
        Section {
            ForEach(items) { todo in
                row(todo)
            }
            .onDelete { delete(items, at: $0) }
        } header: {
            plainHeader(title, subtitle: subtitle, count: items.count)
        }
    }

    /// 아직 언제 할지 안 정한 항목들. 이 화면이 존재하는 이유라 맨 위에 둔다.
    private var unplannedSection: some View {
        Section {
            ForEach(unplannedTodos) { todo in
                VStack(alignment: .leading, spacing: 8) {
                    TodoRow(
                        todo: todo,
                        occurrenceDate: today,
                        onTap: { editingTodo = todo },
                        onDelete: { delete(todo) }
                    )
                    slotPicker(for: todo)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: Metrics.spacingMD, bottom: 6, trailing: Metrics.spacingMD))
            }
            .onMove { move(unplannedTodos, from: $0, to: $1) }
            .onDelete { delete(unplannedTodos, at: $0) }
        } header: {
            plainHeader("시간을 안 정한 할 일", subtitle: "고르면 그 시간대 칸으로 옮겨져요", count: unplannedTodos.count)
        }
    }

    private func slotSection(_ slot: DaySlot, items: [TodoItem]) -> some View {
        Section {
            ForEach(items) { todo in
                row(todo, currentSlot: slot)
            }
            .onMove { move(items, from: $0, to: $1) }
            .onDelete { delete(items, at: $0) }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: slot.symbolName)
                    .font(.system(size: 11))
                Text(slot.label)
                Text("\(items.count)")
                    .foregroundStyle(MoscoPalette.textSecondary.opacity(0.6))
                Spacer()
            }
            .font(.moscoCaption())
            .foregroundStyle(MoscoPalette.textSecondary)
        }
    }

    /// 지난 날짜에 남은 것들. 하나씩 밀어 옮기거나 한 번에 모두 오늘로 가져온다.
    /// 화면 맨 위에 두는 건, 계획을 세우기 전에 "이미 밀린 게 뭔지"부터 보여야
    /// 오늘을 현실적으로 짤 수 있기 때문이다.
    private var overdueSection: some View {
        Section {
            ForEach(overdueTodos) { todo in
                TodoRow(
                    todo: todo,
                    showsDate: true,
                    onTap: { editingTodo = todo },
                    onDelete: { delete(todo) }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: Metrics.spacingMD, bottom: 6, trailing: Metrics.spacingMD))
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        pullIntoToday(todo)
                    } label: {
                        Label("오늘로", systemImage: "arrow.down.circle")
                    }
                    .tint(MoscoPalette.accent)
                }
            }
            .onDelete { delete(overdueTodos, at: $0) }

            Button {
                // 옮기는 동안 `overdueTodos`가 계속 다시 계산되므로 먼저 떠둔다.
                let pending = overdueTodos
                withAnimation(.easeInOut(duration: 0.25)) {
                    for todo in pending { pullIntoToday(todo) }
                }
            } label: {
                Label("모두 오늘로 가져오기", systemImage: "arrow.down.circle.fill")
                    .font(.moscoCaption().weight(.semibold))
                    .foregroundStyle(MoscoPalette.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    // 이게 없으면 글자에만 터치가 잡혀서, 살짝 빗나가면 아무 일도
                    // 안 일어난다 — 안 눌린다고 느끼는 게 대개 이 경우다.
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: Metrics.spacingMD, bottom: 8, trailing: Metrics.spacingMD))
        } header: {
            plainHeader("지난 할 일", subtitle: "오른쪽으로 밀면 오늘로 가져와요", count: overdueTodos.count)
        }
    }

    private var backlogSection: some View {
        Section {
            if showsBacklog {
                ForEach(backlogTodos) { todo in
                    HStack(spacing: 8) {
                        TodoRow(
                            todo: todo,
                            onTap: { editingTodo = todo },
                            onDelete: { delete(todo) }
                        )
                        Button {
                            pullIntoToday(todo)
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(MoscoPalette.accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("오늘로 가져오기")
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: Metrics.spacingMD, bottom: 6, trailing: Metrics.spacingMD))
                }
                .onMove { move(backlogTodos, from: $0, to: $1) }
                .onDelete { delete(backlogTodos, at: $0) }
            }
        } header: {
            collapsibleHeader(
                "언젠가 할 일",
                count: backlogTodos.count,
                isExpanded: showsBacklog
            ) { showsBacklog.toggle() }
        } footer: {
            if showsBacklog {
                Text("화살표를 누르면 오늘로 가져와요.")
                    .font(.moscoCaption())
                    .foregroundStyle(MoscoPalette.textSecondary)
            }
        }
    }

    private var completedSection: some View {
        Section {
            if showsCompleted {
                ForEach(completedToday) { todo in
                    row(todo)
                }
                .onDelete { delete(completedToday, at: $0) }
            }
        } header: {
            collapsibleHeader("완료한 할 일", count: completedToday.count, isExpanded: showsCompleted) {
                showsCompleted.toggle()
            }
        }
    }

    // MARK: - 조각

    private func row(_ todo: TodoItem, currentSlot: DaySlot? = nil) -> some View {
        TodoRow(
            todo: todo,
            occurrenceDate: today,
            onTap: { editingTodo = todo },
            onDelete: { delete(todo) }
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: Metrics.spacingMD, bottom: 6, trailing: Metrics.spacingMD))
        // 시간대를 바꾸는 건 자주 하는 일이 아니라 스와이프에 숨긴다 — 모든 행에
        // 칩을 세 개씩 달면 목록이 통째로 무거워진다.
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if currentSlot != nil {
                ForEach(DaySlot.allCases) { slot in
                    Button {
                        assign(slot, to: todo)
                    } label: {
                        Label(slot.label, systemImage: slot.symbolName)
                    }
                    .tint(slot == currentSlot ? MoscoPalette.textSecondary : MoscoPalette.accent)
                }
            }
        }
    }

    private func slotPicker(for todo: TodoItem) -> some View {
        HStack(spacing: 6) {
            ForEach(DaySlot.allCases) { slot in
                Button {
                    assign(slot, to: todo)
                } label: {
                    chipLabel(slot.label, systemImage: slot.symbolName)
                }
                .buttonStyle(.plain)
            }

            // 오늘 안에서 시간대만 고르는 게 아니라, 아예 다른 날로 미룰 수도
            // 있어야 한다 — 여기까지 와서 "오늘은 못 하겠다"가 되는 게 보통이다.
            Button {
                rescheduleDate = calendar.date(byAdding: .day, value: 1, to: today) ?? today
                reschedulingTodo = todo
            } label: {
                chipLabel("다른 날", systemImage: "calendar")
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.leading, 4)
    }

    /// 시간대 칩은 **중립색**이다.
    ///
    /// 강조색으로 칠했더니, 계획 안 한 할 일이 세 개만 있어도 화면에 강조색 캡슐이
    /// 열두 개가 깔려 정작 할 일 제목보다 버튼이 더 세게 읽혔다. 여기서 강조가
    /// 필요한 건 "무엇을 할지"이지 "어디를 누를지"가 아니다 — 칩은 셀 바로 아래
    /// 붙어 있어 위치만으로도 무엇에 대한 선택인지 알 수 있다.
    private func chipLabel(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10))
            Text(text)
                .font(.moscoCaption().weight(.semibold))
        }
        .foregroundStyle(MoscoPalette.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(MoscoPalette.textSecondary.opacity(0.10), in: Capsule())
    }

    private func plainHeader(_ title: String, subtitle: String?, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(title)
                Text("\(count)")
                    .foregroundStyle(MoscoPalette.textSecondary.opacity(0.6))
                Spacer()
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(MoscoPalette.textSecondary.opacity(0.7))
            }
        }
        .font(.moscoCaption())
        .foregroundStyle(MoscoPalette.textSecondary)
    }

    private func collapsibleHeader(
        _ title: String,
        count: Int,
        isExpanded: Bool,
        toggle: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                Text("\(count)")
                    .foregroundStyle(MoscoPalette.textSecondary.opacity(0.6))
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            .font(.moscoCaption())
            .foregroundStyle(MoscoPalette.textSecondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 동작

    private func rescheduleSheet(for todo: TodoItem) -> some View {
        NavigationStack {
            DatePicker(
                "날짜",
                selection: $rescheduleDate,
                in: today...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding(Metrics.spacingMD)
            .navigationTitle("날짜 고르기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { reschedulingTodo = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("옮기기") {
                        todo.date = calendar.startOfDay(for: rescheduleDate)
                        // 다른 날로 보내면 오늘 기준으로 정한 시간대는 의미가 없다.
                        todo.daySlot = nil
                        reschedulingTodo = nil
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func assign(_ slot: DaySlot, to todo: TodoItem) {
        withAnimation(.easeInOut(duration: 0.25)) {
            todo.daySlot = slot
            // 다른 묶음에서 쓰던 순서 번호를 그대로 가져오면 새 시간대에서 엉뚱한
            // 자리에 끼어든다 — 맨 뒤로 보내고 사용자가 다시 정하게 한다.
            todo.sortIndex = (todos(in: slot).map(\.sortIndex).max() ?? 0) + 1
        }
    }

    /// 끌어서 놓은 결과를 그 묶음 안에서 0부터 다시 매긴다.
    private func move(_ items: [TodoItem], from source: IndexSet, to destination: Int) {
        var reordered = items
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, todo) in reordered.enumerated() {
            todo.sortIndex = index
        }
    }

    private func delete(_ items: [TodoItem], at offsets: IndexSet) {
        for index in offsets where items.indices.contains(index) {
            delete(items[index])
        }
    }

    /// 백로그 항목을 오늘로. 슬롯은 비워둔 채로 올려서, 바로 위 "언제 하실래요?"
    /// 에 나타나 계획을 세우게 한다 — 그게 이 화면의 요점이다.
    private func pullIntoToday(_ todo: TodoItem) {
        withAnimation(.easeInOut(duration: 0.25)) {
            todo.date = today
            todo.daySlot = nil
        }
    }

    private func delete(_ todo: TodoItem) {
        modelContext.delete(todo)
    }
}
