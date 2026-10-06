import Foundation
import Testing

/// 분석 데이터를 읽을 수 있게 만드는 두 장치 — 식별자 출처를 설치마다 한 번만
/// 남기는 것, 개발자 기기를 표시하는 것.
@MainActor
struct AnalyticsReportingTests {

    // MARK: analytics_identity

    @Test("식별자_출처는_설치마다_한_번만_남긴다")
    func 한_번만() {
        let local = MemoryStore()
        #expect(AnalyticsIdentity.markReported(in: local))
        #expect(!AnalyticsIdentity.markReported(in: local), "실행마다 남기면 세션 수와 같은 숫자가 된다")
        #expect(!AnalyticsIdentity.markReported(in: local))
    }

    @Test("재설치하면_식별자_출처를_다시_남긴다")
    func 재설치() {
        #expect(AnalyticsIdentity.markReported(in: MemoryStore()))
        // 앱을 지우면 기기 저장소가 비워진다 — 그때 다시 남아야 재설치 비율이 보인다.
        #expect(AnalyticsIdentity.markReported(in: MemoryStore()))
    }

    // MARK: 내부 사용자

    @Test("내부_사용자_링크를_알아본다")
    func 링크() {
        #expect(InternalUser.command(from: URL(string: "mosco://internal")!) == true)
        #expect(InternalUser.command(from: URL(string: "mosco://internal/on")!) == true)
        #expect(InternalUser.command(from: URL(string: "mosco://internal/off")!) == false)
    }

    @Test("위젯_링크나_다른_앱_링크는_내부_사용자_명령이_아니다")
    func 다른_링크() {
        #expect(InternalUser.command(from: URL(string: "mosco://widget/today_todo")!) == nil)
        #expect(InternalUser.command(from: URL(string: "other://internal")!) == nil)
        #expect(InternalUser.command(from: URL(string: "mosco://internal/whatever")!) == nil)
    }

    // MARK: 사용자 속성

    @Test("사용자_속성_이름과_값이_Firebase_한도_안이다")
    func 한도() {
        let properties: [AnalyticsUserProperty] = [
            .internalUser(true),
            .device(id: DeviceIdentity.makeID(), model: "iPhone17,1"),
            .dataScale(todoCount: 5_000, categoryCount: 999, calendarCount: 999)
        ]
        for (name, value) in properties.flatMap(\.values) {
            #expect(name.count <= 24, "\(name): 이름이 24자를 넘으면 버려진다")
            #expect(value.count <= 36, "\(name)=\(value): 값이 36자를 넘으면 버려진다")
        }
    }
}
