import CoreGraphics
import Foundation

/// 하루치 페이지 머리 스트립의 위치 계산.
///
/// 스트립은 **고른 날이 가운데(넷째 칸)에 오는 7일**을 보여준다. 예전에는 일요일로
/// 시작하는 주 단위로 끊었는데, 그러면 들어온 날이 일요일이면 맨 왼쪽 끝에 붙어
/// 버렸다 — 지금 보고 있는 날이 줄의 한쪽 구석에 있는 게 어색했다. 그래서 칸이
/// 하루 단위로 놓이고, 화면에 보이는 7일의 시작은 어느 요일이든 될 수 있다.
///
/// 화면 구조체 안에 두면 테스트가 닿지 않아 여기 둔다.
enum WeekStripPaging {
    static let daysPerPage = 7

    /// 고른 날 왼쪽에 오는 날 수. 7칸의 가운데가 넷째 칸이다.
    static let daysBeforeCenter = daysPerPage / 2

    /// 그 날을 가운데 두려면 맨 왼쪽 칸에 와야 하는 날.
    static func leadingDay(centering date: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -daysBeforeCenter, to: day) ?? day
    }

    /// 손을 뗀 뒤 멈출 가로 위치.
    ///
    /// 한 번 밀면 **한 주(7칸)만** 넘어간다 — 예전 페이징과 같은 손맛이다. 넘길지는
    /// 시스템이 관성까지 더해 내다본 멈춤 위치(`proposed`)가 반 주를 넘었는지로 본다.
    /// 그래서 짧게 튕겨도 넘어가고, 천천히 조금 밀다 놓으면 제자리로 돌아온다.
    ///
    /// 출발점은 칸 경계로 맞춘다. 미끄러지는 도중에 다시 잡으면 칸 사이에서 출발하기
    /// 때문이다 — 그대로 7칸을 더하면 칸이 어긋난 채로 멈춘다.
    static func restingOffset(start: CGFloat, proposed: CGFloat, dayWidth: CGFloat) -> CGFloat {
        guard dayWidth > 0 else { return proposed }
        let page = dayWidth * CGFloat(daysPerPage)
        let origin = (start / dayWidth).rounded() * dayWidth
        let travel = proposed - origin
        let step: CGFloat = travel > page / 2 ? 1 : (travel < -page / 2 ? -1 : 0)
        return max(origin + step * page, 0)
    }
}
