import SwiftUI

/// 화면 헤더 오른쪽에 서는 작은 유리 캡슐 버튼 — '오늘', '검색', '편집'이 전부
/// 이 모양이다.
///
/// **같은 자리에서 같은 일을 하는 버튼은 화면이 달라도 같게 생겨야 한다.** 예전엔
/// 할 일 화면의 편집 버튼만 유리 캡슐이고 캘린더 상세의 것은 툴바 맨 글자였다 —
/// 두 화면을 오가면 같은 버튼이 매번 다른 모습으로 나타나서, 두 화면이 서로 다른
/// 앱에서 온 것처럼 보였다.
struct HeaderGlassButton: View {
    /// nil이면 **아이콘만** 선다. 헤더에 버튼이 둘 이상 서는 화면에서는 글자를
    /// 빼는 편이 조용하다 — '검색' '편집' '시간표'가 나란히 서면 헤더가 문장처럼
    /// 읽히면서 정작 화면 제목보다 시끄러워진다.
    ///
    /// **글자를 빼면 `accessibilityLabel`이 대신 말한다.** 아이콘만 남기고 이름을
    /// 안 주면 보이스오버에서는 그냥 '버튼'이 된다.
    var title: String? = nil
    var systemImage: String? = nil
    /// 아이콘만 설 때 보이스오버가 읽을 이름. 글자가 있으면 그것을 쓴다.
    var accessibilityName: String? = nil
    /// 툴바 안에서는 끈다. iOS 26의 툴바는 항목마다 유리 배경을 알아서 깔아주는데,
    /// 여기서 또 깔면 테두리가 두 겹으로 겹쳐 같은 버튼이 화면마다 다르게 보인다.
    /// 대신 안쪽 여백을 시스템 배경이 감쌀 만큼으로 맞춰서 크기를 비슷하게 만든다.
    var drawsBackground: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        // 아이콘만 설 때는 조금 키운다 — 글자 옆에 붙는 크기 그대로면
                        // 혼자 남았을 때 눌러야 할 것으로 안 보인다.
                        .font(.system(size: title == nil ? 15 : 11, weight: .semibold))
                }
                if let title {
                    Text(title)
                        .font(.moscoCaption().weight(.semibold))
                }
            }
            .foregroundStyle(MoscoPalette.accent)
            .lineLimit(1)
            // 글자가 '편집'↔'완료'로 바뀔 때 폭이 흐르지 않게 고정 크기로 재고,
            // 좌우 여백은 캡슐이 갖는다.
            .fixedSize()
            // 아이콘만이면 좌우를 좁혀 정사각에 가깝게 — 안 그러면 캡슐이 옆으로
            // 길쭉해서 글자가 빠진 자리가 빈 것처럼 보인다.
            .padding(.horizontal, drawsBackground ? (title == nil ? 9 : 12) : 4)
            .frame(height: drawsBackground ? 34 : 26)
        }
        .buttonStyle(.plain)
        .modifier(OptionalGlass(isActive: drawsBackground))
        // 글자가 없으면 이름을 대신 준다. 있으면 SwiftUI가 글자를 읽는다.
        .accessibilityLabel(accessibilityName ?? title ?? "")
    }

    /// 배경을 안 그릴 때는 `moscoGlass`를 아예 안 붙인다 — 붙여두고 감추면
    /// 툴바가 그 자리를 배경 있는 항목으로 잡아 여백이 어긋난다.
    private struct OptionalGlass: ViewModifier {
        let isActive: Bool

        func body(content: Content) -> some View {
            if isActive {
                content
                    .moscoGlass(in: Capsule())
                    // 유리가 한 프레임 네모로 그려지더라도 여기서 잘려 나간다.
                    .clipShape(Capsule())
            } else {
                content
            }
        }
    }
}
