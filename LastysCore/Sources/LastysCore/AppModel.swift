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
    public var relationship: RelationshipStatus { phone.relationship }
    public private(set) var moments: [Moment]

    /// What this phone keeps between launches. Every change is saved straight away.
    private var phone: PhoneState {
        didSet { store.save(phone) }
    }

    @ObservationIgnored private let phoneKey: PhoneKey
    @ObservationIgnored private let trustee: TrusteeClient
    @ObservationIgnored private let store: PhoneStore
    @ObservationIgnored private let connectivity: Connectivity
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: () -> Date

    public init(
        phoneKey: PhoneKey,
        trustee: TrusteeClient,
        store: PhoneStore,
        connectivity: Connectivity,
        moments: [Moment] = [],
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.phoneKey = phoneKey
        self.trustee = trustee
        self.store = store
        self.connectivity = connectivity
        self.moments = moments
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

    /// Which day of the Relationship `date` falls on: day 1 is the day it started.
    public func dayTogether(on date: Date) -> Int? {
        guard case .active(_, let since) = relationship else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: since), to: calendar.startOfDay(for: date)).day ?? 0
        return days + 1
    }

    /// Loads this Lastys ID's current status from Trustee.
    public func start() async {
        guard phone.lastysID != nil else { return }
        do {
            phone.relationship = try await trustee.relationshipStatus()
        } catch {
            // Errors surface in later slices; for now the last known state stays on screen.
        }
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

    // MARK: Moments

    /// The start of today on this phone.
    private var today: Date { calendar.startOfDay(for: now()) }

    /// The next three Moments from today, soonest first.
    public var upcomingMoments: [Moment] {
        Array(moments.filter(isUpcoming).sorted { $0.date < $1.date }.prefix(3))
    }

    /// Every Moment, newest first.
    public var timeline: [Moment] {
        moments.sorted { $0.date > $1.date }
    }

    public func isUpcoming(_ moment: Moment) -> Bool {
        moment.date >= today
    }

    /// Whole days from today until the Moment; 0 means today.
    public func daysUntil(_ moment: Moment) -> Int {
        calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: moment.date)).day ?? 0
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
