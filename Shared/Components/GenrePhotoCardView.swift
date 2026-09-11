import SwiftUI

public struct GenrePhotoCardView: View {
    let genre: GenreCategory
    let width: CGFloat
    let onFocus: ((GenreCategory) -> Void)?
    
    #if os(tvOS)
    @FocusState private var isFocused: Bool
    #endif
    
    public init(
        genre: GenreCategory,
        width: CGFloat = 260,
        onFocus: ((GenreCategory) -> Void)? = nil
    ) {
        self.genre = genre
        self.width = width
        self.onFocus = onFocus
    }
    
    private var height: CGFloat {
        width * 0.5625 // 16:9 ratio
    }
    
    public var body: some View {
        ZStack(alignment: .leading) {
            // Background container
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.08))
            
            // Movie still photo on the right side
            if let imageURL = genre.imageURL {
                HStack {
                    Spacer()
                    CachedAsyncImage(url: imageURL)
                        .frame(width: width * 0.65, height: height)
                        .clipped()
                        .mask(
                            LinearGradient(
                                colors: [Color.clear, Color.black],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            
            // Bold Genre Typography on the left
            VStack(alignment: .leading, spacing: 2) {
                Text(genre.name.uppercased())
                    .font(.system(size: width * 0.09, weight: .black, design: .rounded))
                    .tracking(1.8)
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.8), radius: 4, x: 0, y: 2)
                
                Text("Genre")
                    .font(.system(size: width * 0.045, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.45))
                    .tracking(0.5)
            }
            .padding(.leading, width * 0.08)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                #if os(tvOS)
                .stroke(
                    isFocused ? Color(red: 0.0, green: 0.72, blue: 1.0) : Color.white.opacity(0.12),
                    lineWidth: isFocused ? 3.5 : 0.8
                )
                #else
                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                #endif
        )
        #if os(tvOS)
        .scaleEffect(isFocused ? 1.06 : 1.0)
        .shadow(
            color: isFocused ? Color(red: 0.0, green: 0.72, blue: 1.0).opacity(0.4) : Color.black.opacity(0.6),
            radius: isFocused ? 18 : 8,
            x: 0,
            y: isFocused ? 8 : 4
        )
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isFocused)
        .focused($isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                onFocus?(genre)
            }
        }
        #else
        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
        #endif
    }
}
