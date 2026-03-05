//
//  MarkdownTextEditor.swift
//  Gijiro
//

import SwiftUI
import AppKit

struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String

    private let styler = MarkdownStyler()

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.drawsBackground = false
        textView.textColor = NSColor.white.withAlphaComponent(0.85)
        textView.font = styler.theme.bodyFont
        textView.insertionPointColor = .white
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 4

        // Set up delegates
        textView.delegate = context.coordinator
        textView.textStorage?.delegate = context.coordinator

        // Initial content (convert markdown to visual prefixes)
        textView.string = MarkdownVisualizer.markdownToVisual(text)
        styler.applyFullDocument(textView.textStorage!)

        // Wire up popup controller
        let coordinator = context.coordinator
        coordinator.popupController.textView = textView
        coordinator.popupController.onTextTransform = { [weak coordinator] in
            guard let coordinator, let tv = coordinator.popupController.textView else { return }
            coordinator.isUpdating = true
            coordinator.parent.text = MarkdownVisualizer.visualToMarkdown(tv.string)
            coordinator.isUpdating = false
        }

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        // Observe scroll for popup repositioning
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(Coordinator.viewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        // Attach child windows after window is available
        DispatchQueue.main.async { [weak coordinator] in
            if let window = textView.window {
                coordinator?.popupController.attachToWindow(window)
            }
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        guard !context.coordinator.isUpdating else { return }
        let visualText = MarkdownVisualizer.markdownToVisual(text)
        guard textView.string != visualText else { return }

        context.coordinator.isUpdating = true
        let selectedRanges = textView.selectedRanges
        textView.string = visualText
        textView.selectedRanges = selectedRanges
        styler.applyFullDocument(textView.textStorage!)
        context.coordinator.isUpdating = false
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: MarkdownTextEditor
        var isUpdating = false
        let popupController = EditorPopupController()

        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        // MARK: - NSTextStorageDelegate

        func textStorage(
            _ textStorage: NSTextStorage,
            willProcessEditing editedMask: NSTextStorageEditActions,
            range editedRange: NSRange,
            changeInLength delta: Int
        ) {
            guard editedMask.contains(.editedCharacters) else { return }
            guard !isUpdating else { return }
            isUpdating = true
            parent.styler.applyStyles(to: textStorage, in: editedRange)
            isUpdating = false
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard !isUpdating else { return }
            guard let textView = notification.object as? NSTextView else { return }

            // Sync binding (convert visual back to markdown)
            isUpdating = true
            parent.text = MarkdownVisualizer.visualToMarkdown(textView.string)
            isUpdating = false

            // Slash menu detection
            detectSlashTrigger(in: textView)
            if popupController.isSlashMenuVisible {
                popupController.updateFilter(cursorPosition: textView.selectedRange().location)
            }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard popupController.isSlashMenuVisible else { return false }

            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                popupController.slashViewModel.moveUp()
                return true
            case #selector(NSResponder.moveDown(_:)):
                popupController.slashViewModel.moveDown()
                return true
            case #selector(NSResponder.insertNewline(_:)):
                popupController.confirmSelection()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                popupController.dismissSlashMenu()
                return true
            default:
                return false
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let selectedRange = textView.selectedRange()

            if selectedRange.length > 0 {
                DispatchQueue.main.async { [weak self] in
                    self?.popupController.showSelectionToolbar()
                }
            } else {
                popupController.dismissSelectionToolbar()
            }

            // Dismiss slash menu if cursor moved before trigger
            if popupController.isSlashMenuVisible {
                popupController.validateSlashPosition(cursorPosition: selectedRange.location)
            }
        }

        // MARK: - Scroll

        @objc func viewDidScroll(_ notification: Notification) {
            popupController.repositionVisiblePanels()
        }

        // MARK: - Slash Detection

        private func detectSlashTrigger(in textView: NSTextView) {
            let string = textView.string as NSString
            let cursorPos = textView.selectedRange().location
            guard cursorPos > 0 else { return }

            // Check the character just before cursor
            let charRange = NSRange(location: cursorPos - 1, length: 1)
            let char = string.substring(with: charRange)
            guard char == "/" else { return }

            // Must be at line start or after whitespace
            let lineRange = string.lineRange(for: charRange)
            let offsetInLine = cursorPos - 1 - lineRange.location

            if offsetInLine == 0 {
                popupController.showSlashMenu(triggerLocation: cursorPos - 1)
            } else {
                let prevCharRange = NSRange(location: cursorPos - 2, length: 1)
                let prevChar = string.substring(with: prevCharRange)
                if prevChar == " " || prevChar == "\t" || prevChar == "\n" {
                    popupController.showSlashMenu(triggerLocation: cursorPos - 1)
                }
            }
        }
    }
}
