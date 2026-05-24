import Foundation

/// Walks a directory tree on a background queue and publishes the result.
final class DiskScanner: ObservableObject {
    @Published private(set) var isScanning = false
    @Published private(set) var status = ""
    @Published private(set) var root: FSNode?

    private var fileCount = 0

    func scan(url: URL) {
        DispatchQueue.main.async {
            self.isScanning = true
            self.status = "Starting…"
            self.root = nil
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            self.fileCount = 0

            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? true
            let rootNode = FSNode(url: url, isDirectory: isDirectory)
            self.walk(rootNode)
            self.sortBySizeDescending(rootNode)

            DispatchQueue.main.async {
                self.root = rootNode
                self.isScanning = false
                let total = ByteCountFormatter.string(fromByteCount: rootNode.size, countStyle: .file)
                self.status = "Done. \(self.fileCount) files, \(total)"
            }
        }
    }

    private func walk(_ node: FSNode) {
        fileCount += 1

        let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .isSymbolicLinkKey]

        guard node.isDirectory else {
            let values = try? node.url.resourceValues(forKeys: keys)
            node.size = Int64(values?.fileSize ?? 0)
            return
        }

        if fileCount % 5000 == 0 {
            let path = node.url.path
            DispatchQueue.main.async { [weak self] in
                self?.status = "Scanning: \(path)"
            }
        }

        let contents = (try? FileManager.default.contentsOfDirectory(
            at: node.url,
            includingPropertiesForKeys: Array(keys),
            options: []
        )) ?? []

        for childURL in contents {
            let values = try? childURL.resourceValues(forKeys: keys)
            // Symlinks would make the walk cyclic and double-count their targets.
            if values?.isSymbolicLink == true { continue }

            let isDirectory = values?.isDirectory ?? false
            let child = FSNode(url: childURL, isDirectory: isDirectory)
            child.parent = node
            walk(child)
            node.size += child.size
            if child.size > 0 || isDirectory {
                node.children.append(child)
            }
        }
    }

    private func sortBySizeDescending(_ node: FSNode) {
        node.children.sort { $0.size > $1.size }
        for child in node.children where child.isDirectory {
            sortBySizeDescending(child)
        }
    }
}
