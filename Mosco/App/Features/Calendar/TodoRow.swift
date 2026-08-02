import SwiftUI

struct TodoRow: View {
    @Bindable var todo: TodoItem
    /// 하루치 리스트(DayTodosContentView)에서는 날짜가 이미 컨텍스트로 있으니 끄고,
    /// 여러 날짜를 한 화면에 섞어 보여줄 때(우선순위별 탭)만 켠다. 우선순위 라벨도
    /// 이 화면에서는 "Should Have"처럼 원어 그대로 풀로 쓴다.
    var showsDate: Bool = false
    /// 어느 날짜의 인스턴스로 보고 있는지(하루치 리스트에서 전달). 반복 일정이면
    /// 완료 체크가 이 날짜의 인스턴스에만 적용된다 — 다른 날의 반복은 그대로.
    var occurrenceDate: Date? = nil
    /// 셀 몸통을 누르면 수정할 수 있게 채팅형 입력창을 다시 띄우는 콜백.
    /// (체크박스는 별도 버튼이라 이 탭과 겹치지 않는다)
    var onTap: (() -> Void)? = nil
    /// 이 할 일을 지운다. nil이면 삭제 메뉴를 감춘다.
    var onDelete: (() -> Void)? = nil
    /// 여러 캘린더를 함께 보고 있을 때만 소속 캘린더 칩을 붙인다 — 하나만 보고
    /// 있으면 전부 같은 캘린더라 칩이 자리만 차지한다.
    var showsCalendarTag: Bool = false

    @State private var showsMemoEditor = false
    @State private var showsDeleteConfirmation = false

    private var isDone: Bool {
        if let occurrenceDate { return todo.isCompleted(on: occurrenceDate) }
        return todo.isCompleted
    }

    private var accentColor: Color {
        todo.category?.color ?? MoscoPalette.textSecondary
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        HStack(alignment: .center, spacing: 12) {
            checkButton

            // 1행: 제목 그대로, 2행: 카테고리(항상 맨 앞) + 날짜/시간을 하나로 합친 태그.
            VStack(alignment: .leading, spacing: 6) {
                Text(todo.title)
                    .font(.moscoBody().weight(.semibold))
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? MoscoPalette.textSecondary : MoscoPalette.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    CategoryTag(category: todo.category)

                    if showsCalendarTag, let calendar = todo.calendar {
                        TagChip(
                            label: calendar.name,
                            tint: CategoryColorPalette.color(forHex: calendar.colorHex)
                        )
                    }

                    if let scheduleLabel {
                        TagChip(label: scheduleLabel, tint: MoscoPalette.textSecondary)
                    }

                    // 반복 일정은 한 번짜리와 겉모습이 같아서, 목록에서 이게
                    // "매주 오는 그 일정"인지 이번 한 번인지 구분이 안 됐다.
                    // 규칙까지 적어주면 태그 줄이 길어지니 반복 아이콘만 붙인다.
                    if todo.repeatRule != .none {
                        Image(systemName: "repeat")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }

                    Spacer(minLength: 0)
                }
            }

            detailButton
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        // 카테고리 색은 체크박스 자체가 이미 나타내니, 카드 배경은 아주 옅은
        // 톤만 얹어서 유리 위에 은은하게 비치는 정도로만 — 색이 "칠해진"
        // 느낌이 아니라 "비치는" 느낌이 되게 한다.
        .background(accentColor.opacity(isDone ? 0.02 : 0.06))
        .moscoGlass(in: shape)
        .overlay(shape.strokeBorder(MoscoPalette.border.opacity(0.4), lineWidth: 0.5))
        .clipShape(shape)
        // 완료된 항목은 카드 전체를 눌러서 확실히 구분되게 — 다만 이미 반투명한
        // 글래스 위에 opacity를 또 낮추면(이중 투명) 얼룩진 것처럼 보여서, 대신
        // 불투명한 스크림을 얹어 톤만 죽인다. allowsHitTesting(false)가 없으면
        // 이 스크림(반투명해도 실제 뷰라 터치를 가로챈다)이 체크박스를 덮어서,
        // 완료 후엔 다시 눌러도 해제가 안 되는 버그가 있었다.
        .overlay(
            shape
                .fill(MoscoPalette.canvas.opacity(isDone ? 0.5 : 0))
                .allowsHitTesting(false)
        )
        .shadow(color: .black.opacity(isDone ? 0.02 : 0.06), radius: 12, y: 5)
        .scaleEffect(isDone ? 0.985 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isDone)
        // 목록에서 바로 지우고 싶을 때를 위한 지름길. 길게 누르기라 좌우 스와이프
        // (날짜 넘기기)와 안 겹친다. 평소엔 안 보이니 행도 복잡해지지 않는다.
        .contextMenu {
            Button {
                showsMemoEditor = true
            } label: {
                Label(hasMemo ? "메모 보기" : "메모 추가", systemImage: "note.text")
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
        // 반복 일정은 하나를 지우면 모든 날짜의 인스턴스가 같이 사라지므로,
        // 확인 문구에서 그걸 먼저 알려준다. 한 번짜리는 확인 없이 바로 지운다.
        .confirmationDialog(
            "반복 일정 전체를 삭제할까요?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { onDelete?() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 일정은 반복 일정이라 모든 날짜에서 함께 삭제돼요.")
        }
    }

    private var hasMemo: Bool { todo.memo != nil }

    /// 누르면 곧바로 상세 화면(메모)을 연다. 예전엔 메뉴를 띄웠는데, 메모 아이콘을
    /// 눌렀더니 메뉴가 나오는 게 아이콘이 약속한 것과 달라 어색했다. 삭제는 상세
    /// 화면 안과 행 길게 누르기로 옮겼다 — 길게 누르기는 좌우 스와이프와 달리
    /// 날짜 넘기기 제스처와 충돌하지 않는다.
    ///
    /// 메모가 있으면 아이콘이 카테고리 색으로 또렷해져서, 열어보지 않아도 메모
    /// 유무가 구분된다.
    private var detailButton: some View {
        Button {
            showsMemoEditor = true
        } label: {
            Image(systemName: hasMemo ? "note.text" : "square.and.pencil")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(hasMemo ? accentColor : MoscoPalette.textSecondary)
                .frame(width: 28, height: 28)
                .background(
                    (hasMemo ? accentColor : MoscoPalette.textSecondary).opacity(hasMemo ? 0.16 : 0.07),
                    in: Circle()
                )
                .opacity(hasMemo ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .animation(.easeOut(duration: 0.2), value: hasMemo)
    }

    /// 체크박스가 완료 컨트롤이면서 동시에 카테고리 색 표시도 겸한다 —
    /// 미완료일 땐 카테고리 색 테두리만 있는 빈 원(그 카테고리라는 걸 미리 보여줌),
    /// 완료하면 그 색으로 꽉 채워지고 흰 체크가 팝 인 되는 스프링 애니메이션.
    private var checkButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                if let occurrenceDate {
                    todo.setCompleted(!isDone, on: occurrenceDate)
                } else {
                    todo.isCompleted.toggle()
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isDone ? accentColor : Color.clear)
                Circle()
                    .strokeBorder(accentColor, lineWidth: isDone ? 0 : 1.75)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(isDone ? 1 : 0)
                    .scaleEffect(isDone ? 1 : 0.4)
            }
            .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
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
