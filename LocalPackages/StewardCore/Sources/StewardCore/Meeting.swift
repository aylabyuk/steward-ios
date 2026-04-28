import Foundation

/// Codable mirror of a subset of `sacramentMeetingSchema` from the web at
/// `src/lib/types/meeting.ts`. All fields are optional so a partially-populated
/// document (or one with new fields the iOS app doesn't know about yet) decodes
/// cleanly. The full schema is far richer — flesh out as Phase 1 features land.
public struct Meeting: Codable, Sendable, Equatable {
    public let meetingType: String?
    public let status: String?
    public let conducting: Assignment?
    public let presiding: Assignment?
    public let openingHymn: Hymn?
    public let sacramentHymn: Hymn?
    public let closingHymn: Hymn?

    public init(
        meetingType: String? = nil,
        status: String? = nil,
        conducting: Assignment? = nil,
        presiding: Assignment? = nil,
        openingHymn: Hymn? = nil,
        sacramentHymn: Hymn? = nil,
        closingHymn: Hymn? = nil
    ) {
        self.meetingType = meetingType
        self.status = status
        self.conducting = conducting
        self.presiding = presiding
        self.openingHymn = openingHymn
        self.sacramentHymn = sacramentHymn
        self.closingHymn = closingHymn
    }

    public struct Assignment: Codable, Sendable, Equatable {
        public let person: Person?
        public let confirmed: Bool?
        public init(person: Person? = nil, confirmed: Bool? = nil) {
            self.person = person
            self.confirmed = confirmed
        }
    }

    public struct Person: Codable, Sendable, Equatable {
        public let name: String?
        public let email: String?
        public let phone: String?
        public init(name: String? = nil, email: String? = nil, phone: String? = nil) {
            self.name = name
            self.email = email
            self.phone = phone
        }
    }

    public struct Hymn: Codable, Sendable, Equatable {
        public let number: Int?
        public let title: String?
        public init(number: Int? = nil, title: String? = nil) {
            self.number = number
            self.title = title
        }
    }
}

public extension Meeting {
    /// Display label for the meeting type. Falls back to a humanised form of
    /// the raw string so unknown types still render something.
    var meetingTypeLabel: String {
        switch meetingType {
        case "regular": "Sacrament"
        case "fast": "Fast & Testimony"
        case "stake": "Stake Conference"
        case "general": "General Conference"
        case let other?: other.capitalized
        case nil: "Meeting"
        }
    }

    var conductingName: String? {
        conducting?.person?.name
    }

    var presidingName: String? {
        presiding?.person?.name
    }
}
