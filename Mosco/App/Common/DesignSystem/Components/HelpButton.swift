import SwiftUI

/// 도움말 한 꼭지.
struct HelpTopic: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let body: String
}

/// 화면 구석에 두는 물음표 버튼. 누르면 그 화면의 기능 설명이 시트로 뜬다.
///
/// 튜토리얼은 한 번 건너뛰면 다시 볼 길이 없고, 나중에 추가된 기능은 아예 안내를
/// 못 받는다. 그래서 "지금 보고 있는 화면"에 대한 설명을 각 화면이 스스로 들고
/// 있게 한다 — 설정 깊은 곳의 도움말 문서보다 훨씬 가깝다.
struct HelpButton: View {
    let title: String
    let topics: [HelpTopic]

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MoscoPalette.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("도움말")
        .sheet(isPresented: $isPresented) {
            HelpSheet(title: title, topics: topics)
        }
    }
}

struct HelpSheet: View {
    let title: String
    let topics: [HelpTopic]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(topics) { topic in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: topic.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(MoscoPalette.accent)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(topic.title)
                                .font(.moscoBody().weight(.semibold))
                                .foregroundStyle(MoscoPalette.textPrimary)
                            Text(topic.body)
                                .font(.moscoCaption())
                                .foregroundStyle(MoscoPalette.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// 화면별 도움말 문구를 한곳에 모아둔다 — 기능이 바뀌면 여기만 고치면 된다.
enum HelpContent {
    static let calendar: [HelpTopic] = [
        HelpTopic(
            icon: "hand.draw",
            title: "달 넘기기",
            body: "달력을 좌우로 밀면 이전·다음 달로 넘어가요. 오른쪽 위 '오늘' 버튼을 누르면 언제든 이번 달로 돌아와요."
        ),
        HelpTopic(
            icon: "calendar.day.timeline.left",
            title: "날짜 고르기",
            body: "날짜를 누르면 달력이 그 주만 남기고 접히고, 아래에 그날의 할 일이 나와요. 접힌 상태에서 좌우로 밀면 주 단위로 이동하고, 아래로 쓸어내리면 다시 펼쳐져요."
        ),
        HelpTopic(
            icon: "square.stack.3d.up",
            title: "캘린더 나누기",
            body: "월 표시 옆 버튼에서 볼 캘린더를 체크로 켜고 끌 수 있어요. 개인·업무처럼 나눠두면 필요한 것만 볼 수 있어요. 설정에서 캘린더를 추가할 수 있어요."
        ),
        HelpTopic(
            icon: "plus.circle",
            title: "빠르게 추가하기",
            body: "아래 입력창에 \"오후 3시 회의\"처럼 적으면 시간을 알아채고 추천 칩을 보여줘요. 켜둔 캘린더가 둘 이상이면 저장할 때 어디에 넣을지 물어봐요."
        ),
        HelpTopic(
            icon: "rectangle.stack",
            title: "+N 표시",
            body: "한 주에 일정이 많으면 다 못 그려서 '+2'처럼 접혀요. 그 날짜를 누르면 아래 목록에서 전부 볼 수 있어요."
        )
    ]

    static let todayPlan: [HelpTopic] = [
        HelpTopic(
            icon: "sun.max",
            title: "언제 할지 정하기",
            body: "시각을 안 정한 오늘 할 일에는 오전·오후·저녁 중 하나를 고를 수 있어요. '언제 할지'를 미리 정해두면 실제로 해내는 비율이 크게 올라간다는 연구 결과가 있어요."
        ),
        HelpTopic(
            icon: "clock",
            title: "고정된 일",
            body: "시작 시각이 정해진 일정은 맨 위에 따로 모여요. 이건 계획할 게 없으니 오늘의 뼈대로만 봐주세요."
        ),
        HelpTopic(
            icon: "tray",
            title: "언젠가",
            body: "날짜를 안 정한 일들이에요. 오른쪽 화살표를 누르면 오늘로 가져오고, 그러면 '언제 하실래요?'에 나타나요."
        ),
        HelpTopic(
            icon: "arrow.up.arrow.down",
            title: "순서 바꾸기와 삭제",
            body: "오른쪽 위 '편집'을 누르면 끌어서 순서를 바꿀 수 있어요. 할 일을 왼쪽으로 밀면 삭제할 수 있고, 길게 누르면 메모와 삭제 메뉴가 나와요."
        ),
        HelpTopic(
            icon: "exclamationmark.triangle",
            title: "너무 많을 때",
            body: "오늘 할 일이 여덟 개를 넘으면 알려드려요. 막지는 않아요 — 사람은 원래 걸리는 시간을 짧게 잡는 편이라, 한 번 짚어드리는 것뿐이에요."
        )
    ]

    static let upcoming: [HelpTopic] = [
        HelpTopic(
            icon: "calendar.badge.clock",
            title: "앞으로 2주",
            body: "가까운 날짜의 일정을 날짜별로 쭉 보여줘요. 달력 격자에서 날짜를 하나씩 눌러보지 않아도 이번 주에 뭐가 있는지 한눈에 보여요."
        ),
        HelpTopic(
            icon: "tray",
            title: "비어 있는 날",
            body: "일정이 없는 날도 '비어 있음'으로 함께 보여줘요. 오늘이 너무 빡빡할 때 어디로 미룰지 고르라고 일부러 남겨둔 거예요."
        ),
        HelpTopic(
            icon: "arrow.turn.up.right",
            title: "미루기",
            body: "일정을 오른쪽으로 밀면 '내일로' 버튼이 나와요. 여러 날에 걸친 일정은 길이를 유지한 채 통째로 밀려요. 반복 일정은 원본이 움직이면 모든 날짜가 함께 바뀌어서 빼뒀어요."
        ),
        HelpTopic(
            icon: "magnifyingglass",
            title: "검색",
            body: "제목과 메모를 함께, 날짜 범위와 상관없이 전부 찾아요. 지난 일정도 나와요."
        )
    ]

    static let settings: [HelpTopic] = [
        HelpTopic(
            icon: "square.stack.3d.up",
            title: "캘린더",
            body: "개인·업무처럼 일정을 크게 나누는 묶음이에요. 달력 화면 위쪽에서 볼 캘린더를 체크로 켜고 꺼요. 새 일정은 켜둔 캘린더가 하나면 거기로 바로 들어가고, 둘 이상이면 만들 때 물어봐요."
        ),
        HelpTopic(
            icon: "circle.grid.2x2",
            title: "카테고리",
            body: "할 일 하나하나의 성격이에요. 색과 알림 설정이 여기 붙어요. 캘린더와는 다른 층이라 함께 쓸 수 있어요."
        ),
        HelpTopic(
            icon: "trash.slash",
            title: "기본 항목은 못 지워요",
            body: "기본 캘린더와 기본 카테고리는 삭제할 수 없어요. 다른 걸 지웠을 때 그 안의 일정을 옮겨 담을 곳이 항상 있어야 하거든요. 지운 묶음의 일정은 기본으로 옮겨져요."
        ),
        HelpTopic(
            icon: "bell",
            title: "알림",
            body: "시작 시각이 있는 할 일에만 보내요. 받을지 여부와 몇 분 전에 받을지는 카테고리마다 따로 정해요. 위쪽 스위치가 꺼져 있으면 카테고리에서 켜둔 것도 오지 않아요."
        ),
        HelpTopic(
            icon: "cloud.sun",
            title: "날씨",
            body: "압축된 주간 달력과 '오늘' 버튼에 그날 날씨를 함께 보여줘요. 위치 권한이 필요해요."
        ),
        HelpTopic(
            icon: "exclamationmark.triangle",
            title: "데이터 초기화",
            body: "할 일·카테고리·캘린더를 전부 지우고 처음 상태로 되돌려요. 되돌릴 수 없고, 동기화를 쓰고 있다면 다른 기기에서도 함께 사라져요."
        )
    ]
}
