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
            HStack(spacing: 5) {
                // Search "pill"
                Button {
                    // open search / focus search field
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        Text("Search")
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)

                        Text("⌘K")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
//                    .background(Color.secondary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 0.5)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 10)) // nicer click area
                }
                .buttonStyle(.plain)

                // Pencil button (simple circle)
                Button {
                    createQuickNote()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.secondary.opacity(0.10))
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)

            // Navigation items
            SidebarItem(
                title: "Home",
                icon: "house",
                isSelected: selectedScreen == .home && selectedMeeting == nil
            ) {
                selectedMeeting = nil
                selectedScreen = .home
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
        let meeting = Meeting(title: "")
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
        .background(isSelected ? Color.white.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 4)
    }
}
