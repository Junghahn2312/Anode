import Foundation

public struct CastMember: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let character: String
    public let profilePath: String?
    
    public init(id: Int, name: String, character: String, profilePath: String? = nil) {
        self.id = id
        self.name = name
        self.character = character
        self.profilePath = profilePath
    }
}
