import SwiftUI

public struct StreamingProvider: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let logoPath: String?
    public let brandColorHex: String
    
    public init(id: Int, name: String, logoPath: String? = nil, brandColorHex: String = "#333333") {
        self.id = id
        self.name = name
        self.logoPath = logoPath
        self.brandColorHex = brandColorHex
    }
    
    public static let netflix = StreamingProvider(id: 8, name: "Netflix", brandColorHex: "#E50914")
    public static let appleTV = StreamingProvider(id: 350, name: "Apple TV+", brandColorHex: "#FFFFFF")
    public static let disneyPlus = StreamingProvider(id: 337, name: "Disney+", brandColorHex: "#113CCF")
    public static let primeVideo = StreamingProvider(id: 9, name: "Prime Video", brandColorHex: "#00A8E1")
    public static let max = StreamingProvider(id: 1899, name: "Max", brandColorHex: "#002BE7")
    
    public static let allMajor: [StreamingProvider] = [
        .netflix,
        .appleTV,
        .disneyPlus,
        .primeVideo,
        .max
    ]
}
