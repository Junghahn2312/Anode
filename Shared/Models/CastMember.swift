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
    
    public var profileURL: URL? {
        guard let profilePath else { return nil }
        if profilePath.hasPrefix("http") { return URL(string: profilePath) }
        return URL(string: "https://image.tmdb.org/t/p/w185\(profilePath)")
    }
    
    public var highResProfileURL: URL? {
        guard let profilePath else { return nil }
        if profilePath.hasPrefix("http") { return URL(string: profilePath) }
        return URL(string: "https://image.tmdb.org/t/p/w500\(profilePath)")
    }
}

public struct PersonDetail: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let biography: String?
    public let profilePath: String?
    public let knownForDepartment: String?
    public let birthday: String?
    public let placeOfBirth: String?
    
    public init(
        id: Int,
        name: String,
        biography: String? = nil,
        profilePath: String? = nil,
        knownForDepartment: String? = nil,
        birthday: String? = nil,
        placeOfBirth: String? = nil
    ) {
        self.id = id
        self.name = name
        self.biography = biography
        self.profilePath = profilePath
        self.knownForDepartment = knownForDepartment
        self.birthday = birthday
        self.placeOfBirth = placeOfBirth
    }
    
    public var profileURL: URL? {
        guard let profilePath else { return nil }
        if profilePath.hasPrefix("http") { return URL(string: profilePath) }
        return URL(string: "https://image.tmdb.org/t/p/w500\(profilePath)")
    }
}
