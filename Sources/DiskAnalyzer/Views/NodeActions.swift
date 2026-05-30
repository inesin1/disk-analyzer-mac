import SwiftUI

/// Everything a node view can do, injected from `ContentView` so the treemap and the list
/// behave identically.
struct NodeActions {
    var trash: (FSNode) -> Void
    var reveal: (FSNode) -> Void
    var open: (FSNode) -> Void
    var copyPath: (FSNode) -> Void
    var drillDown: (FSNode) -> Void
}

@ViewBuilder
func nodeContextMenu(_ node: FSNode, actions: NodeActions) -> some View {
    if node.isDirectory && !node.children.isEmpty {
        Button("Open Here") { actions.drillDown(node) }
        Divider()
    }
    Button("Open in Finder") { actions.open(node) }
    Button("Reveal in Finder") { actions.reveal(node) }
    Button("Copy Path") { actions.copyPath(node) }
    Divider()
    Button("Move to Trash", role: .destructive) { actions.trash(node) }
}
