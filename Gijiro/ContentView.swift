import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedScreen: SidebarScreen = .home
    @State private var selectedMeeting: Meeting?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @Environment(\.modelContext) private var modelContext
    private func createQuickNote() {
        let meeting = Meeting(title: "")
        modelContext.insert(meeting)
        try? modelContext.save()
        selectedMeeting = meeting
    }

    var body: some View {
        Group {
            if selectedMeeting != nil {
                // Full-width notepad — no sidebar, no split view
                NotepadView(meeting: selectedMeeting!, onClose: { selectedMeeting = nil })
                    .frame(minWidth: 500, minHeight: 350)
            } else {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SidebarView(selectedScreen: $selectedScreen, selectedMeeting: $selectedMeeting)
                } detail: {
                    switch selectedScreen {
                    case .home:
                        HomeView(selectedMeeting: $selectedMeeting)
                    default:
                        EmptyView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            createQuickNote()
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
                .background(AppTheme.background)
            }
        }
        .preferredColorScheme(.dark)
    }
}
