import SwiftUI
import SwiftData

/// 캘린더에서 날짜를 먼저 고른 뒤 제목만 입력하는 경로(경로 1).
/// `DayTodosContentView` 하단에 처음부터 붙어있는 카카오톡 스타일 한 줄짜리 입력 바:
/// [날짜] [입력창] [우선순위 점] [전송]. 화면에 떠 있는 요소라 리퀴드 글래스를 서지컬하게 적용.
struct QuickAddView: View {
    /// nil이면 날짜 없이 시작 — "할 일" 탭의 백로그 입력창이 이 경우다.
    /// 캘린더의 하루치 리스트에서는 항상 그 날짜를 넘겨준다.
    let initialDate: Date?
    /// 기존 항목을 눌러 수정 모드로 들어오면 채워진다 — 이 입력창을 새로 만들기
    /// 대신 그 항목을 고치는 용도로 재사용한다(모달 없이, 채팅형 입력창 그대로).
    @Binding var editingTodo: TodoItem?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoCategory.sortOrder) private var categories: [TodoCategory]
    @Query(sort: \TodoCalendar.sortOrder) private var calendars: [TodoCalendar]
    @Query private var allTodos: [TodoItem]
    /// 새로 만드는 일정을 어느 캘린더에 넣을지 정하는 데 쓴다.
    @AppStorage(CalendarSelection.storageKey) private var hiddenCalendarIDs = ""
    /// 보이는 캘린더가 둘 이상일 때, 어디에 넣을지 물어보는 중.
    @State private var isChoosingCalendar = false
    @State private var title = ""
    @State private var category: TodoCategory?
    /// 시스템 Menu는 safeAreaInset 안에서 열릴 때 컴포즈 바 자체가 사라지는
    /// 버그가 있어서, 완전히 커스텀 오버레이로 대체했다.
    @State private var showCategoryOptions = false
    @State private var categoryBeingEdited: TodoCategory?
    @State private var showNewCategorySheet = false
    @State private var showScheduleSheet = false
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var startTime: Date?
    @State private var endTime: Date?
    @State private var repeatRule: RepeatRule = .none
    @State private var repeatEndDate: Date?
    @State private var repeatWeekdays: Set<Int> = []
    @State private var repeatInterval = 2
    @FocusState private var isTitleFocused: Bool

    /// 제목을 보고 카테고리를 자동으로 추천하는 동안 true — 그 사이엔 카테고리
    /// 점이 로딩 표시를 보여주고, 전송은 막는다(판별 결과가 반영되기 전에
    /// 보내버리는 걸 막기 위해).
    @State private var isClassifying = false
    /// 지금 카테고리가 분류기가 골라준 것인지. 사람이 이걸 뒤집는 비율이
    /// 분류기가 값을 하는지에 대한 유일한 근거다.
    @State private var categoryWasSuggested = false
    @State private var classifyTask: Task<Void, Never>?
    private let classifier: CategoryClassifying = EmbeddingCategoryClassifier()
    /// 입력창(글래스 캡슐) 자체의 실측 크기 — 시간 추천 팝업의 높이와 최대 너비를
    /// 여기에 맞춰서, 옵션이 많아도 입력창과 같은 크기 안에서 가로 스크롤되게 한다.
    @State private var composeBarSize: CGSize = .zero

    private let calendar = Calendar.current
    private var isEditing: Bool { editingTodo != nil }

    init(date: Date?, editingTodo: Binding<TodoItem?>) {
        self.initialDate = date
        _editingTodo = editingTodo
        _startDate = State(initialValue: date)
        _endDate = State(initialValue: date)
    }

    var body: some View {
        HStack(spacing: Metrics.spacingSM) {
            if isEditing {
                Button(action: cancelEditing) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(MoscoPalette.textSecondary)
                }
                .transition(.scale.combined(with: .opacity))
            }

            dateButton

            TextField("할 일을 적어보세요", text: $title, axis: .vertical)
                .font(.moscoBody())
                .lineLimit(1...4)
                .focused($isTitleFocused)
                .submitLabel(.send)
                .onSubmit(save)

            categoryButton
            sendButton
        }
        .animation(.easeOut(duration: 0.2), value: isEditing)
        // 보이는 캘린더가 하나면 묻지 않고 거기에 넣는다. 둘 이상일 때만 물어본다 —
        // 어디에 들어갔는지 모르는 채로 만들어지는 게 제일 나쁘다.
        .confirmationDialog("어느 캘린더에 넣을까요?", isPresented: $isChoosingCalendar, titleVisibility: .visible) {
            ForEach(visibleCalendars) { calendar in
                Button(calendar.name) { commitSave(assigning: calendar) }
            }
            Button("취소", role: .cancel) {}
        }
        .onAppear {
            // "미분류"로 시작하는 대신, 사용자가 아직 카테고리를 하나도 안
            // 골랐으면 앱 테마 색으로 seed된 기본 카테고리("할 일")부터 담는다.
            if category == nil, !isEditing, let firstCategory = categories.first {
                category = firstCategory
            }
        }
        .onChange(of: title) { _, newValue in
            scheduleClassification(for: newValue)
        }
        // startDate는 @State 초기값으로만 date를 받으므로, 이 뷰가 그대로 살아있는
        // 채 날짜만 바뀌면(리스트를 좌우로 밀어 날짜 이동) 초기값이 다시 평가되지
        // 않아 입력창의 날짜 칩이 이전 날짜에 멈춰 있었다.
        // 수정 중일 땐 그 항목의 날짜를 들고 있어야 하니 건드리지 않는다.
        .onChange(of: initialDate) { _, newValue in
            guard !isEditing else { return }
            startDate = newValue
            endDate = newValue
        }
        .onChange(of: editingTodo?.id) { _, _ in
            guard let todo = editingTodo else { return }
            title = todo.title
            category = todo.category
            startDate = todo.date
            endDate = todo.effectiveEndDate
            startTime = todo.startTime
            endTime = todo.endTime
            repeatRule = todo.repeatRule
            repeatEndDate = todo.repeatEndDate
            repeatWeekdays = Set(todo.repeatWeekdays)
            repeatInterval = todo.repeatInterval ?? 2
            isTitleFocused = true
        }
        .padding(.horizontal, Metrics.spacingMD)
        .padding(.vertical, Metrics.spacingSM)
        .moscoGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { composeBarSize = proxy.size }
                    .onChange(of: proxy.size) { _, newValue in composeBarSize = newValue }
            }
        )
        .overlay(alignment: .bottomTrailing) {
            if showCategoryOptions {
                categoryOptionsPopup
                    .offset(y: -54)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomTrailing)))
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let suggestion = timeSuggestion {
                timeSuggestionPopup(suggestion)
                    .offset(y: -54)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomLeading)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: timeSuggestion)
        .padding(.horizontal, Metrics.spacingMD)
        .padding(.top, Metrics.spacingSM)
        .padding(.bottom, Metrics.spacingSM)
        .sheet(isPresented: $showScheduleSheet) {
            EventScheduleSheet(
                startDate: $startDate,
                endDate: $endDate,
                startTime: $startTime,
                endTime: $endTime,
                repeatRule: $repeatRule,
                repeatEndDate: $repeatEndDate,
                repeatWeekdays: $repeatWeekdays,
                repeatInterval: $repeatInterval,
                onSave: {
                    // 기존 항목을 고치는 중이면 그 자리에서 반영한다. 새로 만드는
                    // 중이라면 아직 모델이 없으니 입력창 상태로만 남고, 보내기를
                    // 누를 때 함께 저장된다.
                    guard let todo = editingTodo else { return }
                    applySchedule(to: todo)
                }
            )
        }
        .sheet(isPresented: $showNewCategorySheet) {
            CategoryEditorSheet(
                existing: nil,
                usedColorHexValues: categories.map(\.colorHex),
                onSave: { draft in
                    let newCategory = TodoCategory(name: draft.name, colorHex: draft.colorHex, sortOrder: categories.count)
                    newCategory.notifiesBeforeStart = draft.notifiesBeforeStart
                    newCategory.notificationLeadMinutes = draft.notificationLeadMinutes
                    modelContext.insert(newCategory)
                    Analytics.log(.categoryCreated(count: categories.count + 1))
                    category = newCategory
                }
            )
        }
        .sheet(item: $categoryBeingEdited) { editing in
            CategoryEditorSheet(
                existing: editing,
                usedColorHexValues: categories.map(\.colorHex),
                onSave: { draft in
                    editing.name = draft.name
                    editing.colorHex = draft.colorHex
                    editing.notifiesBeforeStart = draft.notifiesBeforeStart
                    editing.notificationLeadMinutes = draft.notificationLeadMinutes
                },
                onDelete: {
                    guard let defaultCategory = categories.first(where: \.isDefault) else { return }
                    if category?.id == editing.id { category = defaultCategory }
                    TodoCategory.delete(editing, reassigningTodosTo: defaultCategory, in: modelContext)
                }
            )
        }
    }

    /// 탭하면 시간/종료일/반복을 설정하는 시트가 뜬다.
    private var dateButton: some View {
        Button {
            showScheduleSheet = true
        } label: {
            TagChip(label: dateLabel, tint: startDate == nil ? MoscoPalette.textSecondary.opacity(0.7) : MoscoPalette.textSecondary)
        }
    }

    private var dateLabel: String {
        guard let startDate else { return "날짜 없음" }

        // 반복이 설정돼 있으면 날짜 대신 반복 규칙이 한눈에 보이게 — 시트를 닫은
        // 뒤에도 버튼만 보고 반복 여부를 알 수 있다.
        if let repeatLabel {
            guard let startTime else { return repeatLabel }
            return "\(repeatLabel) \(startTime.koreanTime)"
        }
        if let endDate, !calendar.isDate(startDate, inSameDayAs: endDate) {
            return "\(startDate.koreanMonthDay) - \(endDate.koreanMonthDay)"
        }
        return koreanScheduleLabel(date: startDate, time: startTime)
    }

    private var repeatLabel: String? {
        switch repeatRule {
        case .none:
            return nil
        case .daily:
            return "매일"
        case .weekly:
            guard !repeatWeekdays.isEmpty else { return "매주" }
            let symbols = repeatWeekdays.sorted().map { KoreanCalendar.weekdaySymbols[$0 - 1] }
            return "매주 " + symbols.joined(separator: "·")
        case .monthly:
            return "매월"
        case .everyNDays:
            return "\(repeatInterval)일마다"
        case .yearly:
            return "매년"
        }
    }

    /// 팔레트 점 형태 — 탭하면 위로 카테고리 옵션이 뜬다. 판별 중엔 로딩 표시로
    /// "지금 고르는 중"임을 보여준다.
    private var categoryButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                showCategoryOptions.toggle()
            }
        } label: {
            ZStack {
                if isClassifying {
                    ClassifyingDot()
                } else {
                    Circle().fill(category?.color ?? MoscoPalette.textSecondary.opacity(0.5))
                }
            }
            .frame(width: 22, height: 22)
            .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
        }
        // 판별이 끝나기 전엔 옵션 팝업을 못 열게 막는다 — 버튼도 자연스럽게
        // 흐려져서 지금은 누를 수 없는 상태라는 게 눈에 보이게.
        .disabled(isClassifying)
        .opacity(isClassifying ? 0.6 : 1)
        .animation(.easeOut(duration: 0.15), value: isClassifying)
    }

    /// 색 원만 나열하면 누르기 전엔 어떤 카테고리인지 알 수 없어서, 다른 화면에서
    /// 쓰는 것과 같은 언어(점 + 이름 캡슐)로 보여준다. 이름이 붙으면 가로로 쉽게
    /// 넘치므로 시간 추천 팝업과 같은 방식으로 입력창 폭 안에서 가로 스크롤시킨다.
    private var categoryOptionsPopup: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categories) { candidate in
                    categoryOption(candidate)
                }

                Button {
                    showNewCategorySheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(MoscoPalette.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Metrics.spacingMD)
        .padding(.vertical, Metrics.spacingSM)
        .frame(maxWidth: composeBarSize.width)
        .moscoGlass(in: Capsule())
        // moscoGlass는 배경만 캡슐로 깔 뿐 내용물을 자르진 않아서, 스크롤 중인
        // 칩이 캡슐 밖으로 삐져나온다 — 내용물도 같은 모양으로 잘라낸다.
        .clipShape(Capsule())
    }

    private func categoryOption(_ candidate: TodoCategory) -> some View {
        let isSelected = category?.id == candidate.id

        return HStack(spacing: 5) {
            Circle()
                .fill(candidate.color)
                .frame(width: 6, height: 6)
            Text(candidate.name)
                .font(.moscoCaption())
                .lineLimit(1)
        }
        .foregroundStyle(candidate.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(candidate.color.opacity(isSelected ? 0.22 : 0.1), in: Capsule())
        .overlay(
            Capsule().strokeBorder(candidate.color, lineWidth: isSelected ? 1.5 : 0)
        )
        .contentShape(Capsule())
        .onTapGesture {
            // 분류기가 골라준 걸 사람이 다른 걸로 바꿨을 때만 센다. 같은 걸 다시
            // 누른 건 뒤집은 게 아니다.
            if categoryWasSuggested, candidate.id != category?.id {
                Analytics.log(.categoryOverridden)
                categoryWasSuggested = false
            }
            category = candidate
            withAnimation(.easeInOut(duration: 0.15)) {
                showCategoryOptions = false
            }
        }
        .onLongPressGesture {
            categoryBeingEdited = candidate
        }
    }

    private var sendButton: some View {
        Button(action: save) {
            Image(systemName: isEditing ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                .font(.system(size: 28))
                // isClassifying도 색에 반영해야 한다 — 안 그러면 실제로는 막혀
                // 있는데 색은 계속 활성 상태처럼 보여서 헷갈린다.
                .foregroundStyle(canSave && !isClassifying ? MoscoPalette.accent : MoscoPalette.textSecondary.opacity(0.35))
        }
        // 우선순위 판별이 끝나기 전엔 못 보내게 막는다 — 판별 결과가 반영되기
        // 전에 보내버리면 그 자동 분류가 무의미해진다.
        .disabled(!canSave || isClassifying)
        .animation(.easeOut(duration: 0.15), value: isClassifying)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - 우선순위 자동 분류

    /// 타이핑이 잠시 멈추면(0.2초) 그때 제목으로 분류를 시작한다 — 글자마다
    /// 요청하면 낭비니까 디바운스.
    private func scheduleClassification(for text: String) {
        classifyTask?.cancel()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isClassifying = false
            return
        }
        classifyTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            isClassifying = true
            let result = await classifier.classify(text, categories: categories, existingTodos: allTodos)
            guard !Task.isCancelled else { return }
            if let result {
                category = result
                // 사람이 나중에 이 배정을 뒤집는지 보려고 표시해둔다 —
                // `categoryOverridden`과 짝이 되어야 분류기의 값을 잴 수 있다.
                categoryWasSuggested = true
            }
            Analytics.log(.categorySuggested(matched: result != nil))
            isClassifying = false
        }
    }

    // MARK: - 입력 텍스트에서 시간 인식

    /// 제목 안에서 찾아낸 시간 표현 하나("토큰"). hour24가 있으면 오전/오후가
    /// 확정된 것이고, hour12만 있으면 모호해서 물어봐야 한다.
    private struct TimeToken {
        let range: Range<String.Index>
        let hour24: Int?
        let hour12: Int?
        let minute: Int
    }

    /// 제목 하나에 담긴 시간 표현을 전부 찾는다 — 두 개가 "~"나 "-"로 이어지면
    /// 시작~종료 범위(예: "4시~7시")로, 하나뿐이면 단일 시간으로 다룬다.
    struct TimeSuggestion: Equatable {
        let matched: String
        let startHour24: Int?
        let startHour12: Int?
        let startMinute: Int
        /// 범위로 인식됐을 때만 채워진다.
        let endHour24: Int?
        let endHour12: Int?
        let endMinute: Int?
    }

    /// 지원 표현: "오후 7시", "오전 7시 30분", "7시", "7시 반", "19:30", "7:30",
    /// "7pm", "7 PM", 그리고 이들의 범위("4시~7시", "4:00-19:00", "2pm~5pm") 등.
    private var timeSuggestion: TimeSuggestion? {
        let tokens = Self.timeTokens(in: title)
        guard let first = tokens.first else { return nil }

        if tokens.count >= 2 {
            let second = tokens[1]
            let between = title[first.range.upperBound..<second.range.lowerBound]
                .trimmingCharacters(in: .whitespaces)
            if between.isEmpty || between == "~" || between == "-" {
                return TimeSuggestion(
                    matched: String(title[first.range.lowerBound..<second.range.upperBound]),
                    startHour24: first.hour24, startHour12: first.hour12, startMinute: first.minute,
                    endHour24: second.hour24, endHour12: second.hour12, endMinute: second.minute
                )
            }
        }

        return TimeSuggestion(
            matched: String(title[first.range]),
            startHour24: first.hour24, startHour12: first.hour12, startMinute: first.minute,
            endHour24: nil, endHour12: nil, endMinute: nil
        )
    }

    /// 제목 안의 모든 시간 표현을 위치 순서대로 찾는다. 같은 자리를 여러 패턴이
    /// 동시에 매칭하면(예: "오후 7시"가 "N시" 패턴에도 걸림) 더 구체적인(긴) 쪽만 남긴다.
    private static func timeTokens(in text: String) -> [TimeToken] {
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
        for match in text.matches(of: /(\d{1,2})\s*(am|pm|AM|PM)/) {
            guard let hour = Int(match.1), (1...12).contains(hour) else { continue }
            let isPM = match.2.lowercased() == "pm"
            found.append(TimeToken(
                range: match.range,
                hour24: isPM ? (hour == 12 ? 12 : hour + 12) : (hour == 12 ? 0 : hour),
                hour12: nil,
                minute: 0
            ))
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

    private static func parseMinute(_ text: String?) -> Int {
        guard let text else { return 0 }
        if text == "반" { return 30 }
        return Int(text.filter(\.isNumber)) ?? 0
    }

    private func koreanTimeLabel(hour24: Int, minute: Int) -> String {
        let period = hour24 >= 12 ? "오후" : "오전"
        var hour12 = hour24 % 12
        if hour12 == 0 { hour12 = 12 }
        return minute == 0 ? "\(period) \(hour12)시" : "\(period) \(hour12)시 \(minute)분"
    }

    /// hour12를 주어진 오전/오후로 확정한 24시간제 값.
    private func resolvedHour24(hour12: Int, isPM: Bool) -> Int {
        isPM ? (hour12 == 12 ? 12 : hour12 + 12) : (hour12 == 12 ? 0 : hour12)
    }

    /// 입력창(TagChip/dateButton)과 같은 언어로 — 캡슐 안에 톤온톤 칩이 나열되는
    /// 모양을 그대로 재사용해서 붕 떠 보이지 않게 한다.
    private func timeSuggestionPopup(_ suggestion: TimeSuggestion) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(suggestionOptions(suggestion).enumerated()), id: \.offset) { _, option in
                    Button {
                        apply(option, suggestion: suggestion)
                    } label: {
                        TagChip(label: option.label, tint: MoscoPalette.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        // 입력창 본체와 같은 inset(가로 spacingMD·세로 spacingSM)을 써야 이질감이
        // 없다 — 이 패딩은 스크롤뷰 "바깥"에 둬서, 스크롤해도 여백 자체는 안 움직이고
        // 그 안쪽 영역만 스크롤되게 한다.
        .padding(.horizontal, Metrics.spacingMD)
        .padding(.vertical, Metrics.spacingSM)
        // 옵션이 늘어나 칩이 축약되는 대신, 입력창과 같은 크기 안에서 가로로
        // 스크롤되게 한다 — 폭도 입력창을 넘지 않게 맞춰야 스크롤이 실제로 걸린다.
        .frame(maxWidth: composeBarSize.width, minHeight: composeBarSize.height, maxHeight: composeBarSize.height)
        .moscoGlass(in: Capsule())
        // moscoGlass는 배경만 캡슐 모양으로 깔 뿐 내용물을 잘라내진 않아서,
        // 스크롤 중인 칩이 캡슐 배경 밖으로 삐져나와 보였다 — 내용물도 같은
        // 모양으로 직접 잘라내야 캡슐 안쪽에서만 스크롤되는 것처럼 보인다.
        .clipShape(Capsule())
    }

    private struct SuggestionOption {
        let label: String
        let startHour24: Int
        let endHour24: Int?
    }

    /// 시작(과 있다면 종료)이 이미 확정(hour24)이면 후보 하나, 오전/오후가
    /// 모호하면 두 후보(같은 기준으로 시작·종료 모두에 적용)를 보여준다.
    private func suggestionOptions(_ suggestion: TimeSuggestion) -> [SuggestionOption] {
        func label(start: Int, end: Int?) -> String {
            guard let end else { return koreanTimeLabel(hour24: start, minute: suggestion.startMinute) }
            return "\(koreanTimeLabel(hour24: start, minute: suggestion.startMinute)) - \(koreanTimeLabel(hour24: end, minute: suggestion.endMinute ?? 0))"
        }

        // 둘 다(또는 시작만) 이미 확정인 경우 — 종료가 모호하면 시작과 같은 기준으로 채운다.
        if let startHour24 = suggestion.startHour24 {
            if let endHour24 = suggestion.endHour24 {
                return [SuggestionOption(label: label(start: startHour24, end: endHour24), startHour24: startHour24, endHour24: endHour24)]
            }
            if let endHour12 = suggestion.endHour12 {
                let isPM = startHour24 >= 12
                let end = resolvedHour24(hour12: endHour12, isPM: isPM)
                return [SuggestionOption(label: label(start: startHour24, end: end), startHour24: startHour24, endHour24: end)]
            }
            return [SuggestionOption(label: label(start: startHour24, end: nil), startHour24: startHour24, endHour24: nil)]
        }

        guard let startHour12 = suggestion.startHour12 else { return [] }

        // 종료가 이미 확정이면 그 기준(오전/오후)을 시작에도 그대로 적용해 하나로 확정.
        if let endHour24 = suggestion.endHour24 {
            let isPM = endHour24 >= 12
            let start = resolvedHour24(hour12: startHour12, isPM: isPM)
            return [SuggestionOption(label: label(start: start, end: endHour24), startHour24: start, endHour24: endHour24)]
        }

        // 종료도 없이 시작만 있는 경우 — 오전/오후 두 후보.
        guard let endHour12 = suggestion.endHour12 else {
            return [false, true].map { isPM in
                let start = resolvedHour24(hour12: startHour12, isPM: isPM)
                return SuggestionOption(label: label(start: start, end: nil), startHour24: start, endHour24: nil)
            }
        }

        if endHour12 < startHour12 {
            // "11시~1시"처럼 끝이 시작보다 작으면 정오를 넘어간다는 뜻이 명확하니
            // 오전 시작 · 오후 종료로 바로 확정한다(되물어볼 필요가 없다).
            let start = resolvedHour24(hour12: startHour12, isPM: false)
            let end = resolvedHour24(hour12: endHour12, isPM: true)
            return [SuggestionOption(label: label(start: start, end: end), startHour24: start, endHour24: end)]
        }

        // "6시~7시"처럼 끝이 시작보다 크거나 같으면 오전만/오후만은 물론
        // 오전에 시작해 오후에 끝나는 것도 똑같이 말이 되니 세 후보를 다 보여준다.
        let amStart = resolvedHour24(hour12: startHour12, isPM: false)
        let pmStart = resolvedHour24(hour12: startHour12, isPM: true)
        let amEnd = resolvedHour24(hour12: endHour12, isPM: false)
        let pmEnd = resolvedHour24(hour12: endHour12, isPM: true)
        return [
            SuggestionOption(label: label(start: amStart, end: amEnd), startHour24: amStart, endHour24: amEnd),
            SuggestionOption(label: label(start: amStart, end: pmEnd), startHour24: amStart, endHour24: pmEnd),
            SuggestionOption(label: label(start: pmStart, end: pmEnd), startHour24: pmStart, endHour24: pmEnd)
        ]
    }

    /// 시간을 확정하면 제목에서 시간 텍스트를 걷어내고 시작(및 종료) 시간으로 설정한다.
    /// 아직 날짜가 없으면(할 일 탭 백로그) 오늘을 기준일로 삼는다.
    private func apply(_ option: SuggestionOption, suggestion: TimeSuggestion) {
        Analytics.log(.timeSuggestionApplied)
        let anchor = startDate ?? calendar.startOfDay(for: Date())
        if startDate == nil { startDate = anchor }
        if endDate == nil { endDate = anchor }

        startTime = calendar.date(bySettingHour: option.startHour24, minute: suggestion.startMinute, second: 0, of: anchor)
        if let endHour24 = option.endHour24 {
            endTime = calendar.date(bySettingHour: endHour24, minute: suggestion.endMinute ?? 0, second: 0, of: anchor)
        }

        if let range = title.range(of: suggestion.matched) {
            title.removeSubrange(range)
        }
        while title.contains("  ") {
            title = title.replacingOccurrences(of: "  ", with: " ")
        }
        title = title.trimmingCharacters(in: .whitespaces)
    }

    /// 지금 화면에 보이도록 켜둔 캘린더들.
    private var visibleCalendars: [TodoCalendar] {
        CalendarSelection.visible(calendars, hidden: CalendarSelection.hidden(from: hiddenCalendarIDs))
    }

    private func save() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // 수정 중이면 소속은 건드리지 않는다 — 이미 어딘가에 들어가 있다.
        guard !isEditing else {
            commitSave(assigning: nil)
            return
        }

        // 보이는 캘린더가 둘 이상이면 어디에 넣을지 물어본다. 하나뿐이면 거기로,
        // 하나도 안 켜져 있으면 기본 캘린더로 조용히 넣는다.
        if visibleCalendars.count >= 2 {
            isChoosingCalendar = true
            return
        }
        commitSave(assigning: visibleCalendars.first ?? calendars.first(where: \.isDefault))
    }

    /// 지금 입력창이 들고 있는 날짜·시간·반복을 할 일에 옮겨 적는다.
    ///
    /// 보내기 버튼과 일정 시트의 '완료'가 **같은 함수**를 쓴다. 예전엔 시트가
    /// 입력창의 상태만 바꾸고 모델에는 손대지 않아서, 기존 항목을 고칠 때 시트에서
    /// 날짜를 정하고 닫아도 보내기를 한 번 더 누르기 전엔 아무 일도 안 일어났다 —
    /// '완료'라고 적힌 버튼을 눌렀는데 완료되지 않는 상태였다.
    private func applySchedule(to todo: TodoItem) {
        let resolvedEndDate: Date? = {
            guard let startDate, let endDate, !calendar.isDate(startDate, inSameDayAs: endDate) else { return nil }
            return endDate
        }()

        todo.date = startDate
        todo.endDate = resolvedEndDate
        todo.startTime = startDate == nil ? nil : startTime
        todo.endTime = startDate == nil ? nil : endTime
        todo.repeatRule = startDate == nil ? .none : repeatRule
        todo.repeatEndDate = startDate == nil ? nil : repeatEndDate
        todo.repeatWeekdays = startDate == nil ? [] : Array(repeatWeekdays)
        todo.repeatInterval = (startDate != nil && repeatRule == .everyNDays) ? repeatInterval : nil
    }

    /// 인자 이름을 `calendar`로 두면 이 뷰의 `Calendar.current` 프로퍼티를 가린다.
    private func commitSave(assigning targetCalendar: TodoCalendar?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let resolvedEndDate: Date? = {
            guard let startDate, let endDate, !calendar.isDate(startDate, inSameDayAs: endDate) else { return nil }
            return endDate
        }()

        if let todo = editingTodo {
            todo.title = trimmed
            todo.category = category
            applySchedule(to: todo)
        } else {
            let todo = TodoItem(
                title: trimmed,
                date: startDate,
                endDate: resolvedEndDate,
                startTime: startDate == nil ? nil : startTime,
                endTime: startDate == nil ? nil : endTime,
                category: category,
                repeatRule: startDate == nil ? .none : repeatRule,
                repeatEndDate: startDate == nil ? nil : repeatEndDate,
                repeatWeekdays: startDate == nil ? [] : Array(repeatWeekdays),
                repeatInterval: (startDate != nil && repeatRule == .everyNDays) ? repeatInterval : nil
            )
            // 어디에도 안 넣으면 캘린더를 하나 끄는 순간 방금 만든 일정이
            // 사라진 것처럼 보인다 — 항상 소속을 준다.
            todo.calendar = targetCalendar ?? calendars.first(where: \.isDefault)
            modelContext.insert(todo)
            // 날짜가 있으면 달력에 자리를 갖는 "일정", 없으면 할 일 탭에만
            // 있는 백로그 "할 일" — 이 앱에서 둘은 실제로 다른 것이다.
            if todo.date == nil {
                Analytics.log(.taskCreated(source: "quick_add", titleLength: trimmed.count))
            } else {
                Analytics.log(
                    .scheduleCreated(
                        source: "quick_add",
                        hasTime: todo.startTime != nil,
                        repeatRule: todo.repeatRule.rawValue,
                        isMultiDay: todo.isMultiDay,
                        titleLength: trimmed.count
                    )
                )
            }
        }

        // 여기서 별도 학습/피드백 기록은 필요 없다 — 카테고리에 방금 이 제목이
        // 들어갔다는 사실 자체가 다음 classify() 호출에서 곧바로 centroid에
        // 반영된다(EmbeddingCategoryClassifier가 매번 existingTodos에서 다시 계산).
        resetFields()
    }

    private func cancelEditing() {
        resetFields()
    }

    /// 다음 항목은 다시 원래 상태(날짜 있으면 그 날짜, 없으면 날짜 없음)로
    /// 초기화한다(수정 모드였다면 해제).
    private func resetFields() {
        title = ""
        editingTodo = nil
        startDate = initialDate
        endDate = initialDate
        startTime = nil
        endTime = nil
        repeatRule = .none
        repeatEndDate = nil
        repeatWeekdays = []
        repeatInterval = 2
    }
}
