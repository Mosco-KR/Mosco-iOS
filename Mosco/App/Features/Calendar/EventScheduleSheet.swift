import SwiftUI

/// 일정 설정 시트 — 최대한 단순하게: 종일 여부, 시작, 종료(끄면 하루짜리),
/// 그리고 반복. 반복은 규칙 하나 고르고 필요할 때만 세부 옵션(요일/간격/종료일)이
/// 아래로 펼쳐진다. 반복 종료일은 옵셔널 — 끄면 무기한.
struct EventScheduleSheet: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @Binding var startTime: Date?
    @Binding var endTime: Date?
    @Binding var repeatRule: RepeatRule
    @Binding var repeatEndDate: Date?
    @Binding var repeatWeekdays: Set<Int>
    @Binding var repeatInterval: Int

    @Environment(\.dismiss) private var dismiss
    /// 날짜 자체가 없는 백로그 항목도 있을 수 있어서(할 일 탭에서 바로 추가) —
    /// 꺼두면 날짜/시간/반복 섹션 전체가 사라진다.
    @State private var hasDate: Bool
    @State private var isAllDay: Bool
    @State private var hasEnd: Bool
    @State private var workingStart: Date
    @State private var workingEnd: Date
    @State private var hasRepeatEnd: Bool
    @State private var workingRepeatEndDate: Date

    init(
        startDate: Binding<Date?>,
        endDate: Binding<Date?>,
        startTime: Binding<Date?>,
        endTime: Binding<Date?>,
        repeatRule: Binding<RepeatRule>,
        repeatEndDate: Binding<Date?>,
        repeatWeekdays: Binding<Set<Int>>,
        repeatInterval: Binding<Int>
    ) {
        _startDate = startDate
        _endDate = endDate
        _startTime = startTime
        _endTime = endTime
        _repeatRule = repeatRule
        _repeatEndDate = repeatEndDate
        _repeatWeekdays = repeatWeekdays
        _repeatInterval = repeatInterval

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let resolvedStart = startDate.wrappedValue ?? today
        let resolvedEnd = endDate.wrappedValue ?? resolvedStart
        _hasDate = State(initialValue: startDate.wrappedValue != nil)
        _isAllDay = State(initialValue: startTime.wrappedValue == nil)
        _hasEnd = State(initialValue: !calendar.isDate(resolvedStart, inSameDayAs: resolvedEnd) || endTime.wrappedValue != nil)
        _workingStart = State(initialValue: Self.combine(day: resolvedStart, time: startTime.wrappedValue))
        _workingEnd = State(initialValue: Self.combine(day: resolvedEnd, time: endTime.wrappedValue))
        _hasRepeatEnd = State(initialValue: repeatEndDate.wrappedValue != nil)
        _workingRepeatEndDate = State(initialValue: repeatEndDate.wrappedValue ?? resolvedStart)
    }

    /// 반복 일정은 날짜가 규칙을 따르므로 날짜 피커를 숨기고 시간만 고르게 한다 —
    /// "반복인데 날짜는 왜 고르지?" 하는 모호함을 없앤다. nil이면 피커 자체를 숨긴다.
    private var dateComponents: DatePickerComponents? {
        if repeatRule != .none {
            return isAllDay ? nil : .hourAndMinute
        }
        return isAllDay ? .date : [.date, .hourAndMinute]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("날짜 설정", isOn: $hasDate.animation())
                } footer: {
                    Text(hasDate ? "" : "날짜 없이 \"할 일\" 탭에만 담아둘 수 있어요.")
                }

                if hasDate {
                    Section {
                        Toggle("종일", isOn: $isAllDay.animation())

                        if let components = dateComponents {
                            DatePicker("시작", selection: $workingStart, displayedComponents: components)

                            Toggle("종료", isOn: $hasEnd.animation())

                            if hasEnd {
                                if repeatRule != .none {
                                    DatePicker("종료", selection: $workingEnd, displayedComponents: components)
                                } else {
                                    DatePicker("종료", selection: $workingEnd, in: workingStart..., displayedComponents: components)
                                }
                            }
                        }
                    } footer: {
                        if repeatRule != .none {
                            Text(isAllDay ? "반복 일정은 반복 규칙에 맞는 날마다 종일로 생겨요." : "반복 일정은 반복 규칙에 맞는 날마다 이 시간에 생겨요.")
                        } else {
                            Text("종료를 끄면 하루짜리 할 일이에요.")
                        }
                    }

                    Section {
                        Picker("반복", selection: $repeatRule.animation()) {
                            ForEach(RepeatRule.allCases) { rule in
                                Text(rule.label).tag(rule)
                            }
                        }

                        if repeatRule == .weekly {
                            weekdaySelector
                        }

                        if repeatRule == .everyNDays {
                            Stepper("\(repeatInterval)일마다", value: $repeatInterval, in: 2...365)
                        }

                        if repeatRule != .none {
                            Toggle("반복 종료일", isOn: $hasRepeatEnd.animation())

                            if hasRepeatEnd {
                                DatePicker("종료일", selection: $workingRepeatEndDate, in: workingStart..., displayedComponents: .date)
                            }
                        }
                    } footer: {
                        if repeatRule != .none {
                            Text(hasRepeatEnd ? "종료일까지 반복돼요." : "종료일 없이 계속 반복돼요. 수정·완료는 모든 반복에 함께 적용돼요.")
                        }
                    }
                }
            }
            .navigationTitle("일정 설정")
            .navigationBarTitleDisplayMode(.inline)
            // 시스템 로케일과 무관하게 날짜 피커가 항상 한국어("2026. 7. 30.")로
            // 나오게 하고, 종일을 껐다 켤 때 시간 부분이 딱딱 튀지 않게 같은
            // 트랜잭션으로 묶는다.
            .environment(\.locale, Locale(identifier: "ko_KR"))
            .animation(.easeInOut(duration: 0.2), value: isAllDay)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료", action: save)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var weekdaySelector: some View {
        HStack(spacing: 6) {
            ForEach(Array(KoreanCalendar.weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                let weekday = index + 1 // Calendar.component(.weekday) 규칙: 1=일요일
                let isOn = repeatWeekdays.contains(weekday)

                Text(symbol)
                    .font(.moscoCaption())
                    .frame(width: 30, height: 30)
                    .foregroundStyle(isOn ? .white : MoscoPalette.textPrimary)
                    .background(isOn ? MoscoPalette.accent : MoscoPalette.surface, in: Circle())
                    .onTapGesture {
                        if isOn {
                            repeatWeekdays.remove(weekday)
                        } else {
                            repeatWeekdays.insert(weekday)
                        }
                    }
            }
        }
        .listRowInsets(EdgeInsets())
        .padding(.vertical, Metrics.spacingSM)
        .frame(maxWidth: .infinity)
    }

    private func save() {
        guard hasDate else {
            startDate = nil
            endDate = nil
            startTime = nil
            endTime = nil
            repeatRule = .none
            repeatEndDate = nil
            dismiss()
            return
        }

        let calendar = Calendar.current

        if repeatRule != .none {
            // 반복 일정: 날짜는 규칙이 정하므로 기준일(원래 탭한 날)은 그대로 두고
            // 하루짜리 인스턴스로 만들며, 시간만 반영한다.
            startDate = calendar.startOfDay(for: workingStart)
            endDate = startDate
            startTime = isAllDay ? nil : workingStart
            endTime = (isAllDay || !hasEnd) ? nil : workingEnd
        } else {
            let resolvedEnd = hasEnd ? workingEnd : workingStart
            startDate = calendar.startOfDay(for: workingStart)
            endDate = calendar.startOfDay(for: resolvedEnd)
            startTime = isAllDay ? nil : workingStart
            endTime = (isAllDay || !hasEnd) ? nil : resolvedEnd
        }

        repeatEndDate = (repeatRule == .none || !hasRepeatEnd) ? nil : workingRepeatEndDate
        dismiss()
    }

    private static func combine(day: Date, time: Date?) -> Date {
        guard let time else { return day }
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: timeComponents.hour ?? 9, minute: timeComponents.minute ?? 0, second: 0, of: day) ?? day
    }
}
