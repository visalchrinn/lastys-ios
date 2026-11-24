import Foundation
import Observation

/// What the app is showing: onboarding until the person has a Lastys ID and a profile, then Home.
public enum Screen: Equatable, Sendable {
    case onboarding(OnboardingStep)
    case home
}

public enum OnboardingStep: Equatable, Sendable {
    case intro(page: Int)
    case language
    case consent
    case recoveryCode
    case profile
}

/// Owns all domain-visible state on the phone and exposes the person's intents.
/// Screens render from it and never decide anything themselves.
@MainActor
@Observable
public final class AppModel {
    public static let introPageCount = 3

    public private(set) var screen: Screen
    /// The last Relationship status Trustee gave, kept on the phone so Home never guesses.
    public var relationship: RelationshipStatus {
        if case .coolingOff(let until) = phone.relationship, now() >= until { return .none }
        return phone.relationship
    }
    /// Every Moment on this phone.
    public var moments: [Moment] { phone.moments }

    /// What this phone keeps between launches. Every change is saved straight away.
    private var phone: PhoneState {
        didSet { store.save(phone) }
    }

    @ObservationIgnored private let phoneKey: PhoneKey
    @ObservationIgnored private let trustee: TrusteeClient
    @ObservationIgnored private let store: PhoneStore
    @ObservationIgnored private let connectivity: Connectivity
    @ObservationIgnored private let reminders: ReminderScheduler
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: () -> Date

    public init(
        phoneKey: PhoneKey,
        trustee: TrusteeClient,
        store: PhoneStore,
        connectivity: Connectivity,
        reminders: ReminderScheduler,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.phoneKey = phoneKey
        self.trustee = trustee
        self.store = store
        self.connectivity = connectivity
        self.reminders = reminders
        self.calendar = calendar
        self.now = now
        let phone = store.load() ?? PhoneState()
        self.phone = phone
        screen = Self.screen(resumingFrom: phone)
    }

    /// Where a launch picks up, given what the phone saved.
    private static func screen(resumingFrom phone: PhoneState) -> Screen {
        if phone.hasFinishedOnboarding { return .home }
        if phone.lastysID == nil { return .onboarding(.intro(page: 0)) }
        if !phone.hasSavedRecoveryCode { return .onboarding(.recoveryCode) }
        return .onboarding(.profile)
    }

    // MARK: Lastys ID

    public var lastysID: LastysID? { phone.lastysID }
    public var nickname: String { phone.nickname ?? "" }
    public var photo: Data? { phone.photo }
    /// Kept on this phone only, for reminders and the Lucky Day Planner. Never shown on a Scan.
    public var birthDate: Date? { phone.birthDate }

    // MARK: Lastys QR

    /// The token for the current minute. ECDSA signatures differ every time, so it is made once per
    /// minute; otherwise the QR would change on every redraw.
    @ObservationIgnored private var currentQRToken: LastysQRToken?

    /// My Lastys QR at `date`, made on the phone with no network. Nil until there is a Lastys ID,
    /// or if the phone's key can't sign. Makes a new token only when the minute changes.
    public func myLastysQR(at date: Date) -> MyLastysQR? {
        guard let personalID = phone.lastysID?.personalID else { return nil }
        if currentQRToken?.minute != LastysQRToken.minute(containing: date) || currentQRToken?.personalID != personalID {
            currentQRToken = try? LastysQRToken(personalID: personalID, at: date, signedBy: phoneKey)
        }
        guard let token = currentQRToken else { return nil }
        return MyLastysQR(payload: token.text, secondsUntilNextCode: LastysQRToken.secondsUntilNextCode(after: date))
    }

    // MARK: Scan

    /// What the last Scan showed. Cleared before every new Scan, so it is never stale.
    public private(set) var scanResult: ScanResult?
    /// Why the last Scan showed nothing, if it didn't work.
    public private(set) var scanProblem: ScanProblem?
    /// True while Trustee is resolving a Scan.
    public private(set) var isScanning = false

    /// Counts Scans, so only the latest one may show what it returns.
    @ObservationIgnored private var scanNumber = 0

    /// Resolves a scanned code live with Trustee. A newer Scan, or closing this one, discards its answer.
    public func scan(_ payload: String) async {
        clearScan()
        let number = scanNumber
        guard connectivity.isOnline else {
            scanProblem = .needsInternet
            return
        }
        isScanning = true
        let outcome: Result<ScanResult, Error>
        do {
            outcome = .success(try await trustee.scan(payload))
        } catch {
            outcome = .failure(error)
        }
        guard number == scanNumber else { return }
        isScanning = false
        switch outcome {
        case .success(let result):
            scanResult = result
        case .failure(let error as TrusteeError):
            scanProblem = ScanProblem(error)
        case .failure(let error as URLError):
            scanProblem = error.code == .notConnectedToInternet ? .needsInternet : .couldNotReachLastys
        case .failure:
            scanProblem = .couldNotReachLastys
        }
    }

    /// Forgets the last Scan, and discards the answer of any Scan still running.
    public func clearScan() {
        scanNumber += 1
        requestProblem = nil
        scanResult = nil
        scanProblem = nil
        isScanning = false
    }

    /// What a Scan of my Lastys QR shows.
    public var shareLevel: ShareLevel { phone.shareLevel }

    // MARK: Relationship request

    /// The Relationship request this phone last sent, as Trustee last reported it.
    public private(set) var outgoingRequest: RelationshipRequest?
    /// Why the last attempt to send or check a Relationship request didn't work.
    public private(set) var requestProblem: RelationshipRequestProblem?
    /// True while Trustee is taking a Relationship request.
    public private(set) var isSendingRequest = false

    /// Only straight after a live Scan that Trustee says allows it, and not while a request is waiting.
    public var canSendRelationshipRequest: Bool {
        guard let scanResult, scanResult.requestBlock == nil, !isSendingRequest else { return false }
        return outgoingRequest?.status != .pending
    }

    /// Offers a Relationship to the person just Scanned.
    public func sendRelationshipRequest() async {
        guard canSendRelationshipRequest, let scanID = scanResult?.scanID else { return }
        guard connectivity.isOnline else {
            requestProblem = .needsInternet
            return
        }
        isSendingRequest = true
        defer { isSendingRequest = false }
        do {
            outgoingRequest = try await trustee.sendRelationshipRequest(scanID: scanID)
            requestProblem = nil
        } catch {
            requestProblem = RelationshipRequestProblem(error)
        }
    }

    /// Asks Trustee where the sent request stands; on acceptance, Home switches to Taken.
    public func refreshOutgoingRequest() async {
        guard let id = outgoingRequest?.id, connectivity.isOnline else { return }
        do {
            let request = try await trustee.relationshipRequest(id: id)
            outgoingRequest = request
            if request.status == .accepted {
                phone.relationship = try await trustee.relationshipStatus()
            }
        } catch {
            requestProblem = RelationshipRequestProblem(error)
        }
    }

    /// Leaves the request's outcome. A request still waiting is kept and followed until it is answered,
    /// so Home switches to Taken even after the Scan screen is closed.
    public func dismissOutgoingRequest() {
        requestProblem = nil
        guard outgoingRequest?.status != .pending else { return }
        outgoingRequest = nil
    }

    /// How often to ask Trustee about a request still waiting. Phase A has no push.
    public static let pendingRequestCheckInterval: Duration = .seconds(3)

    /// The Partner's nickname while in a Relationship, otherwise empty.
    public var partnerNickname: String {
        guard case .active(let partner, _, _) = relationship else { return "" }
        return partner
    }

    /// Which day of the Relationship `date` falls on: day 1 is the day it started.
    public func dayTogether(on date: Date) -> Int? {
        guard case .active(_, let since, _) = relationship else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: since), to: calendar.startOfDay(for: date)).day ?? 0
        return days + 1
    }

    // MARK: Ending a Relationship

    /// Why the last ending action didn't go through.
    public private(set) var endingProblem: EndingProblem?
    /// True while Trustee is taking an ending action.
    public private(set) var isPerformingEndingAction = false

    /// What this Partner can do about ending the Relationship right now, in the order to offer them.
    /// Nothing here ends a Relationship one-sidedly (ADR 0002).
    public var endingActions: [EndingAction] {
        guard case .active(_, _, let stage) = relationship else { return [] }
        switch stage {
        case .together:
            return [.sendEndRequest, .reportSafetyConcern]
        case .ending(let request) where request.sentByMe:
            let canEscalate = request.declined || now() >= request.answerBy
            return [.withdrawEndRequest] + (canEscalate ? [.escalateToTeamReview] : []) + [.reportSafetyConcern]
        case .ending(let request):
            return (request.declined ? [] : [.agreeToEndRequest, .declineEndRequest]) + [.reportSafetyConcern]
        case .inTeamReview(let review):
            return review.reason == .safetyConcern ? [] : [.reportSafetyConcern]
        }
    }

    /// Forgets the last ending problem, e.g. when the Relationship screen opens again.
    public func clearEndingProblem() {
        endingProblem = nil
    }

    /// Takes one of `endingActions` to Trustee, then shows where the Relationship stands.
    public func perform(_ action: EndingAction) async {
        guard endingActions.contains(action), !isPerformingEndingAction else { return }
        guard connectivity.isOnline else {
            endingProblem = .needsInternet
            return
        }
        isPerformingEndingAction = true
        defer { isPerformingEndingAction = false }
        do {
            switch action {
            case .sendEndRequest: try await trustee.sendEndRequest()
            case .withdrawEndRequest: try await trustee.withdrawEndRequest()
            case .agreeToEndRequest: try await trustee.respondToEndRequest(agree: true)
            case .declineEndRequest: try await trustee.respondToEndRequest(agree: false)
            case .escalateToTeamReview: try await trustee.escalateToTeamReview()
            case .reportSafetyConcern: try await trustee.reportSafetyConcern()
            }
            endingProblem = nil
        } catch let error as TrusteeError where [.notAllowedNow, .noRelationship, .cannotEscalateYet].contains(error) {
            endingProblem = .changedMeanwhile
        } catch {
            endingProblem = (error as? URLError)?.code == .notConnectedToInternet ? .needsInternet : .couldNotReachLastys
        }
        if let status = try? await trustee.relationshipStatus() {
            phone.relationship = status
        }
        forgetFormerPartnersBirthDate()
        await syncSharedMoments()
    }

    /// Loads this Lastys ID's current status from Trustee.
    public func start() async {
        scheduleReminders()
        guard phone.lastysID != nil else { return }
        do {
            phone.relationship = try await trustee.relationshipStatus()
        } catch {
            // Errors surface in later slices; for now the last known state stays on screen.
        }
        forgetFormerPartnersBirthDate()
        await syncSharedMoments()
    }

    // MARK: Shared Moments

    /// After a Relationship ends: everything that was shared in it, mine and my former Partner's,
    /// waiting for me to keep, export or delete my own copy.
    public var formerSharedMoments: [Moment] {
        let mine = phone.moments.filter { phone.formerlySharedMomentIDs.contains($0.id) }
        return mine + phone.formerPartnerMoments.map { Self.moment(from: $0) }
    }

    /// Whether Home offers the keep, export or delete decision. Quick hide keeps it off the screen.
    public var showsFormerSharedMoments: Bool {
        !formerSharedMoments.isEmpty && !isQuickHideOn
    }

    /// Why the last sharing step didn't go through.
    public private(set) var sharingProblem: SharingProblem?

    /// Whether this Moment is mine to change. My Partner's Shared Moments are theirs.
    public func isMine(_ moment: Moment) -> Bool {
        phone.moments.contains { $0.id == moment.id }
    }

    /// One of my own Moments, not yet shared, while I'm in a Relationship.
    public func canShare(_ moment: Moment) -> Bool {
        guard case .active = relationship else { return false }
        return phone.moments.contains { $0.id == moment.id && !$0.isShared }
    }

    public func canStopSharing(_ moment: Moment) -> Bool {
        phone.moments.contains { $0.id == moment.id && $0.isShared }
    }

    /// Shares one of my Moments into the Relationship, so my Partner sees it too.
    public func share(_ id: UUID) async {
        guard let moment = phone.moments.first(where: { $0.id == id }), canShare(moment) else { return }
        await setShared(id, true)
    }

    public func stopSharing(_ id: UUID) async {
        guard let moment = phone.moments.first(where: { $0.id == id }), canStopSharing(moment) else { return }
        await setShared(id, false)
    }

    private func setShared(_ id: UUID, _ shared: Bool) async {
        guard connectivity.isOnline else {
            sharingProblem = .needsInternet
            return
        }
        guard let index = phone.moments.firstIndex(where: { $0.id == id }) else { return }
        phone.moments[index].isShared = shared
        await syncSharedMoments()
    }

    /// The sync in flight, if any. Syncs run one after another, so an older set never lands last.
    @ObservationIgnored private var syncInFlight: Task<Void, Never>?

    /// Brings Shared Moments in line with Trustee: while in a Relationship, sends mine and fetches my
    /// Partner's; after it ends, my own stop being shared and everything shared waits for my decision.
    /// Only Moments marked shared ever leave the phone.
    public func syncSharedMoments() async {
        let previous = syncInFlight
        let sync = Task { [weak self] in
            await previous?.value
            await self?.syncSharedMomentsNow()
        }
        syncInFlight = sync
        await sync.value
    }

    private func syncSharedMomentsNow() async {
        guard phone.lastysID != nil, connectivity.isOnline else { return }
        do {
            if case .active = relationship {
                let mine = phone.moments.filter(\.isShared)
                if !mine.isEmpty || phone.hasSharedMoments {
                    try await trustee.setMySharedMoments(mine.map(SharedMoment.init))
                    phone.hasSharedMoments = !mine.isEmpty
                }
                phone.partnerMoments = try await trustee.partnerSharedMoments()
            } else if phone.moments.contains(where: \.isShared) || phone.hasSharedMoments || !phone.partnerMoments.isEmpty {
                var ended = phone
                ended.formerlySharedMomentIDs += ended.moments.filter(\.isShared).map(\.id)
                for index in ended.moments.indices { ended.moments[index].isShared = false }
                ended.partnerMoments = []
                ended.hasSharedMoments = false
                phone = ended
            }
            // Copies from a Relationship that ended stay mine to decide about, even in a new one.
            phone.formerPartnerMoments = try await trustee.formerSharedMoments()
            sharingProblem = nil
        } catch {
            sharingProblem = SharingProblem(error)
        }
        scheduleReminders()
    }

    /// Keeps everything that was shared: my own Moments stay, and my copy of my former Partner's
    /// becomes personal Moments on this phone.
    public func keepFormerSharedMoments() async {
        let received = phone.formerPartnerMoments.map { shared -> Moment in
            var personal = Self.moment(from: shared)
            personal.isShared = false
            return personal
        }
        guard await discardReceivedCopies() else { return }
        var kept = phone
        kept.moments += received.filter { copy in !kept.moments.contains { $0.id == copy.id } }
        kept.formerlySharedMomentIDs = []
        phone = kept
        scheduleReminders()
    }

    /// Deletes my copy of everything that was shared, my own Moments included.
    /// My former Partner's own copy is untouched.
    public func deleteFormerSharedMoments() async {
        guard await discardReceivedCopies() else { return }
        var deleted = phone
        deleted.moments.removeAll { deleted.formerlySharedMomentIDs.contains($0.id) }
        deleted.formerlySharedMomentIDs = []
        phone = deleted
        scheduleReminders()
    }

    /// Tells Trustee I've dealt with my copy of what my former Partner shared, if there is any.
    private func discardReceivedCopies() async -> Bool {
        guard !phone.formerPartnerMoments.isEmpty else { return true }
        guard connectivity.isOnline else {
            sharingProblem = .needsInternet
            return false
        }
        do {
            try await trustee.discardFormerSharedMoments()
            phone.formerPartnerMoments = []
            sharingProblem = nil
            return true
        } catch {
            sharingProblem = SharingProblem(error)
            return false
        }
    }

    /// Everything that was shared in my ended Relationship as an .ics file to save or share.
    public func formerSharedMomentsCalendar() -> String {
        MomentCalendarFile.make(formerSharedMoments, calendar: calendar, now: now())
    }

    // MARK: Onboarding

    public func nextIntroPage() {
        guard case .onboarding(.intro(let page)) = screen else { return }
        screen = page + 1 < Self.introPageCount ? .onboarding(.intro(page: page + 1)) : .onboarding(.language)
    }

    public func skipIntro() {
        guard case .onboarding(.intro) = screen else { return }
        screen = .onboarding(.language)
    }

    public var language: Language { phone.language }

    public func chooseLanguage(_ language: Language) {
        phone.language = language
    }

    public func confirmLanguage() {
        guard screen == .onboarding(.language) else { return }
        screen = .onboarding(.consent)
    }

    /// The person confirms they are 18 or older.
    public var isOver18 = false
    /// The person accepts the Terms and the Privacy Notice.
    public var acceptsTerms = false
    /// Why the last onboarding step couldn't go ahead, if it couldn't.
    public private(set) var onboardingProblem: OnboardingProblem?
    /// True while Trustee is creating the Lastys ID.
    public private(set) var isCreatingLastysID = false

    public var canContinueFromConsent: Bool {
        isOver18 && acceptsTerms && !isCreatingLastysID
    }

    /// Creates the Lastys ID, then shows its Recovery code.
    public func continueFromConsent() async {
        guard screen == .onboarding(.consent), canContinueFromConsent else { return }
        isCreatingLastysID = true
        defer { isCreatingLastysID = false }
        do {
            let created = try await trustee.createLastysID()
            onboardingProblem = nil
            var withLastysID = phone
            withLastysID.lastysID = created.lastysID
            withLastysID.recoveryCode = created.recoveryCode
            phone = withLastysID // one save, so a relaunch never finds the ID without its Recovery code
            screen = .onboarding(.recoveryCode)
        } catch TrusteeError.phoneAlreadyHasLastysID {
            onboardingProblem = .phoneAlreadyHasLastysID
        } catch {
            onboardingProblem = .couldNotReachTrustee
        }
    }

    public var recoveryCode: String? { phone.recoveryCode }

    /// The person confirms they have saved their Recovery code somewhere safe.
    public var hasSavedRecoveryCode = false

    public var canContinueFromRecoveryCode: Bool { hasSavedRecoveryCode }

    public func continueFromRecoveryCode() {
        guard screen == .onboarding(.recoveryCode), canContinueFromRecoveryCode else { return }
        phone.hasSavedRecoveryCode = true
        screen = .onboarding(.profile)
    }

    /// What scanners will see.
    public var profileNickname = ""
    /// Optional; what scanners will see.
    public var profilePhoto: Data?
    /// Stays on this phone.
    public var profileBirthDate: Date?
    /// True while Trustee is saving the profile.
    public private(set) var isSavingProfile = false

    public var canFinishProfile: Bool {
        !trimmedProfileNickname.isEmpty && profileBirthDate != nil && !isSavingProfile
    }

    private var trimmedProfileNickname: String {
        profileNickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Sends the nickname and photo to Trustee, keeps the birth date on the phone, then shows Home.
    public func finishProfile() async {
        guard screen == .onboarding(.profile), canFinishProfile, let birthDate = profileBirthDate else { return }
        let nickname = trimmedProfileNickname
        isSavingProfile = true
        defer { isSavingProfile = false }
        do {
            try await trustee.updateProfile(nickname: nickname, photo: profilePhoto)
        } catch {
            onboardingProblem = .couldNotReachTrustee
            return
        }
        onboardingProblem = nil
        var finished = phone
        finished.nickname = nickname
        finished.photo = profilePhoto
        finished.birthDate = birthDate
        finished.hasFinishedOnboarding = true
        phone = finished
        screen = .home
    }

    // MARK: Quick hide

    /// Quick hide keeps the status card and Shared Moments off this phone's screen, for when someone
    /// may be looking at it. It never reaches Trustee, so a Scan of this Lastys ID still shows the truth.
    public var isQuickHideOn: Bool { phone.isQuickHideOn }

    /// Offered to everyone once onboarded, Single or Taken: if only Taken people had it, its presence
    /// on screen would give their status away.
    public var canUseQuickHide: Bool { phone.hasFinishedOnboarding }

    public var showsStatusCard: Bool { !isQuickHideOn }

    public func setQuickHide(_ on: Bool) {
        guard canUseQuickHide else { return }
        phone.isQuickHideOn = on
        scheduleReminders()
    }

    // MARK: Calendar state

    /// What the Lucky Day Planner is planning for.
    public var plannerEvent: LuckyEvent = .wedding
    /// My birth date as changed in the planner only; nil means my profile's.
    var plannerMyBirthDateOverride: Date?

    /// The month the Calendar shows; nil means the current month.
    private var calendarShownMonth: Date?
    /// The day the Calendar has selected; nil means today.
    private var calendarSelectedDay: Date?

    // MARK: Moments

    /// The start of today on this phone.
    private var today: Date { calendar.startOfDay(for: now()) }

    /// The Moments this screen may show: Quick hide leaves out Shared Moments.
    private var visibleMoments: [Moment] {
        isQuickHideOn ? allMoments.filter { !$0.isShared } : allMoments
    }

    /// My own Moments and what my Partner shares with me.
    private var allMoments: [Moment] {
        phone.moments + phone.partnerMoments.map { Self.moment(from: $0) }
    }

    private static func moment(from shared: SharedMoment) -> Moment {
        Moment(id: shared.id, type: shared.type, title: shared.title, date: shared.date,
               repeatsOnKhmerLunarDate: shared.repeatsOnKhmerLunarDate, isShared: true)
    }

    /// Each Moment's next occurrence from today, nearest first, at most three.
    public var upcomingMoments: [UpcomingMoment] {
        Array(visibleMoments.map(upcoming).sorted { $0.date < $1.date }.prefix(3))
    }

    /// Every Moment on its own date, newest first.
    public var timeline: [Moment] {
        visibleMoments.sorted { $0.date > $1.date }
    }

    /// Whether the Moment's own date is still ahead, for the timeline.
    public func isUpcoming(_ moment: Moment) -> Bool {
        moment.date >= today
    }

    public func canSave(_ draft: MomentDraft) -> Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Adds a personal Moment. It stays on this phone and is never sent to Trustee.
    @discardableResult
    public func addMoment(_ draft: MomentDraft) -> Moment? {
        guard canSave(draft) else { return nil }
        let moment = Moment(
            type: draft.type, title: Self.trimmed(draft.title), date: draft.date,
            repeatsOnKhmerLunarDate: draft.repeatsOnKhmerLunarDate, media: draft.media
        )
        phone.moments.append(moment)
        scheduleReminders()
        return moment
    }

    public func updateMoment(id: UUID, to draft: MomentDraft) {
        guard canSave(draft), let index = phone.moments.firstIndex(where: { $0.id == id }) else { return }
        var moment = phone.moments[index]
        moment.type = draft.type
        moment.title = Self.trimmed(draft.title)
        moment.date = draft.date
        moment.repeatsOnKhmerLunarDate = draft.repeatsOnKhmerLunarDate
        moment.media = draft.media
        phone.moments[index] = moment
        scheduleReminders()
        if moment.isShared { Task { await syncSharedMoments() } }
    }

    public func deleteMoment(id: UUID) {
        let wasShared = phone.moments.first { $0.id == id }?.isShared ?? false
        phone.moments.removeAll { $0.id == id }
        scheduleReminders()
        if wasShared { Task { await syncSharedMoments() } }
    }

    /// The media files Moments still use, so the phone can remove the rest.
    public var mediaFileNamesInUse: Set<String> {
        Set(phone.moments.compactMap(\.media?.fileName))
    }

    // MARK: Reminders

    private func upcoming(_ moment: Moment) -> UpcomingMoment {
        let date = nextOccurrence(of: moment, onOrAfter: today)
        let days = calendar.dateComponents([.day], from: today, to: date).day ?? 0
        return UpcomingMoment(moment: moment, date: date, daysUntil: days)
    }

    private func nextOccurrence(of moment: Moment, onOrAfter day: Date) -> Date {
        if moment.repeatsOnKhmerLunarDate {
            return SampleKhmerCalendar.nextOccurrence(of: moment.date, onOrAfter: day, calendar: calendar)
        }
        let original = calendar.startOfDay(for: moment.date)
        if original >= day { return original }
        let parts = calendar.dateComponents([.month, .day], from: original)
        return calendar.nextDate(after: day.addingTimeInterval(-1), matching: parts, matchingPolicy: .nextTime) ?? original
    }

    /// How many occurrences of each Moment have reminders booked ahead: this one and the next, so the
    /// next year is covered even once today's reminder has passed, and if the app isn't opened for a year.
    static let occurrencesBooked = 2

    /// Hands iOS every reminder still to come: 7 days before, the day before and on the day of each
    /// Moment's next occurrences. Called on every change, at launch and when the app comes back.
    func scheduleReminders() {
        let current = now()
        // Quick hide keeps Shared Moments off the lock screen as well as off Home.
        let due = visibleMoments.flatMap { moment -> [Reminder] in
            occurrences(of: moment, count: Self.occurrencesBooked).flatMap { occurrence in
                dueReminders(for: moment, on: occurrence, after: current)
            }
        }
        reminders.replaceAll(with: due.sorted { $0.fires < $1.fires })
    }

    private func occurrences(of moment: Moment, count: Int) -> [Date] {
        var dates: [Date] = []
        var from = today
        while dates.count < count {
            let next = nextOccurrence(of: moment, onOrAfter: from)
            dates.append(next)
            from = calendar.date(byAdding: .day, value: 1, to: next) ?? next.addingTimeInterval(86_400)
        }
        return dates
    }

    /// The reminders for one occurrence that haven't fired yet.
    private func dueReminders(for moment: Moment, on occurrence: Date, after current: Date) -> [Reminder] {
        Reminder.daysBefore.compactMap { days in
            guard let day = calendar.date(byAdding: .day, value: -days, to: occurrence),
                  let fires = calendar.date(bySettingHour: Reminder.hour, minute: 0, second: 0, of: day),
                  fires > current
            else { return nil }
            return Reminder(momentID: moment.id, title: moment.title, fires: fires, when: Reminder.When(daysBefore: days))
        }
    }

    private static func trimmed(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum OnboardingProblem: Equatable, Sendable {
    /// This phone already made a Lastys ID (ADR 0001). Recovery or Phone transfer are the way back.
    case phoneAlreadyHasLastysID
    /// Trustee couldn't be reached; trying again may work.
    case couldNotReachTrustee
}

public enum ScanProblem: Equatable, Sendable {
    /// No internet: a Scan always asks Trustee, so it never shows a stale status.
    case needsInternet
    case notALastysQR
    case expiredQR
    case forgedQR
    /// Lastys couldn't be reached or answered strangely; trying again may work.
    case couldNotReachLastys
    /// This phone has no Lastys ID yet.
    case noLastysID

    init(_ error: TrusteeError) {
        switch error {
        case .notALastysQR: self = .notALastysQR
        case .expiredQR: self = .expiredQR
        case .forgedQR: self = .forgedQR
        case .noLastysID: self = .noLastysID
        default: self = .couldNotReachLastys // not something a Scan returns
        }
    }
}

public enum RelationshipRequestProblem: Equatable, Sendable {
    /// Sending or checking a request needs Trustee, so it needs internet.
    case needsInternet
    /// Something changed since the Scan (it got too old, or one of you became Taken): Scan them again.
    case scanAgain
    case couldNotReachLastys

    init(_ error: Error) {
        switch error as? TrusteeError {
        case .scanTooOld, .scanRequired, .youAreTaken, .youAreCoolingOff, .theyAreTaken, .theyAreCoolingOff, .thatIsYou:
            self = .scanAgain
        default:
            self = (error as? URLError)?.code == .notConnectedToInternet ? .needsInternet : .couldNotReachLastys
        }
    }
}

/// One step a Partner can take towards ending a Relationship, or away from it.
public enum EndingAction: Hashable, Sendable {
    case sendEndRequest
    case withdrawEndRequest
    case agreeToEndRequest
    case declineEndRequest
    case escalateToTeamReview
    case reportSafetyConcern
}

public enum EndingProblem: Equatable, Sendable {
    case needsInternet
    /// The Partner or the Lastys team acted first; the screen now shows where things stand.
    case changedMeanwhile
    case couldNotReachLastys
}

public enum SharingProblem: Equatable, Sendable {
    /// Sharing goes through Trustee, so it needs internet.
    case needsInternet
    case couldNotReachLastys

    init(_ error: Error) {
        self = (error as? URLError)?.code == .notConnectedToInternet ? .needsInternet : .couldNotReachLastys
    }
}

// MARK: - Calendar

/// One square of the month grid.
public struct CalendarDay: Identifiable, Equatable, Sendable {
    public let date: Date
    public let isInMonth: Bool
    public let isToday: Bool
    public let isSelected: Bool
    public let holiday: PublicHoliday?
    public let hasMoments: Bool
    /// A sample Sil day (see `SampleKhmerCalendar`).
    public let isSilDay: Bool

    public var id: Date { date }
}

/// The month the Calendar shows, as weeks of seven days starting on the calendar's first weekday.
public struct CalendarMonth: Equatable, Sendable {
    /// The first day of the month.
    public let firstDay: Date
    public let weeks: [[CalendarDay]]

    /// Every square, week after week.
    public var days: [CalendarDay] { weeks.flatMap { $0 } }
}

/// What's on the selected day.
public struct CalendarDayDetails: Equatable, Sendable {
    public let date: Date
    public let lunarDate: KhmerLunarDate
    public let holiday: PublicHoliday?
    public let moments: [Moment]
    public let isSilDay: Bool

    /// No public holiday, no Moment and no Sil day: the day shows as having nothing on it.
    public var hasNothingOn: Bool { holiday == nil && moments.isEmpty && !isSilDay }
}

extension AppModel {
    /// Today's Khmer lunar date for Home's header: a sample, from the same provider as the Calendar.
    public var todayLunarDate: KhmerLunarDate {
        SampleKhmerCalendar.lunarDate(of: today, calendar: calendar)
    }

    /// Today, as this phone's clock has it.
    public var currentDay: Date { today }

    /// The last year whose official public holidays this build knows.
    public var publicHolidaysKnownThrough: Int { CambodianPublicHolidays.coveredYears.upperBound }

    /// Lunar dates and Sil days are samples until the cultural advisor's rules arrive.
    public var silDaysAreSample: Bool { SampleKhmerCalendar.isSample }

    /// Short weekday names in grid order, starting on the calendar's first weekday.
    public var calendarWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    private var shownMonth: Date {
        calendarShownMonth ?? firstOfMonth(today)
    }

    private var selectedDay: Date {
        calendarSelectedDay ?? today
    }

    public var calendarMonth: CalendarMonth {
        let first = shownMonth
        let leading = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let cells = Int((Double(leading + daysInMonth) / 7).rounded(.up)) * 7
        let gridStart = calendar.date(byAdding: .day, value: -leading, to: first) ?? first
        let holidays = holidaysByDay(around: first)
        let days = (0..<cells).compactMap { offset -> CalendarDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else { return nil }
            return CalendarDay(
                date: date,
                isInMonth: calendar.isDate(date, equalTo: first, toGranularity: .month),
                isToday: date == today,
                isSelected: date == selectedDay,
                holiday: holidays[date],
                hasMoments: !moments(on: date).isEmpty,
                isSilDay: SampleKhmerCalendar.isSilDay(date, calendar: calendar)
            )
        }
        return CalendarMonth(firstDay: first, weeks: stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) })
    }

    public var selectedCalendarDay: CalendarDayDetails {
        let day = selectedDay
        return CalendarDayDetails(
            date: day,
            lunarDate: SampleKhmerCalendar.lunarDate(of: day, calendar: calendar),
            holiday: holidaysByDay(around: day)[day],
            moments: moments(on: day),
            isSilDay: SampleKhmerCalendar.isSilDay(day, calendar: calendar)
        )
    }

    public func selectCalendarDay(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        calendarSelectedDay = day
        calendarShownMonth = firstOfMonth(day)
    }

    public func showNextCalendarMonth() { moveCalendar(byMonths: 1) }
    public func showPreviousCalendarMonth() { moveCalendar(byMonths: -1) }

    /// The next public holidays from today, soonest first.
    public func upcomingPublicHolidays(limit: Int) -> [PublicHoliday] {
        let year = calendar.component(.year, from: today)
        return Array(publicHolidays(in: year...year + 1).filter { $0.date >= today }.prefix(limit))
    }

    private func moveCalendar(byMonths months: Int) {
        calendarShownMonth = calendar.date(byAdding: .month, value: months, to: shownMonth).map(firstOfMonth)
    }

    private func firstOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
    }

    /// The Moments that fall on `day` (each comes back every year), Quick hide respected.
    private func moments(on day: Date) -> [Moment] {
        visibleMoments.filter { nextOccurrence(of: $0, onOrAfter: day) == day }
    }

    private func holidaysByDay(around date: Date) -> [Date: PublicHoliday] {
        let year = calendar.component(.year, from: date)
        return Dictionary(publicHolidays(in: year - 1...year + 1).map { ($0.date, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func publicHolidays(in years: ClosedRange<Int>) -> [PublicHoliday] {
        years.flatMap { CambodianPublicHolidays.days(in: $0, calendar: calendar) }
    }
}

// MARK: - Lucky Day Planner

extension AppModel {
    /// The planner's suggestions are samples until the cultural advisor's rules arrive.
    public var luckyDaysAreSample: Bool { SampleLuckyDays.isSample }

    /// My birth date as the planner uses it: my profile's, unless changed here.
    public var plannerMyBirthDate: Date? {
        get { plannerMyBirthDateOverride ?? birthDate }
        set { plannerMyBirthDateOverride = newValue }
    }

    /// My Partner's birth date, kept on this phone for next time. Entered while Taken, it belongs to that
    /// Relationship and is forgotten when it ends.
    public var plannerPartnerBirthDate: Date? {
        get { phone.partnerBirthDate }
        set {
            var updated = phone
            updated.partnerBirthDate = newValue.map { calendar.startOfDay(for: $0) }
            if case .active(_, let since, _) = relationship, newValue != nil {
                updated.partnerBirthDateRelationshipSince = since
            } else if newValue == nil {
                updated.partnerBirthDateRelationshipSince = nil
            }
            phone = updated
        }
    }

    /// A birth date to start the pickers from: 25 years before today.
    public var plannerDefaultBirthDate: Date {
        calendar.date(byAdding: .year, value: -25, to: today) ?? today
    }

    /// The latest birth date a picker allows: today.
    public var plannerLatestBirthDate: Date { today }

    public func addPlannerPartnerBirthDate() {
        plannerPartnerBirthDate = plannerDefaultBirthDate
    }

    public func removePlannerPartnerBirthDate() {
        plannerPartnerBirthDate = nil
    }

    /// The sample score of each given day for `plannerEvent`, or nothing without both birth dates.
    public func luckyDayScores(for days: [Date]) -> [LuckyDay] {
        guard let mine = plannerMyBirthDate, let partner = plannerPartnerBirthDate else { return [] }
        return SampleLuckyDays.scores(for: days, event: plannerEvent, myBirthDate: mine, partnerBirthDate: partner, calendar: calendar)
    }

    /// Forgets a Partner's birth date entered during a Relationship that has since ended.
    func forgetFormerPartnersBirthDate() {
        guard let since = phone.partnerBirthDateRelationshipSince else { return }
        if case .active(_, let current, _) = relationship, current == since { return }
        var updated = phone
        updated.partnerBirthDate = nil
        updated.partnerBirthDateRelationshipSince = nil
        phone = updated
    }

    public var plannerNeedsPartnerBirthDate: Bool { plannerPartnerBirthDate == nil }

    /// The best days for `plannerEvent` in the next six months, best first. Worked out on the phone:
    /// no birth date goes to Trustee.
    public var luckyDays: [LuckyDay] {
        guard let mine = plannerMyBirthDate, let partner = plannerPartnerBirthDate else { return [] }
        return SampleLuckyDays.suggest(plannerEvent, myBirthDate: mine, partnerBirthDate: partner, after: today, calendar: calendar)
    }
}
