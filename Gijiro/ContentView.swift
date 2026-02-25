import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedScreen: SidebarScreen = .home
    @State private var selectedMeeting: Meeting?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        if selectedMeeting != nil {
            // Full-width notepad — no sidebar, no split view
            NotepadView(meeting: selectedMeeting!, onClose: { selectedMeeting = nil })
                .preferredColorScheme(.dark)
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
            .preferredColorScheme(.dark)
            .frame(minWidth: 500, minHeight: 350)
        }
    }
}
