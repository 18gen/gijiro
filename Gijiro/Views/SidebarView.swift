import SwiftUI
import SwiftData

enum SidebarScreen: Hashable {
    case home
    case history
}

struct SidebarView: View {
    @Binding var selectedScreen: SidebarScreen
    @Binding var selectedMeeting: Meeting?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App branding
            Text("Gijiro")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

            // Search field placeholder
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Text("Search")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\u{2318}K")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .font(.caption)
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // Compose button
            Button {
                createQuickNote()
            } label: {
                Label("New Note", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()
                .padding(.vertical, 4)

            // Navigation items
            SidebarItem(
                title: "Home",
                icon: "house",
                isSelected: selectedScreen == .home && selectedMeeting == nil
            ) {
                selectedMeeting = nil
                selectedScreen = .home
            }

            SidebarItem(
                title: "Meeting History",
                icon: "clock",
                isSelected: selectedScreen == .history && selectedMeeting == nil
            ) {
                selectedMeeting = nil
                selectedScreen = .history
            }

            Divider()
                .padding(.vertical, 4)

            // Spaces section
            Text("Spaces")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 4)

            SidebarItem(title: "My notes", icon: "lock", isSelected: false) {
                selectedMeeting = nil
                selectedScreen = .home
            }

            Spacer()

            Divider()

            // Bottom bar
            HStack {
                SettingsLink {
                    Image(systemName: "gear")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("v0.1.0")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 180, idealWidth: 200, maxWidth: 240)
    }

    private func createQuickNote() {
        let meeting = Meeting(title: "Quick Note")
        modelContext.insert(meeting)
        try? modelContext.save()
        selectedMeeting = meeting
    }
}

private struct SidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 4)
    }
}
