import SwiftUI

public struct TVMediaCardView: View {
    let item: MediaItem
    let width: CGFloat
    let showCinemaBadge: Bool
    let onFocus: ((MediaItem) -> Void)?
    
    @Environment(\.isFocused) private var isFocused: Bool
    @ObservedObject private var watchlist = WatchlistStore.shared
    
    public init(
        item: MediaItem,
        width: CGFloat = 220,
        showCinemaBadge: Bool = false,
        onFocus: ((MediaItem) -> Void)? = nil
    ) {
        self.item = item
        self.width = width
        self.showCinemaBadge = showCinemaBadge
        self.onFocus = onFocus
    }
    
    private var height: CGFloat {
        width * 1.5
    }
    
    public var body: some View {
        TVExpandingMediaCardView(
            item: item,
            normalWidth: width,
            showCinemaBadge: showCinemaBadge,
            onFocus: onFocus
        )
    }
}

public struct TVCardButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .focusEffectDisabled()
    }
}

public extension ButtonStyle where Self == TVCardButtonStyle {
    static var tvCard: TVCardButtonStyle { TVCardButtonStyle() }
}
