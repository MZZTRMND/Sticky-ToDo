import SwiftUI

struct DividerRow: View {
    let title: String
    let onRename: (String) -> Void
    @Binding var editTrigger: Bool

    @State private var isEditing = false
    @State private var draftTitle = ""
    @FocusState private var isEditingFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            if isEditing {
                TextField("", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: true, vertical: false)
                    .focused($isEditingFocused)
                    .onSubmit(commitEdit)
                    .onExitCommand { cancelEdit() }
                    .onChange(of: isEditingFocused) { focused in
                        if focused == false {
                            commitEdit()
                        }
                    }
            } else {
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: true, vertical: false)
                    .onTapGesture(count: 2) {
                        startEdit()
                    }
            }
            line
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .contentShape(Rectangle())
        .onChange(of: editTrigger) { shouldEdit in
            guard shouldEdit else { return }
            startEdit()
            editTrigger = false
        }
    }

    private var line: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        textColor.opacity(0.25),
                        textColor.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }

    private var textColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.5) : Theme.textPrimary.opacity(0.5)
    }

    private func startEdit() {
        draftTitle = title
        isEditing = true
        DispatchQueue.main.async {
            isEditingFocused = true
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func commitEdit() {
        guard isEditing else { return }
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty == false && trimmed != title {
            onRename(trimmed)
        }
        isEditing = false
    }

    private func cancelEdit() {
        isEditing = false
        draftTitle = title
    }
}
