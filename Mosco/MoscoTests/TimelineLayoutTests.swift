import Foundation
import Testing

/// 시간표 배치 — 겹치는 일정을 어떻게 다루느냐가 전부다.
/// 그냥 겹쳐 그리면 뒤엣것이 가려서 **있는데 안 보이는** 일정이 생긴다.
@Suite("시간표 배치")
struct TimelineLayoutTests {

    private func item(_ id: String, _ startHour: Double, _ endHour: Double) -> TimelineItem {
        TimelineItem(id: id, startMinute: Int(startHour * 60), endMinute: Int(endHour * 60))
    }

    private func untimed(_ id: String) -> TimelineItem {
        TimelineItem(id: id, startMinute: TimelineLayout.untimed, endMinute: TimelineLayout.untimed)
    }

    private func placement(_ result: [TimelinePlacement], _ id: String) -> TimelinePlacement? {
        result.first { $0.id == id }
    }

    // MARK: 시각 없는 항목

    @Test("시각이_없으면_시간축에_놓지_않는다")
    func 시각_없음() {
        let result = TimelineLayout.place([untimed("장보기"), untimed("우유")])
        #expect(result.isEmpty, "시각 없는 할 일이 축 위 아무 데나 놓였다")
    }

    @Test("시각_있는_것만_골라_놓는다")
    func 섞인_입력() {
        let result = TimelineLayout.place([item("회의", 10, 11), untimed("장보기")])
        #expect(result.count == 1)
        #expect(result[0].id == "회의")
    }

    // MARK: 겹치지 않을 때

    @Test("겹치지_않으면_전부_한_열을_쓴다")
    func 안_겹침() {
        let result = TimelineLayout.place([item("아침", 9, 10), item("점심", 12, 13)])
        #expect(result.allSatisfy { $0.columnCount == 1 }, "겹치지도 않는데 폭이 좁아졌다")
        #expect(result.allSatisfy { $0.column == 0 })
    }

    @Test("아침_일정_때문에_저녁이_좁아지지_않는다")
    func 무리가_나뉜다() {
        // 겹치는 것끼리만 폭을 나눠야 한다. 하루 전체를 한 무리로 보면
        // 아침에 겹친 회의 둘 때문에 저녁 운동까지 반쪽이 된다.
        let result = TimelineLayout.place([
            item("회의A", 9, 10), item("회의B", 9, 10), item("운동", 19, 20),
        ])
        #expect(placement(result, "운동")?.columnCount == 1)
        #expect(placement(result, "회의A")?.columnCount == 2)
    }

    // MARK: 겹칠 때

    @Test("겹치면_나란히_서고_폭을_나눈다")
    func 겹침() {
        let result = TimelineLayout.place([item("A", 9, 11), item("B", 10, 12)])
        #expect(result.allSatisfy { $0.columnCount == 2 }, "겹쳤는데 폭이 그대로다 = 하나가 가려진다")
        #expect(Set(result.map(\.column)) == [0, 1], "같은 열에 겹쳐 놓였다")
    }

    @Test("셋이_겹치면_셋으로_나뉜다")
    func 셋_겹침() {
        let result = TimelineLayout.place([item("A", 9, 12), item("B", 10, 12), item("C", 11, 12)])
        #expect(result.allSatisfy { $0.columnCount == 3 })
        #expect(Set(result.map(\.column)) == [0, 1, 2])
    }

    @Test("앞_열이_비면_다시_쓴다")
    func 열_재사용() {
        // A가 10시에 끝나면 그 열은 비어 있다. C를 새 열에 놓으면 폭만 좁아진다.
        let result = TimelineLayout.place([
            item("A", 9, 10), item("B", 9, 12), item("C", 10, 11),
        ])
        #expect(placement(result, "C")?.column == placement(result, "A")?.column)
    }

    @Test("맞닿기만_한_일정은_겹친_것이_아니다")
    func 맞닿음() {
        // 10시에 끝나고 10시에 시작하는 것은 겹치지 않는다.
        // 다만 최소 높이(30분) 때문에 9:50~10:00은 10:20까지 늘어난다.
        let result = TimelineLayout.place([item("A", 9, 10), item("B", 10, 11)])
        #expect(result.allSatisfy { $0.columnCount == 1 })
    }

    // MARK: 너무 짧은 일정

    @Test("아주_짧은_일정도_읽을_수_있는_높이를_갖는다")
    func 최소_높이() {
        let result = TimelineLayout.place([TimelineItem(id: "잠깐", startMinute: 600, endMinute: 601)])
        #expect(result[0].durationMinutes >= TimelineLayout.minimumDurationMinutes,
                "1분짜리를 1분 높이로 그리면 제목이 한 글자도 안 들어간다")
        #expect(result[0].startMinute == 600, "시작 시각은 그대로여야 한다")
    }

    // MARK: 순서

    @Test("결과는_시작_시각_순이다")
    func 정렬() {
        let result = TimelineLayout.place([item("늦게", 15, 16), item("일찍", 9, 10)])
        #expect(result.map(\.id) == ["일찍", "늦게"])
    }

    @Test("입력_순서를_바꿔도_같은_배치가_나온다")
    func 순서_무관() {
        let items = [item("A", 9, 11), item("B", 10, 12), item("C", 14, 15)]
        #expect(TimelineLayout.place(items) == TimelineLayout.place(items.reversed()))
    }

    @Test("빈_입력은_빈_결과다")
    func 빈_입력() {
        #expect(TimelineLayout.place([]).isEmpty)
    }

    // MARK: 보이는 시간 범위

    @Test("일정이_없으면_기본_시간대를_보여준다")
    func 기본_범위() {
        #expect(TimelineLayout.visibleHourRange([]) == 8...22)
    }

    @Test("일정_범위에_맞춰_축이_줄어든다")
    func 범위_축소() {
        // 늘 0~24시를 그리면 새벽 여섯 시간이 늘 비고 정작 일정이 몰린 곳이 좁아진다.
        let range = TimelineLayout.visibleHourRange([item("회의", 10, 11)])
        #expect(range.lowerBound == 9)
        #expect(range.upperBound <= 13)
    }

    @Test("새벽_일정도_범위_안에_들어온다")
    func 새벽() {
        let range = TimelineLayout.visibleHourRange([item("새벽", 1, 2)])
        #expect(range.lowerBound == 0, "0시 아래로 내려가면 안 된다")
        #expect(range.contains(1))
    }

    // MARK: 축 눈금 표기

    @Test("첫_눈금에는_오전오후를_붙인다")
    func 첫_눈금() {
        #expect(TimelineLayout.axisLabel(hour: 9) == "오전 9시")
        #expect(TimelineLayout.axisLabel(hour: 15) == "오후 3시")
    }

    @Test("오전오후가_안_바뀌면_되풀이하지_않는다")
    func 되풀이_안_함() {
        // `오전 9시` `오전 10시` `오전 11시`로 늘어놓으면 읽을 것이 없는 글자가
        // 눈금마다 반복된다.
        #expect(TimelineLayout.axisLabel(hour: 10, previousHour: 9) == "10시")
        #expect(TimelineLayout.axisLabel(hour: 11, previousHour: 10) == "11시")
    }

    @Test("오전오후가_바뀌는_자리에서만_다시_붙인다")
    func 경계에서_붙임() {
        #expect(TimelineLayout.axisLabel(hour: 12, previousHour: 11) == "오후 12시")
        #expect(TimelineLayout.axisLabel(hour: 13, previousHour: 12) == "1시")
        // 자정을 넘어가는 자리도 같다.
        #expect(TimelineLayout.axisLabel(hour: 24, previousHour: 23) == "오전 12시")
    }

    @Test("눈금의_12시도_다른_화면과_같은_뜻이다")
    func 눈금_12시() {
        // 오전 12시가 자정, 오후 12시가 정오 — TimeExpressionParser와 같은 규칙.
        #expect(TimelineLayout.axisLabel(hour: 0) == "오전 12시")
        #expect(TimelineLayout.axisLabel(hour: 12) == "오후 12시")
    }

    @Test("눈금은_앱의_다른_시각_표기와_같은_말을_쓴다")
    func 표기_일관성() {
        // 한 번은 `오전 01`로 맞춰봤는데 시계가 아니라 표처럼 읽혔다.
        // 폭 문제는 글자를 깎는 대신 오른쪽 정렬로 푼다.
        for hour in [0, 9, 12, 15, 23] {
            #expect(TimelineLayout.axisLabel(hour: hour).hasSuffix("시"))
        }
    }

    @Test("자정까지_가는_일정도_범위를_넘지_않는다")
    func 자정() {
        let range = TimelineLayout.visibleHourRange([item("밤샘", 22, 24)])
        #expect(range.upperBound == 24, "24시를 넘겨 그리면 빈 칸이 생긴다")
    }
}
