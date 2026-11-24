import LastysCore
import SwiftUI

/// The Lucky Day Planner: suggested dates for an engagement, a wedding or a house blessing.
/// Its results are samples, and the disclaimer stays above them at all times. Birth dates stay on this phone.
struct LuckyDayPlannerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    Picker("Planning", selection: $model.plannerEvent) {
                        ForEach(LuckyEvent.allCases, id: \.self) { event in
                            Text(event.title).tag(event)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    DatePicker(
                        "Your birth date",
                        selection: Binding(
                            get: { model.plannerMyBirthDate ?? model.plannerDefaultBirthDate },
                            set: { model.plannerMyBirthDate = $0 }
                        ),
                        in: ...model.plannerLatestBirthDate,
                        displayedComponents: .date
                    )
                    if let partner = model.plannerPartnerBirthDate {
                        DatePicker(
                            "Partner's birth date",
                            selection: Binding(get: { partner }, set: { model.plannerPartnerBirthDate = $0 }),
                            in: ...model.plannerLatestBirthDate,
                            displayedComponents: .date
                        )
                        Button("Remove your Partner's birth date", role: .destructive) { model.removePlannerPartnerBirthDate() }
                    } else {
                        Button("Add your Partner's birth date") { model.addPlannerPartnerBirthDate() }
                    }
                } footer: {
                    Text("Birth dates stay on this phone. They are never sent to Lastys and never appear on a Scan.")
                }

                Section {
                    // Always shown with the results, so no suggestion is ever read as real advice.
                    Label("Sample results. The cultural advisor's rules haven't arrived yet, so these dates are only an example of how the planner will work.", systemImage: "info.circle")
                        .font(.jakarta(13, .semibold))
                        .foregroundStyle(Theme.roseDeep)
                    if model.plannerNeedsPartnerBirthDate {
                        Text("Add your Partner's birth date to see suggested dates.")
                            .foregroundStyle(Theme.muted)
                    }
                    ForEach(model.luckyDays, id: \.date) { day in
                        LuckyDayRow(day: day)
                    }
                } header: {
                    Text("Suggested dates")
                }
            }
            .navigationTitle("Lucky Day Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct LuckyDayRow: View {
    let day: LuckyDay

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(day.date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                    .font(.jakarta(15, .bold))
                Text(day.reasons.prefix(3).map(\.text).joined(separator: " · "))
                    .font(.jakarta(13))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                Text(verbatim: String(day.score))
                    .font(.jakarta(18, .heavy))
                    .foregroundStyle(Theme.rose)
                Text("Sample")
                    .font(.jakarta(10, .bold))
                    .foregroundStyle(Theme.muted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Sample score \(day.score) out of 100"))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

extension LuckyEvent {
    var title: LocalizedStringKey {
        switch self {
        case .engagement: return "Engagement"
        case .wedding: return "Wedding"
        case .houseBlessing: return "House blessing"
        }
    }

    /// Lower case, for use inside a sentence.
    var inSentence: String {
        switch self {
        case .engagement: return String(localized: "an engagement")
        case .wedding: return String(localized: "a wedding")
        case .houseBlessing: return String(localized: "a house blessing")
        }
    }
}

extension LuckyReason {
    var text: String {
        switch self {
        case .waxingMoon: return String(localized: "Waxing moon")
        case .fullMoon: return String(localized: "Full moon")
        case .silDay: return String(localized: "Sil day")
        case .goodMonthFor(let event): return String(localized: "A good month for \(event.inSentence)")
        case .yourBirthWeekday: return String(localized: "Your birth weekday")
        case .partnersBirthWeekday: return String(localized: "Your Partner's birth weekday")
        case .numbersAgree: return String(localized: "Your birth days add up with this date")
        case .publicHoliday: return String(localized: "A public holiday, so busier")
        }
    }
}
