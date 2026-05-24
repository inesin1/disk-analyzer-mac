import Foundation

/// A single entry in the scanned tree. Reference type so children can point back at their
/// parent and so the UI can mutate sizes in place after a deletion.
final class FSNode: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool

    /// Bytes on disk. For directories, the sum of all children.
    var size: Int64 = 0
    var children: [FSNode] = []
    weak var parent: FSNode?

    init(url: URL, isDirectory: Bool) {
        self.url = url
        self.name = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        self.isDirectory = isDirectory
    }

    static func == (lhs: FSNode, rhs: FSNode) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
