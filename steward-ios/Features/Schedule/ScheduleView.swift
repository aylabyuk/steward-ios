import SwiftUI
import StewardCore

#if canImport(FirebaseFirestore)
/// Mobile schedule. Calendar-driven (mirrors web's `useUpcomingMeetings`):
/// the list is the next N Sundays starting today, each rendering whether
/// or not a meeting doc exists for that date. Horizon starts at 4 weeks
/// and grows in 4-week steps as the user nears the bottom (capped at 16).
///
/// Each meeting's **date strip** is a `pinnedViews: [.sectionHeaders]`
/// section header — it sticks to the top of the scroll viewport while
/// that meeting's body scrolls past, then is replaced by the next card's
/// strip. Mirrors `MobileSundayBlock`'s `sticky top-0` strip on the web.
struct ScheduleView: View {
    let auth: AuthClient
    let wardId: String

    @State private var schedule: CollectionSubscription<Meeting>
    @State private var ward: DocSubscription<Ward>
    @State private var horizonWeeks: Int = Self.initialWeeks
    @State private var loadingMore: Bool = false
    @State private var path = NavigationPath()

    private static let initialWeeks = 4
    private static let stepWeeks = 4
    private static let maxWeeks = 16

    init(auth: AuthClient, wardId: String) {
        self.auth = auth
        self.wardId = wardId
        let path = "wards/\(wardId)/meetings"
        let source = FirestoreCollectionSource(path: path)
        self._schedule = State(initialValue: CollectionSubscription<Meeting>(
            source: source,
            decoder: { try JSONDecoder().decode(Meeting.self, from: $0) },
            path: path
        ))
        let wardSource = FirestoreDocSource(path: "wards/\(wardId)")
        self._ward = State(initialValue: DocSubscription<Ward>(
            source: wardSource,
            decoder: { try JSONDecoder().decode(Ward.self, from: $0) }
        ))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.parchment.ignoresSafeArea()
                content
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                ScheduleTopBar(
                    wardTitle: Ward.displayTitle(ward: ward.data, wardId: wardId),
                    auth: auth
                )
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SlotContext.self) { context in
                AssignSlotFormView(context: context, path: $path)
            }
            .navigationDestination(for: InvitationDraft.self) { draft in
                InvitationPreviewView(draft: draft, path: $path)
            }
        }
    }

    private func slotContext(date: String, kind: SlotKind) -> SlotContext {
        SlotContext(
            wardId: wardId,
            meetingDate: date,
            kind: kind,
            wardName: Ward.displayTitle(ward: ward.data, wardId: wardId),
            inviterName: auth.displayName ?? auth.email ?? "Bishopric"
        )
    }

    @ViewBuilder
    private var content: some View {
        if let error = schedule.error {
            errorState(error)
        } else {
            ScrollView {
                AppBarHeader(
                    eyebrow: "Sacrament meeting",
                    title: "Schedule",
                    description: "Assign speakers for the weeks ahead."
                )

                let dates = UpcomingSundays.next(from: Date(), weeks: horizonWeeks)
                let byDate = Dictionary(uniqueKeysWithValues: schedule.items.map { ($0.id, $0.data) })

                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(dates, id: \.self) { date in
                        Section {
                            MeetingCardBody(
                                date: date,
                                meeting: byDate[date],
                                wardId: wardId,
                                onAssign: { kind in
                                    path.append(slotContext(date: date, kind: kind))
                                }
                            )
                        } header: {
                            MeetingCardHeader(date: date, meeting: byDate[date], wardId: wardId)
                        }
                    }
                    horizonFooter
                }
                .padding(.bottom, Spacing.s12)
            }
        }
    }

    /// "Loading…" sentinel at the bottom of the list. Mirrors the web's
    /// IntersectionObserver — when this row appears on screen, advance
    /// the horizon by `stepWeeks` (capped at `maxWeeks`) after a short
    /// delay so the growth doesn't feel instantaneous.
    @ViewBuilder
    private var horizonFooter: some View {
        if horizonWeeks < Self.maxWeeks {
            Text(loadingMore ? "Loading…" : "")
                .font(.monoEyebrow)
                .tracking(1.4)
                .foregroundStyle(Color.walnut3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.s6)
                .onAppear { advanceHorizon() }
        } else {
            Text("Showing up to 16 weeks ahead")
                .font(.monoEyebrow)
                .tracking(1.4)
                .foregroundStyle(Color.walnut3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.s6)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.border.opacity(0.6)).frame(height: 0.5)
                }
        }
    }

    private func advanceHorizon() {
        guard horizonWeeks < Self.maxWeeks, loadingMore == false else { return }
        loadingMore = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            horizonWeeks = min(horizonWeeks + Self.stepWeeks, Self.maxWeeks)
            loadingMore = false
        }
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
}
#endif
