import Foundation

/// Codable mirror of the web's `speakerSchema` (in `src/lib/types/meeting.ts`),
/// limited to the fields the iOS schedule card reads. Stored in Firestore at
/// `wards/{wardId}/meetings/{date}/speakers/{speakerId}`.
///
/// All fields are optional except `name` so a partial / draft doc still
/// decodes — mirrors the web's lenient schema (`name.min(1)`, others
/// optional or with `.catch` defaults).
public struct Speaker: Codable, Sendable, Hashable {
    public let name: String
    public let email: String?
    public let phone: String?
    public let topic: String?
    /// Free-form lifecycle string from the backend — `"planned" | "invited" |
    /// "confirmed" | "declined"`. We keep it raw so a future status the web
    /// adds doesn't crash the parse; the UI maps via `StatusBadge.Tone`.
    public let status: String?
    public let role: String?
    /// 0-based slot position on the program. `nil` when the doc is a
    /// draft that hasn't been ordered yet — those sort to the end.
    public let order: Int?
    /// Provenance of the most recent status write. Stamped by every
    /// status mutation (manual via pills, speaker-response via Apply).
    /// Free-form so a future source value doesn't crash the parse.
    /// Known values: `"manual"`, `"speaker-response"`.
    public let statusSource: String?
    /// Firebase Auth uid of whoever last stamped status (a bishop
    /// uid for either source — `applyResponseToSpeaker` stamps the
    /// applying bishop, not the speaker). The chat-banner pill
    /// confirm dialog uses this for the "X set the current status"
    /// override prefix.
    public let statusSetBy: String?
    /// ISO8601 string (Firestore Timestamp sanitized by
    /// `FirestoreCollectionSource`) — when the most recent status
    /// write happened. The chat banner formats this as the date
    /// suffix on the provenance line.
    public let statusSetAt: String?
    /// `wards/{wardId}/speakerInvitations/{invitationId}` document id
    /// linking this row to its invitation snapshot. Populated by the
    /// post-callable status flip after `sendSpeakerInvitation` returns.
    /// Absent for planned speakers and pre-callable rollout docs.
    public let invitationId: String?

    public init(
        name: String,
        email: String? = nil,
        phone: String? = nil,
        topic: String? = nil,
        status: String? = nil,
        role: String? = nil,
        order: Int? = nil,
        statusSource: String? = nil,
        statusSetBy: String? = nil,
        statusSetAt: String? = nil,
        invitationId: String? = nil
    ) {
        self.name = name
        self.email = email
        self.phone = phone
        self.topic = topic
        self.status = status
        self.role = role
        self.order = order
        self.statusSource = statusSource
        self.statusSetBy = statusSetBy
        self.statusSetAt = statusSetAt
        self.invitationId = invitationId
    }

    /// What the schedule row shows beneath the speaker's name in the
    /// italic-serif subtitle slot. Falls back to "Topic of Choice"
    /// when the bishopric hasn't (yet) recorded a topic — keeps the
    /// row visually balanced and tells the bishop the speaker has
    /// freedom to choose. The letter template uses a wordier
    /// equivalent ("a topic of your choosing"); the schedule row
    /// stays terser.
    public var displayTopic: String {
        let trimmed = topic?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Topic of Choice" : trimmed
    }

    /// Stable sort: ascending by `order`, with un-ordered docs going to the
    /// end (tiebreak on `id`) so a missing `order` doesn't shuffle the list
    /// each time Firestore re-emits.
    public static func sorted(
        _ items: [CollectionItem<Speaker>]
    ) -> [CollectionItem<Speaker>] {
        items.sorted { lhs, rhs in
            switch (lhs.data.order, rhs.data.order) {
            case let (l?, r?) where l != r: return l < r
            case (nil, _?):                 return false
            case (_?, nil):                 return true
            default:                        return lhs.id < rhs.id
            }
        }
    }

    /// Two-digit zero-padded slot number — "01" aligns with "12" in the
    /// mono-eyebrow column on the schedule card.
    public static func slotLabel(forIndex index: Int) -> String {
        String(format: "%02d", index + 1)
    }

    /// Whether the meeting card should render an explicit
    /// "Add another speaker" row below the last slot. True only when
    /// the bishop has met the typical floor (e.g. 2) but hasn't
    /// reached the ceiling (e.g. 4) — below the floor the
    /// `Assign Speaker` placeholder slots already serve as the
    /// affordance, and at the ceiling there's no room to add.
    public static func canAddMore(
        assignedCount: Int,
        floor: Int,
        ceiling: Int
    ) -> Bool {
        assignedCount >= floor && assignedCount < ceiling
    }

    /// Whether the roster contains at least one speaker the bishopric
    /// has already invited and received a confirmation for. Drives the
    /// Sunday-Type menu lock — once anyone is confirmed, switching the
    /// meeting type would silently strand their commitment, so the
    /// bishop has to remove the confirmed speaker first. Mirrors the
    /// web's `hasConfirmedSpeaker` predicate in
    /// `src/features/schedule/SundayCard/SundayCard.tsx`.
    public static func hasConfirmed(_ items: [CollectionItem<Speaker>]) -> Bool {
        items.contains { $0.data.status == "confirmed" }
    }

    /// The Firestore payload for a new (or updated) speaker doc, ready
    /// to feed into `setData(merge: true)`. Empty strings are dropped
    /// rather than written so the doc reads cleanly in the emulator
    /// UI and matches the web's lenient Zod (`z.literal("")` short
    /// circuit) on the read side. The caller stamps `createdAt` /
    /// `updatedAt` with `FieldValue.serverTimestamp()` since those
    /// types live in the FirebaseFirestore module the app target
    /// imports — keeping `firestoreData` Firebase-free.
    public static func firestoreData(
        for draft: InvitationDraft,
        status: InvitationStatus,
        order: Int? = nil
    ) -> [String: Any] {
        var dict: [String: Any] = [
            "name": draft.name,
            "status": status.rawValue,
        ]
        if let role = draft.role {
            dict["role"] = role.rawValue
        }
        if let topic = draft.topic, topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            dict["topic"] = topic
        }
        if let email = draft.email, email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            dict["email"] = email
        }
        if let phone = draft.phone, phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            dict["phone"] = phone
        }
        if let order {
            dict["order"] = order
        }
        return dict
    }

    /// Build the row list a single meeting card renders: actual speakers
    /// up front (sorted by `order`), padded out with empty placeholders
    /// to `minSlotCount` so the bishop sees missing slots as "Not assigned"
    /// rather than a short list. If the roster already has more speakers
    /// than `minSlotCount`, every speaker still renders — no truncation.
    /// Mirrors `MobileSundayBody`'s `SPEAKER_SLOT_COUNT = 4` padding.
    public static func slots(
        _ items: [CollectionItem<Speaker>],
        minSlotCount: Int
    ) -> [SpeakerSlot] {
        let sortedItems = sorted(items)
        let total = max(sortedItems.count, minSlotCount)
        return (0..<total).map { idx in
            SpeakerSlot(index: idx, speaker: idx < sortedItems.count ? sortedItems[idx] : nil)
        }
    }
}

/// One speaker row on a meeting card — either a real assignment
/// (`speaker != nil`) or an empty placeholder ("Not assigned"). Identity
/// keys on the speaker's id when filled, on the slot index when empty,
/// so SwiftUI's diff stays stable as the roster fills in.
public struct SpeakerSlot: Identifiable, Sendable, Equatable {
    public let index: Int
    public let speaker: CollectionItem<Speaker>?

    public init(index: Int, speaker: CollectionItem<Speaker>?) {
        self.index = index
        self.speaker = speaker
    }

    public var id: String {
        speaker?.id ?? "empty-\(index)"
    }

    public var label: String {
        Speaker.slotLabel(forIndex: index)
    }
}
