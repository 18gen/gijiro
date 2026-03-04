//
//  EditorPopupController.swift
//  Gijiro
//

import AppKit
import SwiftUI

final class EditorPopupController {
    weak var textView: NSTextView?
    weak var parentWindow: NSWindow?

    // Slash menu
    private var slashPanel: NSPanel?
    let slashViewModel = SlashMenuViewModel()
    private(set) var slashTriggerLocation: Int?

    // Selection toolbar
    private var toolbarPanel: NSPanel?

    // Callback to sync text binding after mutations
    var onTextTransform: (() -> Void)?

    var isSlashMenuVisible: Bool { slashPanel?.isVisible ?? false }
    var isToolbarVisible: Bool { toolbarPanel?.isVisible ?? false }

    // MARK: - Window Attachment

    func attachToWindow(_ window: NSWindow) {
        parentWindow = window
    }

    // MARK: - Slash Menu

    func showSlashMenu(triggerLocation: Int) {
        slashTriggerLocation = triggerLocation
        slashViewModel.reset()

        let panel = getOrCreateSlashPanel()
        positionSlashPanel()

        if let parentWindow {
            parentWindow.addChildWindow(panel, ordered: .above)
        }
        panel.orderFront(nil)
    }

    func dismissSlashMenu() {
        slashPanel?.orderOut(nil)
        if let parentWindow, let panel = slashPanel {
            parentWindow.removeChildWindow(panel)
        }
        slashTriggerLocation = nil
        slashViewModel.reset()
    }

    func updateFilter(cursorPosition: Int) {
        guard let triggerLocation = slashTriggerLocation,
              let textView,
              cursorPosition > triggerLocation else {
            dismissSlashMenu()
            return
        }

        let string = textView.string as NSString
        // Extract text between "/" (exclusive) and cursor
        let filterStart = triggerLocation + 1
        let filterLength = cursorPosition - filterStart
        guard filterLength >= 0, filterStart + filterLength <= string.length else {
            dismissSlashMenu()
            return
        }

        if filterLength == 0 {
            slashViewModel.filterText = ""
        } else {
            let filterRange = NSRange(location: filterStart, length: filterLength)
            slashViewModel.filterText = string.substring(with: filterRange)
        }

        positionSlashPanel()
    }

    func validateSlashPosition(cursorPosition: Int) {
        guard let triggerLocation = slashTriggerLocation else { return }
        // Dismiss if cursor moved before the trigger
        if cursorPosition <= triggerLocation {
            dismissSlashMenu()
        }
    }

    func confirmSelection() {
        let commands = slashViewModel.filteredCommands
        guard !commands.isEmpty else {
            dismissSlashMenu()
            return
        }
        let index = min(slashViewModel.selectedIndex, commands.count - 1)
        completeSlashCommand(commands[index])
    }

    // MARK: - Selection Toolbar

    func showSelectionToolbar() {
        guard let textView, textView.selectedRange().length > 0 else { return }
        // Don't show toolbar while slash menu is active
        guard !isSlashMenuVisible else { return }

        let panel = getOrCreateToolbarPanel()
        positionToolbarPanel()

        if let parentWindow, !panel.isVisible {
            parentWindow.addChildWindow(panel, ordered: .above)
        }
        panel.orderFront(nil)
    }

    func dismissSelectionToolbar() {
        toolbarPanel?.orderOut(nil)
        if let parentWindow, let panel = toolbarPanel {
            parentWindow.removeChildWindow(panel)
        }
    }

    // MARK: - Repositioning

    func repositionVisiblePanels() {
        if isSlashMenuVisible { positionSlashPanel() }
        if isToolbarVisible { positionToolbarPanel() }
    }

    // MARK: - Text Transformations

    func applyBlockCommand(_ command: BlockCommand) {
        guard let textView, let textStorage = textView.textStorage else { return }

        let string = textStorage.string as NSString
        let cursorRange = textView.selectedRange()
        let lineRange = string.lineRange(for: cursorRange)
        let lineContent = string.substring(with: lineRange)

        // Strip existing block prefix
        var stripped = lineContent
        if let match = BlockCommand.prefixPattern.firstMatch(
            in: lineContent, range: NSRange(location: 0, length: lineContent.utf16.count)
        ) {
            stripped = String((lineContent as NSString).substring(from: match.range.upperBound))
        }

        // Build new line
        let newLine: String
        if command == .divider {
            newLine = "---\n"
        } else if command == .codeBlock {
            let content = stripped.trimmingCharacters(in: .newlines)
            newLine = "```\n\(content)\n```\n"
        } else {
            newLine = command.prefix + stripped
        }

        if textView.shouldChangeText(in: lineRange, replacementString: newLine) {
            textStorage.replaceCharacters(in: lineRange, with: newLine)
            textView.didChangeText()
        }

        // Position cursor at end of content
        let cursorPos = lineRange.location + newLine.count - (newLine.hasSuffix("\n") ? 1 : 0)
        textView.setSelectedRange(NSRange(location: cursorPos, length: 0))

        onTextTransform?()
    }

    func applyInlineFormat(_ format: InlineFormat) {
        guard let textView, let textStorage = textView.textStorage else { return }

        let selectedRange = textView.selectedRange()
        guard selectedRange.length > 0 else { return }

        let selectedText = (textStorage.string as NSString).substring(with: selectedRange)
        let (prefix, suffix) = format.wrapper
        let replacement = prefix + selectedText + suffix

        if textView.shouldChangeText(in: selectedRange, replacementString: replacement) {
            textStorage.replaceCharacters(in: selectedRange, with: replacement)
            textView.didChangeText()
        }

        // Re-select the wrapped text (excluding syntax markers)
        let newStart = selectedRange.location + prefix.utf16.count
        textView.setSelectedRange(NSRange(location: newStart, length: selectedText.utf16.count))

        onTextTransform?()
    }

    // MARK: - Private: Slash Command Completion

    private func completeSlashCommand(_ command: BlockCommand) {
        guard let triggerLocation = slashTriggerLocation,
              let textView, let textStorage = textView.textStorage else { return }

        // Calculate the range of "/" + filter text
        let cursorPos = textView.selectedRange().location
        let removeRange = NSRange(location: triggerLocation, length: cursorPos - triggerLocation)

        // Remove "/" and filter text
        if textView.shouldChangeText(in: removeRange, replacementString: "") {
            textStorage.replaceCharacters(in: removeRange, with: "")
            textView.didChangeText()
        }

        // Position cursor at the trigger location
        textView.setSelectedRange(NSRange(location: triggerLocation, length: 0))

        dismissSlashMenu()

        // Apply block command to current line
        applyBlockCommand(command)
    }

    // MARK: - Private: Panel Creation

    private func getOrCreateSlashPanel() -> NSPanel {
        if let panel = slashPanel { return panel }

        let hostingView = NSHostingView(rootView:
            SlashMenuView(viewModel: slashViewModel) { [weak self] command in
                self?.completeSlashCommand(command)
            }
        )
        hostingView.frame = NSRect(origin: .zero, size: hostingView.fittingSize)

        let panel = makePanel(contentView: hostingView)
        slashPanel = panel
        return panel
    }

    private func getOrCreateToolbarPanel() -> NSPanel {
        if let panel = toolbarPanel { return panel }

        let hostingView = NSHostingView(rootView:
            SelectionToolbarView(
                onInlineFormat: { [weak self] format in
                    self?.applyInlineFormat(format)
                },
                onBlockCommand: { [weak self] command in
                    self?.applyBlockCommand(command)
                    self?.dismissSelectionToolbar()
                }
            )
        )
        hostingView.frame = NSRect(origin: .zero, size: hostingView.fittingSize)

        let panel = makePanel(contentView: hostingView)
        toolbarPanel = panel
        return panel
    }

    private func makePanel(contentView: NSView) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentView.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.contentView = contentView
        panel.animationBehavior = .utilityWindow
        return panel
    }

    // MARK: - Private: Positioning

    private func positionSlashPanel() {
        guard let triggerLocation = slashTriggerLocation,
              let rect = screenRect(forRange: NSRange(location: triggerLocation, length: 1)),
              let panel = slashPanel else { return }

        // Resize to fit content
        if let hostingView = panel.contentView as? NSHostingView<SlashMenuView> {
            let size = hostingView.fittingSize
            panel.setContentSize(size)
        }

        // Position below the cursor line
        let origin = NSPoint(x: rect.origin.x, y: rect.origin.y - panel.frame.height - 4)
        panel.setFrameOrigin(origin)
    }

    private func positionToolbarPanel() {
        guard let textView,
              let panel = toolbarPanel else { return }

        let selectedRange = textView.selectedRange()
        guard selectedRange.length > 0,
              let rect = screenRect(forRange: selectedRange) else { return }

        // Resize to fit content
        if let hostingView = panel.contentView {
            let size = hostingView.fittingSize
            panel.setContentSize(size)
        }

        // Position above the selection
        let origin = NSPoint(x: rect.origin.x, y: rect.maxY + 4)
        panel.setFrameOrigin(origin)
    }

    private func screenRect(forRange range: NSRange) -> NSRect? {
        guard let textView else { return nil }
        var actualRange = NSRange()
        let rect = textView.firstRect(forCharacterRange: range, actualRange: &actualRange)
        guard rect != .zero else { return nil }
        return rect
    }
}
