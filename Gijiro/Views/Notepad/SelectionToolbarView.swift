//
//  SelectionToolbarView.swift
//  Gijiro
//

import SwiftUI

struct SelectionToolbarView: View {
    let onInlineFormat: (InlineFormat) -> Void
    let onBlockCommand: (BlockCommand) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(InlineFormat.allCases) { format in
                Button { onInlineFormat(format) } label: {
                    Image(systemName: format.icon)
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(ToolbarItemButtonStyle())
            }

            Divider()
                .frame(height: 18)
                .opacity(0.3)
                .padding(.horizontal, 4)

            Menu {
                ForEach(BlockCommand.allCases) { command in
                    Button {
                        onBlockCommand(command)
                    } label: {
                        Label(command.label, systemImage: command.icon)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Turn into")
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .buttonStyle(ToolbarItemButtonStyle())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background {
            VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.surfaceStroke, lineWidth: 1)
                .blendMode(.overlay)
        )
        .shadow(color: .black.opacity(0.20), radius: 26, y: 12)
        .shadow(color: .black.opacity(0.10), radius: 10, y: 3)
    }
}

private struct ToolbarItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? .white : .white.opacity(0.85))
            .frame(minWidth: 28, minHeight: 26)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
    }
}
