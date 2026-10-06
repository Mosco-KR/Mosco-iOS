import Foundation
import Testing

/// 기기를 한 대씩 알아보기. 1.4.2까지는 내부 사용자 표시가 **계정 하나에 하나**여서,
/// 한 대를 표시하면 같은 Apple 계정의 모든 기기가 같이 분석에서 빠졌다.
@Suite("기기 등록부")
struct DeviceIdentityTests {

    private let pro14 = "iPhone15,2"
    private let pro18 = "iPhone19,3"

    private func resolve(
        cloud: MemoryStore?,
        local: MemoryStore,
        model: String,
        id: String = "aaaa1111"
    ) -> (device: DeviceRecord, registry: [DeviceRecord]) {
        DeviceIdentity.resolve(
            cloud: cloud, local: local, model: model,
            now: Date(timeIntervalSince1970: 0), newID: { id }
        )
    }

    // MARK: 같은 기기를 같은 기기로

    @Test("처음_켜면_등록부에_한_대가_선다")
    func 첫_실행() {
        let cloud = MemoryStore(), local = MemoryStore()
        let result = resolve(cloud: cloud, local: local, model: pro14)

        #expect(result.device.id == "aaaa1111")
        #expect(result.device.model == pro14)
        #expect(!result.device.isInternal)
        #expect(result.registry.count == 1)
    }

    /// id가 바뀌면 보고서에서 한 대가 두 대가 된다.
    @Test("두_번째_실행은_같은_id를_쓴다")
    func 같은_id() {
        let cloud = MemoryStore(), local = MemoryStore()
        _ = resolve(cloud: cloud, local: local, model: pro14, id: "처음")
        let again = resolve(cloud: cloud, local: local, model: pro14, id: "새로-만들면-안-됨")

        #expect(again.device.id == "처음")
        #expect(again.registry.count == 1)
    }

    @Test("기기가_여러_대면_등록부에_나란히_쌓인다")
    func 여러_대() {
        let cloud = MemoryStore()
        _ = resolve(cloud: cloud, local: MemoryStore(), model: pro14, id: "기기1")
        let second = resolve(cloud: cloud, local: MemoryStore(), model: pro18, id: "기기2")

        #expect(second.registry.map(\.id) == ["기기1", "기기2"])
        #expect(second.device.id == "기기2")
    }

    /// iCloud에 있던 목록이 정본이다 — 새로 깐 기기도 다른 기기들을 본다.
    @Test("iCloud에_있는_목록을_정본으로_읽는다")
    func iCloud_정본() {
        let cloud = MemoryStore()
        _ = resolve(cloud: cloud, local: MemoryStore(), model: pro14, id: "기기1")

        let fresh = resolve(cloud: cloud, local: MemoryStore(), model: pro18, id: "기기2")
        #expect(fresh.registry.count == 2)
    }

    @Test("iCloud를_못_쓰면_기기에_적어두고_계속_동작한다")
    func iCloud_없이() {
        let local = MemoryStore()
        _ = resolve(cloud: nil, local: local, model: pro14, id: "기기1")
        let again = resolve(cloud: nil, local: local, model: pro14, id: "다른-값")

        #expect(again.device.id == "기기1")
        #expect(again.registry.count == 1)
    }

    // MARK: 표시는 한 대에만 붙는다

    @Test("한_대를_표시해도_다른_기기는_빠지지_않는다")
    func 한_대만() {
        let cloud = MemoryStore()
        let first = resolve(cloud: cloud, local: MemoryStore(), model: pro14, id: "기기1")
        _ = resolve(cloud: cloud, local: MemoryStore(), model: pro18, id: "기기2")

        let marked = DeviceIdentity.mark(
            true, deviceID: first.device.id, model: pro14, cloud: cloud, local: MemoryStore()
        )

        #expect(DeviceIdentity.isInternal(deviceID: "기기1", in: marked))
        #expect(!DeviceIdentity.isInternal(deviceID: "기기2", in: marked), "다른 기기까지 빠지면 1.4.2와 같은 문제다")
    }

    @Test("끄면_그_기기만_다시_들어온다")
    func 끄기() {
        let cloud = MemoryStore(), local = MemoryStore()
        let device = resolve(cloud: cloud, local: local, model: pro14).device
        _ = DeviceIdentity.mark(true, deviceID: device.id, model: pro14, cloud: cloud, local: local)
        let off = DeviceIdentity.mark(false, deviceID: device.id, model: pro14, cloud: cloud, local: local)

        #expect(!DeviceIdentity.isInternal(deviceID: device.id, in: off))
        // 껐는데 다음 실행에 다시 켜지면 안 된다(기종을 물려받는 규칙 때문에).
        #expect(!resolve(cloud: cloud, local: local, model: pro14).device.isInternal)
    }

    // MARK: 재설치를 건너오기

    /// 앱을 지우면 기기 저장소가 비워져서 id가 새로 생긴다. 기종이 같고 내부로
    /// 표시된 줄이 있으면 그 표시를 물려받는다 — 지웠다 깔 때마다 개발자 기기가
    /// 실사용자로 섞여 들어오는 것이 이 전체를 만든 이유다.
    @Test("재설치하면_같은_기종의_내부_표시를_물려받는다")
    func 재설치() {
        let cloud = MemoryStore()
        let before = resolve(cloud: cloud, local: MemoryStore(), model: pro14, id: "지우기-전")
        _ = DeviceIdentity.mark(true, deviceID: before.device.id, model: pro14, cloud: cloud, local: MemoryStore())

        // 앱을 지웠다 다시 깔았다 — 기기 저장소가 비어 있다.
        let after = resolve(cloud: cloud, local: MemoryStore(), model: pro14, id: "다시-깐-뒤")
        #expect(after.device.isInternal)
    }

    @Test("같은_계정의_다른_기종은_표시를_물려받지_않는다")
    func 다른_기종() {
        let cloud = MemoryStore()
        let mine = resolve(cloud: cloud, local: MemoryStore(), model: pro14, id: "내-기기")
        _ = DeviceIdentity.mark(true, deviceID: mine.device.id, model: pro14, cloud: cloud, local: MemoryStore())

        let other = resolve(cloud: cloud, local: MemoryStore(), model: pro18, id: "다른-기기")
        #expect(!other.device.isInternal)
    }

    /// 1.4.2까지 켜둔 계정 단위 표시를 업데이트 뒤에 잃으면, 개발자 기기가 조용히
    /// 실사용자로 돌아온다.
    @Test("예전_계정_단위_표시를_켜둔_기기는_표시를_유지한다")
    func 예전_표시() {
        let cloud = MemoryStore([DeviceIdentity.legacyInternalKey: "1"])
        #expect(resolve(cloud: cloud, local: MemoryStore(), model: pro14).device.isInternal)

        let localOnly = MemoryStore([DeviceIdentity.legacyInternalKey: "1"])
        #expect(resolve(cloud: nil, local: localOnly, model: pro14).device.isInternal)
    }

    /// 옛 표시를 계정에 남겨두면 **그 뒤에 추가되는 기기까지** 전부 내부가 된다.
    @Test("옛_표시는_등록부로_옮긴_뒤_내려간다")
    func 옛_표시를_내린다() {
        let cloud = MemoryStore([DeviceIdentity.legacyInternalKey: "1"])
        let mine = resolve(cloud: cloud, local: MemoryStore(), model: pro14, id: "내-기기")
        #expect(mine.device.isInternal)

        let later = resolve(cloud: cloud, local: MemoryStore(), model: pro18, id: "나중에-산-기기")
        #expect(!later.device.isInternal)
    }

    // MARK: 값의 모양

    /// 보고서에 뜬 값과 설정 화면에 뜬 값을 눈으로 맞춰야 하므로 짧아야 한다.
    @Test("기기_id는_8자_16진수다")
    func id_모양() {
        for _ in 0..<20 {
            let id = DeviceIdentity.makeID()
            #expect(id.count == 8)
            #expect(id.allSatisfy { $0.isHexDigit && !$0.isUppercase })
        }
    }

    @Test("등록부는_JSON_한_줄로_저장되고_그대로_읽힌다")
    func 저장_왕복() {
        let cloud = MemoryStore(), local = MemoryStore()
        _ = resolve(cloud: cloud, local: local, model: pro14, id: "기기1")

        #expect(DeviceIdentity.read(from: cloud).map(\.id) == ["기기1"])
        #expect(DeviceIdentity.read(from: local).map(\.id) == ["기기1"], "iCloud가 늦게 붙는 실행을 위해 기기에도 적어둔다")
        #expect(DeviceIdentity.read(from: MemoryStore()).isEmpty)
        #expect(DeviceIdentity.read(from: MemoryStore([DeviceIdentity.registryKey: "망가진 값"])).isEmpty)
    }
}
