//
//  MarkdownNotesEditor.swift
//  Gijiro
//
//  Created by Gen Ichihashi on 2026-02-24.
//

import SwiftUI

struct MarkdownNotesEditor: View {
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            MarkdownTextView(text: $text)

            if text.isEmpty {
                Text("Write notes...")
                    .foregroundStyle(.tertiary)
                    .allowsHitTesting(false)
            }
        }
    }
}
