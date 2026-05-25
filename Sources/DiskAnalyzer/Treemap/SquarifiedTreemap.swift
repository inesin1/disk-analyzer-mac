import CoreGraphics

struct TreemapRect {
    let node: FSNode
    let rect: CGRect
}

/// Squarified treemap layout: lays children out as rectangles whose areas are proportional to
/// their size, greedily filling rows that keep the aspect ratio as close to 1 as possible.
enum SquarifiedTreemap {
    private typealias Item = (node: FSNode, area: Double)

    static func layout(node: FSNode, in rect: CGRect, minPixelArea: CGFloat = 4) -> [TreemapRect] {
        let totalSize = node.children.reduce(Int64(0)) { $0 + $1.size }
        guard totalSize > 0, rect.width > 1, rect.height > 1 else { return [] }

        let areaPerByte = Double(rect.width) * Double(rect.height) / Double(totalSize)
        let items = node.children
            .map { Item(node: $0, area: Double($0.size) * areaPerByte) }
            .filter { $0.area >= Double(minPixelArea) }

        var results: [TreemapRect] = []
        squarify(items, in: rect, into: &results)
        return results
    }

    private static func squarify(_ items: [Item], in bounds: CGRect, into out: inout [TreemapRect]) {
        var items = items
        var rect = bounds

        while !items.isEmpty {
            let shortSide = Double(min(rect.width, rect.height))
            guard shortSide > 0 else { return }

            // Keep adding items to the row while doing so improves the worst aspect ratio.
            var row: [Item] = []
            for item in items {
                let candidate = row + [item]
                guard worstRatio(candidate, sideLength: shortSide) < worstRatio(row, sideLength: shortSide) else { break }
                row = candidate
            }

            let rowArea = row.reduce(0.0) { $0 + $1.area }
            if rect.width >= rect.height {
                let width = CGFloat(rowArea / shortSide)
                var y = rect.minY
                for item in row {
                    let height = CGFloat(item.area) / width
                    out.append(TreemapRect(node: item.node, rect: CGRect(x: rect.minX, y: y, width: width, height: height)))
                    y += height
                }
                rect = CGRect(x: rect.minX + width, y: rect.minY, width: rect.width - width, height: rect.height)
            } else {
                let height = CGFloat(rowArea / shortSide)
                var x = rect.minX
                for item in row {
                    let width = CGFloat(item.area) / height
                    out.append(TreemapRect(node: item.node, rect: CGRect(x: x, y: rect.minY, width: width, height: height)))
                    x += width
                }
                rect = CGRect(x: rect.minX, y: rect.minY + height, width: rect.width, height: rect.height - height)
            }

            items.removeFirst(row.count)
        }
    }

    /// Worst width/height ratio among the row's rectangles. `.infinity` for an empty row, so
    /// the first item is always accepted.
    private static func worstRatio(_ row: [Item], sideLength: Double) -> Double {
        guard !row.isEmpty else { return .infinity }

        let rowArea = row.reduce(0.0) { $0 + $1.area }
        let areaSquared = rowArea * rowArea
        let sideSquared = sideLength * sideLength

        return row.reduce(0.0) { worst, item in
            let ratio = (sideSquared * item.area) / areaSquared
            return max(worst, max(ratio, 1 / ratio))
        }
    }
}
