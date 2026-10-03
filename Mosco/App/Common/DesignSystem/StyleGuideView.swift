import SwiftUI

/// 토큰과 컴포넌트를 한 화면에 늘어놓은 참고용 화면. `#Preview`로만 연다.
///
/// **릴리스 빌드에는 들어가지 않는다.** 앱 어디에서도 이 화면으로 가는 길이 없는데
/// 타깃에는 컴파일돼 들어갔고, 그래서 Xcode가 문자열을 뽑을 때 여기의 `Text`들이
/// (`Large Title`, `추가하기`, `3시 프로젝트 회의`…) 번역 카탈로그에 섞여 들어왔다.
/// 번역할 일이 없는 키 여남은 개가 앱과 함께 배포될 뻔했다.
#if DEBUG
struct StyleGuideView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.spacingXL) {
                    header
                    quickInputPreviewSection
                    categoryPaletteSection
                    colorSection
                    typographySection
                    buttonSection
                }
                .padding(Metrics.spacingMD)
                .padding(.bottom, Metrics.spacingXL)
            }
            .background(MoscoPalette.background.ignoresSafeArea())
            .navigationTitle(Text(verbatim: "Design System"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingXS) {
            Text(verbatim: "Mosco")
                .font(.moscoLargeTitle())
                .foregroundStyle(MoscoPalette.textPrimary)
            Text(verbatim: "한 줄로 던지면, 카테고리는 자동으로.")
                .font(.moscoBody())
                .foregroundStyle(MoscoPalette.textSecondary)
        }
    }

    private var quickInputPreviewSection: some View {
        SectionContainer(title: String(localized: "빠른 입력 미리보기")) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: Metrics.spacingSM) {
                    Text(verbatim: "3시 프로젝트 회의")
                        .font(.moscoBody())
                        .foregroundStyle(MoscoPalette.textPrimary)

                    HStack(spacing: Metrics.spacingSM) {
                        TagChip(label: "오후 3:00", tint: MoscoPalette.textSecondary)
                        CategoryTag(category: nil)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var categoryPaletteSection: some View {
        SectionContainer(title: "카테고리 색상 팔레트 (사용자가 직접 고른다)") {
            SurfaceCard {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: Metrics.spacingSM) {
                    ForEach(CategoryColorPalette.hexValues, id: \.self) { hex in
                        Circle()
                            .fill(CategoryColorPalette.color(forHex: hex))
                            .frame(width: 28, height: 28)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var colorSection: some View {
        EmptyView()
    }

    private var typographySection: some View {
        SectionContainer(title: "타이포그래피") {
            VStack(alignment: .leading, spacing: Metrics.spacingSM) {
                Text(verbatim: "Large Title").font(.moscoLargeTitle())
                Text(verbatim: "Title").font(.moscoTitle())
                Text(verbatim: "Headline").font(.moscoHeadline())
                Text(verbatim: "Body 텍스트입니다").font(.moscoBody())
                Text(verbatim: "Caption").font(.moscoCaption())
            }
            .foregroundStyle(MoscoPalette.textPrimary)
        }
    }

    private var buttonSection: some View {
        SectionContainer(title: "버튼") {
            Button { } label: { Text(verbatim: "추가하기") }
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
#endif
