import SwiftUI

/// 튜토리얼이 지나가는 자리들. **이 순서가 곧 이 앱을 쓰는 순서**다 —
/// 달력 아래 입력창에 적고, 달력에서 오늘을 눌러 열고, 끝내고, 정리한다(삭제).
///
/// 1.4.0에서 탭이 없어지면서 순서가 바뀌었다. 예전엔 오늘 탭에서 적고 끝낸 뒤
/// 달력 탭으로 건너가 정리했다. 이제는 달력(홈)에서 적고, 오늘 페이지 하나에서
/// 끝내기와 정리를 다 한다 — 화면을 한 번만 옮긴다.
///
/// 앞의 세 박자(`typeTitle`·`pickTime`·`send`)를 따로 두는 건 지시가 매 순간
/// 하나여야 하기 때문이다. "적고, 시간을 고르고, 보내세요"를 한 번에 말하면
/// 사람은 첫 문장만 하고 멈춘다. 대신 화면에 보이는 번호는 셋을 묶어 하나로
/// 센다 — 사람이 느끼는 단위는 "할 일 하나 적기" 하나다.
enum TutorialStep: Int, CaseIterable {
    /// 시작할지 말지 고르는 카드. **여기서 안 고르면 아무것도 시작되지 않는다.**
    case welcome
    /// 입력창에 시간을 포함해 한 줄 적기.
    case typeTitle
    /// 제목에서 알아챈 시간 칩 누르기.
    case pickTime
    /// 보내기.
    case send
    /// 달력에서 오늘을 눌러 오늘 페이지 열기. 방금 적은 할 일이 거기 있다.
    case openDay
    /// 셀을 눌러 완료.
    case complete
    /// 꾹 눌러 나오는 메뉴로 정리(삭제).
    case cleanUp
    /// 끝맺음 카드.
    case finish
}

extension TutorialStep {

    // MARK: - 진행 표시

    /// 화면에 보여줄 순서 번호(1~4). 시작/끝 카드는 세지 않는다.
    var chapter: Int? {
        switch self {
        case .welcome, .finish: nil
        case .typeTitle, .pickTime, .send: 1
        case .openDay: 2
        case .complete: 3
        case .cleanUp: 4
        }
    }

    static let chapterCount = 4

    /// 카드로 화면 한가운데 서는 단계(스포트라이트 없음).
    var isCard: Bool {
        self == .welcome || self == .finish
    }

    /// 화면을 어둡게 덮고 다른 조작을 막는가.
    ///
    /// **마지막 '정리' 단계만 예외다.** 그 단계의 과제는 셀을 꾹 눌러 나오는 시스템
    /// 메뉴에서 '삭제'를 고르는 것인데, 그 메뉴는 앱 창 안에 뜬다 — 위에서 덮고
    /// 있으면 어두워진 채로 뜨고, 무엇보다 **눌리지 않는다**. 여기서는 마스크를
    /// 걷고 안내 문구만 남긴다(지시가 하나뿐이라 길을 잃을 자리도 없다).
    var masksBackground: Bool {
        self != .cleanUp
    }

    // MARK: - 문구

    var title: String {
        switch self {
        case .welcome: "1분이면 다 배워요"
        case .typeTitle: "아래 칸에 그대로 적어보세요"
        case .pickTime: "위에 뜬 시간을 누르세요"
        // 실제로는 화살표 자리에 버튼 아이콘을 넣어 그린다(`TutorialOverlay`의
        // `instruction(for:)`). 이 문장은 그 조립이 안 될 때를 위한 예비다.
        case .send: "오른쪽 화살표를 누르세요"
        case .complete: "칸을 한 번 톡 누르세요"
        case .openDay: "달력에서 오늘을 누르세요"
        case .cleanUp: "연습한 할 일을 지워볼게요"
        case .finish: "다 하셨어요"
        }
    }

    /// 그대로 따라 적으면 되는 예시. **문장 속에 묻으면 안 읽힌다** — 지시에서
    /// 떼어내 칩 하나로 크게 보여준다. 이름이 앞, 시간이 뒤인 이유는 `TutorialPractice`.
    var sample: String? {
        self == .typeTitle ? TutorialPractice.sample : nil
    }

    /// 순서가 둘인 단계는 번호를 매겨 나눈다. 한 줄로 뭉치면("꾹 눌러 메뉴에서
    /// 삭제를 누르세요") 첫 동작만 하고 멈추는 사람이 생긴다.
    var checklist: [String]? {
        guard self == .cleanUp else { return nil }
        return ["할 일을 꾹 누르세요", "메뉴에서 ‘삭제’를 누르세요"]
    }

    /// 작은 글씨 한 줄. **지시가 아니라 곁들임**이라, 없으면 없는 대로 둔다.
    /// 지시가 이미 분명한 단계에는 아무것도 붙이지 않는다.
    var hint: String? {
        switch self {
        case .welcome: "직접 해보면서 익히는 게 제일 빨라요"
        case .pickTime: "시간 설정을 따로 열 필요가 없어요"
        case .complete: "다시 누르면 취소돼요"
        case .openDay: "방금 적은 할 일이 거기 있어요"
        case .finish: "적고, 끝내고, 정리하기. 이게 전부예요"
        case .typeTitle, .send, .cleanUp: nil
        }
    }

    /// 한참 머물러 있을 때만 나타나는 도움 링크의 문구.
    ///
    /// **막다른 길을 없애는 장치다.** 지시를 못 따라가는 사람이 남은 길은 "전부
    /// 그만두기"뿐이면, 한 걸음 막힌 것 때문에 나머지 세 걸음을 통째로 잃는다.
    var assistLabel: String? {
        switch self {
        case .typeTitle, .pickTime, .send: "대신 적어드릴까요?"
        case .openDay: "대신 열어드릴까요?"
        case .complete, .cleanUp: "이 단계 넘기기"
        case .welcome, .finish: nil
        }
    }

    // MARK: - 스포트라이트 모양

    /// 재어 올린 자리에서 얼마나 넓혀 구멍을 뚫을지.
    ///
    /// 적는 두 단계에서 위쪽이 유독 넓은 건, 그 자리에 시간 칩이 떠오르기
    /// 때문이다. 칩이 뜬 순간 구멍 밖이면 방금 나타난 것이 어두워진 채로 보인다.
    /// 칩의 자리를 따로 재지 않고 입력창 위를 통째로 열어두는 쪽을 택했다 —
    /// 칩은 입력창에 얹힌 오버레이라, 나타나고 사라지는 그 짧은 사이에 구멍이
    /// 커졌다 작아졌다 하는 것보다 열어두는 편이 조용하다.
    var holeInsets: EdgeInsets {
        switch self {
        case .typeTitle, .pickTime: EdgeInsets(top: 66, leading: 6, bottom: 6, trailing: 6)
        case .send: EdgeInsets(top: 8, leading: 6, bottom: 6, trailing: 6)
        case .complete, .cleanUp: EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        case .openDay: EdgeInsets(top: 4, leading: 2, bottom: 2, trailing: 2)
        case .welcome, .finish: EdgeInsets()
        }
    }

    /// 구멍의 모서리 — 아래에 있는 것의 모양을 그대로 따라가야 도려낸 것처럼 보인다.
    var holeRadius: CGFloat {
        switch self {
        case .typeTitle, .pickTime, .send: 30
        case .complete, .cleanUp: 24
        case .openDay: 12
        case .welcome, .finish: 0
        }
    }
}
