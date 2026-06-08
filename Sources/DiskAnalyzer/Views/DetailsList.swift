import SwiftUI

/// Flat list of the current node's children, sorted by size.
struct DetailsList: View {
    let node: FSNode?
    @Binding var selection: Set<UUID>
    let actions: NodeActions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(node?.url.path ?? "—")
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.1))

            Divider()

            if let node {
                // List gives Command-click and Shift-click selection for free on macOS.
                List(node.children, id: \.id, selection: $selection) { child in
                    row(for: child)
                }
                .listStyle(.inset)
                .onKeyPress(.return) { drillDownSelected() }
                .onKeyPress(.space) { drillDownSelected() }
            } else {
                Text("No data").foregroundStyle(.secondary).padding()
            }
        }
    }

    private func row(for child: FSNode) -> some View {
        HStack {
            Image(systemName: child.isDirectory ? "folder.fill" : "doc")
                .foregroundStyle(child.isDirectory ? .blue : .secondary)
            Text(child.name).lineLimit(1).truncationMode(.middle)
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: child.size, countStyle: .file))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .contextMenu { nodeContextMenu(child, actions: actions) }
    }

    private func drillDownSelected() -> KeyPress.Result {
        guard let node, selection.count == 1, let id = selection.first,
              let child = node.children.first(where: { $0.id == id }),
              child.isDirectory
        else { return .handled }

        actions.drillDown(child)
        return .handled
    }
}
