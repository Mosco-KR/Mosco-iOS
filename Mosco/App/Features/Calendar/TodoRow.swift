import SwiftUI
import SwiftData
import StoreKit

struct TodoRow: View {
    @Bindable var todo: TodoItem
    /// 하루치 리스트(DayTodosContentView)에서는 날짜가 이미 컨텍스트로 있으니 끄고,
    /// 여러 날짜를 한 화면에 섞어 보여줄 때(우선순위별 탭)만 켠다. 우선순위 라벨도
    /// 이 화면에서는 "Should Have"처럼 원어 그대로 풀로 쓴다.
    var showsDate: Bool = false
    /// 어느 날짜의 인스턴스로 보고 있는지(하루치 리스트에서 전달). 반복 일정이면
    /// 완료 체크가 이 날짜의 인스턴스에만 적용된다 — 다른 날의 반복은 그대로.
    var occurrenceDate: Date? = nil
    /// 수정 — 채팅형 입력창을 다시 띄우거나 상세를 연다. 꾹 눌러 나오는 메뉴의
    /// "수정"에서 부른다. 예전엔 셀 몸통 탭이 이걸 맡았는데, 그러면 완료가
    /// 26pt 동그라미 안으로 밀려나 매번 정확히 겨눠야 했다 — 목록에서 제일 자주
    /// 하는 일이 제일 어려운 조작이 되어 있었다.
    var onTap: (() -> Void)? = nil
    /// 이 할 일을 지운다. nil이면 삭제 메뉴를 감춘다.
    var onDelete: (() -> Void)? = nil
    /// 여러 캘린더를 함께 보고 있을 때만 소속 캘린더 칩을 붙인다 — 하나만 보고
    /// 있으면 전부 같은 캘린더라 칩이 자리만 차지한다.
    var showsCalendarTag: Bool = false
    /// 메모 본문을 셀 안에서 바로 펼쳐 보여줄지.
    ///
    /// 할 일 목록에서만 켠다. 거기서는 메모가 "열어봐야 아는 딸린 정보"가 아니라
    /// 할 일의 일부다 — 무엇을 적어뒀는지 보려고 매번 시트를 열어야 한다면 적어둔
    /// 보람이 없다. 달력의 하루치 목록은 한 칸에 여러 날이 겹치는 화면이라 셀
    /// 높이가 들쭉날쭉해지면 훑기 어려워서 끈다.
    var showsMemoPreview: Bool = false

    /// 이 화면이 어디인지 — 복제 이벤트에 그대로 실어 보낸다.
    var analyticsSource: String = "app"

    /// 앱스토어 리뷰 요청. 시스템이 연 3회 한도 안에서 실제로 띄울지 정한다.
    @Environment(\.requestReview) private var requestReview
    @Environment(\.modelContext) private var modelContext
    @Environment(TodoClipboard.self) private var clipboard
    @Query(sort: \TodoCalendar.sortOrder) private var calendars: [TodoCalendar]
    @State private var showsMemoEditor = false
    @State private var showsDeleteConfirmation = false
    @State private var showsDuplicatePicker = false

    private var isDone: Bool {
        if let occurrenceDate { return todo.isCompleted(on: occurrenceDate) }
        return todo.isCompleted
    }

    private var accentColor: Color {
        todo.category?.color ?? MoscoPalette.textSecondary
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        HStack(alignment: .center, spacing: 10) {
            // 막대와 체크는 한 덩어리로 붙여둔다 — 둘 사이가 벌어지면 왼쪽 끝에
            // 요소가 두 개 흩어진 것처럼 보인다.
            categoryBar
                .padding(.trailing, -2)

            checkMark

            // 1행: 제목 그대로, 2행: 카테고리(항상 맨 앞) + 날짜/시간을 하나로 합친 태그.
            VStack(alignment: .leading, spacing: 6) {
                Text(todo.title)
                    .font(.moscoBody().weight(.semibold))
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? MoscoPalette.textSecondary : MoscoPalette.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // **한 행에서 카테고리 색이 쓰이는 자리는 체크 동그라미 하나뿐이다.**
                // 왼쪽 한 열에 모여 있어 목록을 훑을 때 색이 세로로 정렬돼 읽히고,
                // 나머지는 전부 중립색이라 눈이 쉰다. 예전엔 칩·아이콘·메모 버튼까지
                // 전부 색을 따라가서 한 행에 색이 여섯 군데씩 흩어졌다.
                //
                // 여기 칩들은 **무엇인지 이름으로 말한다** — 색까지 입힐 이유가 없다.
                HStack(spacing: 6) {
                    // 색 점은 끈다 — 왼쪽 막대가 이미 같은 말을 하고 있다.
                    CategoryTag(category: todo.category, showsColorDot: false)

                    if showsCalendarTag, let calendar = todo.calendar {
                        // 캘린더 색은 위쪽 선택기에서만 쓴다(설정 화면이 그렇게
                        // 안내하고 있다). 여기서 또 칠하면 카테고리 색과 경쟁한다.
                        TagChip(label: calendar.name, tint: MoscoPalette.textSecondary)
                    }

                    if let scheduleLabel {
                        TagChip(label: scheduleLabel, tint: MoscoPalette.textSecondary)
                    }

                    // 메모가 있다는 것도 이 행의 성격 중 하나라, 다른 성격들과 같은
                    // 줄에서 같은 모양으로 말한다. 예전엔 오른쪽 끝 버튼의 아이콘
                    // 진하기로 유무를 알렸는데, 버튼의 일이 "수정"으로 바뀌면서
                    // 그 자리에 메모 여부를 실을 수 없게 됐다.
                    //
                    // 본문을 아래에 펼쳐 보여주는 화면에서는 이 태그를 뺀다 —
                    // 내용이 바로 아래 있는데 "메모 있음"이라고 또 말할 이유가 없다.
                    if hasMemo, !showsMemoPreview {
                        TagChip(label: "메모", tint: MoscoPalette.textSecondary)
                    }

                    // 디데이로 표시해둔 항목. 남은 날짜는 적지 않는다 — 옆의 날짜
                    // 태그와 같은 말을 두 번 하는 셈이고, 여기서 알고 싶은 건
                    // "이게 그 챙기는 일이구나"뿐이다. 남은 날짜를 세는 건
                    // '다가오는' 화면의 디데이 카드가 맡는다.
                    //
                    // 별이 아니라 깃발인 건, 별은 어느 앱에서나 "즐겨찾기/중요"라는
                    // 뜻으로 굳어 있어서다. 디데이는 중요도가 아니라 **날을 세는
                    // 표시**고, 깃발은 달력 위 한 지점을 찍는 말에 가깝다.
                    if todo.isDDay {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(MoscoPalette.textSecondary)
                    }

                    // 반복 일정은 한 번짜리와 겉모습이 같아서, 목록에서 이게
                    // "매주 오는 그 일정"인지 이번 한 번인지 구분이 안 됐다.
                    // 규칙까지 적어주면 태그 줄이 길어지니 반복 아이콘만 붙인다.
                    if todo.repeatRule != .none {
                        Image(systemName: "repeat")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(MoscoPalette.textSecondary)
                    }

                    Spacer(minLength: 0)
                }

                if showsMemoPreview, let memo = todo.memo, !memo.isEmpty {
                    memoPreview(memo)
                }
            }

            // 수정할 방법이 없는 화면(onTap이 없는 곳)에서는 자리도 만들지 않는다.
            if onTap != nil {
                editButton
            }
        }
        .padding(.vertical, 13)
        // 왼쪽은 막대가 자리를 채우므로 안쪽 여백을 줄인다.
        .padding(.leading, 9)
        .padding(.trailing, 14)
        .contentShape(Rectangle())
        // **셀 전체가 완료 버튼이다.** 목록에서 제일 자주 하는 일이라 제일 넓은
        // 히트 영역을 준다. 수정은 꾹 눌러 나오는 메뉴로 옮겼다 — 자주 하는
        // 조작일수록 겨누기 쉬워야 한다.
        .onTapGesture(perform: toggleCompletion)
        // 완료된 항목은 내용만 흐려진다. 배경보다 뒤에 놓아서 카드 자체는
        // 불투명하게 남는다 — 카드까지 반투명해지면 뒤가 비쳐 얼룩져 보인다.
        .opacity(isDone ? 0.55 : 1)
        // **여기엔 리퀴드 글래스를 쓰지 않는다.** 유리는 매 프레임 뒤 배경을
        // 다시 읽어 흐리는 작업이라, 화면에 N개가 깔리는 리스트 셀에 붙이면
        // 그 비용이 셀 수만큼 늘어난다(달력 막대에서 이미 같은 이유로 걷어냈다).
        // 유리는 화면 위에 떠 있는 소수의 요소에만 쓴다 — GlassSurface 주석의 원칙.
        //
        // 카드 배경은 **중립색 하나**다. 예전엔 여기에도 카테고리 색을 옅게
        // 깔았는데, 목록이 길어지면 카드마다 바탕색이 달라 화면 전체가 알록달록해
        // 눈이 피로했다. 색은 왼쪽 막대 하나에만 — 찾을 때 필요한 자리에만 찍는다.
        .background(MoscoPalette.surface, in: shape)
        .overlay(shape.strokeBorder(MoscoPalette.border.opacity(0.4), lineWidth: 0.5))
        .shadow(color: .black.opacity(isDone ? 0.02 : 0.06), radius: 12, y: 5)
        .scaleEffect(isDone ? 0.985 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isDone)
        // 몸통 탭이 완료로 가면서, 나머지 조작은 전부 이 메뉴가 맡는다. 평소엔
        // 안 보이니 행도 복잡해지지 않는다.
        .contextMenu {
            // 맨 위에 둔다 — 몸통 탭에서 밀려난 조작이라 제일 먼저 눈에 띄어야 한다.
            if onTap != nil {
                Button {
                    onTap?()
                } label: {
                    Label("수정", systemImage: "pencil")
                }
            }

            Button {
                showsMemoEditor = true
            } label: {
                Label(hasMemo ? "메모 보기" : "메모 추가", systemImage: "note.text")
            }

            Button {
                if !todo.isDDay { Analytics.log(.dDaySet) }
                todo.isDDay.toggle()
            } label: {
                Label(
                    todo.isDDay ? "디데이 해제" : "디데이로 표시",
                    systemImage: todo.isDDay ? "flag.slash" : "flag"
                )
            }

            // 같은 일이 이따금 되풀이될 때. 반복 규칙을 걸면 원본 하나가 모든
            // 날짜를 대표해서 한 날만 고치거나 지울 수 없는데, 이런 일은 각각
            // 따로 서 있어야 한다.
            Button {
                showsDuplicatePicker = true
            } label: {
                Label("다른 날로 복제…", systemImage: "calendar.badge.plus")
            }

            // 날짜를 아직 못 정했을 때. 복사해두고 달력을 넘겨 다니다가 원하는
            // 날에 붙여넣는다 — 시트 안의 달력으로는 다른 일정도 날씨도 못 본다.
            Button {
                clipboard.copy(todo)
            } label: {
                Label("복사", systemImage: "doc.on.doc")
            }

            // 만들 때 고른 캘린더를 나중에 바꿀 방법이 없었다 — 옮기려면 지우고
            // 다시 만드는 수밖에 없었다.
            if calendars.count > 1 {
                Menu {
                    ForEach(calendars) { calendar in
                        Button {
                            todo.calendar = calendar
                        } label: {
                            if todo.calendar?.id == calendar.id {
                                Label(calendar.name, systemImage: "checkmark")
                            } else {
                                Text(calendar.name)
                            }
                        }
                    }
                } label: {
                    Label("캘린더 옮기기", systemImage: "square.stack.3d.up")
                }
            }

            if onDelete != nil {
                Button(role: .destructive) {
                    if todo.repeatRule == .none {
                        onDelete?()
                    } else {
                        showsDeleteConfirmation = true
                    }
                } label: {
                    Label("삭제", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showsMemoEditor) {
            TodoDetailSheet(todo: todo)
        }
        .sheet(isPresented: $showsDuplicatePicker) {
            DuplicateDatePicker(todo: todo) { date in
                modelContext.insert(todo.duplicated(to: date))
                Analytics.log(.taskDuplicated(source: analyticsSource, method: "picker"))
            }
        }
        // 반복 일정은 하나를 지우면 모든 날짜의 인스턴스가 같이 사라지므로,
        // 확인 문구에서 그걸 먼저 알려준다. 한 번짜리는 확인 없이 바로 지운다.
        .confirmationDialog(
            "모든 반복을 삭제할까요?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { onDelete?() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 할 일은 반복돼요. 하루만 골라 삭제할 수는 없어요.")
        }
    }

    /// 할 일을 끝낸 직후는 앱이 사용자에게 뭔가를 해준 순간이라, 리뷰를 부탁하기
    /// 가장 좋은 자리다. 조건이 다 찼는지는 `ReviewPrompt`가 정한다.
    ///
    /// 바로 띄우지 않고 조금 기다리는 건 체크 애니메이션(스프링 0.35초) 위로
    /// 시스템 시트가 덮치지 않게 하려는 것이다 — 방금 누른 결과를 눈으로 확인한
    /// 다음에 물어야 부탁으로 읽힌다.
    private func askForReviewIfEarned() {
        guard ReviewPrompt.recordCompletionAndAsk() else { return }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            requestReview()
            Analytics.log(.reviewPromptRequested)
        }
    }

    private var hasMemo: Bool { todo.memo != nil }

    /// 셀 안에 펼쳐 보여주는 메모 본문. 누르면 메모 화면으로 간다.
    ///
    /// **셀 몸통 탭(완료)과 겹치지 않게 버튼으로 감싼다.** 그냥 텍스트로 두면
    /// 메모를 읽으려고 누른 손가락이 할 일을 완료시킨다 — 읽는 동작과 끝내는
    /// 동작은 되돌리는 비용이 다르다.
    ///
    /// 왼쪽 세로선은 "여기부터는 본문"이라는 표시다. 인용문에서 빌려온 모양이라
    /// 제목과 같은 무게로 읽히지 않는다.
    private func memoPreview(_ memo: String) -> some View {
        Button {
            showsMemoEditor = true
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Capsule()
                    .fill(MoscoPalette.textSecondary.opacity(0.25))
                    .frame(width: 2)

                Text(memo)
                    .font(.moscoCaption())
                    .foregroundStyle(MoscoPalette.textSecondary)
                    .multilineTextAlignment(.leading)
                    // 세 줄이면 무엇을 적었는지 알기 충분하고, 그보다 길어지면
                    // 메모 하나가 목록을 통째로 차지한다. 전문은 눌러서 본다.
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }

    /// 수정으로 바로 가는 지름길.
    ///
    /// 몸통 탭이 완료로 넘어가면서 수정은 꾹 눌러야만 닿는 곳이 됐는데, 꾹 누르기는
    /// 알고 있어야 쓸 수 있는 조작이다. 목록에 보이는 버튼 하나가 같은 곳으로
    /// 데려가면 처음 쓰는 사람도 길을 찾는다.
    ///
    /// 예전엔 이 자리가 메모 버튼이었다. 메모 유무는 아이콘 진하기로 알렸는데,
    /// 그건 두 상태를 나란히 놓고 봐야 알아채는 구분이었다 — 이제 태그 줄에서
    /// 이름으로 말한다.
    private var editButton: some View {
        Button {
            onTap?()
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MoscoPalette.textSecondary)
                .frame(width: 28, height: 28)
                .background(MoscoPalette.textSecondary.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }

    /// 셀 왼쪽 끝의 카테고리 색 막대 — 달력 격자의 일정 블록과 같은 표기다.
    /// 목록을 훑을 때 색이 세로 한 줄로 정렬돼 읽히고, 달력에서 보던 색이 목록에서도
    /// 같은 자리에 있어 두 화면이 한 앱처럼 이어진다.
    ///
    /// **한 행에서 카테고리 색이 쓰이는 자리는 이 막대 하나뿐이다.** 예전엔 체크
    /// 동그라미가 그 자리였는데, 색을 두 군데 쓰면 어느 쪽이 무슨 뜻인지 알 수 없게
    /// 된다 — 자리가 옮겨간 것이지 늘어난 게 아니다.
    private var categoryBar: some View {
        Capsule()
            .fill(accentColor)
            .frame(width: 4)
            // 셀 높이에서 위아래로 조금 물러난다 — 끝까지 채우면 카드 모서리의
            // 둥근 곡선과 부딪혀 막대 끝이 잘려 보인다.
            .padding(.vertical, 2)
    }

    /// 완료 표시. **버튼이 아니라 표시 전용이다** — 누르는 건 셀 전체가 받는다.
    /// 예전엔 이게 26pt 버튼이라 매번 정확히 겨눠야 했다.
    ///
    /// 색은 중립색이다. 카테고리 색은 왼쪽 막대가 맡고, 여기서 알고 싶은 건
    /// "끝냈는가" 하나뿐이다.
    ///
    /// 원이 아니라 둥근 사각형인 건 셀·카드·태그가 전부 둥근 사각형/캡슐이기
    /// 때문이다. 한 행에서 혼자만 정원이면 다른 데서 가져다 놓은 것처럼 보인다.
    private var checkMark: some View {
        let box = RoundedRectangle(cornerRadius: 8, style: .continuous)

        return ZStack {
            box.fill(isDone ? MoscoPalette.textSecondary : Color.clear)
            box.strokeBorder(MoscoPalette.textSecondary.opacity(isDone ? 0 : 0.45), lineWidth: 1.75)
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MoscoPalette.surface)
                .opacity(isDone ? 1 : 0)
                .scaleEffect(isDone ? 1 : 0.4)
        }
        .frame(width: 26, height: 26)
    }

    /// 셀을 눌렀을 때. 반복 일정이면 보고 있는 날짜의 인스턴스만 뒤집는다.
    private func toggleCompletion() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            if let occurrenceDate {
                todo.setCompleted(!isDone, on: occurrenceDate)
            } else {
                todo.isCompleted.toggle()
            }
        }
        // isDone은 방금 뒤집기 **전** 값이라, 새 상태는 그 반대다.
        let nowCompleted = !isDone
        Analytics.log(
            .taskCompleted(
                source: "app",
                completed: nowCompleted,
                isRepeating: todo.repeatRule != .none
            )
        )
        if nowCompleted { askForReviewIfEarned() }
    }

    /// 날짜/시간 관련 정보를 태그 하나로 합치는 정책:
    /// - 여러 날에 걸치면(멀티데이) 기간을 우선 보여주고, 시작 시간이 있으면 덧붙인다.
    /// - 하루짜리는, 날짜 컨텍스트가 필요한 화면(showsDate)에서는 상대 날짜(+시간)를,
    ///   이미 하루 안에 있는 화면에서는 시간만(있을 때만) 보여준다 — 날짜 중복 표기 방지.
    private var scheduleLabel: String? {
        guard let date = todo.date else {
            // 날짜 없는 백로그 항목 — 시간만 있는 건 의미가 없으니 태그 자체를 생략.
            return nil
        }

        if todo.isMultiDay, let effectiveEnd = todo.effectiveEndDate {
            let range = "\(date.koreanMonthDay) - \(effectiveEnd.koreanMonthDay)"
            guard let startTime = todo.startTime else { return range }
            return "\(range) \(startTime.koreanTime)"
        }

        if showsDate {
            let dayPart = date.koreanRelativeDay
            guard let startTime = todo.startTime else { return dayPart }
            if let endTime = todo.endTime {
                return "\(dayPart) \(startTime.koreanTime) - \(endTime.koreanTime)"
            }
            return "\(dayPart) \(startTime.koreanTime)"
        }

        guard let startTime = todo.startTime else { return nil }
        if let endTime = todo.endTime {
            return "\(startTime.koreanTime) - \(endTime.koreanTime)"
        }
        return startTime.koreanTime
    }
}
