//
//  HomeView.swift
//  Gijiro
//
//  Created by Gen Ichihashi on 2026-02-24.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.startDate, order: .reverse) private var meetings: [Meeting]
    @Binding var selectedMeeting: Meeting?

    @StateObject private var vm = HomeViewModel()
    @FocusState private var askFocused: Bool

    private let accentColor = Color(red: 0.30, green: 0.60, blue: 1.00)

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    UpcomingSection(
                        events: vm.calendarService.upcomingEvents,
                        isLoading: vm.calendarService.isLoading,
                        currentEventID: vm.calendarService.currentEvent?.id,
                        onSelect: openOrCreateMeeting
                    )

                    HistorySection(meetings: meetings) { selectedMeeting = $0 }
                }
                .padding(.top, 12)
                .padding(.bottom, 100)
                .padding(.horizontal, 36)
                .frame(maxWidth: 700)
            }
            .onTapGesture { askFocused = false }

            floatingAskBar
                .background(AppTheme.background)
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .task { await vm.onAppear() }
        .popover(isPresented: $vm.showAskResult) {
            ScrollView {
                Text(vm.askAnswer)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(width: 400, height: 300)
        }
    }

    private func openOrCreateMeeting(for event: CalendarEvent) {
        if let existing = meetings.first(where: { $0.calendarEventID == event.id }) {
            selectedMeeting = existing
            return
        }
        let meeting = Meeting(title: event.title)
        meeting.calendarEventID = event.id
        modelContext.insert(meeting)
        try? modelContext.save()
        selectedMeeting = meeting
    }
}

// MARK: - Floating AskBar

private extension HomeView {
    var floatingAskBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            if askFocused {
                quickPromptsTray
                    .transition(
                        .asymmetric(
                            insertion: .push(from: .bottom).combined(with: .opacity),
                            removal:   .push(from: .top).combined(with: .opacity)
                        )
                    )
            }

            AskBar(
                text: $vm.askText,
                isAsking: $vm.isAsking,
                focus: $askFocused,
                placeholder: askFocused ? "Type / for recipes · Enter to ask" : "Ask anything",
                onSend: { Task { await vm.ask(meetings: meetings, prompt: vm.askText) } }
            ) {
                if !askFocused, let first = HomeViewModel.quickPrompts.first {
                    QuickPromptPill(prompt: first) {
                        Task { await vm.runQuickPrompt(meetings: meetings, prompt: first) }
                    }
                    .transition(.opacity)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
        .frame(maxWidth: 700)
        .overlay(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .strokeBorder(
                    askFocused ? accentColor : Color.white.opacity(0.12),
                    lineWidth: askFocused ? 1.5 : 1
                )
        )
        .padding(.bottom, 10)
        .padding(.horizontal, 20)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 0)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: askFocused)
    }

    var quickPromptsTray: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(HomeViewModel.quickPrompts.prefix(8).enumerated()), id: \.offset) { index, p in
                    if index > 0 {
                        Text("|")
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 2)
                    }
                    TrayPromptButton(prompt: p) {
                        Task { await vm.runQuickPrompt(meetings: meetings, prompt: p) }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 5)
        }
    }
}

// MARK: - Tray Prompt Button

private struct TrayPromptButton: View {
    let prompt: QuickPrompt
    let action: () -> Void

    @State private var isHovered = false

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
                    .foregroundStyle(isHovered ? .primary : .secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.07) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 2)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}
