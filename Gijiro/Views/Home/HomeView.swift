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
                    .padding(.horizontal, 36)
                    .frame(maxWidth: 800)

                    Divider().padding(.vertical, 8)

                    HistorySection(meetings: meetings) { selectedMeeting = $0 }
                        .padding(.horizontal, 36)
                        .padding(.bottom, 100)
                        .frame(maxWidth: 800)
                }
                .padding(.top, 12)
            }
            .onTapGesture { askFocused = false }

            AskBar(
                askText: $vm.askText,
                isAsking: $vm.isAsking,
                focus: $askFocused,
                quickPrompts: HomeViewModel.quickPrompts,
                onAsk: { Task { await vm.ask(meetings: meetings, prompt: vm.askText) } },
                onQuickPrompt: { prompt in Task { await vm.runQuickPrompt(meetings: meetings, prompt: prompt) } }
            )
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
