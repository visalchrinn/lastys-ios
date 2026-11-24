import Foundation

/// An iCalendar (.ics) file of Moments, so a person can save or share them anywhere, each repeating yearly.
public enum MomentCalendarFile {
    public static func make(_ moments: [Moment], calendar: Calendar, now: Date) -> String {
        var lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Lastys//Moments//EN", "CALSCALE:GREGORIAN"]
        for moment in moments {
            lines += [
                "BEGIN:VEVENT",
                "UID:\(moment.id.uuidString)@lastys",
                "DTSTAMP:\(stamp(now))",
                "DTSTART;VALUE=DATE:\(day(moment.date, calendar: calendar))",
                "SUMMARY:\(escaped(moment.title))",
                "RRULE:FREQ=YEARLY",
            ]
            if moment.repeatsOnKhmerLunarDate {
                lines.append("DESCRIPTION:\(escaped("In Lastys this repeats on its Khmer lunar date; here it repeats on the same date."))")
            }
            lines.append("END:VEVENT")
        }
        lines.append("END:VCALENDAR")
        return lines.flatMap(folded).joined(separator: "\r\n") + "\r\n"
    }

    /// RFC 5545: lines of at most 75 bytes, each continuation starting with a space,
    /// breaking only between characters so Khmer text stays whole.
    private static func folded(_ line: String) -> [String] {
        var pieces: [String] = []
        var current = ""
        for character in line {
            let limit = pieces.isEmpty ? 75 : 74
            if current.utf8.count + String(character).utf8.count > limit {
                pieces.append(current)
                current = ""
            }
            current.append(character)
        }
        pieces.append(current)
        return pieces.enumerated().map { index, piece in index == 0 ? piece : " " + piece }
    }

    private static func day(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func stamp(_ date: Date) -> String {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let p = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(
            format: "%04d%02d%02dT%02d%02d%02dZ",
            p.year ?? 0, p.month ?? 0, p.day ?? 0, p.hour ?? 0, p.minute ?? 0, p.second ?? 0
        )
    }

    /// iCalendar text escaping: backslash, semicolon, comma and line breaks of any kind.
    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
