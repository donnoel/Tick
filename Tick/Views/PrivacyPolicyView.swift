import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Updated October 24, 2026")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    policySection("Your information", text: "Ticks is developed by Don Noel. It helps you record time for your Spaces. Your Space names, Tick descriptions, notes, dates, durations, preferences, and optional voice memos and Auto Tick rules are stored on your devices. Ticks does not use advertising, cross-app tracking, or third-party analytics SDKs.")

                    policySection("iCloud and your devices", text: "When iCloud is available, Ticks uses Apple’s private iCloud storage to synchronize your records and voice memos across your devices. Saved Auto Tick rules include their location names, coordinates, and radii. Ticks uses an iCloud account identifier to keep accounts’ cached data separate. The app and widgets share local storage, and the Watch keeps a local copy of time records. This content is not sent to a developer-operated server. Apple processes iCloud data under its own privacy terms.")

                    policySection("Optional location access", text: "Auto Ticks uses your current location when you ask to create a rule. With your permission, enabled rules monitor arrival and departure at saved locations, including in the background, to start or stop time. Ticks does not record routes or a history of raw location samples. You can disable or delete rules in Auto Ticks and change location permission in Settings. Regular timers work without location access.")

                    policySection("Microphone and notifications", text: "The microphone is used only when you choose to record a voice memo. Recordings are saved with the selected Space and synchronized through iCloud when available. Ticks does not transcribe recordings. Optional notifications provide Auto Tick updates. You can change microphone and notification permissions in Settings; other timekeeping features remain available.")

                    policySection("Sharing reports", text: "Reports are shared only when you choose to share them. Review the report, included notes, destination app, and recipients before sending. Shared copies are then handled by those recipients and services under their own privacy practices. Deleting a Tick does not recall a report you have already shared.")

                    policySection("Keeping and deleting data", text: "Your records remain available until you delete them. You can delete Ticks, Auto Tick rules, voice memos, or an entire Space in the app. Deleting a Space also deletes its related records; archiving only hides it from active lists. Deletions synchronize when your devices reconnect. Small deletion records, such as identifiers and timestamps, may be retained to prevent deleted items from returning during synchronization. Previously shared copies and backups may remain outside the app’s control.")

                    policySection("Your controls", text: "You can edit your records in Ticks and manage Ticks’ permissions and iCloud access in Apple’s Settings. Turning off a permission stops future use of that permission but does not remove existing records. Deleting the app does not necessarily delete your iCloud data; manage that data through your iCloud storage settings. Ticks does not require a separate developer account.")

                    policySection("Policy updates", text: "This policy describes the current app. If its privacy practices change, the policy and its updated date will be revised. This copy is included in the app and can be read without an internet connection.")

                    policySection("Contact", text: "For privacy questions, email donnoel@icloud.com.")
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
                .textSelection(.enabled)
            }
            .tickScreenBackground()
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("privacy.done")
                }
            }
        }
    }

    private func policySection(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
