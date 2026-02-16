import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
                .font(.system(size: 13, weight: .semibold))

            Picker("Theme", selection: $settings.appearance) {
                ForEach(AppSettings.Appearance.allCases) { appearance in
                    Text(appearance.title).tag(appearance)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .frame(width: 300)
    }
}
