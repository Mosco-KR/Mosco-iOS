import SwiftUI
import SwiftData

/// 할 일에 붙는 메모를 쓰는 화면. 어떤 할 일의 메모인지 알 수 있게 제목·카테고리·
/// 일정 요약을 위에 두고, 나머지 세로를 전부 입력 영역에 준다.
///
/// 삭제는 여기 두지 않는다 — 화면 이름이 "메모"인데 삭제 버튼이 있으면 메모를
/// 지우는 건지 할 일을 지우는 건지 헷갈리고, 지우려고 굳이 이 화면까지 들어오는
/// 것도 번거롭다. 삭제는 목록 셀의 버튼이 맡는다.
///
/// 입력 중인 값을 곧바로 모델에 쓰지 않고 로컬 @State에 담았다가 "완료"에서 한 번에
/// 반영한다. 그래야 "취소"가 실제로 되돌리기로 동작한다(@Bindable로 바로 묶으면
/// 타이핑하는 족족 저장돼서 취소할 게 남지 않는다).
struct TodoDetailSheet: View {
    let todo: TodoItem

    @Environment(\.dismiss) private var dismiss
    @State private var memo: String

    init(todo: TodoItem) {
        self.todo = todo
        _memo = State(initialValue: todo.memo ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Metrics.spacingMD) {
                summary

                // 메모가 이 화면의 주인공이라 남은 세로를 전부 준다. 예전엔 Form 안의
                // lineLimit(4...10) 필드라 화면 대부분이 빈 채로 남았다.
                ZStack(alignment: .topLeading) {
                    if memo.isEmpty {
                        Text("메모를 입력하세요")
                            .font(.moscoBody())
                            .foregroundStyle(MoscoPalette.textSecondary.opacity(0.6))
                            // TextEditor의 기본 내부 여백과 맞춰서 글자가 겹쳐 보이지 않게.
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $memo)
                        .font(.moscoBody())
                        .scrollContentBackground(.hidden)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Metrics.spacingSM)
                .background(MoscoPalette.canvas)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                // 입력 영역이 어디까지인지가 이 화면의 유일한 구조 신호라, 테두리가
                // 안 보이면 화면이 통째로 빈 종이처럼 보인다 — separator 원래
                // 알파 그대로 1pt로 그린다(예전엔 여기에 0.4를 또 곱했다).
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(MoscoPalette.border, lineWidth: 1)
                )
            }
            .padding(Metrics.spacingMD)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(MoscoPalette.canvas.opacity(0.5))
            .navigationTitle("메모")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        save()
                        dismiss()
                    }
                }
            }
        }
    }

    /// 어떤 할 일의 메모를 쓰고 있는지 잊지 않도록 제목과 일정을 위에 둔다.
    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(todo.title)
                .font(.moscoTitle())
                .foregroundStyle(MoscoPalette.textPrimary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                CategoryTag(category: todo.category)

                if let scheduleLabel {
                    TagChip(label: scheduleLabel, tint: MoscoPalette.textSecondary)
                }

                Spacer(minLength: 0)
            }
        }
    }

    /// 날짜/시간을 한 줄로 — TodoRow의 정책과 같은 결로 맞춘다.
    private var scheduleLabel: String? {
        guard let date = todo.date else { return nil }

        if todo.isMultiDay, let effectiveEnd = todo.effectiveEndDate {
            let range = "\(date.koreanMonthDay) - \(effectiveEnd.koreanMonthDay)"
            guard let startTime = todo.startTime else { return range }
            return "\(range) \(startTime.koreanTime)"
        }

        guard let startTime = todo.startTime else { return date.koreanMonthDay }
        if let endTime = todo.endTime {
            return "\(date.koreanMonthDay) \(startTime.koreanTime) - \(endTime.koreanTime)"
        }
        return "\(date.koreanMonthDay) \(startTime.koreanTime)"
    }

    private func save() {
        let trimmed = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        // 빈 문자열 대신 nil로 되돌려야 "메모 없음"이 한 가지 상태로만 표현된다 —
        // 셀의 메모 표시도 이 값 하나로 판단한다.
        todo.memo = trimmed.isEmpty ? nil : trimmed
    }
}
