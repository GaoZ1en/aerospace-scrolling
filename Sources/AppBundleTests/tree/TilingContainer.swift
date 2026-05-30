@testable import AppBundle
import AppKit

extension TilingContainer {
    @MainActor
    static func newScrolling(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat) -> TilingContainer {
        TilingContainer(parent: parent, adaptiveWeight: adaptiveWeight, .h, .scrolling, index: INDEX_BIND_LAST)
    }
}
