import SwiftUI

struct SettingsView: View {
    @State private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("API Keys") {
                SecureField("Deepgram API Key (Streaming)", text: $settings.deepgramAPIKey)
                SecureField("OpenAI API Key (Whisper)", text: $settings.whisperAPIKey)
                SecureField("Anthropic API Key (Claude)", text: $settings.claudeAPIKey)
            }

            Section("Defaults") {
                Picker("Default Tone", selection: $settings.defaultToneMode) {
                    Text("Casual (\u{30BF}\u{30E1}\u{53E3})").tag("casual")
                    Text("Business (\u{3067}\u{3059}/\u{307E}\u{3059})").tag("business")
                    Text("Formal (\u{656C}\u{8A9E})").tag("formal")
                }

                Toggle("Auto-record when meeting starts", isOn: $settings.autoRecord)
            }

            Section("Google Calendar") {
                TextField("Google Client ID", text: $settings.googleClientID)
                SecureField("Google Client Secret", text: $settings.googleClientSecret)

                HStack {
                    if GoogleAuthService.shared.isAuthenticated {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Sign Out") {
                            GoogleAuthService.shared.signOut()
                        }
                    } else {
                        Label("Not connected", systemImage: "xmark.circle")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Sign In with Google") {
                            Task {
                                try? await GoogleAuthService.shared.signIn()
                            }
                        }
                        .disabled(settings.googleClientID.isEmpty || settings.googleClientSecret.isEmpty)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 400)
    }
}
