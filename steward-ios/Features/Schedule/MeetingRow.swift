import SwiftUI
import StewardCore

struct MeetingRow: View {
    let date: String  // YYYY-MM-DD (Firestore document ID)
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            headerRow
            assignmentLines
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.border)
                .frame(height: 0.5)
        }
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s3) {
            Text(ShortDateFormatter.shortDate(fromISO8601: date))
                .font(.displaySection)
                .foregroundStyle(Color.walnut)

            if let badge = meeting.typeBadge {
                StatusBadge(label: badge.label, tone: badge.tone)
            }

            Spacer()

            if let status = meeting.status {
                StatusBadge(rawStatus: status)
            }
        }
    }

    @ViewBuilder
    private var assignmentLines: some View {
        if meeting.conductingName != nil || meeting.presidingName != nil {
            VStack(alignment: .leading, spacing: 2) {
                if let conducting = meeting.conductingName {
                    AssignmentLine(role: "Conducting", name: conducting)
                }
                if let presiding = meeting.presidingName {
                    AssignmentLine(role: "Presiding", name: presiding)
                }
            }
        }
    }

}

private struct AssignmentLine: View {
    let role: String
    let name: String
    var body: some View {
        HStack(spacing: Spacing.s2) {
            Text(role.uppercased())
                .font(.monoMicro)
                .tracking(1.2)
                .foregroundStyle(Color.brassDeep)
                .frame(width: 80, alignment: .leading)
            Text(name)
                .font(.bodySmall)
                .foregroundStyle(Color.walnut2)
        }
    }
}

#Preview("Light") {
    VStack(spacing: 0) {
        MeetingRow(
            date: "2026-04-26",
            meeting: Meeting(
                meetingType: "regular", status: "approved",
                conducting: .init(person: .init(name: "Bishop Smith")),
                presiding: .init(person: .init(name: "President Jones"))
            )
        )
        MeetingRow(
            date: "2026-05-03",
            meeting: Meeting(
                meetingType: "fast", status: "draft",
                conducting: .init(person: .init(name: "Brother Lee"))
            )
        )
        MeetingRow(
            date: "2026-05-10",
            meeting: Meeting(meetingType: "regular", status: "pending_approval")
        )
        MeetingRow(
            date: "2026-05-17",
            meeting: Meeting(meetingType: "stake", status: "published")
        )
    }
    .background(Color.parchment)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    MeetingRow(
        date: "2026-04-26",
        meeting: Meeting(
            meetingType: "regular", status: "approved",
            conducting: .init(person: .init(name: "Bishop Smith")),
            presiding: .init(person: .init(name: "President Jones"))
        )
    )
    .background(Color.parchment)
    .preferredColorScheme(.dark)
}
