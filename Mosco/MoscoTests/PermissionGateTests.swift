import Foundation
import Testing

/// 권한이 걸린 스위치 — 기기 설정에서 알림을 끄고 앱으로 돌아오면 스위치가 켜진
/// 채로 남던 버그(2026-08-18). 저장된 값과 실제로 동작하는지는 다른 이야기다.
@Suite("권한 스위치")
struct PermissionGateTests {

    // MARK: 무엇으로 보이는가

    @Test("권한이_거부되면_켜뒀어도_꺼진_것으로_보인다")
    func 거부되면_꺼져_보인다() {
        #expect(PermissionGate.isOn(userPreference: true, permission: .denied) == false)
    }

    @Test("아직_안_물어본_상태도_꺼진_것으로_보인다")
    func 미결정도_꺼져_보인다() {
        // 안 물어봤으면 알림은 안 온다. 켜져 보이면 안 되는 이유가 거부와 같다.
        #expect(PermissionGate.isOn(userPreference: true, permission: .notDetermined) == false)
    }

    @Test("권한이_있고_켜뒀으면_켜진_것으로_보인다")
    func 허용되면_켜져_보인다() {
        #expect(PermissionGate.isOn(userPreference: true, permission: .granted) == true)
    }

    @Test("사용자가_껐으면_권한과_무관하게_꺼져_보인다", arguments: [
        PermissionState.granted, .denied, .notDetermined,
    ])
    func 사용자가_끄면_항상_꺼짐(permission: PermissionState) {
        #expect(PermissionGate.isOn(userPreference: false, permission: permission) == false)
    }

    // MARK: 켜려 할 때 무엇을 하는가

    @Test("안_물어봤으면_시스템_창을_띄운다")
    func 미결정이면_요청() {
        #expect(PermissionGate.intent(for: .notDetermined) == .requestPermission)
    }

    @Test("거부됐으면_앱에서_못_되돌리므로_설정으로_보낸다")
    func 거부면_설정으로() {
        // 한 번 거부된 권한은 앱이 다시 물을 수 없다. 여기서 요청을 시도하면
        // 아무 일도 안 일어나고 사용자는 스위치가 고장 났다고 여긴다.
        #expect(PermissionGate.intent(for: .denied) == .openSystemSettings)
    }

    @Test("이미_허용됐으면_설정값만_바꾼다")
    func 허용이면_바로_켬() {
        #expect(PermissionGate.intent(for: .granted) == .enableDirectly)
    }

    // MARK: 안내를 띄울 것인가

    @Test("켜뒀는데_거부된_경우에만_안내를_띄운다")
    func 안내_조건() {
        #expect(PermissionGate.isBlockedByPermission(userPreference: true, permission: .denied) == true)
    }

    @Test("사용자가_스스로_껐으면_안내하지_않는다")
    func 스스로_끈_경우() {
        // 의도한 상태다. 여기에 "설정에서 허용하세요"를 띄우면 잔소리가 된다.
        #expect(PermissionGate.isBlockedByPermission(userPreference: false, permission: .denied) == false)
    }

    @Test("권한이_있으면_안내하지_않는다", arguments: [true, false])
    func 허용이면_안내_없음(userPreference: Bool) {
        #expect(
            PermissionGate.isBlockedByPermission(userPreference: userPreference, permission: .granted) == false
        )
    }

    // MARK: 사용자가 켜둔 기록은 지우지 않는다

    @Test("권한이_다시_허용되면_원래_켜뒀던_대로_돌아온다")
    func 기록이_남는다() {
        let 사용자가_켜둠 = true
        #expect(PermissionGate.isOn(userPreference: 사용자가_켜둠, permission: .denied) == false)
        // 설정에서 허용하고 돌아온 상황 — 저장값은 그대로다
        #expect(PermissionGate.isOn(userPreference: 사용자가_켜둠, permission: .granted) == true)
    }
}
