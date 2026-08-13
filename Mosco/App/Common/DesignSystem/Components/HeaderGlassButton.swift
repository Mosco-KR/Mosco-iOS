import SwiftUI

/// 화면 헤더 오른쪽에 서는 작은 유리 캡슐 버튼 — '오늘', '검색', '편집'이 전부
/// 이 모양이다.
///
/// **같은 자리에서 같은 일을 하는 버튼은 화면이 달라도 같게 생겨야 한다.** 예전엔
/// 할 일 화면의 편집 버튼만 유리 캡슐이고 캘린더 상세의 것은 툴바 맨 글자였다 —
/// 두 화면을 오가면 같은 버튼이 매번 다른 모습으로 나타나서, 두 화면이 서로 다른
/// 앱에서 온 것처럼 보였다.
struct HeaderGlassButton: View {
    let title: String
    var systemImage: String? = nil
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
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.moscoCaption().weight(.semibold))
            }
            .foregroundStyle(MoscoPalette.accent)
            .lineLimit(1)
            // 글자가 '편집'↔'완료'로 바뀔 때 폭이 흐르지 않게 고정 크기로 재고,
            // 좌우 여백은 캡슐이 갖는다.
            .fixedSize()
            .padding(.horizontal, drawsBackground ? 12 : 4)
            .frame(height: drawsBackground ? 34 : 26)
        }
        .buttonStyle(.plain)
        .modifier(OptionalGlass(isActive: drawsBackground))
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
