import SwiftUI
import SwiftData

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
    /// 메모 본문을 셀 안에 얼마나 보여줄지. **메모는 어느 화면에서든 항상 보인다** —
    /// 열어봐야 아는 딸린 정보로 두면 적어둔 보람이 없다. 화면마다 다른 건 길이뿐이다.
    var memoDisplay: MemoDisplay = .compact

    /// 잠금화면에 띄우지 못한 이유. 경우마다 사용자에게 할 말이 달라서
    /// 성공/실패 한 가지가 아니라 경우를 그대로 든다.

    enum MemoDisplay {
        /// 세 줄까지만. 목록을 훑는 화면에서는 메모 하나가 화면을 다 차지하면 안 된다.
        case compact
        /// 전문. 할 일 목록은 "지금 무엇을 해야 하나"에 답하는 화면이라, 적어둔 게
        /// 있으면 그것까지가 할 일이다.
        case full

        var lineLimit: Int? {
            switch self {
            case .compact: 3
            case .full: nil
            }
        }
    }

    /// 완료를 여기에 알리기만 한다. 실제 리뷰 요청은 `RootTabView`가 낸다 —
    /// 이 셀은 완료 직후 목록에서 걸러져 사라질 수 있는 뷰라, 잠시 뒤에 시트를
    /// 띄우는 일을 맡기기에 적당하지 않다.
    @Environment(ReviewPrompt.self) private var reviewPrompt

    /// 튜토리얼이 없는 자리에서도 안전하도록 옵셔널로 받는다.
    @Environment(TutorialCoordinator.self) private var tutorial: TutorialCoordinator?
    /// 셀 안의 메모를 눌러 여는 화면. 메뉴에서 여는 것(`TodoActions`)과는 다른
    /// 입구라 각자 자기 상태를 갖는다.
    @State private var showsMemoEditor = false

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
                //
                // 한 줄에 다 못 들어가면 다음 줄로 넘어간다. 예전엔 HStack이라
                // 칩이 서넛만 붙어도 뒤쪽이 잘려 나갔는데, 잘린 게 캘린더인지
                // 시간인지는 열어봐야 알 수 있었다 — 보여줄 거면 다 보여준다.
                WrappingHStack(spacing: 6, lineSpacing: 6) {
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
                }
                // Layout 안에 Spacer를 넣으면 폭을 무한히 요구하는 칩이 하나 낀
                // 셈이라 줄바꿈 계산이 통째로 깨진다 — 왼쪽 정렬은 프레임으로 준다.
                .frame(maxWidth: .infinity, alignment: .leading)

                if let memo = todo.memo, !memo.isEmpty {
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
        // 꾹 눌러 나오는 메뉴와 그 뒤에 열리는 것들. 시간표 블록도 같은 것을 쓴다 —
        // 같은 동작이 화면마다 다르면 다른 기능처럼 읽힌다.
        .sheet(isPresented: $showsMemoEditor) {
            TodoDetailSheet(todo: todo)
        }
        .modifier(TodoActions(
            todo: todo,
            occurrenceDate: occurrenceDate,
            onTap: onTap,
            onDelete: onDelete
        ))
        // 몸통 탭이 완료로 가면서, 나머지 조작은 전부 이 메뉴가 맡는다. 평소엔
        // 안 보이니 행도 복잡해지지 않는다.
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
                    .lineLimit(memoDisplay.lineLimit)
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
        TodoCategoryBar(color: accentColor)
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
        TodoCheckMark(isDone: isDone)
    }

    // MARK: - 잠금화면에 띄우기

    /// 이 할 일이 지금 잠금화면에 떠 있는가.
    ///
    /// 관찰되는 값이라 띄우거나 내리는 즉시 메뉴 문구가 따라온다 — 컨텍스트 메뉴는
    /// 셀 body와 함께 만들어져서, 관찰되지 않는 값을 읽으면 문구가 고정돼 버린다.

    /// 셀을 눌렀을 때. 반복 일정이면 보고 있는 날짜의 인스턴스만 뒤집는다.
    /// 완료를 뒤집는다. 알맹이는 `TodoCompletion`에 있다 — 시간표 블록도 같은
    /// 함수를 쓴다. 화면마다 따로 쓰면 한쪽만 기록되거나 튜토리얼이 안 넘어간다.
    private func toggleCompletion() {
        TodoCompletion.toggle(
            todo,
            occurrenceDate: occurrenceDate,
            tutorial: tutorial,
            reviewPrompt: reviewPrompt
        )
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
