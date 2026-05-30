import Common

struct ToggleScrollFocusAlignmentCommand: Command {
    let args: ToggleScrollFocusAlignmentCmdArgs
    let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        config.scrollingFocusAlignment = switch config.scrollingFocusAlignment {
            case .center: .smart
            case .smart: .center
        }
        io.out("scrolling focus alignment: \(config.scrollingFocusAlignment.rawValue)")
        return .succ
    }
}
