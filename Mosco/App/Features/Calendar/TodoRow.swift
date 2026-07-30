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

    private var isDone: Bool {
        if let occurrenceDate { return todo.isCompleted(on: occurrenceDate) }
        return todo.isCompleted
    }

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.spacingSM) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    if let occurrenceDate {
                        todo.setCompleted(!isDone, on: occurrenceDate)
                    } else {
                        todo.isCompleted.toggle()
                    }
                }
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isDone ? MoscoPalette.accent : MoscoPalette.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 1)

            // 1행: 제목 그대로, 2행: 우선순위(항상 맨 앞) + 날짜/시간을 하나로 합친 태그.
            VStack(alignment: .leading, spacing: 6) {
                Text(todo.title)
                    .font(.moscoBody())
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? MoscoPalette.textSecondary : MoscoPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    PriorityTag(priority: todo.priority)

                    if let scheduleLabel {
                        TagChip(label: scheduleLabel, tint: MoscoPalette.textSecondary)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(Metrics.spacingSM)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .moscoGlass(in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        // 완료된 항목은 카드 전체를 눌러서 확실히 구분되게 — 다만 이미 반투명한
        // 글래스 위에 opacity를 또 낮추면(이중 투명) 얼룩진 것처럼 보여서, 대신
        // 불투명한 스크림을 얹어 톤만 죽인다. allowsHitTesting(false)가 없으면
        // 이 스크림(반투명해도 실제 뷰라 터치를 가로챈다)이 체크박스를 덮어서,
        // 완료 후엔 다시 눌러도 해제가 안 되는 버그가 있었다.
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .fill(MoscoPalette.canvas.opacity(isDone ? 0.55 : 0))
                .allowsHitTesting(false)
        )
        .animation(.easeOut(duration: 0.15), value: isDone)
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
