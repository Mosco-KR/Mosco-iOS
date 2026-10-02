import SwiftUI

/// 달 이름을 누르면 올라오는 달 고르기. 몇 달을 넘겨 가야 하는 일을 한 번에 끝낸다.
///
/// 휠보다 격자 — 열두 달이 한눈에 보이고, 누르면 바로 닫힌다.
struct MonthPickerSheet: View {
    @Binding var month: CalendarMonth
    @Environment(\.dismiss) private var dismiss
    @State private var year: Int

    private let current = CalendarMonth.containing(Date())

    init(month: Binding<CalendarMonth>) {
        _month = month
        _year = State(initialValue: month.wrappedValue.year)
    }

    var body: some View {
        VStack(spacing: Metrics.spacingLG) {
            HStack {
                yearButton("chevron.left", label: String(localized: "이전 해")) { year -= 1 }
                Spacer()
                Text(verbatim: DateText.yearLabel(year))
                    .font(.moscoTitle())
                    .foregroundStyle(MoscoPalette.textPrimary)
                    .contentTransition(.numericText(value: Double(year)))
                    .animation(.easeInOut(duration: 0.2), value: year)
                Spacer()
                yearButton("chevron.right", label: String(localized: "다음 해")) { year += 1 }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(1...12, id: \.self) { number in
                    monthCell(number)
                }
            }
        }
        .padding(.horizontal, Metrics.spacingLG)
        .padding(.top, Metrics.spacingLG)
        .presentationDetents([.height(330)])
        .presentationDragIndicator(.visible)
    }

    private func yearButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MoscoPalette.textSecondary)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func monthCell(_ number: Int) -> some View {
        let target = current.advanced(by: (year - current.year) * 12 + (number - current.month))
        let isSelected = target == month
        let isThisMonth = target == current
        return Button {
            month = target
            dismiss()
        } label: {
            VStack(spacing: 5) {
                Text(verbatim: DateText.monthName(number))
                    .font(.moscoBody().weight(isSelected ? .bold : .medium))
                // 이번 달은 점 하나로 — 고른 달(채운 칸)과 겹쳐도 구분된다.
                Circle()
                    .fill(isThisMonth ? (isSelected ? Color.white : MoscoPalette.accent) : .clear)
                    .frame(width: 5, height: 5)
            }
            .foregroundStyle(isSelected ? Color.white : MoscoPalette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                isSelected ? MoscoPalette.accent : MoscoPalette.textSecondary.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
