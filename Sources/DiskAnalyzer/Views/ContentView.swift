import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = DiskScanner()
    @State private var currentNode: FSNode?
    @State private var pathStack: [FSNode] = []
    @State private var selection: Set<UUID> = []
    @State private var refreshTick = 0

    private var selectedNodes: [FSNode] {
        guard let currentNode else { return [] }
        return currentNode.children.filter { selection.contains($0.id) }
    }

    private var selectedDirectory: FSNode? {
        guard selectedNodes.count == 1, let node = selectedNodes.first, node.isDirectory else { return nil }
        return node
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
            Divider()
            statusBar
        }
        .frame(minWidth: 900, minHeight: 600)
        .onChange(of: scanner.root) { _, root in
            guard let root else { return }
            currentNode = root
            pathStack = [root]
            selection.removeAll()
        }
    }

    @ViewBuilder
    private var content: some View {
        if scanner.isScanning {
            VStack {
                ProgressView()
                Text(scanner.status).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let currentNode {
            let actions = makeActions()
            HSplitView {
                DetailsList(node: currentNode, selection: $selection, actions: actions)
                    .frame(minWidth: 280, idealWidth: 340)
                TreemapView(node: currentNode, selection: $selection, actions: actions)
                    .frame(minWidth: 400)
            }
            // FSNode is a class, so deleting a child does not change any value SwiftUI observes.
            // Bumping the id forces both panes to rebuild with the new sizes.
            .id(refreshTick)
        } else {
            VStack(spacing: 10) {
                Text("Pick a folder to scan").font(.title3)
                Button("Open…") { pickFolder() }.controlSize(.large)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button { pickFolder() } label: {
                Label("Scan Folder", systemImage: "folder.badge.questionmark")
            }
            Button { scanner.scan(url: URL(fileURLWithPath: NSHomeDirectory())) } label: {
                Label("Home", systemImage: "house")
            }
            Button { scanner.scan(url: URL(fileURLWithPath: "/")) } label: {
                Label("Whole Disk", systemImage: "internaldrive")
            }

            Divider().frame(height: 16)

            Button { goUp() } label: { Image(systemName: "arrow.up") }
                .disabled(pathStack.count <= 1)
                .keyboardShortcut(.upArrow, modifiers: .command)
            Button {
                if let node = selectedDirectory { drillDown(node) }
            } label: {
                Image(systemName: "arrow.down")
            }
            .disabled(selectedDirectory == nil)

            breadcrumbs

            Spacer()

            Button(role: .destructive) { trash(selectedNodes) } label: {
                Label(
                    selectedNodes.isEmpty ? "Trash" : "Trash (\(selectedNodes.count))",
                    systemImage: "trash"
                )
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(selectedNodes.isEmpty)
            .help("Command-Delete — move to trash")

            // Plain Delete as a second shortcut, the way Finder does it.
            Button("") { trash(selectedNodes) }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(selectedNodes.isEmpty)
                .opacity(0)
                .frame(width: 0, height: 0)

            if selectedNodes.count == 1 {
                Button { revealInFinder(selectedNodes[0]) } label: {
                    Label("Reveal in Finder", systemImage: "magnifyingglass")
                }
            }
        }
        .padding(8)
    }

    private var breadcrumbs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(Array(pathStack.enumerated()), id: \.element.id) { index, node in
                    Button(node.name) {
                        pathStack = Array(pathStack.prefix(index + 1))
                        currentNode = node
                        selection.removeAll()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)

                    if index < pathStack.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var statusBar: some View {
        HStack {
            Text(scanner.status).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            if !selectedNodes.isEmpty {
                Text(selectionSummary).font(.system(size: 11))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var selectionSummary: String {
        let total = selectedNodes.reduce(0) { $0 + $1.size }
        let size = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        return selectedNodes.count == 1
            ? "Selected: \(selectedNodes[0].name) — \(size)"
            : "Selected: \(selectedNodes.count) items — \(size)"
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            scanner.scan(url: url)
        }
    }

    private func drillDown(_ node: FSNode) {
        guard node.isDirectory, !node.children.isEmpty else {
            selection = [node.id]
            return
        }
        pathStack.append(node)
        currentNode = node
        selection.removeAll()
    }

    private func goUp() {
        guard pathStack.count > 1 else { return }
        pathStack.removeLast()
        currentNode = pathStack.last
        selection.removeAll()
    }

    /// Moves every node to the trash behind a single confirmation.
    private func trash(_ nodes: [FSNode]) {
        guard !nodes.isEmpty, confirmTrash(nodes) else { return }

        var failures: [(node: FSNode, error: Error)] = []
        for node in nodes {
            do {
                try FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
                removeFromTree(node)
            } catch {
                failures.append((node, error))
            }
        }
        selection.removeAll()

        guard !failures.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Could not delete \(failures.count) of \(nodes.count)"
        alert.informativeText = failures
            .prefix(5)
            .map { "• \($0.node.name): \($0.error.localizedDescription)" }
            .joined(separator: "\n")
        alert.runModal()
    }

    private func confirmTrash(_ nodes: [FSNode]) -> Bool {
        let total = nodes.reduce(0) { $0 + $1.size }
        let size = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)

        let alert = NSAlert()
        if nodes.count == 1 {
            alert.messageText = "Move to trash?"
            alert.informativeText = "\(nodes[0].url.path)\n\(size)"
        } else {
            let preview = nodes.prefix(5).map { "• \($0.name)" }.joined(separator: "\n")
            let more = nodes.count > 5 ? "\n… and \(nodes.count - 5) more" : ""
            alert.messageText = "Move \(nodes.count) items to trash?"
            alert.informativeText = "\(preview)\(more)\n\nTotal size: \(size)"
        }
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")

        return alert.runModal() == .alertFirstButtonReturn
    }

    private func removeFromTree(_ node: FSNode) {
        guard let parent = node.parent else { return }
        parent.children.removeAll { $0.id == node.id }

        var ancestor: FSNode? = parent
        while let current = ancestor {
            current.size -= node.size
            ancestor = current.parent
        }
        refreshTick &+= 1
    }

    private func revealInFinder(_ node: FSNode) {
        NSWorkspace.shared.activateFileViewerSelecting([node.url])
    }

    private func copyPaths(_ nodes: [FSNode]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(nodes.map(\.url.path).joined(separator: "\n"), forType: .string)
    }

    /// Right-clicking inside a multi-selection acts on the whole selection, otherwise only on
    /// the node under the cursor.
    private func contextTargets(for node: FSNode) -> [FSNode] {
        selection.count > 1 && selection.contains(node.id) ? selectedNodes : [node]
    }

    private func makeActions() -> NodeActions {
        NodeActions(
            trash: { trash(contextTargets(for: $0)) },
            reveal: revealInFinder,
            open: { NSWorkspace.shared.open($0.url) },
            copyPath: { copyPaths(contextTargets(for: $0)) },
            drillDown: drillDown
        )
    }
}
