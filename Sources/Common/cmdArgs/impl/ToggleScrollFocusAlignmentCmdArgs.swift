public struct ToggleScrollFocusAlignmentCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .toggleScrollFocusAlignment,
        allowInConfig: true,
        help: toggle_scroll_focus_alignment_help_generated,
        flags: [:],
        posArgs: [],
    )
}
