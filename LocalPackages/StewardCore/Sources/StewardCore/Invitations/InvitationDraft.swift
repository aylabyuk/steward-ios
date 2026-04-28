import Foundation

/// The validated form output. Produced by `AssignSlotFormView`,
/// consumed by `InvitationPreviewView`. Pure value type — no
/// I/O, no Firebase, no SwiftUI — so the form's behaviour is
/// fully testable from `StewardTests`.
public struct InvitationDraft: Sendable, Hashable {
    public let kind: SlotKind
    public let wardId: String
    public let meetingDate: String   // ISO YYYY-MM-DD, the meeting doc id
    public let wardName: String
    public let inviterName: String

    public let name: String
    public let email: String?
    public let phone: String?
    public let topic: String?
    public let role: SpeakerRole?

    public init(
        kind: SlotKind,
        wardId: String,
        meetingDate: String,
        wardName: String,
        inviterName: String,
        name: String,
        email: String? = nil,
        phone: String? = nil,
        topic: String? = nil,
        role: SpeakerRole? = nil
    ) {
        self.kind = kind
        self.wardId = wardId
        self.meetingDate = meetingDate
        self.wardName = wardName
        self.inviterName = inviterName
        self.name = name
        self.email = email
        self.phone = phone
        self.topic = topic
        self.role = role
    }

    public enum ValidationError: Error, Equatable {
        case nameRequired
        case invalidEmail
        case roleRequired
    }

    /// Validates the draft against the web's lenient Zod rules:
    /// `name.min(1)`, email valid-or-empty, phone free-form.
    /// Speakers additionally require a SPEAKER_ROLES selection;
    /// prayers carry their role implicitly via `kind`.
    public func validate() -> Result<InvitationDraft, ValidationError> {
        guard name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .failure(.nameRequired)
        }
        if let raw = email, raw.isEmpty == false {
            if InvitationDraft.isValidEmail(raw) == false {
                return .failure(.invalidEmail)
            }
        }
        if kind == .speaker, role == nil {
            return .failure(.roleRequired)
        }
        return .success(self)
    }

    /// Whether the share-sheet path makes sense — needs at least one
    /// channel (email or phone) the bishop could deliver through.
    /// "Mark as Invited" doesn't gate on this; sharing does.
    public var canSend: Bool {
        let hasEmail = (email?.isEmpty == false)
        let hasPhone = (phone?.isEmpty == false)
        return hasEmail || hasPhone
    }

    /// Modest RFC-5321-ish check. We don't want to reject anything the
    /// web would accept — Zod's `z.email()` is also relaxed — so this
    /// matches a single `@` with non-empty local + domain parts and a
    /// dot in the domain. Sanitization happens at send time.
    static func isValidEmail(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@") else { return false }
        let parts = trimmed.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let local = parts[0]
        let domain = parts[1]
        return local.isEmpty == false && domain.contains(".") && domain.hasPrefix(".") == false && domain.hasSuffix(".") == false
    }
}
