import SwiftUI

struct AboutView: View {
    let versionText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sticky ToDo")
                .font(.system(size: 20, weight: .semibold))

            Text(versionText)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)

            Text("StickyToDo is a lightweight macOS desktop widget for daily tasks. It stays on top of your desktop, lets you quickly add, complete, delete, and edit tasks, and saves everything between sessions. Designed for speed and focus with a clean, minimal UI.")
                .font(.system(size: 13, weight: .regular))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 380)
    }
}
