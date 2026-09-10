import SwiftUI

public struct TVSkeletonCardView: View {
    let width: CGFloat
    let isLandscape: Bool
    
    @State private var phase: CGFloat = 0
    
    public init(width: CGFloat = 220, isLandscape: Bool = false) {
        self.width = width
        self.isLandscape = isLandscape
    }
    
    private var height: CGFloat {
        isLandscape ? (width * 9.0 / 16.0) : (width * 1.5)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.12))
                .frame(width: width, height: height)
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.0), Color.white.opacity(0.08), Color.white.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: phase * width)
                )
                .clipped()
            
            if !isLandscape {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.12))
                    .frame(width: width * 0.75, height: 14)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.08))
                    .frame(width: width * 0.45, height: 10)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 1.5
            }
        }
    }
}
