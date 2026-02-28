//
//  AskBar.swift
//  Gijiro
//

import SwiftUI

struct AskBar<Accessory: View>: View {
    @Binding var text: String
    @Binding var isAsking: Bool
    var focus: FocusState<Bool>.Binding
    var placeholder: String
    let onSend: () -> Void
    var accessory: Accessory

    init(
        text: Binding<String>,
        isAsking: Binding<Bool>,
        focus: FocusState<Bool>.Binding,
        placeholder: String = "Ask anything",
        onSend: @escaping () -> Void,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self._text = text
        self._isAsking = isAsking
        self.focus = focus
        self.placeholder = placeholder
        self.onSend = onSend
        self.accessory = accessory()
    }

    private var shouldShowSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused(focus)
                .lineLimit(1...5)
                .frame(maxWidth: .infinity)
                .onSubmit(onSend)

            accessory

            if shouldShowSend {
                PromptSendButton(size: 30, action: onSend)
                    .disabled(isAsking)
            }
        }
        .frame(minHeight: 38)
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                .blendMode(.overlay)
        )
        .animation(.spring(response: 0.22, dampingFraction: 0.80), value: shouldShowSend)
    }
}

extension AskBar where Accessory == EmptyView {
    init(
        text: Binding<String>,
        isAsking: Binding<Bool>,
        focus: FocusState<Bool>.Binding,
        placeholder: String = "Ask anything",
        onSend: @escaping () -> Void
    ) {
        self._text = text
        self._isAsking = isAsking
        self.focus = focus
        self.placeholder = placeholder
        self.onSend = onSend
        self.accessory = EmptyView()
    }
}
