import SwiftUI

struct TreemapView: View {
    let node: FSNode
    @Binding var selection: UUID?
    let onDrillDown: (FSNode) -> Void

    var body: some View {
        GeometryReader { geometry in
            let rects = SquarifiedTreemap.layout(node: node, in: CGRect(origin: .zero, size: geometry.size))
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.05)
                ForEach(rects, id: \.node.id) { tile in
                    TreemapCell(tile: tile, isSelected: selection == tile.node.id)
                        .frame(width: tile.rect.width, height: tile.rect.height)
                        .offset(x: tile.rect.minX, y: tile.rect.minY)
                        .onTapGesture { selection = tile.node.id }
                        .simultaneousGesture(TapGesture(count: 2).onEnded { onDrillDown(tile.node) })
                }
            }
        }
    }
}

private struct TreemapCell: View {
    let tile: TreemapRect
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(color(for: tile.node))

            if isSelected {
                // Wash plus double border, so the highlight reads on any tile color.
                Rectangle().fill(Color.white.opacity(0.30))
                Rectangle().strokeBorder(Color.white, lineWidth: 2).padding(2)
                Rectangle().strokeBorder(Color.accentColor, lineWidth: 3)
            } else {
                Rectangle().strokeBorder(Color.black.opacity(0.4), lineWidth: 0.5)
            }

            if tile.rect.width > 60 && tile.rect.height > 24 {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tile.node.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(ByteCountFormatter.string(fromByteCount: tile.node.size, countStyle: .file))
                        .font(.system(size: 10))
                        .opacity(0.8)
                }
                .padding(4)
                .foregroundStyle(.white)
            }
        }
        .contentShape(Rectangle())
        .help("\(tile.node.url.path)\n\(ByteCountFormatter.string(fromByteCount: tile.node.size, countStyle: .file))")
    }

    private func color(for node: FSNode) -> Color {
        guard !node.isDirectory else {
            return Color(hue: 0.58, saturation: 0.25, brightness: 0.55)
        }

        switch node.url.pathExtension.lowercased() {
        case "mov", "mp4", "mkv", "avi", "webm":
            return Color(hue: 0.95, saturation: 0.55, brightness: 0.7)
        case "jpg", "jpeg", "png", "gif", "heic", "tiff", "webp":
            return Color(hue: 0.12, saturation: 0.6, brightness: 0.75)
        case "mp3", "wav", "flac", "aac", "m4a":
            return Color(hue: 0.78, saturation: 0.5, brightness: 0.7)
        case "zip", "tar", "gz", "bz2", "7z", "rar", "dmg", "pkg":
            return Color(hue: 0.05, saturation: 0.7, brightness: 0.65)
        case "app":
            return Color(hue: 0.55, saturation: 0.6, brightness: 0.75)
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "key", "pages", "numbers":
            return Color(hue: 0.0, saturation: 0.45, brightness: 0.65)
        case "swift", "py", "js", "ts", "go", "rs", "c", "cpp", "h", "java", "rb":
            return Color(hue: 0.45, saturation: 0.5, brightness: 0.65)
        case let ext:
            // Anything else gets a stable hue derived from the extension.
            let hue = Double(abs(ext.hashValue) % 360) / 360.0
            return Color(hue: hue, saturation: 0.4, brightness: 0.6)
        }
    }
}
