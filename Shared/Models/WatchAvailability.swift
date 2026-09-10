import Foundation

public struct PurchaseOption: Identifiable, Codable, Hashable, Sendable {
    public var id: String { "\(providerName)-\(price)" }
    public let providerName: String
    public let price: String
    public let quality: String?
    
    public init(providerName: String, price: String, quality: String? = "4K") {
        self.providerName = providerName
        self.price = price
        self.quality = quality
    }
}

public struct WatchAvailability: Codable, Hashable, Sendable {
    public let subscriptions: [StreamingProvider]
    public let rentOptions: [PurchaseOption]
    public let buyOptions: [PurchaseOption]
    public let cinemaStatus: String?
    public let attribution: String
    
    public init(
        subscriptions: [StreamingProvider] = [],
        rentOptions: [PurchaseOption] = [],
        buyOptions: [PurchaseOption] = [],
        cinemaStatus: String? = nil,
        attribution: String = "Streaming availability provided by JustWatch via TMDB"
    ) {
        self.subscriptions = subscriptions
        self.rentOptions = rentOptions
        self.buyOptions = buyOptions
        self.cinemaStatus = cinemaStatus
        self.attribution = attribution
    }
    
    public var hasAnyAvailability: Bool {
        !subscriptions.isEmpty || !rentOptions.isEmpty || !buyOptions.isEmpty || cinemaStatus != nil
    }
}
