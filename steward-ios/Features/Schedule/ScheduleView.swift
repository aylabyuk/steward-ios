import SwiftUI
import StewardCore

#if canImport(FirebaseFirestore)
struct ScheduleView: View {
    let auth: AuthClient
    let wardId: String

    @State private var schedule: CollectionSubscription<Meeting>

    init(auth: AuthClient, wardId: String = "stv1") {
        self.auth = auth
        self.wardId = wardId
        let path = "wards/\(wardId)/meetings"
        let source = FirestoreCollectionSource(path: path)
        self._schedule = State(initialValue: CollectionSubscription<Meeting>(
            source: source,
            decoder: { try JSONDecoder().decode(Meeting.self, from: $0) },
            path: path
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Schedule")
                .toolbar { signOutToolbar }
        }
    }

    @ViewBuilder
    private var content: some View {
        if schedule.loading {
            ProgressView("Loading schedule…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = schedule.error {
            ContentUnavailableView(
                "Couldn't load schedule",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription)
            )
        } else if schedule.items.isEmpty {
            ContentUnavailableView(
                "No meetings yet",
                systemImage: "calendar",
                description: Text("Add meetings on the web to see them here.")
            )
        } else {
            List(sortedItems) { item in
                MeetingRow(date: item.id, meeting: item.data)
            }
        }
    }

    private var sortedItems: [CollectionItem<Meeting>] {
        // Document IDs are ISO date strings (YYYY-MM-DD), so lexicographic
        // sort matches chronological. Most recent first.
        schedule.items.sorted { $0.id > $1.id }
    }

    @ToolbarContentBuilder
    private var signOutToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Sign out", action: auth.signOut)
        }
    }
}
#endif
