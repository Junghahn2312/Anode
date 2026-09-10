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
    public static let primeVideo = StreamingProvider(id: 9, name: "Prime Video", brandColorHex: "#00A8E1")
    public static let disneyPlus = StreamingProvider(id: 337, name: "Disney+", brandColorHex: "#113CCF")
    public static let appleTV = StreamingProvider(id: 350, name: "Apple TV+", brandColorHex: "#FFFFFF")
    public static let paramountPlus = StreamingProvider(id: 531, name: "Paramount+", brandColorHex: "#0064FF")
    public static let nowTV = StreamingProvider(id: 39, name: "NOW", brandColorHex: "#007A53")
    public static let bbcIPlayer = StreamingProvider(id: 38, name: "BBC iPlayer", brandColorHex: "#FF005A")
    public static let itvx = StreamingProvider(id: 41, name: "ITVX", brandColorHex: "#00FF7F")
    public static let channel4 = StreamingProvider(id: 103, name: "Channel 4", brandColorHex: "#A0F000")
    public static let skyGo = StreamingProvider(id: 29, name: "Sky Go", brandColorHex: "#0047FF")
    public static let mubi = StreamingProvider(id: 11, name: "MUBI", brandColorHex: "#0F1A24")
    public static let crunchyroll = StreamingProvider(id: 283, name: "Crunchyroll", brandColorHex: "#F47521")
    public static let max = StreamingProvider(id: 1899, name: "Max", brandColorHex: "#002BE7")
    
    public static var allCases: [StreamingProvider] {
        allGlobal
    }
    
    public static let allGlobal: [StreamingProvider] = [
        .netflix,
        .primeVideo,
        .disneyPlus,
        .appleTV,
        .max,
        .paramountPlus,
        .mubi,
        .crunchyroll,
        .nowTV,
        .bbcIPlayer,
        .itvx,
        .channel4,
        .skyGo
    ]
    
    public static var allUK: [StreamingProvider] {
        allGlobal
    }
    
    public static let allMajor: [StreamingProvider] = [
        .netflix,
        .appleTV,
        .disneyPlus,
        .primeVideo,
        .paramountPlus,
        .nowTV,
        .bbcIPlayer
    ]
    
    public var brandColor: Color {
        switch id {
        case 8: return Color(red: 0.9, green: 0.05, blue: 0.08)
        case 9: return Color(red: 0.0, green: 0.66, blue: 0.88)
        case 337: return Color(red: 0.07, green: 0.24, blue: 0.81)
        case 350: return Color.white
        case 531: return Color(red: 0.0, green: 0.39, blue: 1.0)
        case 39: return Color(red: 0.0, green: 0.48, blue: 0.33)
        case 38: return Color(red: 1.0, green: 0.0, blue: 0.35)
        case 41: return Color(red: 0.0, green: 1.0, blue: 0.5)
        case 103: return Color(red: 0.63, green: 0.94, blue: 0.0)
        case 29: return Color(red: 0.0, green: 0.28, blue: 1.0)
        case 11: return Color(red: 0.2, green: 0.25, blue: 0.3)
        case 283: return Color(red: 0.96, green: 0.46, blue: 0.13)
        case 1899: return Color(red: 0.0, green: 0.17, blue: 0.91)
        default: return Color(white: 0.3)
        }
    }
}
