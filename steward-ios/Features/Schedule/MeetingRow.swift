import SwiftUI
import StewardCore

struct MeetingRow: View {
    let date: String  // YYYY-MM-DD (Firestore document ID)
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(displayDate)
                    .font(.headline)
                Spacer()
                Text(meeting.meetingTypeLabel)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary, in: .capsule)
                    .accessibilityLabel("Meeting type: \(meeting.meetingTypeLabel)")
            }
            if let conducting = meeting.conductingName {
                Text("Conducting: \(conducting)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let presiding = meeting.presidingName {
                Text("Presiding: \(presiding)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let status = meeting.status, status.isEmpty == false {
                Text(status.replacing("_", with: " ").capitalized)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var displayDate: String {
        let strategy = Date.ISO8601FormatStyle()
            .year().month().day()
        if let parsed = try? Date(date, strategy: strategy) {
            return parsed.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
        return date
    }
}

#Preview {
    List {
        MeetingRow(
            date: "2026-04-28",
            meeting: Meeting(
                meetingType: "regular",
                status: "approved",
                conducting: .init(person: .init(name: "Bishop Smith")),
                presiding: .init(person: .init(name: "President Jones"))
            )
        )
        MeetingRow(
            date: "2026-05-05",
            meeting: Meeting(
                meetingType: "fast",
                status: "draft",
                conducting: .init(person: .init(name: "Brother Lee"))
            )
        )
    }
}
