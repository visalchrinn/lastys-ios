import Foundation

/// A domain scenario written once as data and run against both the fake and the real Trustee.
///
/// Each step is one request from one phone: an action, its arguments, and the fields the
/// response must contain. A failed request responds with `{ "error": "<code>" }`.
/// See `/scenarios/README.md` for the format.
public struct Scenario: Decodable, Sendable, CustomStringConvertible {
    public struct Step: Decodable, Sendable {
        /// Which phone sends the request. Each phone holds at most one Lastys ID.
        public let phone: String
        /// The action name, e.g. `create-lastys-id`.
        public let action: String
        public let arguments: [String: String]
        /// Fields the response must contain with exactly these values. Other fields are ignored.
        public let expect: [String: String]

        enum CodingKeys: String, CodingKey {
            case phone, action = "do", arguments = "with", expect
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            phone = try c.decode(String.self, forKey: .phone)
            action = try c.decode(String.self, forKey: .action)
            arguments = try c.decodeIfPresent([String: String].self, forKey: .arguments) ?? [:]
            expect = try c.decodeIfPresent([String: String].self, forKey: .expect) ?? [:]
        }
    }

    public let name: String
    public let steps: [Step]

    public var description: String { name }

    public static func decode(_ json: String) throws -> Scenario {
        try JSONDecoder().decode(Scenario.self, from: Data(json.utf8))
    }

    public static func load(from url: URL) throws -> Scenario {
        try JSONDecoder().decode(Scenario.self, from: Data(contentsOf: url))
    }
}

public struct ScenarioFailure: Equatable, Sendable, CustomStringConvertible {
    /// 1-based step number.
    public let step: Int
    public let message: String

    public init(step: Int, message: String) {
        self.step = step
        self.message = message
    }

    public var description: String { "step \(step): \(message)" }
}
