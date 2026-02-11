import SwiftUI
import UniformTypeIdentifiers

struct ReorderDropDelegate: DropDelegate {
    let target: TaskItem
    let store: TaskStore
    @Binding var draggingId: UUID?

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func dropEntered(info: DropInfo) {
        guard let draggingId, draggingId != target.id else { return }
        withAnimation(.easeInOut(duration: 0.12)) {
            store.moveTask(from: draggingId, to: target.id)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingId = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
