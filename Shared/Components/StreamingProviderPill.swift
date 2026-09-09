import SwiftUI

public struct StreamingProviderPill: View {
    let provider: StreamingProvider
    let isSelected: Bool
    let action: () -> Void
    
    public init(provider: StreamingProvider, isSelected: Bool, action: @escaping () -> Void) {
        self.provider = provider
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Text(provider.name)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .black : .white.opacity(0.8))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.12), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}
