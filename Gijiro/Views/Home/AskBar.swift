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
    var focus: FocusState<Bool>.Binding   // ✅ instead of @Binding Bool

    let quickPrompts: [QuickPrompt]
    let onAsk: () -> Void
    let onQuickPrompt: (QuickPrompt) -> Void

    private var isFocused: Bool { focus.wrappedValue }

    var body: some View {
        VStack(spacing: 0) {
            if isFocused {
                // ... unchanged
            }

            VStack(spacing: 0) {
                // ...
                HStack(spacing: 10) {
                    TextField("Ask anything", text: $askText)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused(focus)           // ✅
                        .onSubmit(onAsk)

                    // ... unchanged

                    if !isFocused, let first = quickPrompts.first {
                        QuickPromptPill(prompt: first) { onQuickPrompt(first) }
                    }
                }
                // ...
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}
