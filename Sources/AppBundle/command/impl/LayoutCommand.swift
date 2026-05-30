import AppKit
import Common

struct LayoutCommand: Command {
    let args: LayoutCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        let targetDescription = args.toggleBetween.val.first(where: { !window.matchesDescription($0) })
            ?? args.toggleBetween.val.first.orDie()
        if window.matchesDescription(targetDescription) { return .fail }
        switch targetDescription {
            case .scrolling:
                return changeTilingLayout(io, targetLayout: .scrolling, targetOrientation: .h, window: window)
            case .horizontal:
                return changeTilingLayout(io, targetLayout: nil, targetOrientation: .h, window: window)
            case .vertical:
                return changeTilingLayout(io, targetLayout: nil, targetOrientation: .v, window: window)
            case .tiling:
                guard let parent = window.parent else { return .fail }
                switch parent.cases {
                    case .macosPopupWindowsContainer:
                        return .fail // Impossible
                    case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer, .macosHiddenAppsWindowsContainer:
                        return .fail(io.err("Can't change layout for macOS minimized, fullscreen windows or windows or hidden apps. This behavior is subject to change"))
                    case .tilingContainer:
                        return .succ // Nothing to do
                    case .workspace(let workspace):
                        window.lastFloatingSize = try await window.getAxSize() ?? window.lastFloatingSize
                        try await window.relayoutWindow(on: workspace, forceTile: true)
                        return .succ
                }
            case .floating:
                let workspace = target.workspace
                window.bindAsFloatingWindow(to: workspace)
                if let size = window.lastFloatingSize { window.setAxFrame(nil, size) }
                return .succ
        }
    }
}

@MainActor private func changeTilingLayout(_ io: CmdIo, targetLayout: Layout?, targetOrientation _: Orientation?, window: Window) -> BinaryExitCode {
    guard let parent = window.parent else { return .fail }
    switch parent.cases {
        case .tilingContainer(let parent):
            let targetLayout = targetLayout ?? parent.layout
            parent.layout = targetLayout
            return .succ
        case .workspace, .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
             .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer:
            return .fail(io.err("The window is non-tiling"))
    }
}

extension Window {
    fileprivate func matchesDescription(_ layout: LayoutCmdArgs.LayoutDescription) -> Bool {
        return switch layout {
            case .scrolling:   (parent as? TilingContainer)?.layout == .scrolling
            case .horizontal:  (parent as? TilingContainer)?.orientation == .h
            case .vertical:    (parent as? TilingContainer)?.orientation == .v
            case .tiling:      parent is TilingContainer
            case .floating:    parent is Workspace
        }
    }
}
