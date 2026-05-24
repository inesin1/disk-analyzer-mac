import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = DiskScanner()
    @State private var selection: UUID?

    private var selectedNode: FSNode? {
        guard let selection, let root = scanner.root else { return nil }
        return root.children.first { $0.id == selection }
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
    }

    @ViewBuilder
    private var content: some View {
        if scanner.isScanning {
            VStack {
                ProgressView()
                Text(scanner.status).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let root = scanner.root {
            DetailsList(node: root, selection: $selection)
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
            Spacer()
        }
        .padding(8)
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
}
