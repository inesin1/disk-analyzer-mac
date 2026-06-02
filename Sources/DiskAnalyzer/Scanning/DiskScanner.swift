import Foundation

/// Walks a directory tree on a background queue and publishes the result.
final class DiskScanner: ObservableObject {
    @Published private(set) var isScanning = false
    @Published private(set) var status = ""
    @Published private(set) var root: FSNode?

    /// Identifies a file across mount points; used to count hard-linked files only once.
    private struct DevInode: Hashable {
        let dev: Int32
        let ino: UInt64
    }

    private var visitedInodes = Set<DevInode>()
    private var fileCount = 0

    /// Paths that would otherwise be counted twice or are not real storage: the Data volume
    /// is already visible through firmlinks (/Users, /Applications, …), the rest are
    /// snapshots, swap, device nodes and external mounts.
    private let skipPaths: Set<String> = [
        "/System/Volumes/Data",
        "/System/Volumes/Preboot",
        "/System/Volumes/Recovery",
        "/System/Volumes/Update",
        "/System/Volumes/VM",
        "/System/Volumes/xarts",
        "/System/Volumes/iSCPreboot",
        "/System/Volumes/Hardware",
        "/private/var/vm",
        "/.vol",
        "/dev",
        "/Volumes",
    ]

    func scan(url: URL) {
        DispatchQueue.main.async {
            self.isScanning = true
            self.status = "Starting…"
            self.root = nil
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            self.visitedInodes.removeAll()
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
        if node.isDirectory && skipPaths.contains(node.url.path) {
            return
        }

        fileCount += 1

        guard node.isDirectory else {
            let (size, inode) = sizeAndInode(of: node.url)
            if let inode {
                node.size = visitedInodes.insert(inode).inserted ? size : 0
            } else {
                node.size = size
            }
            return
        }

        if fileCount % 5000 == 0 {
            let path = node.url.path
            DispatchQueue.main.async { [weak self] in
                self?.status = "Scanning: \(path)"
            }
        }

        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
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

    /// Allocated size plus, for hard-linked files, the key used to deduplicate them.
    ///
    /// `st_blocks` is the space actually taken on disk, unlike `st_size`: iCloud placeholders
    /// report a large logical size while holding no blocks, and APFS clones share their blocks
    /// with the original.
    private func sizeAndInode(of url: URL) -> (Int64, DevInode?) {
        var info = stat()
        guard url.path.withCString({ lstat($0, &info) }) == 0 else { return (0, nil) }

        let size = Int64(info.st_blocks) * 512
        let inode = info.st_nlink > 1
            ? DevInode(dev: Int32(info.st_dev), ino: UInt64(info.st_ino))
            : nil
        return (size, inode)
    }

    private func sortBySizeDescending(_ node: FSNode) {
        node.children.sort { $0.size > $1.size }
        for child in node.children where child.isDirectory {
            sortBySizeDescending(child)
        }
    }
}
