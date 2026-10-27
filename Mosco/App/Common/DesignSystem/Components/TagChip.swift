import SwiftUI

/// 짧은 메타데이터를 다는 칩.
///
/// ## 두 가지 모양이 있다
///
/// **누를 수 있으면 채우고, 읽기만 하면 글자만 둔다.** 입력창의 날짜 칩이나 달력
/// 머리의 필터처럼 누르는 것은 캡슐로 채워야 단추로 보인다. 반대로 목록 행의
/// 카테고리·시각은 읽기만 하는 것인데, 거기까지 캡슐을 채웠더니 한 행에 알약이
/// 서넛씩 떠서 **무엇을 눌러야 하는지가 흐려지고 화면이 소란스러웠다.**
///
/// ## 한 줄을 넘지 않는다
///
/// 칩 안에서 글자가 줄바꿈되면 "오늘 오전 10시"가 두 줄이 되면서 행 높이가
/// 들쭉날쭉해진다. 좁으면 줄이는 게 아니라 **그대로 한 줄로 두고**, 자리가 모자라면
/// 바깥(`WrappingHStack`)이 다음 줄로 넘긴다.
struct TagChip: View {
    let label: String
    let tint: Color
    /// 누르는 칩인가. 기본은 채운 캡슐(단추로 보여야 하는 자리).
    var filled: Bool = true

    var body: some View {
        Text(label)
            .font(.moscoCaption())
            .foregroundStyle(tint)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, filled ? 12 : 0)
            .padding(.vertical, filled ? 6 : 0)
            .background {
                if filled { Capsule().fill(tint.opacity(0.12)) }
            }
    }
}
