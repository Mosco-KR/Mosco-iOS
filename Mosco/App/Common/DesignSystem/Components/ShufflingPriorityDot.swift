import SwiftUI

/// 우선순위를 자동으로 판별하는 동안 보여주는 로딩 표시 — 시스템 심볼의
/// 기본 pulse 이펙트를 그대로 써서, 커스텀 애니메이션이 아니라 iOS 전반에서
/// 보던 "지금 뭔가 진행 중"인 그 느낌을 그대로 재사용한다.
struct ShufflingPriorityDot: View {
    var body: some View {
        Image(systemName: "circle.fill")
            .resizable()
            .foregroundStyle(MoscoPalette.accent)
            .symbolEffect(.pulse, options: .repeating)
    }
}
