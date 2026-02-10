import AppKit
import SwiftUI

struct WindowDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView {
        DragView()
    }

    func updateNSView(_ nsView: DragView, context: Context) {}
}

final class DragView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }
}
