import AppKit

@MainActor fileprivate var scrollOffsets: [ObjectIdentifier: CGFloat] = [:]

extension Workspace {
    @MainActor
    func layoutWorkspace() async throws {
        if isEffectivelyEmpty { return }
        let rect = workspaceMonitor.visibleRectPaddedByOuterGaps
        // If monitors are aligned vertically and the monitor below has smaller width, then macOS may not allow the
        // window on the upper monitor to take full width. rect.height - 1 resolves this problem
        // But I also faced this problem in monitors horizontal configuration. ¯\_(ツ)_/¯
        try await layoutRecursive(rect.topLeftCorner, width: rect.width, height: rect.height - 1, virtual: rect, LayoutContext(self))
    }
}

extension TreeNode {
    @MainActor
    fileprivate func layoutRecursive(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        let physicalRect = Rect(topLeftX: point.x, topLeftY: point.y, width: width, height: height)
        switch nodeCases {
            case .workspace(let workspace):
                lastAppliedLayoutPhysicalRect = physicalRect
                lastAppliedLayoutVirtualRect = virtual
                try await workspace.rootTilingContainer.layoutRecursive(point, width: width, height: height, virtual: virtual, context)
                for window in workspace.children.filterIsInstance(of: Window.self) {
                    window.lastAppliedLayoutPhysicalRect = nil
                    window.lastAppliedLayoutVirtualRect = nil
                    try await window.layoutFloatingWindow(context)
                }
            case .window(let window):
                if window.windowId != currentlyManipulatedWithMouseWindowId {
                    lastAppliedLayoutVirtualRect = virtual
                    if window.isFullscreen && window == context.workspace.rootTilingContainer.mostRecentWindowRecursive {
                        lastAppliedLayoutPhysicalRect = nil
                        window.layoutFullscreen(context)
                    } else {
                        lastAppliedLayoutPhysicalRect = physicalRect
                        window.isFullscreen = false
                        window.setAxFrame(point, CGSize(width: width, height: height))
                    }
                }
            case .tilingContainer(let container):
                lastAppliedLayoutPhysicalRect = physicalRect
                lastAppliedLayoutVirtualRect = virtual
                try await container.layoutScrolling(point, width: width, height: height, virtual: virtual, context)
            case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
                 .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer:
                return // Nothing to do for weirdos
        }
    }
}

private struct LayoutContext {
    let workspace: Workspace
    let resolvedGaps: ResolvedGaps

    @MainActor
    init(_ workspace: Workspace) {
        self.workspace = workspace
        self.resolvedGaps = ResolvedGaps(gaps: config.gaps, monitor: workspace.workspaceMonitor)
    }
}

extension Window {
    @MainActor
    fileprivate func layoutFloatingWindow(_ context: LayoutContext) async throws {
        let workspace = context.workspace
        let windowRect = try await getAxRect() // Probably not idempotent
        let currentMonitor = windowRect?.center.monitorApproximation
        if let currentMonitor, let windowRect, workspace != currentMonitor.activeWorkspace {
            let windowTopLeftCorner = windowRect.topLeftCorner
            let xProportion = (windowTopLeftCorner.x - currentMonitor.visibleRect.topLeftX) / currentMonitor.visibleRect.width
            let yProportion = (windowTopLeftCorner.y - currentMonitor.visibleRect.topLeftY) / currentMonitor.visibleRect.height

            let workspaceRect = workspace.workspaceMonitor.visibleRect
            var newX = workspaceRect.topLeftX + xProportion * workspaceRect.width
            var newY = workspaceRect.topLeftY + yProportion * workspaceRect.height

            let windowWidth = windowRect.width
            let windowHeight = windowRect.height
            newX = newX.coerce(in: workspaceRect.minX ... max(workspaceRect.minX, workspaceRect.maxX - windowWidth))
            newY = newY.coerce(in: workspaceRect.minY ... max(workspaceRect.minY, workspaceRect.maxY - windowHeight))

            setAxFrame(CGPoint(x: newX, y: newY), nil)
        }
        if isFullscreen {
            layoutFullscreen(context)
            isFullscreen = false
        }
    }

    @MainActor
    fileprivate func layoutFullscreen(_ context: LayoutContext) {
        let monitorRect = noOuterGapsInFullscreen
            ? context.workspace.workspaceMonitor.visibleRect
            : context.workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        setAxFrame(monitorRect.topLeftCorner, CGSize(width: monitorRect.width, height: monitorRect.height))
    }
}

extension TilingContainer {
    @MainActor
    fileprivate func layoutScrolling(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        guard !children.isEmpty else { return }

        let rawGap = context.resolvedGaps.inner.get(.h).toDouble()
        let widths = children.map { scrollingColumnWidth(for: $0, viewportWidth: width) }
        let totalWidth = widths.reduce(CGFloat(0), +)
        let mruIndex = mostRecentChild?.ownIndex ?? 0
        let mruLeading = widths.prefix(mruIndex).reduce(CGFloat(0), +)
        let mruWidth = widths[mruIndex]
        let lastOffset = scrollOffsets[ObjectIdentifier(self)] ?? 0
        let targetOffset = switch config.scrollingFocusAlignment {
            case .center: mruLeading + mruWidth / 2 - width / 2
            case .smart:
                mruLeading >= lastOffset && (mruLeading + mruWidth) <= lastOffset + width
                    ? lastOffset
                    : mruLeading
        }
        let scrollOffset = targetOffset.coerce(in: 0 ... max(0, totalWidth - width))
        scrollOffsets[ObjectIdentifier(self)] = scrollOffset

        var columnX = point.x - scrollOffset
        var virtualX = virtual.topLeftX
        let lastIndex = children.indices.last
        for (index, child) in children.enumerated() {
            let columnWidth = widths[index]
            child.setWeight(.h, columnWidth)
            let gap = rawGap - (index == 0 ? rawGap / 2 : 0) - (index == lastIndex ? rawGap / 2 : 0)
            let childX = index == 0 ? columnX : columnX + rawGap / 2
            try await child.layoutRecursive(
                CGPoint(x: childX, y: point.y),
                width: columnWidth - gap,
                height: height,
                virtual: Rect(topLeftX: virtualX, topLeftY: virtual.topLeftY, width: columnWidth, height: height),
                context,
            )
            columnX += columnWidth
            virtualX += columnWidth
        }

        lastAppliedLayoutVirtualRect = Rect(topLeftX: virtual.topLeftX, topLeftY: virtual.topLeftY, width: totalWidth, height: height)
    }

    @MainActor
    private func scrollingColumnWidth(for child: TreeNode, viewportWidth: CGFloat) -> CGFloat {
        let defaultWidth = max(CGFloat(320), viewportWidth * CGFloat(config.scrollingColumnWidth) / 100.0)
        let explicitWidth = child.getWeight(.h)
        guard explicitWidth >= 160 else { return defaultWidth }
        return explicitWidth.coerce(in: 160 ... max(480, viewportWidth * 1.5))
    }
}
