import SwiftUI
import SwiftData

/// 앞으로 2주를 날짜별로 쭉 늘어놓는 화면.
///
/// 이 앱에 비어 있던 자리를 채운다. "오늘" 탭은 오늘만, 달력은 한 달 격자만 보여줘서
/// **"이번 주에 뭐 있지?"에 답하는 화면이 없었다** — 지금까지는 월 격자에서 날짜를
/// 하나씩 눌러 확인해야 했다.
///
/// 특히 오늘 계획 화면의 과부하 알림이 "몇 개는 다른 날로 미뤄도 좋아요"라고 하면서
/// 정작 **어느 날이 비어 있는지 볼 방법을 안 줬다.** 그래서 일정이 없는 날도 "비어
/// 있음"으로 함께 보여준다 — 미룰 곳이 눈에 보여야 미룰 수 있다.
///
/// 검색은 날짜 범위와 무관하게 **전체**를 훑고 메모 내용까지 본다. 예전 메모 탭이
/// 하던 일(메모 모아보기)을 그대로 흡수하면서, "메모가 있는 항목만"이라는 제약은
/// 없앤 셈이다.
struct UpcomingScreen: View {
    @Query private var allTodos: [TodoItem]
    /// 달력 탭에서 켜둔 캘린더만 본다.
    @AppStorage(CalendarSelection.storageKey) private var hiddenCalendarIDs = ""

    @State private var query = ""
    @State private var detailTodo: TodoItem?

    private let calendar = Calendar.current
    /// 앞으로 며칠까지 늘어놓을지. 2주면 "이번 주와 다음 주"가 다 들어온다.
    private static let horizonDays = 14

    private var today: Date { calendar.startOfDay(for: .now) }

    private var visibleTodos: [TodoItem] {
        let hidden = CalendarSelection.hidden(from: hiddenCalendarIDs)
        return allTodos.filter { CalendarSelection.matches($0, hidden: hidden) }
    }

    private var upcomingDays: [Date] {
        (0..<Self.horizonDays).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    private func todos(on day: Date) -> [TodoItem] {
        visibleTodos
            .filter { $0.occurs(on: day) }
            .sorted { $0.sortableMinutes < $1.sortableMinutes }
    }

    /// 디데이로 표시해둔 것 **전부**를 가까운 순으로. 처음엔 가장 가까운 하나만
    /// 보여줬는데, 여러 개를 표시해두면 나머지가 어디로 갔는지 알 수 없었다.
    ///
    /// 탭을 새로 만들지 않고 이 화면 맨 위에 두는 건, 탭 구성이 상황에 따라
    /// 바뀌면 길 찾기가 어려워지고 "앞으로 무슨 일이 있나"를 보는 이 화면과
    /// 의미도 딱 맞기 때문이다. 지난 디데이는 뺀다 — 세어봐야 의미가 없다.
    private var dDayTodos: [TodoItem] {
        visibleTodos
            .filter { todo in
                guard todo.isDDay, let date = todo.date else { return false }
                return calendar.startOfDay(for: date) >= today
            }
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }

    private var dDaySection: some View {
        Section {
            ForEach(dDayTodos) { todo in
                dDayCard(todo)
            }
        } header: {
            Text("손꼽아 기다리는 일")
                .font(.moscoCaption().weight(.semibold))
                .foregroundStyle(MoscoPalette.textSecondary)
        }
    }

    private func dDayCard(_ todo: TodoItem) -> some View {
        HStack(spacing: Metrics.spacingMD) {
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.moscoBody().weight(.semibold))
                    .foregroundStyle(MoscoPalette.textPrimary)
                    .lineLimit(1)
                if let date = todo.date {
                    Text(date.koreanMonthDayWeekday)
                        .font(.moscoCaption())
                        .foregroundStyle(MoscoPalette.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Text(dDayLabel(for: todo.date ?? today, from: today))
                .font(.system(size: 24, weight: .bold).monospacedDigit())
                .foregroundStyle(MoscoPalette.accent)
        }
        .padding(Metrics.spacingMD)
        .background(MoscoPalette.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: Metrics.spacingMD, bottom: 8, trailing: Metrics.spacingMD))
        .onTapGesture { detailTodo = todo }
    }

    // MARK: - 검색

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 제목과 메모를 함께 본다 — 어느 쪽에 적었는지 기억나지 않아도 찾을 수 있게.
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

    var body: some View {
        NavigationStack {
            List {
                if trimmedQuery.isEmpty {
                    if !dDayTodos.isEmpty { dDaySection }
                    agendaSections
                } else {
                    searchSection
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(MoscoPalette.canvas)
            // 제목을 두지 않는다 — 날짜 헤더가 줄줄이 이어지는 것 자체가 이미
            // "앞으로 무슨 일이 있는지"를 말하고, 좁은 화면에서 제목 줄은 목록이
            // 차지할 수 있는 높이만 가져간다.
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "할 일과 메모에서 찾기")
            .sheet(item: $detailTodo) { todo in
                TodoDetailSheet(todo: todo)
            }
        }
    }

    @ViewBuilder
    private var agendaSections: some View {
        ForEach(upcomingDays, id: \.self) { day in
            let items = todos(on: day)
            Section {
                if items.isEmpty {
                    // 빈 날을 감추면 "어디로 미룰까"에 답할 수 없다 — 이 줄이
                    // 이 화면의 절반이다.
                    Text("일정 없음")
                        .font(.moscoCaption())
                        .foregroundStyle(MoscoPalette.textSecondary.opacity(0.6))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: Metrics.spacingMD, bottom: 10, trailing: Metrics.spacingMD))
                } else {
                    ForEach(items) { todo in
                        row(todo, on: day)
                    }
                }
            } header: {
                dayHeader(day, count: items.count)
            }
        }
    }

    @ViewBuilder
    private var searchSection: some View {
        if searchResults.isEmpty {
            ContentUnavailableView.search(text: trimmedQuery)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        } else {
            Section {
                ForEach(searchResults) { todo in
                    row(todo, on: todo.date.map { calendar.startOfDay(for: $0) })
                }
            } header: {
                Text("\(searchResults.count)개 찾았어요")
                    .font(.moscoCaption())
                    .foregroundStyle(MoscoPalette.textSecondary)
            }
        }
    }

    private func dayHeader(_ day: Date, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(day.koreanMonthDayWeekday)
                .foregroundStyle(
                    calendar.isDateInToday(day) ? MoscoPalette.accent : MoscoPalette.textPrimary
                )
            if calendar.isDateInToday(day) {
                Text("오늘")
                    .foregroundStyle(MoscoPalette.accent)
            } else if calendar.isDateInTomorrow(day) {
                Text("내일")
                    .foregroundStyle(MoscoPalette.textSecondary)
            }
            if count > 0 {
                Text("\(count)")
                    .foregroundStyle(MoscoPalette.textSecondary.opacity(0.6))
            }
            Spacer()
        }
        .font(.moscoCaption().weight(.semibold))
    }

    private func row(_ todo: TodoItem, on day: Date?) -> some View {
        TodoRow(
            todo: todo,
            // 검색 결과는 여러 날짜가 섞이므로 날짜를 함께 보여준다.
            showsDate: !trimmedQuery.isEmpty,
            occurrenceDate: day,
            onTap: { detailTodo = todo },
            onDelete: nil
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: Metrics.spacingMD, bottom: 4, trailing: Metrics.spacingMD))
        // "다른 날로 미루기"를 여기서 바로 할 수 있어야 이 화면이 제 값을 한다.
        // 반복 일정은 원본을 옮기면 모든 날짜가 함께 움직여서 빼둔다.
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if todo.repeatRule == .none, let day {
                Button {
                    postpone(todo, from: day)
                } label: {
                    Label("내일로", systemImage: "arrow.turn.up.right")
                }
                .tint(MoscoPalette.accent)
            }
        }
    }

    private func postpone(_ todo: TodoItem, from day: Date) {
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            // 여러 날에 걸친 일정은 길이를 유지한 채 통째로 하루 민다.
            if let start = todo.date, let end = todo.endDate {
                let length = calendar.dateComponents([.day], from: start, to: end).day ?? 0
                todo.date = next
                todo.endDate = calendar.date(byAdding: .day, value: length, to: next)
            } else {
                todo.date = next
            }
        }
    }
}
