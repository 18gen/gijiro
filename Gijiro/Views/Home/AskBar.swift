//
//  AskBar.swift
//  Gijiro
//
//  Created by Gen Ichihashi on 2026-02-24.
//

import SwiftUI

struct AskBar: View {
    @Binding var askText: String
    @Binding var isAsking: Bool
    var focus: FocusState<Bool>.Binding

    let quickPrompts: [QuickPrompt]
    let onAsk: () -> Void
    let onQuickPrompt: (QuickPrompt) -> Void

    private var isFocused: Bool { focus.wrappedValue }

    var body: some View {
        VStack(spacing: 10) {
            if isFocused {
                // your expanded content (quick prompts list etc.)
                // put it here, it will appear above the pill
            }

            pill
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
        .frame(maxWidth: 860)                 // similar to Granola (not full width)
        .animation(.easeOut(duration: 0.18), value: isFocused)
    }

    private var pill: some View {
        HStack(spacing: 12) {
            TextField("Ask anything", text: $askText)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused(focus)
                .onSubmit(onAsk)
                .padding(.vertical, 14)

            Spacer(minLength: 0)

            if !isFocused, let first = quickPrompts.first {
                QuickPromptPill(prompt: first) { onQuickPrompt(first) }
            }

            // Optional: send button (only when there is text)
            if !askText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: onAsk) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(.thinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(.horizontal, 16)
        .background(pillBackground)
        .overlay(pillBorder)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }

    private var pillBackground: some View {
        ZStack {
            #if os(macOS)
            VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            #else
            Color(.systemBackground).opacity(0.85)
            #endif
        }
    }

    private var pillBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            .blendMode(.overlay)
    }
}
