public struct CenterColumnCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .centerColumn,
        allowInConfig: true,
        help: center_column_help_generated,
        flags: [:],
        posArgs: [],
    )
}
