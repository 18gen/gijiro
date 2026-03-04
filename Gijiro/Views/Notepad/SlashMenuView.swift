//
//  SlashMenuView.swift
//  Gijiro
//

import SwiftUI
import Combine

final class SlashMenuViewModel: ObservableObject {
    @Published var filterText: String = "" {
        didSet { selectedIndex = 0 }
    }
    @Published var selectedIndex: Int = 0

    var filteredCommands: [BlockCommand] {
        if filterText.isEmpty { return Array(BlockCommand.allCases) }
        let query = filterText.lowercased()
        return BlockCommand.allCases.filter { $0.label.lowercased().contains(query) }
    }

    func moveUp() {
        guard !filteredCommands.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + filteredCommands.count) % filteredCommands.count
    }

    func moveDown() {
        guard !filteredCommands.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % filteredCommands.count
    }

    func reset() {
        filterText = ""
        selectedIndex = 0
    }
}

struct SlashMenuView: View {
    @ObservedObject var viewModel: SlashMenuViewModel
    let onSelect: (BlockCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Turn into")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ForEach(Array(viewModel.filteredCommands.enumerated()), id: \.element.id) { index, command in
                SlashMenuRow(command: command, isHighlighted: index == viewModel.selectedIndex)
                    .onTapGesture { onSelect(command) }
                    .onHover { hovering in
                        if hovering { viewModel.selectedIndex = index }
                    }
            }

            if viewModel.filteredCommands.isEmpty {
                Text("No results")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(12)
            }
        }
        .frame(width: 220)
        .padding(.vertical, 4)
        .background {
            VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.surfaceStroke, lineWidth: 1)
                .blendMode(.overlay)
        )
        .shadow(color: .black.opacity(0.20), radius: 26, y: 12)
        .shadow(color: .black.opacity(0.10), radius: 10, y: 3)
    }
}

private struct SlashMenuRow: View {
    let command: BlockCommand
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: command.icon)
                .font(.system(size: 13))
                .foregroundStyle(isHighlighted ? .white : .secondary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(isHighlighted ? 0.12 : 0.06))
                )

            Text(command.label)
                .font(.system(size: 13, weight: isHighlighted ? .medium : .regular))
                .foregroundStyle(isHighlighted ? .white : .primary.opacity(0.85))

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHighlighted ? Color.primary.opacity(0.10) : Color.clear)
        )
        .padding(.horizontal, 4)
    }
}
