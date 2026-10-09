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

    // MARK: - 이벤트에 함께 실리는 값

    /// user property만으로는 기기를 가를 수 없다. GA4의 user property는 사용자
    /// 하나당 값 하나인데, 이 앱의 사용자 식별자는 iCloud로 기기를 건너 공유된다 —
    /// 아이폰 한 대를 내부로 표시하면 그 사람의 맥에서 온 이벤트까지 함께 빠졌다.
    @Test("기기와_내부_표시는_이벤트에도_실린다")
    func 이벤트에_실린다() {
        let device = AnalyticsUserProperty.device(id: "cafe1234", model: "iPhone17,1")
        let names = device.eventParameters.map(\.name)
        #expect(names.contains("device_id"))
        #expect(names.contains("device_model"))

        let internalUser = AnalyticsUserProperty.internalUser(true)
        #expect(internalUser.eventParameters.map(\.name) == ["internal_user"])
    }

    /// 보유 규모는 "그 사람이 어떤 사람인가"라 사용자 단위가 맞다. 모든 이벤트에
    /// 붙여봐야 같은 말을 되풀이할 뿐이다.
    @Test("보유_규모는_이벤트에_싣지_않는다")
    func 규모는_빠진다() {
        let scale = AnalyticsUserProperty.dataScale(todoCount: 12, categoryCount: 3, calendarCount: 1)
        #expect(scale.eventParameters.isEmpty)
        #expect(!scale.values.isEmpty, "사용자 속성으로는 계속 나가야 한다")
    }

    @Test("이벤트_자신의_파라미터가_공통값을_이긴다")
    func 이벤트가_이긴다() {
        let merged = Analytics.merge(
            ["source": "widget"],
            with: ["device_id": "cafe1234", "source": "덮어쓰면 안 된다"]
        )
        #expect(merged["source"] == "widget", "공통값이 이기면 그 이벤트가 하려던 말이 사라진다")
        #expect(merged["device_id"] == "cafe1234")
    }
}
