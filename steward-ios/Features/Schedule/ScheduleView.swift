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
        ZStack(alignment: .top) {
            Color.parchment.ignoresSafeArea()
            content
            stickyToolbar
        }
    }

    @ViewBuilder
    private var content: some View {
        if schedule.loading {
            loadingState
        } else if let error = schedule.error {
            errorState(error)
        } else if schedule.items.isEmpty {
            emptyState
        } else {
            ScrollView {
                AppBarHeader(
                    eyebrow: "Ward administration",
                    title: "Schedule",
                    description: "Upcoming sacrament meetings."
                )
                .padding(.top, Spacing.s12)  // leave room for the glass toolbar

                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(ScheduleSections.groupByMonth(schedule.items), id: \.title) { section in
                        Section {
                            ForEach(section.items) { item in
                                MeetingRow(date: item.id, meeting: item.data)
                            }
                        } header: {
                            monthHeader(section.title)
                        }
                    }
                }
                .padding(.bottom, Spacing.s12)
            }
        }
    }

    private var stickyToolbar: some View {
        HStack {
            Spacer()
            Button("Sign out", action: auth.signOut)
                .font(.monoEyebrow)
                .tracking(1.4)
                .foregroundStyle(Color.walnut2)
                .padding(.horizontal, Spacing.s3)
                .padding(.vertical, Spacing.s2)
                .glassEffect(.regular.interactive(), in: .capsule)
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s2)
    }

    private func monthHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.monoEyebrow)
                .tracking(1.6)
                .foregroundStyle(Color.brassDeep)
            Spacer()
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s5)
        .padding(.bottom, Spacing.s2)
        .background(Color.parchment.opacity(0.95))
    }

    private var loadingState: some View {
        VStack(spacing: Spacing.s3) {
            ProgressView()
            Text("Loading schedule…")
                .font(.bodySmall)
                .foregroundStyle(Color.walnut2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ error: Error) -> some View {
        VStack(spacing: Spacing.s3) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(Color.bordeaux)
            Text("Couldn't load schedule")
                .font(.displaySection)
                .foregroundStyle(Color.walnut)
            Text(error.localizedDescription)
                .font(.bodySmall)
                .foregroundStyle(Color.walnut2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.s8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.s3) {
            Image(systemName: "calendar")
                .font(.system(size: 36))
                .foregroundStyle(Color.walnut3)
            Text("No meetings yet")
                .font(.displaySection)
                .foregroundStyle(Color.walnut)
            Text("Add meetings on the web to see them here.")
                .font(.bodySmall)
                .foregroundStyle(Color.walnut2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}
#endif
