import SwiftUI

struct QuickPrompt: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let prompt: String
}

struct QuickPromptButton: View {
    let prompt: QuickPrompt
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: prompt.icon)
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                    .padding(5)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text(prompt.label)
                    .font(.body)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Pill-outlined variant for the collapsed inline prompt
struct QuickPromptPill: View {
    let prompt: QuickPrompt
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: prompt.icon)
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                    .padding(5)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text(prompt.label)
                    .font(.body)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(
                Capsule()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
