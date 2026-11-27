import LastysCore
import SwiftUI

/// The Calendar tab: a month of Moments, public holidays and Sil days, the selected day,
/// and the public holidays to come. Lunar dates and Sil days are samples, and say so.
struct CalendarView: View {
    @Environment(AppModel.self) private var model
    @State private var showingPlanner = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Calendar")
                    .font(.jakarta(26, .heavy))
                    .tracking(-0.6)
                monthCard
                SelectedDayCard(details: model.selectedCalendarDay)
                plannerButton
                upcomingHolidays
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .foregroundStyle(Theme.ink)
        .sheet(isPresented: $showingPlanner) {
            LuckyDayPlannerView()
                .environment(model)
        }
    }

    private var plannerButton: some View {
        Button {
            showingPlanner = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "star")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Theme.rose)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.roseTint))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lucky Day Planner")
                        .font(.jakarta(15, .bold))
                    Text("Dates for an engagement, a wedding or a house blessing (sample)")
                        .font(.jakarta(13))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.muted)
            }
            .card()
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Month

    private var monthCard: some View {
        let month = model.calendarMonth
        return VStack(spacing: 12) {
            HStack {
                Button { model.showPreviousCalendarMonth() } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("Previous month"))
                Spacer()
                Text(month.firstDay, format: .dateTime.month(.wide).year())
                    .font(.jakarta(17, .bold))
                Spacer()
                Button { model.showNextCalendarMonth() } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("Next month"))
            }
            .foregroundStyle(Theme.ink)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(model.calendarWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(verbatim: symbol)
                        .font(.jakarta(12, .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                }
                ForEach(month.days) { day in
                    DayCell(day: day) { model.selectCalendarDay(day.date) }
                }
            }

            legend
        }
        .card()
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: Theme.rose, text: "Public holiday")
            legendItem(color: Theme.green, text: "Moment")
            legendItem(color: Theme.muted, text: "Sil day (sample)")
        }
        .font(.jakarta(12))
        .foregroundStyle(Theme.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendItem(color: Color, text: LocalizedStringKey) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
        }
    }

    // MARK: Upcoming public holidays

    private var upcomingHolidays: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Upcoming public holidays")
                .font(.jakarta(17, .bold))
                .tracking(-0.2)
            let holidays = model.upcomingPublicHolidays(limit: 8)
            if holidays.isEmpty {
                Text("No public holidays known after \(String(model.publicHolidaysKnownThrough)) yet.")
                    .font(.jakarta(14))
                    .foregroundStyle(Theme.muted)
            }
            ForEach(holidays, id: \.self) { holiday in
                HStack {
                    Text(holiday.name.title)
                        .font(.jakarta(14, .semibold))
                    Spacer()
                    Text(holiday.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(.jakarta(13))
                        .foregroundStyle(Theme.muted)
                }
                .frame(minHeight: 32)
            }
        }
        .card()
    }
}

private struct DayCell: View {
    let day: CalendarDay
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(spacing: 3) {
                Text(day.date, format: .dateTime.day())
                    .font(.jakarta(15, day.isToday ? .heavy : .medium))
                    .foregroundStyle(numberColor)
                HStack(spacing: 2) {
                    if day.holiday != nil { dot(Theme.rose) }
                    if day.hasMoments { dot(Theme.green) }
                    if day.isSilDay { dot(Theme.muted) }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(day.isSelected ? Theme.rose : Color.clear)
            )
            .overlay(
                // Today keeps a ring even when another day is selected, so the two never look alike.
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(day.isToday && !day.isSelected ? Theme.rose : Color.clear, lineWidth: 1.5)
            )
            .opacity(day.isInMonth ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(day.isSelected ? .isSelected : [])
        .accessibilityHint(day.isToday ? Text("Today") : Text(verbatim: ""))
    }

    private var numberColor: Color {
        if day.isSelected { return .white }
        return day.holiday != nil ? Theme.roseDark : Theme.ink
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(day.isSelected ? Color.white : color).frame(width: 5, height: 5)
    }
}

private struct SelectedDayCard: View {
    let details: CalendarDayDetails

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(details.date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                .font(.jakarta(17, .bold))
            Text(details.lunarDate.text)
                .font(.jakarta(14))
                .foregroundStyle(Theme.muted)
            if details.isSilDay {
                Label("Sil day (sample)", systemImage: "moon.stars")
                    .font(.jakarta(14))
                    .foregroundStyle(Theme.muted)
            }
            if let holiday = details.holiday {
                Label(holiday.name.title, systemImage: "flag.fill")
                    .font(.jakarta(14, .semibold))
                    .foregroundStyle(Theme.roseDark)
            }
            ForEach(details.moments) { moment in
                Label(moment.title, systemImage: moment.isShared ? "person.2.fill" : "heart")
                    .font(.jakarta(14, .semibold))
                    .foregroundStyle(Theme.green)
            }
            if details.hasNothingOn {
                Text("Nothing on this day.")
                    .font(.jakarta(14))
                    .foregroundStyle(Theme.muted)
            }
        }
        .card()
    }
}

extension KhmerLunarDate {
    /// e.g. "14 Kaeut, Kadeuk (sample lunar date)". Every lunar date is marked as a sample.
    var text: LocalizedStringKey {
        isWaxing
            ? "\(day) Kaeut, \(month.title) (sample lunar date)"
            : "\(day) Roaj, \(month.title) (sample lunar date)"
    }
}

extension KhmerLunarMonth {
    var title: String {
        switch self {
        case .migasir: return "Migasir"
        case .bos: return "Bos"
        case .meak: return "Meak"
        case .phalkun: return "Phalkun"
        case .chaet: return "Chaet"
        case .pisakh: return "Pisakh"
        case .ches: return "Ches"
        case .asath: return "Asath"
        case .srap: return "Srap"
        case .phatrabot: return "Phatrabot"
        case .assoch: return "Assoch"
        case .kadeuk: return "Kadeuk"
        }
    }
}

extension PublicHolidayName {
    var title: LocalizedStringKey {
        switch self {
        case .newYear: return "International New Year's Day"
        case .victoryDay: return "Victory over Genocide Day"
        case .womensDay: return "International Women's Day"
        case .khmerNewYear: return "Khmer New Year"
        case .labourDay: return "International Labour Day"
        case .labourDayAndVisakBochea: return "International Labour Day and Visak Bochea"
        case .visakBochea: return "Visak Bochea"
        case .royalPloughing: return "Royal Ploughing Ceremony"
        case .kingsBirthday: return "King's Birthday"
        case .queenMothersBirthday: return "Queen Mother's Birthday"
        case .constitutionDay: return "Constitution Day"
        case .pchumBen: return "Pchum Ben"
        case .kingFatherCommemoration: return "Commemoration of King Father Norodom Sihanouk"
        case .coronationDay: return "King's Coronation Day"
        case .independenceDay: return "Independence Day"
        case .waterFestival: return "Water Festival (Bon Om Touk)"
        case .peaceDay: return "Peace Day"
        }
    }
}

#Preview {
    CalendarView()
        .environment(AppModel.preview())
        .background(Theme.background)
}
