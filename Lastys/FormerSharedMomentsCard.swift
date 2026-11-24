import LastysCore
import SwiftUI

/// After a Relationship ends: my copy of what my former Partner shared, to keep, export or delete.
/// What I decide never touches their own Moments.
struct FormerSharedMomentsCard: View {
    @Environment(AppModel.self) private var model
    @State private var exportFile: URL?
    @State private var confirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Our Shared Moments")
                .font(.jakarta(17, .bold))
            Text("A Relationship of yours ended. Decide about your copy of the \(model.formerSharedMoments.count) Moments shared in it: keep them, export them, or delete them. Your former Partner decides about theirs.")
                .font(.jakarta(13))
                .foregroundStyle(Theme.muted)
            ForEach(model.formerSharedMoments) { moment in
                HStack {
                    Text(verbatim: moment.title).font(.jakarta(14, .semibold))
                    Spacer()
                    Text(moment.date, format: .dateTime.day().month(.abbreviated).year())
                        .font(.jakarta(13))
                        .foregroundStyle(Theme.muted)
                }
            }
            Button("Keep them") { Task { await model.keepFormerSharedMoments() } }
                .buttonStyle(PrimaryButtonStyle())
            if let exportFile {
                ShareLink(item: exportFile) {
                    Label("Export as a calendar file", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(GhostButtonStyle())
            }
            Button("Delete my copy", role: .destructive) { confirmingDelete = true }
                .buttonStyle(GhostButtonStyle())
            if let problem = model.sharingProblem {
                Text(problem.message)
                    .font(.jakarta(13, .medium))
                    .foregroundStyle(Theme.roseDeep)
            }
        }
        .card(padding: 20)
        .task(id: model.formerSharedMoments.map(\.id)) { exportFile = writeExportFile() }
        .confirmationDialog("Delete your copy of these Moments?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete my copy", role: .destructive) { Task { await model.deleteFormerSharedMoments() } }
        } message: {
            Text("This deletes your own Moments that were shared, too. Your former Partner keeps their copy.")
        }
    }

    /// The .ics file in a temporary folder, ready for the share sheet.
    private func writeExportFile() -> URL? {
        let url = FileManager.default.temporaryDirectory.appending(path: "Lastys Shared Moments.ics")
        do {
            try Data(model.formerSharedMomentsCalendar().utf8).write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

extension SharingProblem {
    var message: LocalizedStringKey {
        switch self {
        case .needsInternet: return "Shared Moments go through Lastys, so this needs an internet connection."
        case .couldNotReachLastys: return "Couldn't reach Lastys. Try again."
        }
    }
}
