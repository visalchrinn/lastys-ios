import Foundation

/// Cambodia's official public holidays, one entry per day off.
public enum CambodianPublicHolidays {
    /// The years this build knows. Each year's list is set by a Royal Government sub-decree.
    public static let coveredYears = 2026...2027

    /// - 2026: Sub-Decree No. 167 (2025), 21 days. Dates from Andersen Cambodia's table of the sub-decree,
    ///   matching AKP's count of 21 and qppstudio.net's dates.
    /// - 2027: Sub-Decree No. 198 (16 Sept 2026), 22 days. Dates from realestate.com.kh's table of the
    ///   sub-decree, matching time.now and holidaydb.com.
    private static let list: [Int: [(month: Int, day: Int, name: PublicHolidayName)]] = [
        2026: [
            (1, 1, .newYear), (1, 7, .victoryDay), (3, 8, .womensDay),
            (4, 14, .khmerNewYear), (4, 15, .khmerNewYear), (4, 16, .khmerNewYear),
            (5, 1, .labourDayAndVisakBochea), (5, 5, .royalPloughing), (5, 14, .kingsBirthday),
            (6, 18, .queenMothersBirthday), (9, 24, .constitutionDay),
            (10, 10, .pchumBen), (10, 11, .pchumBen), (10, 12, .pchumBen),
            (10, 15, .kingFatherCommemoration), (10, 29, .coronationDay), (11, 9, .independenceDay),
            (11, 23, .waterFestival), (11, 24, .waterFestival), (11, 25, .waterFestival),
            (12, 29, .peaceDay),
        ],
        2027: [
            (1, 1, .newYear), (1, 7, .victoryDay), (3, 8, .womensDay),
            (4, 14, .khmerNewYear), (4, 15, .khmerNewYear), (4, 16, .khmerNewYear),
            (5, 1, .labourDay), (5, 14, .kingsBirthday), (5, 20, .visakBochea), (5, 24, .royalPloughing),
            (6, 18, .queenMothersBirthday), (9, 24, .constitutionDay),
            (9, 29, .pchumBen), (9, 30, .pchumBen), (10, 1, .pchumBen),
            (10, 15, .kingFatherCommemoration), (10, 29, .coronationDay), (11, 9, .independenceDay),
            (11, 12, .waterFestival), (11, 13, .waterFestival), (11, 14, .waterFestival),
            (12, 29, .peaceDay),
        ],
    ]

    /// Every public holiday day in `year`, in date order; empty for a year this build doesn't know.
    public static func days(in year: Int, calendar: Calendar) -> [PublicHoliday] {
        (list[year] ?? []).compactMap { entry in
            calendar.date(from: DateComponents(year: year, month: entry.month, day: entry.day))
                .map { PublicHoliday(date: $0, name: entry.name) }
        }
    }
}

public struct PublicHoliday: Equatable, Hashable, Sendable {
    /// The start of the day.
    public let date: Date
    public let name: PublicHolidayName
}

public enum PublicHolidayName: String, CaseIterable, Sendable {
    case newYear, victoryDay, womensDay, khmerNewYear
    case labourDay, labourDayAndVisakBochea, visakBochea, royalPloughing
    case kingsBirthday, queenMothersBirthday, constitutionDay, pchumBen
    case kingFatherCommemoration, coronationDay, independenceDay, waterFestival, peaceDay
}

