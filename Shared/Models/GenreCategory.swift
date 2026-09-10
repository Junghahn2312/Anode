import SwiftUI

public struct GenreCategory: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let imageURL: URL?
    public let heroBackdropURL: URL?
    public let description: String
    
    public init(id: String, name: String, imageURL: URL?, heroBackdropURL: URL?, description: String) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.heroBackdropURL = heroBackdropURL
        self.description = description
    }
    
    public static let action = GenreCategory(
        id: "action",
        name: "Action",
        imageURL: URL(string: "https://image.tmdb.org/t/p/w780/euYIwmwkmz95mnXvufEmbL6ovhA.jpg"), // Gladiator II / combat still
        heroBackdropURL: URL(string: "https://image.tmdb.org/t/p/original/euYIwmwkmz95mnXvufEmbL6ovhA.jpg"),
        description: "High-stakes thrills, explosive sequences, and relentless adrenaline."
    )
    
    public static let drama = GenreCategory(
        id: "drama",
        name: "Drama",
        imageURL: URL(string: "https://image.tmdb.org/t/p/w780/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg"), // Oppenheimer
        heroBackdropURL: URL(string: "https://image.tmdb.org/t/p/original/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg"),
        description: "Intimate character portraits, moral dilemmas, and powerful narratives."
    )
    
    public static let comedy = GenreCategory(
        id: "comedy",
        name: "Comedy",
        imageURL: URL(string: "https://image.tmdb.org/t/p/w780/tmU7GeKVybMWF9YdfZveL75z5Un.jpg"),
        heroBackdropURL: URL(string: "https://image.tmdb.org/t/p/original/tmU7GeKVybMWF9YdfZveL75z5Un.jpg"),
        description: "Sharp wit, hilarious misadventures, and lighthearted entertainment."
    )
    
    public static let thriller = GenreCategory(
        id: "thriller",
        name: "Thriller",
        imageURL: URL(string: "https://image.tmdb.org/t/p/w780/3s2j9u82L4x6Z9V5z0e7Q1r3w.jpg"), // Slow Horses / tension
        heroBackdropURL: URL(string: "https://image.tmdb.org/t/p/original/3s2j9u82L4x6Z9V5z0e7Q1r3w.jpg"),
        description: "Unrelenting suspense, psychological twists, and edge-of-your-seat tension."
    )
    
    public static let sciFi = GenreCategory(
        id: "sci-fi",
        name: "Sci-Fi",
        imageURL: URL(string: "https://image.tmdb.org/t/p/w780/xOMo8BRK7PfcJv9JCnx7s520Wio.jpg"), // Dune: Part Two
        heroBackdropURL: URL(string: "https://image.tmdb.org/t/p/original/xOMo8BRK7PfcJv9JCnx7s520Wio.jpg"),
        description: "Vast worlds, technological futures, and existential exploration."
    )
    
    public static let horror = GenreCategory(
        id: "horror",
        name: "Horror",
        imageURL: URL(string: "https://image.tmdb.org/t/p/w780/4c4k2j9u82L4x6Z9V5z0e7Q1r3w.jpg"), // Nosferatu
        heroBackdropURL: URL(string: "https://image.tmdb.org/t/p/original/4c4k2j9u82L4x6Z9V5z0e7Q1r3w.jpg"),
        description: "Chilling dread, supernatural encounters, and atmospheric terrors."
    )
    
    public static let allCurated: [GenreCategory] = [
        .action,
        .drama,
        .comedy,
        .thriller,
        .sciFi,
        .horror
    ]
}
