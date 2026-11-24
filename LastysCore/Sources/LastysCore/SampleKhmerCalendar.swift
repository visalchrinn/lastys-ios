import Foundation

/// A Khmer lunar date. Every value from `SampleKhmerCalendar` is a sample: show it as one.
public struct KhmerLunarDate: Equatable, Sendable {
    /// 1 to 15 within the waxing (kaeut) or waning (roaj) half of the month.
    public let day: Int
    public let isWaxing: Bool
    public let month: KhmerLunarMonth
    public let isSample: Bool
}

public enum KhmerLunarMonth: Int, CaseIterable, Sendable {
    case migasir, bos, meak, phalkun, chaet, pisakh, ches, asath, srap, phatrabot, assoch, kadeuk
}

/// The one calendar data provider for Khmer lunar dates and Sil days. SAMPLE data until the cultural
/// advisor's rules arrive: it follows the mean motion of the moon, without real leap-month rules.
public enum SampleKhmerCalendar {
    /// Everything here is a sample, and screens label it so.
    public static let isSample = true

    static let synodicMonth: TimeInterval = 29.530_588 * 86_400
    static let lunarMonthsPerYear = 365.242_19 / 29.530_588
    /// A known new moon: 6 January 2000, 18:14 UTC.
    static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440)

    /// The sample lunar date of the day containing `date`, taken at noon.
    public static func lunarDate(of date: Date, calendar: Calendar) -> KhmerLunarDate {
        let (lunation, dayOfMonth) = position(of: date, calendar: calendar)
        let fullMoon = referenceNewMoon.addingTimeInterval((Double(lunation) + 0.5) * synodicMonth)
        // Named after the Gregorian month its full moon falls in: Kadeuk's full moon is in November.
        let gregorianMonth = calendar.component(.month, from: fullMoon)
        let month = KhmerLunarMonth(rawValue: gregorianMonth % 12) ?? .migasir
        return KhmerLunarDate(
            day: dayOfMonth <= 15 ? dayOfMonth : dayOfMonth - 15,
            isWaxing: dayOfMonth <= 15,
            month: month,
            isSample: isSample
        )
    }

    /// Sil days, the Buddhist holy days: the 8th and 15th of the waxing moon, the 8th of the waning moon,
    /// and the last day of the month (the 14th or 15th of the waning moon, as the month has 29 or 30 days).
    public static func isSilDay(_ date: Date, calendar: Calendar) -> Bool {
        let day = position(of: date, calendar: calendar).dayOfMonth
        if [8, 15, 23].contains(day) { return true }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else { return day == 30 }
        return day >= 29 && position(of: tomorrow, calendar: calendar).dayOfMonth == 1
    }

    /// The first day on or after `day` that falls on the same sample lunar date as `original`: each year
    /// after it, the date moves by the whole number of synodic months nearest that many solar years.
    public static func nextOccurrence(of original: Date, onOrAfter day: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: original)
        var years = 0.0
        while true {
            let months = (years * lunarMonthsPerYear).rounded()
            let candidate = calendar.startOfDay(for: start.addingTimeInterval(months * synodicMonth))
            if candidate >= day { return candidate }
            years += 1
        }
    }

    /// Which lunation the day falls in, and its day within it (1 to 30), measured at local noon.
    private static func position(of date: Date, calendar: Calendar) -> (lunation: Int, dayOfMonth: Int) {
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        let elapsed = noon.timeIntervalSince(referenceNewMoon) / synodicMonth
        let lunation = Int(elapsed.rounded(.down))
        let age = (elapsed - Double(lunation)) * 29.530_588
        return (lunation, min(Int(age) + 1, 30))
    }
}
