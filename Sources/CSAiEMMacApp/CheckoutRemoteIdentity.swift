import Foundation

/// A sanitized identity claimed by a checkout's remote configuration. This is
/// not live provider verification, a redirect resolution, or deletion authority.
struct CheckoutRemoteIdentity: Codable, Equatable, Sendable {
  let host: String
  let owner: String
  let repository: String

  var groupingKey: String {
    "\(host)/\(owner.lowercased())/\(repository.lowercased())"
  }

  var browserURL: String { "https://\(host)/\(owner)/\(repository)" }

  private init(host: String, owner: String, repository: String) {
    self.host = host
    self.owner = owner
    self.repository = repository
  }

  static func parse(_ raw: String?) -> Self? {
    guard let raw else { return nil }
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, value.utf8.count <= 8_192,
          value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
          !value.contains("\\") else { return nil }

    let components: URLComponents
    if value.contains("://") {
      guard let parsed = URLComponents(string: value) else { return nil }
      components = parsed
    } else {
      // Git's SCP form is not a URL. Convert it to SSH syntax before parsing;
      // local paths and arbitrary host aliases do not establish provider IDs.
      let expression = #"^(?:[^@/\s]+@)?([A-Za-z0-9.-]+):(.+)$"#
      let scpValue = String(value.prefix { $0 != "?" && $0 != "#" })
      let authorityStart = scpValue.lastIndex(of: "@").map { scpValue.index(after: $0) } ?? scpValue.startIndex
      guard let match = scpValue.range(of: expression, options: .regularExpression),
            match == (scpValue.startIndex..<scpValue.endIndex),
            let separator = scpValue[authorityStart...].firstIndex(of: ":"),
            let parsed = URLComponents(string: "ssh://" + String(scpValue[..<separator]) + "/" + String(scpValue[scpValue.index(after: separator)...])) else { return nil }
      components = parsed
    }

    guard let scheme = components.scheme?.lowercased(),
          let defaultPort = ["https": 443, "http": 80, "ssh": 22, "git": 9418][scheme],
          components.port == nil || components.port == defaultPort,
          let rawHost = components.host else { return nil }
    var host = rawHost.lowercased()
    if host.hasSuffix(".") { host.removeLast() }
    guard isSafeHost(host) else { return nil }

    // User info, query parameters, and fragments are deliberately never copied
    // into any identity or display field. Decode path escapes once, then require
    // exactly two safe components so encoded separators/traversal cannot alias.
    guard components.percentEncodedPath.range(of: #"%(?:2f|5c)"#, options: [.regularExpression, .caseInsensitive]) == nil else { return nil }
    let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let parts = path.split(separator: "/", omittingEmptySubsequences: false)
    guard parts.count == 2 else { return nil }
    let owner = String(parts[0])
    var repository = String(parts[1])
    if repository.lowercased().hasSuffix(".git") { repository.removeLast(4) }
    guard isSafeComponent(owner), isSafeComponent(repository) else { return nil }
    return Self(host: host, owner: owner, repository: repository)
  }

  private static func isSafeHost(_ host: String) -> Bool {
    guard host.count <= 253, host.contains("."),
          host.range(of: #"^[A-Za-z0-9.-]+$"#, options: .regularExpression) != nil else { return false }
    let labels = host.split(separator: ".", omittingEmptySubsequences: false)
    guard !labels.allSatisfy({ $0.allSatisfy(\.isNumber) }) else { return false }
    return labels.allSatisfy { label in
      !label.isEmpty && label.count <= 63 && label.first != "-" && label.last != "-"
    }
  }

  private static func isSafeComponent(_ component: String) -> Bool {
    !component.isEmpty && component.utf8.count <= 255 && component != "." && component != ".." &&
      component.range(of: #"^[A-Za-z0-9_.-]+$"#, options: .regularExpression) != nil
  }

  private enum CodingKeys: String, CodingKey {
    case host, owner, repository, groupingKey, browserURL
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let host = try container.decode(String.self, forKey: .host)
    let owner = try container.decode(String.self, forKey: .owner)
    let repository = try container.decode(String.self, forKey: .repository)
    guard host == host.lowercased(), Self.isSafeHost(host),
          Self.isSafeComponent(owner), Self.isSafeComponent(repository) else {
      throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid sanitized checkout identity."))
    }
    self.init(host: host, owner: owner, repository: repository)
    if let storedKey = try container.decodeIfPresent(String.self, forKey: .groupingKey), storedKey != groupingKey {
      throw DecodingError.dataCorruptedError(forKey: .groupingKey, in: container, debugDescription: "Checkout identity key does not match its components.")
    }
    if let storedURL = try container.decodeIfPresent(String.self, forKey: .browserURL), storedURL != browserURL {
      throw DecodingError.dataCorruptedError(forKey: .browserURL, in: container, debugDescription: "Checkout display URL does not match its components.")
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(host, forKey: .host)
    try container.encode(owner, forKey: .owner)
    try container.encode(repository, forKey: .repository)
    try container.encode(groupingKey, forKey: .groupingKey)
    try container.encode(browserURL, forKey: .browserURL)
  }
}

enum CheckoutIdentityRelation: String, Codable, Sendable {
  case sameOrigin
  case differentOrigins
  case unknown

  static func compare(_ firstRemote: String?, _ secondRemote: String?) -> Self {
    guard let first = CheckoutRemoteIdentity.parse(firstRemote),
          let second = CheckoutRemoteIdentity.parse(secondRemote) else { return .unknown }
    return first.groupingKey == second.groupingKey ? .sameOrigin : .differentOrigins
  }
}
