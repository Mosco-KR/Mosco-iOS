import SwiftUI

/// "이 할 일을 어느 날로 한 번 더?"에만 답하는 시트.
///
/// 기본값을 원본 다음 날로 두는 건, 복제하려는 대부분이 "또 해야 하는 일"이라
/// 앞이 아니라 뒤에 있기 때문이다. 날짜가 없는 백로그 항목은 기준이 없으니 오늘부터.
struct DuplicateDatePicker: View {
    let todo: TodoItem
    let onConfirm: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date

    init(todo: TodoItem, onConfirm: @escaping (Date) -> Void) {
        self.todo = todo
        self.onConfirm = onConfirm
        let calendar = Calendar.current
        let base = todo.date ?? Date()
        _date = State(
            initialValue: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: base))
                ?? base
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(.horizontal, Metrics.spacingSM)

                Spacer(minLength: 0)
            }
            .background(MoscoPalette.canvas.ignoresSafeArea())
            // 무엇이 복제되는지 제목으로 말한다 — 시트 안에 할 일을 또 그리면
            // 방금 꾹 눌렀던 그 셀을 두 번 보여주는 셈이다.
            .navigationTitle(todo.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("복제") {
                        onConfirm(date)
                        dismiss()
                    }
                }
            }
        }
        // 달력만 있으면 되는 시트라 화면을 다 덮을 이유가 없다.
        .presentationDetents([.medium, .large])
    }
}
