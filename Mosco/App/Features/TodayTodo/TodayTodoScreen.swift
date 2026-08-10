import SwiftUI
import SwiftData
import UIKit

/// 할 일 화면 — 이 앱에서 "지금 무엇을 해야 하나"에 답하는 단 하나의 목록이다.
///
/// **예전엔 '오늘'과 '다가오는' 두 탭이 이 일을 나눠 가졌다.** '다가오는'은 앞으로
/// 2주를 날짜별로 늘어놓았는데, 정작 그 답은 달력 탭이 더 잘 하고 있었다 — 한 달을
/// 한눈에 보고 날짜를 누르면 그날 목록이 나온다. 같은 질문에 두 화면이 답하면
/// 사용자는 어느 쪽을 봐야 하는지부터 정해야 한다. 그래서 하나로 합치고, 이 화면은
/// **지난 미완료와 오늘**만 본다. 앞날은 달력이 맡는다.
///
/// 시간대(오전/오후/저녁)로 오늘을 쪼개던 것도 걷어냈다. 할 일을 적는 것보다
/// 그것을 어느 칸에 넣을지 정하는 데 손이 더 갔고, 정해둔 칸이 실제 하루와
/// 어긋나면 목록이 통째로 거짓말이 됐다. 지금은 **사용자가 끌어서 정한 순서**
/// 하나로만 줄을 선다.
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
    /// 날짜를 안 정하고 만든 할 일. 이 화면은 "지난 것과 오늘"만 보는 곳이라 접어
    /// 두지만, 섹션 자체를 없애지는 않는다 — 그러면 날짜 없이 만든 할 일이 달력에도
    /// 여기에도 안 나와서 앱 어디에서도 볼 수 없게 된다.
    @State private var showsBacklog = false
    /// 끌어서 순서를 바꾸는 동안만 켜진다.
    @State private var isEditing = false
    @State private var detailTodo: TodoItem?

    @State private var query = ""
    @State private var isSearching = false
    @FocusState private var isSearchFocused: Bool

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
        ordered(visibleTodos.filter { $0.date == nil && !$0.isCompleted })
    }

    private func isDone(_ todo: TodoItem) -> Bool { todo.isCompleted(on: today) }

    /// 오늘 남은 할 일 **전부**를 한 줄로 세운다. 시각이 정해진 것과 아닌 것을
    /// 갈라 놓지 않는 건, 하루는 원래 그렇게 흐르지 않기 때문이다 — 3시 회의와
    /// 그 전에 끝내야 할 정리는 같은 줄에 있어야 순서를 정할 수 있다.
    private var incompleteToday: [TodoItem] {
        ordered(todayTodos.filter { !isDone($0) })
    }

    private var completedToday: [TodoItem] {
        todayTodos.filter(isDone)
    }

    /// 디데이로 표시해둔 것 **전부**를 가까운 순으로. 지난 디데이는 뺀다 —
    /// 세어봐야 의미가 없다.
    private var dDayTodos: [TodoItem] {
        visibleTodos
            .filter { todo in
                guard todo.isDDay, let date = todo.date else { return false }
                return calendar.startOfDay(for: date) >= today
            }
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }

    /// 사용자가 끌어서 정한 순서를 먼저 보고, 아직 안 건드린 것들은 만든 순서로.
    ///
    /// **`sortIndex`는 화면 전체에서 하나의 줄 번호다.** 예전엔 시간대 칸마다 따로
    /// 0부터 매겨서, 칸이 사라진 지금은 서로 다른 칸에 있던 항목들의 번호가 겹친다.
    /// 그 경우 `createdAt`이 뒤를 받쳐 순서가 흔들리지 않게 한다 — 한 번 끌어서
    /// 옮기면 그 줄 전체가 0부터 다시 매겨지며 정리된다.
    private func ordered(_ items: [TodoItem]) -> [TodoItem] {
        items.sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private var isOverloaded: Bool {
        incompleteToday.count > Self.overloadThreshold
    }

    // MARK: - 검색

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 제목과 메모를 함께 본다 — 어느 쪽에 적었는지 기억나지 않아도 찾을 수 있게.
    /// 날짜 범위와 무관하게 **전체**를 훑는다. 이 화면이 오늘까지만 보여주기 때문에
    /// 더 그렇다 — 앞날의 할 일에 닿는 유일한 검색 창구다.
    private var searchResults: [TodoItem] {
        let keyword = trimmedQuery
        guard !keyword.isEmpty else { return [] }
        return visibleTodos
            .filter {
                $0.title.localizedStandardContains(keyword)
                    || ($0.memo ?? "").localizedStandardContains(keyword)
            }
            .sorted { lhs, rhs in
                // 날짜 없는 항목은 맨 뒤로.
                switch (lhs.date, rhs.date) {
                case let (l?, r?): return l < r
                case (nil, _?): return false
                case (_?, nil): return true
                default: return lhs.createdAt < rhs.createdAt
                }
            }
    }

    // MARK: - 본문

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if isSearching { searchField }
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
            .sheet(item: $detailTodo) { todo in
                TodoDetailSheet(todo: todo)
            }
        }
    }

    /// 오늘이 며칠인지 늘 보이게 — 예전엔 "오늘 할 일"이라면서 정작 날짜가 어디에도
    /// 없었다. 오른쪽엔 검색과 편집(순서 바꾸기) 둘.
    private var header: some View {
        // 왼쪽은 두 줄(날짜 + 남은 개수), 오른쪽은 작은 버튼 둘이다. 베이스라인을
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
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearching.toggle()
                    if !isSearching { query = "" }
                }
                isSearchFocused = isSearching
            } label: {
                Text(isSearching ? "완료" : "검색")
                    .font(.moscoCaption().weight(.semibold))
                    .foregroundStyle(MoscoPalette.accent)
            }
            .buttonStyle(.plain)

            // 검색 중에는 순서를 바꿀 수 없다 — 검색 결과는 날짜순이라 거기서
            // 끌어 옮긴 자리가 목록으로 돌아가면 아무 의미가 없다.
            if !isSearching {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isEditing.toggle() }
                } label: {
                    Text(isEditing ? "완료" : "편집")
                        .font(.moscoCaption().weight(.semibold))
                        .foregroundStyle(MoscoPalette.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Metrics.spacingMD)
        .padding(.top, Metrics.spacingSM)
        .padding(.bottom, Metrics.spacingSM)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MoscoPalette.textSecondary)
            TextField("할 일과 메모에서 찾기", text: $query)
                .font(.moscoBody())
                .focused($isSearchFocused)
                .submitLabel(.search)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(MoscoPalette.surface, in: Capsule())
        .padding(.horizontal, Metrics.spacingMD)
        .padding(.bottom, Metrics.spacingSM)
    }

    private var planList: some View {
        List {
            if isSearching, !trimmedQuery.isEmpty {
                searchSection
            } else {
                // 디데이는 맨 위 — 손꼽아 기다리는 날이 있으면 그게 오늘 하루의
                // 배경이 된다. 하나도 없으면 자리 자체를 만들지 않는다.
                if !dDayTodos.isEmpty { dDaySection }
                if !overdueTodos.isEmpty { overdueSection }
                if isOverloaded { overloadNotice }

                if incompleteToday.isEmpty && overdueTodos.isEmpty && backlogTodos.isEmpty {
                    emptyState
                }

                if !incompleteToday.isEmpty { todaySection }
                if !backlogTodos.isEmpty { backlogSection }
                if !completedToday.isEmpty { completedSection }
            }
        }
        .scrollContentBackground(.hidden)
        // 시스템 기본 섹션 간격은 이 화면엔 과하다 — 섹션이 넷뿐이라 그 간격이
        // 그대로 빈 화면으로 읽힌다. 구분은 헤더 글자가 이미 하고 있다.
        .listSectionSpacing(Metrics.spacingMD)
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
        .listRowInsets(EdgeInsets(top: Metrics.listRowGap, leading: Metrics.spacingMD, bottom: Metrics.listRowGap, trailing: Metrics.spacingMD))
    }

    /// 세로로 쌓지 않고 **가로로 넘겨 보는 카드**로 둔다. 세로로 쌓으면 디데이를
    /// 몇 개만 등록해도 오늘 할 일이 화면 밖으로 밀려난다. 가로 카드는 개수와
    /// 상관없이 높이가 한 줄로 고정된다.
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
            // List의 행 밖으로 카드가 잘리지 않게.
            .scrollClipDisabled()
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 0, trailing: 0))
        } header: {
            Text("디데이")
                .font(.moscoCaption().weight(.semibold))
                .foregroundStyle(MoscoPalette.textSecondary)
        }
    }

    /// 가장 가까운 하나만 색을 꽉 채운다 — 여러 장이 똑같이 생기면 어느 게 먼저
    /// 오는지 결국 날짜를 하나씩 읽어야 알 수 있다.
    private func dDayCard(_ todo: TodoItem, isNearest: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(dDayLabel(for: todo.date ?? today))
                .font(.system(size: 27, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(isNearest ? .white : MoscoPalette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 6)

            Text(todo.title)
                .font(.moscoCaption().weight(.semibold))
                .foregroundStyle(isNearest ? .white : MoscoPalette.textPrimary)
                .lineLimit(1)

            if let date = todo.date {
                Text(date.koreanMonthDayWeekday)
                    .font(.system(size: 11))
                    .foregroundStyle(isNearest ? .white.opacity(0.75) : MoscoPalette.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(width: 138, height: 112, alignment: .topLeading)
        // 유리도 그림자도 쓰지 않는다 — 셀과 같은 이유로 단색 채우기만 쓴다.
        .background(
            isNearest ? MoscoPalette.accent : MoscoPalette.accent.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .contentShape(Rectangle())
        .onTapGesture { detailTodo = todo }
    }

    /// 지난 날짜에 남은 것들. 화면 맨 위(디데이 다음)에 두는 건, 계획을 세우기 전에
    /// "이미 밀린 게 뭔지"부터 보여야 오늘을 현실적으로 짤 수 있기 때문이다.
    ///
    /// 옮기는 방법은 **버튼 하나**뿐이다. 예전엔 행마다 스와이프로도 하나씩 옮길 수
    /// 있었는데, 밀린 일을 하나씩 골라 옮기는 건 실제로 하지 않는 일이었다 —
    /// 대개는 전부 오늘로 가져오거나, 하나를 골라 지운다. 남길 것을 고르는 일은
    /// 셀의 메뉴가 이미 맡고 있다.
    private var overdueSection: some View {
        Section {
            ForEach(overdueTodos) { todo in
                row(todo, showsDate: true)
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
            plainHeader("지난 할 일", count: overdueTodos.count)
        }
    }

    /// 오늘 할 일 하나의 줄. 끌어서 순서를 바꿀 수 있고, 그 순서가 곧 `sortIndex`다.
    private var todaySection: some View {
        Section {
            ForEach(incompleteToday) { todo in
                row(todo)
            }
            .onMove { move(incompleteToday, from: $0, to: $1) }
            .onDelete { delete(incompleteToday, at: $0) }
        } header: {
            plainHeader("오늘 할 일", count: incompleteToday.count)
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
                            onDelete: { delete(todo) },
                            showsMemoPreview: true,
                            analyticsSource: "today_plan"
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
                    .listRowInsets(EdgeInsets(top: Metrics.listRowGap, leading: Metrics.spacingMD, bottom: Metrics.listRowGap, trailing: Metrics.spacingMD))
                }
                .onMove { move(backlogTodos, from: $0, to: $1) }
                .onDelete { delete(backlogTodos, at: $0) }
            }
        } header: {
            collapsibleHeader(
                "날짜를 안 정한 할 일",
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

    private var searchSection: some View {
        Group {
            if searchResults.isEmpty {
                ContentUnavailableView.search(text: trimmedQuery)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(searchResults) { todo in
                        // 검색 결과는 여러 날짜가 섞이므로 날짜를 함께 보여준다.
                        // 오늘 인스턴스로 보면 안 된다 — 다른 날의 항목까지
                        // 오늘의 완료 상태로 그려진다.
                        TodoRow(
                            todo: todo,
                            showsDate: true,
                            onTap: { editingTodo = todo },
                            onDelete: { delete(todo) },
                            showsMemoPreview: true,
                            analyticsSource: "search"
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Metrics.listRowGap, leading: Metrics.spacingMD, bottom: Metrics.listRowGap, trailing: Metrics.spacingMD))
                    }
                } header: {
                    plainHeader("검색 결과", count: searchResults.count)
                }
            }
        }
    }

    // MARK: - 조각

    private func row(_ todo: TodoItem, showsDate: Bool = false) -> some View {
        TodoRow(
            todo: todo,
            showsDate: showsDate,
            occurrenceDate: today,
            onTap: { editingTodo = todo },
            onDelete: { delete(todo) },
            showsMemoPreview: true,
            analyticsSource: "today_plan"
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: Metrics.listRowGap, leading: Metrics.spacingMD, bottom: Metrics.listRowGap, trailing: Metrics.spacingMD))
    }

    private func plainHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
            Text("\(count)")
                .foregroundStyle(MoscoPalette.textSecondary.opacity(0.6))
            Spacer()
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

    /// 오늘 기준 D-day 표기: 오늘이면 "D-DAY", 미래는 D-n.
    private func dDayLabel(for day: Date) -> String {
        let days = calendar.dateComponents(
            [.day],
            from: today,
            to: calendar.startOfDay(for: day)
        ).day ?? 0
        return days == 0 ? "D-DAY" : "D-\(days)"
    }

    // MARK: - 동작

    /// 끌어서 놓은 결과를 0부터 다시 매긴다. 한 화면에 줄이 하나뿐이라, 여기서 정한
    /// 번호가 곧 이 할 일의 순서다 — 다른 목록에서 봐도 같은 순서로 선다.
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

    /// 지난 항목/백로그를 오늘로. 순서 번호는 맨 뒤로 보내서, 이미 오늘 줄을 세워둔
    /// 항목들 사이로 끼어들지 않게 한다.
    private func pullIntoToday(_ todo: TodoItem) {
        withAnimation(.easeInOut(duration: 0.25)) {
            todo.date = today
            todo.sortIndex = (incompleteToday.map(\.sortIndex).max() ?? 0) + 1
        }
    }

    private func delete(_ todo: TodoItem) {
        modelContext.delete(todo)
        Analytics.log(.taskDeleted(source: "today_tab", count: 1))
    }
}
