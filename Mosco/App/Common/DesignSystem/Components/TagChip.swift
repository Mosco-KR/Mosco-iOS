import SwiftUI

/// 짧은 메타데이터를 다는 칩.
///
/// ## 두 가지 모양이 있다
///
/// **기본은 채운 캡슐이다.** 한때 "누르는 것만 채우고 읽기만 하는 것은 글자만 둔다"로
/// 갈랐는데, 목록 행에서 배경을 걷어내자 태그끼리 경계가 없어져 **한 문장으로 붙어
/// 읽혔다** — '일' 카테고리가 날짜 앞에 서니 `일 11월 8일`이 요일처럼 보였다.
/// 소란스러웠던 원인은 캡슐이 아니라 **색**이었고, 그건 톤을 중립 하나로 묶어서
/// 해결했다. `filled: false`는 아직 남아 있지만 지금 쓰는 자리는 없다.
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
