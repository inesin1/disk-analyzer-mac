import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = DiskScanner()
    @State private var currentNode: FSNode?
    @State private var pathStack: [FSNode] = []
    @State private var selection: UUID?

    private var selectedNode: FSNode? {
        guard let selection, let currentNode else { return nil }
        return currentNode.children.first { $0.id == selection }
    }

    private var selectedDirectory: FSNode? {
        guard let selectedNode, selectedNode.isDirectory else { return nil }
        return selectedNode
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
            selection = nil
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
                if let selectedDirectory { drillDown(selectedDirectory) }
            } label: {
                Image(systemName: "arrow.down")
            }
            .disabled(selectedDirectory == nil)

            breadcrumbs

            Spacer()

            if let selectedNode {
                Button { revealInFinder(selectedNode) } label: {
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
                        selection = nil
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
            if let selectedNode {
                let size = ByteCountFormatter.string(fromByteCount: selectedNode.size, countStyle: .file)
                Text("Selected: \(selectedNode.name) — \(size)").font(.system(size: 11))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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
            selection = node.id
            return
        }
        pathStack.append(node)
        currentNode = node
        selection = nil
    }

    private func goUp() {
        guard pathStack.count > 1 else { return }
        pathStack.removeLast()
        currentNode = pathStack.last
        selection = nil
    }

    private func revealInFinder(_ node: FSNode) {
        NSWorkspace.shared.activateFileViewerSelecting([node.url])
    }

    private func copyPath(_ node: FSNode) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(node.url.path, forType: .string)
    }

    private func makeActions() -> NodeActions {
        NodeActions(
            reveal: revealInFinder,
            open: { NSWorkspace.shared.open($0.url) },
            copyPath: copyPath,
            drillDown: drillDown
        )
    }
}
