import AppKit
import Common

struct CenterColumnCommand: Command {
    let args: CenterColumnCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    @MainActor
    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let column = focusedScrollingColumn(io) else { return .fail }
        column.markAsMostRecentChild()
        return .succ
    }
}

struct ScrollCommand: Command {
    let args: ScrollCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    @MainActor
    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let column = focusedScrollingColumn(io) else { return .fail }
        guard let index = column.ownIndex else { return .fail }
        let root = focus.workspace.rootTilingContainer
        let targetIndex = index + args.direction.val.focusOffset
        guard let target = root.children.getOrNil(atIndex: targetIndex) else { return .fail }
        target.markAsMostRecentChild()
        _ = target.mostRecentWindowRecursive?.focusWindow()
        return .succ
    }
}

struct MoveColumnCommand: Command {
    let args: MoveColumnCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    @MainActor
    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let column = focusedScrollingColumn(io) else { return .fail }
        guard let index = column.ownIndex else { return .fail }
        let root = focus.workspace.rootTilingContainer
        let targetIndex = index + args.direction.val.focusOffset
        guard root.children.indices.contains(targetIndex) else { return .fail }
        let binding = column.unbindFromParent()
        column.bind(to: binding.parent, adaptiveWeight: binding.adaptiveWeight, index: targetIndex)
        column.markAsMostRecentChild()
        return .succ
    }
}

struct SetColumnWidthCommand: Command {
    let args: SetColumnWidthCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    @MainActor
    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let column = focusedScrollingColumn(io) else { return .fail }
        let viewportWidth = focus.workspace.workspaceMonitor.visibleRectPaddedByOuterGaps.width
        switch args.change.val {
            case .reset:
                column.setWeight(.h, 1)
            case .points(let width):
                column.setWeight(.h, CGFloat(width))
            case .percent(let percent):
                column.setWeight(.h, viewportWidth * CGFloat(percent) / 100)
            case .adjustPercent(let percent):
                let nextWidth = column.getWeight(.h) + viewportWidth * CGFloat(percent) / 100
                column.setWeight(.h, nextWidth)
        }
        column.markAsMostRecentChild()
        return .succ
    }
}

@MainActor
private func focusedScrollingColumn(_ io: CmdIo) -> TreeNode? {
    let root = focus.workspace.rootTilingContainer
    guard root.layout == .scrolling else {
        _ = io.err("The workspace root layout is not scrolling")
        return nil
    }
    guard let window = focus.windowOrNil else {
        _ = io.err(noWindowIsFocused)
        return nil
    }
    guard let column = window.parentsWithSelf.first(where: { $0.parent === root }) else {
        _ = io.err("The focused window is not in a scrolling column")
        return nil
    }
    return column
}

private extension CardinalDirection {
    var focusOffset: Int {
        switch self {
            case .left: -1
            case .right: 1
            case .up, .down: dieT("Expected horizontal direction")
        }
    }
}
