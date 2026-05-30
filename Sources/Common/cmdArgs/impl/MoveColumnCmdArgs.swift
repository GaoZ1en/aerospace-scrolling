public struct MoveColumnCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .moveColumn,
        allowInConfig: true,
        help: move_column_help_generated,
        flags: [:],
        posArgs: [newMandatoryPosArgParser(\.direction, parseCardinalDirectionArg, placeholder: "(left|right)")],
    )

    public var direction: Lateinit<CardinalDirection> = .uninitialized

    public init(rawArgs: [String], _ direction: CardinalDirection) {
        self.commonState = .init(rawArgs.slice)
        self.direction = .initialized(direction)
    }
}

func parseMoveColumnCmdArgs(_ args: StrArrSlice) -> ParsedCmd<MoveColumnCmdArgs> {
    parseSpecificCmdArgs(MoveColumnCmdArgs(rawArgs: args), args)
        .filter("move-column only accepts left or right") {
            $0.direction.val == .left || $0.direction.val == .right
        }
}
