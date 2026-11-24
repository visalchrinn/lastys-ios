import Foundation
import LastysCore

/// Phase A sample content shown on Home until onboarding and Moments arrive.
enum SampleData {
    static let nickname = "Srey Pich"

    static func moments(relativeTo today: Date = Date()) -> [Moment] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: today)
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: start) ?? start }
        return [
            Moment(type: "Birthday", title: "Mom's birthday", date: day(5)),
            Moment(type: "Custom", title: "Graduation day", date: day(-156)),
            Moment(type: "Custom", title: "Ancestor ceremony", date: day(27), repeatsOnKhmerLunarDate: true),
        ]
    }
}

extension AppModel {
    /// The sample person and Moments, talking to the given Trustee.
    @MainActor static func sample(trustee: TrusteeClient) -> AppModel {
        AppModel(trustee: trustee, nickname: SampleData.nickname, moments: SampleData.moments())
    }

    /// A model for SwiftUI previews, backed by its own fake Trustee.
    @MainActor static var preview: AppModel {
        sample(trustee: FakeTrustee().client(forPhone: "preview"))
    }
}
