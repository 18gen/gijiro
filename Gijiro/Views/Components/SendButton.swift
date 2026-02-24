import SwiftUI

struct SendButton: View {
    var size: CGFloat = 32
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Theme.accent)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
