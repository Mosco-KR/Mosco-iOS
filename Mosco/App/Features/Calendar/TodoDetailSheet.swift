import SwiftUI
import SwiftData

/// 할 일 셀의 + 버튼으로 여는, "제목·일정 말고 더 붙이고 싶은 것들"을 모아두는 시트.
/// 지금은 메모 하나뿐이지만 알림·첨부처럼 늘어날 자리라, 처음부터 항목별 섹션으로
/// 나눠둔다 — 나중에 섹션 하나만 더 얹으면 되게.
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
            Form {
                Section {
                    // 자동 포커스는 일부러 안 건다 — 메모를 "읽으러" 여는 경우가
                    // 더 많은데 키보드가 바로 올라오면 화면 절반을 가린다.
                    TextField("메모를 입력하세요", text: $memo, axis: .vertical)
                        .lineLimit(4...10)
                } header: {
                    Text("메모")
                } footer: {
                    Text("이 할 일에 대해 기억해둘 내용을 자유롭게 적어두세요.")
                }
            }
            .navigationTitle(todo.title)
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

    private func save() {
        let trimmed = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        // 빈 문자열 대신 nil로 되돌려야 "메모 없음"이 한 가지 상태로만 표현된다 —
        // 셀의 메모 뱃지도 이 값 하나로 판단한다.
        todo.memo = trimmed.isEmpty ? nil : trimmed
    }
}
