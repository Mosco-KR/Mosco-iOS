import Foundation
import Testing

/// 테스트용 저장소 — 진짜 iCloud/UserDefaults 없이 판정만 본다.
final class MemoryStore: IdentityStore, @unchecked Sendable {
    private var values: [String: String]
    init(_ values: [String: String] = [:]) { self.values = values }
    func string(forKey key: String) -> String? { values[key] }
    func set(_ value: String, forKey key: String) { values[key] = value }
}

/// 같은 사람을 같은 사람으로 세기 — 이게 없으면 앱을 지웠다 깔 때마다
/// 새 사람이 되고, 재방문·리텐션이 전부 실제보다 낮게 잡힌다.
@Suite("분석용 식별자")
struct AnalyticsIdentityTests {

    private let key = AnalyticsIdentity.key

    @Test("아무_데도_없으면_새로_만든다")
    func 첫_실행() {
        let cloud = MemoryStore(), local = MemoryStore()
        let result = AnalyticsIdentity.resolve(cloud: cloud, local: local, newID: { "새-값" })

        #expect(result.id == "새-값")
        #expect(result.origin == .created)
        #expect(local.string(forKey: key) == "새-값", "로컬에 안 남으면 다음 실행에 또 만든다")
        #expect(cloud.string(forKey: key) == "새-값", "iCloud에 안 올라가면 재설치 때 사라진다")
    }

    @Test("재설치해도_iCloud에_있던_값을_그대로_쓴다")
    func 재설치() {
        // 앱을 지우면 로컬은 비지만 iCloud는 남는다 — 그게 이 설계의 핵심이다.
        let cloud = MemoryStore([AnalyticsIdentity.key: "원래-사람"])
        let local = MemoryStore()

        let result = AnalyticsIdentity.resolve(cloud: cloud, local: local, newID: { "새-값" })

        #expect(result.id == "원래-사람", "재설치했다고 다른 사람이 됐다")
        #expect(result.origin == .restoredFromCloud)
        #expect(local.string(forKey: key) == "원래-사람", "로컬에도 적어둬야 다음이 빠르다")
    }

    @Test("기기를_바꿔도_같은_사람이다")
    func 기기_교체() {
        // 새 기기 = 로컬이 빈 상태. 재설치와 같은 경로로 처리된다.
        let cloud = MemoryStore([AnalyticsIdentity.key: "원래-사람"])
        let result = AnalyticsIdentity.resolve(cloud: cloud, local: MemoryStore(), newID: { "새-값" })
        #expect(result.id == "원래-사람")
    }

    @Test("iCloud를_나중에_켜면_로컬_값을_올린다")
    func 나중에_로그인() {
        let cloud = MemoryStore()
        let local = MemoryStore([AnalyticsIdentity.key: "쓰던-값"])

        let result = AnalyticsIdentity.resolve(cloud: cloud, local: local, newID: { "새-값" })

        #expect(result.id == "쓰던-값", "iCloud를 켰다고 사람이 바뀌면 안 된다")
        #expect(result.origin == .promotedFromLocal)
        #expect(cloud.string(forKey: key) == "쓰던-값")
    }

    @Test("iCloud를_못_쓰면_로컬_값으로_계속_간다")
    func iCloud_없음() {
        let local = MemoryStore([AnalyticsIdentity.key: "쓰던-값"])
        let result = AnalyticsIdentity.resolve(cloud: nil, local: local, newID: { "새-값" })
        #expect(result.id == "쓰던-값")
    }

    @Test("iCloud도_없고_처음이면_로컬에만_만든다")
    func iCloud_없는_첫_실행() {
        let local = MemoryStore()
        let result = AnalyticsIdentity.resolve(cloud: nil, local: local, newID: { "새-값" })
        #expect(result.id == "새-값")
        #expect(local.string(forKey: key) == "새-값")
    }

    @Test("이미_있는_값을_절대_덮어쓰지_않는다")
    func 덮어쓰지_않는다() {
        // 덮어쓰는 순간 그 사람은 통계에서 두 사람이 된다.
        let cloud = MemoryStore([AnalyticsIdentity.key: "진짜"])
        let local = MemoryStore([AnalyticsIdentity.key: "낡은"])

        let result = AnalyticsIdentity.resolve(cloud: cloud, local: local, newID: { "새-값" })

        #expect(result.id == "진짜", "iCloud가 정본이어야 기기 간에 하나로 모인다")
    }

    @Test("빈_문자열은_값이_없는_것으로_친다", arguments: ["", "  "])
    func 빈_값(stored: String) {
        // 저장은 됐는데 내용이 없는 경우 — 그대로 쓰면 모두가 같은 사람이 된다.
        let cloud = MemoryStore([AnalyticsIdentity.key: stored.trimmingCharacters(in: .whitespaces)])
        let result = AnalyticsIdentity.resolve(cloud: cloud, local: MemoryStore(), newID: { "새-값" })
        #expect(result.id == "새-값")
    }

    @Test("두_번_불러도_값이_안_바뀐다")
    func 멱등() {
        let cloud = MemoryStore(), local = MemoryStore()
        var counter = 0
        let make = { counter += 1; return "값-\(counter)" }

        let first = AnalyticsIdentity.resolve(cloud: cloud, local: local, newID: make)
        let second = AnalyticsIdentity.resolve(cloud: cloud, local: local, newID: make)

        #expect(first.id == second.id, "앱을 켤 때마다 사람이 바뀐다")
        #expect(second.origin == .restoredFromCloud)
    }
}
