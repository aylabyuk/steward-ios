import Foundation

/// One option in the ⋯-menu's "Sunday Type" radio group on each meeting
/// card. Mirrors the web's `MEETING_TYPES` enum and `TYPE_LABELS` map
/// (in `src/lib/types/meeting.ts` + `src/features/meetings/utils/meetingLabels.ts`).
///
/// Kept as a static list rather than a CaseIterable enum so the iOS
/// `Meeting.meetingType` field stays a permissive `String?` — a future
/// type the web adds shouldn't crash the iOS parse, just render with
/// the raw string until iOS catches up.
public struct SundayTypeOption: Sendable, Equatable, Identifiable {
    public let raw: String
    public let label: String

    public var id: String { raw }

    public init(raw: String, label: String) {
        self.raw = raw
        self.label = label
    }

    public static let all: [SundayTypeOption] = [
        .init(raw: "regular", label: "Regular"),
        .init(raw: "fast", label: "Fast & Testimony"),
        .init(raw: "stake", label: "Stake Conference"),
        .init(raw: "general", label: "General Conference"),
    ]
}
