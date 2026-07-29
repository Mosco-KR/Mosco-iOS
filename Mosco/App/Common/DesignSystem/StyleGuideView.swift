import SwiftUI

struct StyleGuideView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                    header
                    quickInputPreviewSection
                    prioritySection
                    colorSection
                    typographySection
                    buttonSection
                }
                .padding(Metrics.spacingMD)
                .padding(.bottom, Metrics.spacingXL)
            }
            .background(MoscoPalette.background.ignoresSafeArea())
            .navigationTitle("Design System")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingXS) {
            Text("Mosco")
                .font(.moscoLargeTitle())
                .foregroundStyle(MoscoPalette.textPrimary)
            Text("한 줄로 던지면, 우선순위는 자동으로.")
                .font(.moscoBody())
                .foregroundStyle(MoscoPalette.textSecondary)
        }
    }

    private var quickInputPreviewSection: some View {
        SectionContainer(title: "빠른 입력 미리보기") {
            SurfaceCard {
                VStack(alignment: .leading, spacing: Metrics.spacingSM) {
                    Text("3시 프로젝트 회의")
                        .font(.moscoBody())
                        .foregroundStyle(MoscoPalette.textPrimary)

                    HStack(spacing: Metrics.spacingSM) {
                        TagChip(label: "오후 3:00", tint: MoscoPalette.textSecondary)
                        PriorityTag(priority: .should)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var prioritySection: some View {
        SectionContainer(title: "우선순위 태그 (탭으로 수정 가능)") {
            SurfaceCard {
                HStack(spacing: Metrics.spacingSM) {
                    ForEach(DemoPriority.allCases) { priority in
                        PriorityTag(priority: priority)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var colorSection: some View {
        SectionContainer(title: "컬러 팔레트") {
            HStack(spacing: Metrics.spacingSM) {
                ForEach(DemoPriority.allCases) { priority in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(priority.color)
                            .frame(width: 44, height: 44)
                        Text(priority.rawValue.capitalized)
                            .font(.moscoCaption())
                            .foregroundStyle(MoscoPalette.textPrimary)
                        Text(priority.hex)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(MoscoPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var typographySection: some View {
        SectionContainer(title: "타이포그래피") {
            VStack(alignment: .leading, spacing: Metrics.spacingSM) {
                Text("Large Title").font(.moscoLargeTitle())
                Text("Title").font(.moscoTitle())
                Text("Headline").font(.moscoHeadline())
                Text("Body 텍스트입니다").font(.moscoBody())
                Text("Caption").font(.moscoCaption())
            }
            .foregroundStyle(MoscoPalette.textPrimary)
        }
    }

    private var buttonSection: some View {
        SectionContainer(title: "버튼") {
            Button("추가하기") {}
                .buttonStyle(.moscoPrimary)
        }
    }
}

private struct SectionContainer<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSM) {
            Text(title)
                .font(.moscoHeadline())
                .foregroundStyle(MoscoPalette.textSecondary)
            content
        }
    }
}

#Preview {
    StyleGuideView()
}
