import LastysCore
import SwiftUI

/// The Lucky Day Planner: suggested dates for an engagement, a wedding or a house blessing.
/// Its results are samples, and the disclaimer stays above them at all times. Birth dates stay on this phone.
struct LuckyDayPlannerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    eventChips
                    birthDateField(
                        "Your birth date",
                        selection: Binding(
                            get: { model.plannerMyBirthDate ?? model.plannerDefaultBirthDate },
                            set: { model.plannerMyBirthDate = $0 }
                        )
                    )
                    partnerSection
                    Text("Birth dates stay on this phone. They are never sent to Lastys and never appear on a Scan.")
                        .font(.jakarta(12))
                        .foregroundStyle(Theme.muted)
                    results
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .foregroundStyle(Theme.ink)
        .background(Theme.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Text("Lucky Day Planner")
                .font(.jakarta(20, .bold))
                .tracking(-0.2)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Done")
        }
        .padding(.leading, 20)
        .padding(.trailing, 12)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var eventChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LuckyEvent.allCases, id: \.self) { event in
                    let selected = model.plannerEvent == event
                    Button { model.plannerEvent = event } label: {
                        Text(event.title)
                            .font(.jakarta(14, .semibold))
                            .foregroundStyle(selected ? Color.white : Theme.ink)
                            .padding(.horizontal, 14)
                            .frame(height: 40)
                            .background(Capsule().fill(selected ? Theme.ink : Theme.surface))
                            .overlay(Capsule().strokeBorder(selected ? Theme.ink : Theme.fieldBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private func birthDateField(_ title: LocalizedStringKey, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.jakarta(14, .semibold))
            HStack {
                DatePicker(title, selection: selection, in: ...model.plannerLatestBirthDate, displayedComponents: .date)
                    .labelsHidden()
                    .tint(Theme.rose)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.fieldBorder, lineWidth: 1))
            )
        }
    }

    @ViewBuilder
    private var partnerSection: some View {
        if let partner = model.plannerPartnerBirthDate {
            birthDateField(
                "Partner's birth date",
                selection: Binding(get: { partner }, set: { model.plannerPartnerBirthDate = $0 })
            )
            Button("Remove your Partner's birth date", role: .destructive) { model.removePlannerPartnerBirthDate() }
                .font(.jakarta(14, .semibold))
                .frame(minHeight: 44)
        } else {
            Button("Add your Partner's birth date") { model.addPlannerPartnerBirthDate() }
                .buttonStyle(GhostButtonStyle())
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Always shown with the results, so no suggestion is ever read as real advice.
            Label("Sample results. The cultural advisor's rules haven't arrived yet, so these dates are only an example of how the planner will work.", systemImage: "info.circle")
                .font(.jakarta(13, .semibold))
                .foregroundStyle(Theme.roseDeep)
            if model.plannerNeedsPartnerBirthDate {
                Text("Add your Partner's birth date to see suggested dates.")
                    .font(.jakarta(14))
                    .foregroundStyle(Theme.muted)
            }
            ForEach(model.luckyDays, id: \.date) { day in
                LuckyDayRow(day: day)
            }
        }
    }
}

private struct LuckyDayRow: View {
    let day: LuckyDay

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
                    .font(.jakarta(15, .bold))
                Text(day.reasons.prefix(3).map(\.text).joined(separator: " · "))
                    .font(.jakarta(13))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            Text(verbatim: String(day.score))
                .font(.jakarta(13, .bold))
                .foregroundStyle(Theme.roseDark)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Capsule().fill(Theme.roseTint))
                .accessibilityLabel(Text("Sample score \(day.score) out of 100"))
        }
        .card()
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
        case .engagement: return AppText.string("an engagement")
        case .wedding: return AppText.string("a wedding")
        case .houseBlessing: return AppText.string("a house blessing")
        }
    }
}

extension LuckyReason {
    var text: String {
        switch self {
        case .waxingMoon: return AppText.string("Waxing moon")
        case .fullMoon: return AppText.string("Full moon")
        case .silDay: return AppText.string("Sil day")
        case .goodMonthFor(let event): return AppText.string("A good month for \(event.inSentence)")
        case .yourBirthWeekday: return AppText.string("Your birth weekday")
        case .partnersBirthWeekday: return AppText.string("Your Partner's birth weekday")
        case .numbersAgree: return AppText.string("Your birth days add up with this date")
        case .publicHoliday: return AppText.string("A public holiday, so busier")
        }
    }
}
