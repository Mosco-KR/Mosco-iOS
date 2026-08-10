import CoreGraphics

enum Metrics {
    static let cardRadius: CGFloat = 18
    static let buttonRadius: CGFloat = 14
    static let chipRadius: CGFloat = 100

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 20
    static let spacingXL: CGFloat = 32

    /// 목록에서 카드형 셀 하나가 위아래로 두는 여백 — 셀 사이 간격은 이 값의 두 배다.
    /// 셀을 그리는 세 화면(달력 하루치·오늘 계획·다가오는)이 같은 값을 써야
    /// 화면을 옮겨 다닐 때 같은 목록으로 읽힌다. 예전엔 화면마다 4·6pt로 제각각이라
    /// '다가오는' 탭만 유독 빽빽해 보였다.
    static let listRowGap: CGFloat = 6

    /// 날짜/구역을 가르는 헤더가 바로 앞 셀과 두는 간격. 셀 사이보다 넉넉해야
    /// 구역이 바뀌었다는 게 읽힌다.
    static let listSectionGap: CGFloat = 14
}
