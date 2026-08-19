import SwiftUI

/// 할 일 하나를 그릴 때 쓰는 **공용 조각들**.
///
/// 목록 셀과 시간표 블록이 같은 것을 쓴다. 예전엔 시간표 블록이 자기만의 모양을
/// 갖고 있었는데 — 카테고리 색을 배경에 옅게 깔고 왼쪽에 띠를 세웠다 — 목록은
/// 중립색 카드에 색을 체크 한 곳에만 쓰는 규칙이라 **두 화면이 서로 다른 앱에서
/// 온 것처럼 보였다.**
///
/// 색 규칙은 `DesignSystem/README.md`의 "색은 한 행에 한 번"이다.

/// 왼쪽 카테고리 막대.
struct TodoCategoryBar: View {
    let color: Color

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: 4)
            // 끝까지 채우면 카드 모서리의 둥근 곡선과 부딪혀 막대 끝이 잘려 보인다.
            .padding(.vertical, 2)
    }
}

/// 완료 체크 상자.
struct TodoCheckMark: View {
    let isDone: Bool
    /// 시간표의 짧은 블록에서는 26pt가 높이를 다 먹는다.
    var size: CGFloat = 26

    var body: some View {
        let box = RoundedRectangle(cornerRadius: size / 3.25, style: .continuous)

        return ZStack {
            box.fill(isDone ? MoscoPalette.textSecondary : Color.clear)
            box.strokeBorder(MoscoPalette.textSecondary.opacity(isDone ? 0 : 0.45), lineWidth: 1.75)
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.46, weight: .bold))
                .foregroundStyle(MoscoPalette.surface)
                .opacity(isDone ? 1 : 0)
                .scaleEffect(isDone ? 1 : 0.4)
        }
        .frame(width: size, height: size)
    }
}

/// 완료를 뒤집는다 — **목록과 시간표가 같은 함수를 쓴다.**
///
/// 뒤집기만 하는 게 아니라 분석 이벤트·튜토리얼 진행·리뷰 부탁까지 딸려 있어서,
/// 화면마다 따로 쓰면 한쪽만 기록되거나 한쪽에서만 튜토리얼이 안 넘어간다.
enum TodoCompletion {
    @MainActor
    static func toggle(
        _ todo: TodoItem,
        occurrenceDate: Date?,
        tutorial: TutorialCoordinator?,
        reviewPrompt: ReviewPrompt
    ) {
        // **뒤집기 전에 값을 떠둔다.** `isCompleted`는 계산 결과라 뒤집은 뒤에
        // 읽으면 이미 새 값이다 — 예전엔 그래서 완료가 `completed=false`로
        // 기록되고, 리뷰 부탁이 완료를 **푸는** 순간에 세어졌다.
        let wasDone: Bool
        if let occurrenceDate {
            wasDone = todo.isCompleted(on: occurrenceDate)
        } else {
            wasDone = todo.isCompleted
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            if let occurrenceDate {
                todo.setCompleted(!wasDone, on: occurrenceDate)
            } else {
                todo.isCompleted.toggle()
            }
        }

        let nowCompleted = !wasDone
        Analytics.log(
            .todoCompleted(
                source: "app",
                completed: nowCompleted,
                isRepeating: todo.repeatRule != .none
            )
        )
        tutorial?.didToggleCompletion(id: todo.id, completed: nowCompleted)
        // 할 일을 끝낸 직후는 앱이 사용자에게 뭔가를 해준 순간이라, 리뷰를
        // 부탁하기 좋은 자리다. 조건이 다 찼는지는 `ReviewPrompt`가 정한다.
        if nowCompleted { reviewPrompt.recordCompletion() }
    }
}
