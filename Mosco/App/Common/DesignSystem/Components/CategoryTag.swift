import SwiftUI

/// nil이면 아직 분류되지 않은 할 일 — 중립 회색으로 "미분류"를 보여준다.
struct CategoryTag: View {
    let category: TodoCategory?
    /// 색 점을 붙일지. 같은 행에서 카테고리 색을 이미 다른 자리가 말하고 있으면
    /// 끈다(할 일 셀은 왼쪽 막대가 그 역할을 한다) — 색이 두 군데면 어느 쪽이
    /// 무슨 뜻인지 알 수 없게 된다. 점이 없어도 이름은 그대로 남는다.
    var showsColorDot: Bool = true

    private var color: Color {
        category?.color ?? MoscoPalette.textSecondary
    }

    private var label: String {
        category?.name ?? "미분류"
    }

    var body: some View {
        // 색은 **점 하나에만** 남긴다. 예전엔 글자와 배경까지 카테고리 색이라
        // 칩 하나가 통째로 색 덩어리였고, 목록에 여러 개가 놓이면 어느 것을
        // 봐야 할지 알 수 없었다. 이름은 글자가 말하고, 색은 5pt짜리 점이 말한다.
        // 이 점 덕분에 체크 동그라미가 없는 곳(메모 화면 등)에서도 소속이 보인다.
        HStack(spacing: 5) {
            if showsColorDot {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            }
            Text(label)
                .font(.moscoCaption())
        }
        .foregroundStyle(MoscoPalette.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        // TagChip과 같은 알파를 쓴다 — 한 줄에 나란히 서는 칩끼리 배경 농도가
        // 다르면 같은 종류로 안 읽힌다.
        .background(MoscoPalette.textSecondary.opacity(0.12), in: Capsule())
    }
}
