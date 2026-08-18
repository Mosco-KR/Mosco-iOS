import Foundation
import CoreLocation
import Observation
import WeatherKit

/// 하루치 날씨 요약 — 뷰가 필요한 것만 담는다. WeatherKit 타입을 그대로 뷰까지
/// 흘리지 않아야, 날씨를 못 받아온 상태(권한 없음/오프라인)를 그냥 "값이 없다"로
/// 단순하게 다룰 수 있다.
struct DailyWeather: Equatable {
    /// SF Symbol 이름(예: "cloud.rain.fill") — WeatherKit이 주는 값 그대로.
    let symbolName: String
    let highCelsius: Int
    let lowCelsius: Int
}

/// 날씨를 못 보여주는 이유. 설정 화면에서 사용자가 무엇을 해야 하는지 안내하고,
/// 개발 중에는 WeatherKit 설정이 빠졌는지 바로 알아채는 용도로도 쓴다.
enum WeatherUnavailableReason: Equatable {
    /// 사용자가 설정에서 날씨 표시를 껐다.
    case disabledByUser
    /// 위치 권한이 없다 — 설정 앱으로 보내면 된다.
    case locationDenied
    /// 위치는 받았는데 WeatherKit 호출이 실패했다(대개 App ID에 WeatherKit
    /// 케이퍼빌리티가 안 켜져 있을 때. 로그에 jwt token 실패로 찍힌다).
    case serviceFailed(String)
}

/// 앱에서 쓰는 날씨를 한곳에서 받아 보관한다.
///
/// WeatherKit은 Apple Developer 계정의 App ID에 WeatherKit 케이퍼빌리티가 켜져
/// 있어야 실제 데이터를 준다. 안 켜져 있거나 위치 권한이 없으면 조용히 빈 상태로
/// 남고, 화면에서는 날씨 표시가 그냥 안 보인다 — 앱의 나머지 기능은 그대로 쓴다.
@Observable
final class WeatherStore {
    /// dayKey → 그날 날씨. 예보는 보통 열흘치라 그 범위 밖 날짜는 값이 없다.
    private(set) var dailyByDayKey: [String: DailyWeather] = [:]
    /// 마지막 시도가 실패했다면 그 이유. 성공했거나 아직 안 해봤으면 nil.
    private(set) var unavailableReason: WeatherUnavailableReason?

    /// 사용자가 설정에서 끄면 아예 안 받아오고 표시도 안 한다.
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            if isEnabled {
                loadIfNeeded()
            } else {
                dailyByDayKey = [:]
                unavailableReason = .disabledByUser
            }
        }
    }

    private static let enabledKey = "showsWeather"

    /// 위치 권한을 화면이 쓰는 형태로. 날씨는 위치 없이는 아무것도 못 한다.
    var permission: PermissionState {
        switch CLLocationManager().authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    /// 스위치에 표시할 값 — 켜뒀어도 위치 권한이 없으면 꺼진 것으로 보인다.
    var isEffectivelyOn: Bool {
        PermissionGate.isOn(userPreference: isEnabled, permission: permission)
    }

    @ObservationIgnored private let service = WeatherKit.WeatherService.shared
    @ObservationIgnored private let locationProvider = OneShotLocationProvider()
    /// 같은 세션에서 여러 화면이 동시에 요청해도 실제 호출은 한 번만.
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    init() {
        // 키가 없으면(첫 실행) 켜진 상태로 시작한다.
        isEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    func weather(for date: Date) -> DailyWeather? {
        guard isEnabled else { return nil }
        return dailyByDayKey[date.dayKey]
    }

    /// 화면이 뜰 때 한 번 부른다. 이미 받아왔거나 받는 중이면 아무것도 안 한다.
    func loadIfNeeded() {
        guard isEnabled, dailyByDayKey.isEmpty, loadTask == nil else { return }
        loadTask = Task { [weak self] in
            await self?.load()
            self?.loadTask = nil
        }
    }

    /// 설정에서 권한을 켜고 돌아왔을 때처럼, 실패했던 걸 다시 시도한다.
    func retry() {
        guard isEnabled else { return }
        loadTask?.cancel()
        loadTask = nil
        unavailableReason = nil
        loadIfNeeded()
    }

    private func load() async {
        guard let location = await locationProvider.currentLocation() else {
            unavailableReason = .locationDenied
            return
        }

        do {
            let forecast = try await service.weather(for: location, including: .daily)
            var result: [String: DailyWeather] = [:]
            for day in forecast {
                result[day.date.dayKey] = DailyWeather(
                    symbolName: day.symbolName,
                    highCelsius: Int(day.highTemperature.converted(to: .celsius).value.rounded()),
                    lowCelsius: Int(day.lowTemperature.converted(to: .celsius).value.rounded())
                )
            }
            dailyByDayKey = result
            unavailableReason = nil
        } catch {
            unavailableReason = .serviceFailed(error.localizedDescription)
        }
    }
}

/// 위치를 딱 한 번만 받아오는 얇은 래퍼. 날씨는 도시 단위면 충분해서 정확도를
/// 낮게(kilometer) 잡는다 — 배터리도 덜 쓰고 권한 부담도 적다.
private final class OneShotLocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func currentLocation() async -> CLLocation? {
        // 이미 기다리는 요청이 있으면 새로 만들지 않는다(연속 호출 방어).
        guard continuation == nil else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                finish(with: nil)
            default:
                manager.requestLocation()
            }
        }
    }

    private func finish(with location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            break
        case .denied, .restricted:
            finish(with: nil)
        default:
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(with: locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(with: nil)
    }
}
