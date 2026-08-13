import ActivityKit
import SwiftUI
import WidgetKit

/// 사용자가 고른 할 일 하나의 남은 시간을 잠금화면과 다이나믹 아일랜드에 띄운다.
///
/// **접힌 상태는 두 가지만 말한다: 카테고리 색과 남은 시간.** 아일랜드 양옆은 글자
/// 서너 개가 들어가면 꽉 차는 자리라, 여기서 더 말하려 들면 아무 말도 못 하게 된다.
///
/// **남은 시간은 앱이 아니라 시스템이 센다.** `Text(timerInterval:)`은 앱이 꺼져
/// 있어도 스스로 줄어든다 — 예전처럼 앱이 "N분"을 계산해 넣으면 잠금화면을 켜라고
/// 만든 기능이 정작 앱이 자는 동안 멈춘 숫자를 보여줬다. 부호는 붙지 않는다
/// (부호가 붙는 건 `.offset`이고, 그건 안 쓴다).
///
/// **시작 시각이 되면 남은 시간을 걷는다.** '진행중'으로 바꿔 붙들지 않는다 —
/// 이 기능은 "언제 시작하나"에 답하는 것이고, 시작한 뒤에는 답할 것이 없다.
/// 활동 자체는 앱이 다음에 돌 때 내려가고(`TodoLiveActivityController.sync`),
/// 그 사이에는 `staleDate`가 지나 `context.isStale`이 켜지므로 여기서 표기만 걷는다.
///
/// **표기는 앱의 셀을 그대로 따른다**(`TodoRow`) — 왼쪽 카테고리 색 막대, 중립색
/// 캡슐 칩, 10pt 상태 아이콘, 메모 앞의 인용 선. 잠금화면만 다른 언어로 말하면
/// 같은 앱으로 안 읽힌다.
///
/// **색은 카테고리 색 하나로만 말한다** — 왼쪽 막대와 완료 버튼(접힌 상태에서는
/// 점)이고, 칩·아이콘·남은 시간은 전부 중립색이다. 앱의 목록은 색을 한 행에 한
/// 자리로 몰아두지만(행이 여러 개라 흩어지면 눈이 피로하다) 여기엔 일정이 하나뿐이라,
/// 막대와 버튼이 같은 색으로 묶여 한 덩어리로 읽히는 편이 낫다.
struct TodoLiveActivity: Widget {
    /// 눌러서 들어왔을 때 앱이 남길 이름. 위젯들과 같은 자리에 세워 서로 비교된다.
    static let deepLinkKind = WidgetDeepLink.liveActivityKind

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TodoActivityAttributes.self) { context in
            lockScreen(context)
                .widgetURL(WidgetDeepLink.url(kind: Self.deepLinkKind))
        } dynamicIsland: { context in
            DynamicIsland {
                // 카테고리 이름만. 색은 아래 제목 앞의 막대가 맡는다 — 앱과 같은
                // 규칙으로, 한 화면에서 카테고리 색이 쓰이는 자리는 하나뿐이다.
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.event.categoryName ?? "미분류")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context)
                        .font(.headline)
                        .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    eventDetail(context, memoLineLimit: 2)
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                }
            } compactLeading: {
                dot(context.state.event.colorHex)
            } compactTrailing: {
                countdown(context)
                    .font(.caption)
                    // 글자 폭이 바뀔 때마다 아일랜드가 넓어졌다 좁아지지 않게.
                    // 8시간까지 띄울 수 있어서 `7:59:23`이 들어갈 자리가 필요하다.
                    .frame(maxWidth: 64)
            } minimal: {
                // 여기는 글자 두어 개가 한계라 `29:47`이 안 들어간다. 활동이 여럿일
                // 때만 나오는 자리이기도 해서 카테고리 색만 남긴다.
                dot(context.state.event.colorHex)
            }
            .widgetURL(WidgetDeepLink.url(kind: Self.deepLinkKind))
            .keylineTint(color(context.state.event.colorHex))
        }
    }

    // MARK: - 잠금화면

    private func lockScreen(_ context: ActivityViewContext<TodoActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(context.state.event.categoryName ?? "미분류")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                // 남은 시간은 오른쪽 위에 크게. 잠금화면을 켜서 제일 먼저 찾는 값이다.
                countdown(context)
                    .font(.title3.weight(.semibold))
            }

            eventDetail(context, memoLineLimit: 3)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .activityBackgroundTint(nil)
    }

    // MARK: - 일정 한 덩어리

    /// 색 막대 + (제목 / 칩 줄 / 메모) + 완료 버튼.
    ///
    /// 막대를 왼쪽에 세우고 나머지를 그 오른쪽에 쌓는 건 앱의 셀(`TodoRow`)과 같은
    /// 짜임이다. 칩 줄의 순서도 같다 — 시각, 캘린더, 그다음 켜고 끄는 표시들.
    private func eventDetail(
        _ context: ActivityViewContext<TodoActivityAttributes>,
        memoLineLimit: Int
    ) -> some View {
        let event = context.state.event

        return HStack(alignment: .top, spacing: 10) {
            Capsule()
                .fill(color(event.colorHex))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)

                // 이름이 있는 것은 칩으로, 켜고 끄는 표시는 캡슐 없는 아이콘으로.
                // 앱의 셀 태그 줄 규칙 그대로다.
                HStack(spacing: 6) {
                    chip(timeRange(event))

                    if let calendarName = event.calendarName {
                        chip(calendarName)
                    }

                    if event.isDDay { marker("flag.fill") }
                    if event.isRepeating { marker("repeat") }
                }

                if let memo = event.memo, !memo.isEmpty {
                    memoView(memo, lineLimit: memoLineLimit)
                }
            }

            Spacer(minLength: 8)

            completeButton(context)
        }
        // 막대가 안쪽 내용 높이만큼만 서게 한다.
        .fixedSize(horizontal: false, vertical: true)
    }

    /// 메모. 앱의 셀에서 쓰는 표기 그대로 — 왼쪽 세로선은 "여기부터는 본문"이라는
    /// 표시다. 인용문에서 빌려온 모양이라 제목과 같은 무게로 읽히지 않는다.
    private func memoView(_ memo: String, lineLimit: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Capsule()
                .fill(.secondary.opacity(0.25))
                .frame(width: 2)

            Text(memo)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(lineLimit)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 2)
    }

    /// 앱의 `TagChip`을 그대로 옮긴 모양(중립색 글자 + 같은 색 0.12 배경). 토큰은
    /// 앱 타깃에만 있어 위젯에서는 값으로 다시 적는다. 여백만 잠금화면 폭에 맞춰
    /// 한 단계 좁혔다.
    private func chip(_ label: String) -> some View {
        Text(label)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.secondary.opacity(0.12), in: Capsule())
    }

    /// 켜고 끄는 표시(반복·디데이). 칩으로 만들지 않는다 — 앱에서 `D-DAY`를 칩으로
    /// 붙였다가 혼자 튀어서 아이콘으로 되돌린 자리다.
    private func marker(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    /// 앱과 같은 표기(`TodoRow`의 시각 태그) — 구분자는 하이픈이다.
    ///
    /// **절대 시각이라 앱이 자도 영원히 맞다.** 옆에서 세는 숫자가 멈추거나 걷혀도
    /// "몇 시 일정인가"는 여기가 언제나 답한다.
    private func timeRange(_ event: TodoActivityAttributes.Event) -> String {
        guard let endLabel = event.endLabel else { return event.startLabel }
        return "\(event.startLabel) - \(endLabel)"
    }

    /// 여기서 바로 끝낸다. 완료하면 대상이 사라지므로 활동도 함께 정리된다.
    ///
    /// **왼쪽 막대와 같은 카테고리 색이다.** 화면에 일정이 하나뿐이라 색이 두 군데
    /// 있어도 무엇을 가리키는지 헷갈릴 여지가 없고, 오히려 막대와 버튼이 같은 색으로
    /// 묶여 "이 일정의 버튼"으로 읽힌다.
    private func completeButton(_ context: ActivityViewContext<TodoActivityAttributes>) -> some View {
        let intent = ToggleTodoFromActivityIntent(
            todoID: context.attributes.todoID,
            dayKey: context.attributes.dayKey
        )

        return Button(intent: intent) {
            Text("완료")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color(context.state.event.colorHex))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                // 앱의 태그·버튼이 전부 캡슐이라 여기도 캡슐이다. 배경은 같은 색을
                // 옅게 깐 톤온톤 — `TagChip`과 같은 방식이다.
                .background(color(context.state.event.colorHex).opacity(0.18), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 조각

    /// 시작까지 남은 시간. **시스템이 센다** — 앱이 꺼져 있어도 줄어든다.
    ///
    /// 시작 시각이 지나면(= `staleDate`가 지나 stale이 되면) 아무것도 그리지 않는다.
    /// 0에서 멈춘 숫자나 '진행중'을 붙여두면, 이미 지나간 일을 아직 기다리는 것처럼
    /// 읽힌다. 그때 남는 건 옆의 절대 시각과 완료 버튼이고, 활동 자체는 앱이 다음에
    /// 돌 때 내려간다.
    ///
    /// 범위의 시작을 `min(지금, 시작 시각)`으로 잡는 건 `ClosedRange`가 뒤집힌 값을
    /// 받으면 죽기 때문이다 — stale로 넘어가는 찰나에 실제로 뒤집힐 수 있다.
    @ViewBuilder
    private func countdown(_ context: ActivityViewContext<TodoActivityAttributes>) -> some View {
        if !context.isStale {
            let start = context.state.event.startDate
            Text(timerInterval: min(.now, start)...start, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
        }
    }

    private func dot(_ hex: String?) -> some View {
        Circle()
            .fill(color(hex))
            .frame(width: 10, height: 10)
    }

    private func color(_ hex: String?) -> Color {
        guard let hex else { return .secondary }
        return CategoryColorPalette.color(forHex: hex)
    }
}
