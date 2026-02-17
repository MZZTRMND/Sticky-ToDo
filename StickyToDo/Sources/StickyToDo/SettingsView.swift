import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Appearance")
                    .font(.system(size: 13, weight: .semibold))

                Picker("Theme", selection: $settings.appearance) {
                    ForEach(AppSettings.Appearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("General")
                    .font(.system(size: 13, weight: .semibold))
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                Toggle("Show in Menu Bar", isOn: $settings.showInMenuBar)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Tasks")
                    .font(.system(size: 13, weight: .semibold))
                Toggle("Show Completed Tasks", isOn: $settings.showCompletedTasks)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}
