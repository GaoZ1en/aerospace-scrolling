import AppKit
import Common

final class TilingContainer: TreeNode, NonLeafTreeNodeObject {
    fileprivate var _orientation: Orientation
    var orientation: Orientation { _orientation }
    var layout: Layout

    @MainActor
    init(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, _ orientation: Orientation, _ layout: Layout, index: Int) {
        self._orientation = .h
        self.layout = .scrolling
        super.init(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    @MainActor
    static func newScrolling(parent: NonLeafTreeNodeObject, adaptiveWeight: CGFloat, index: Int) -> TilingContainer {
        TilingContainer(parent: parent, adaptiveWeight: adaptiveWeight, .h, .scrolling, index: index)
    }
}

extension TilingContainer {
    var isRootContainer: Bool { parent is Workspace }
    // Scrolling layout is always horizontal; orientation changes are no-ops.
    func normalizeOppositeOrientationForNestedContainers() {
        for child in children {
            (child as? TilingContainer)?.normalizeOppositeOrientationForNestedContainers()
        }
    }
}

enum Layout: String {
    case scrolling
}

extension String {
    func parseLayout() -> Layout? {
        Layout(rawValue: self)
    }
}
