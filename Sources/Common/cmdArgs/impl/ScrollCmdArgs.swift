public struct ScrollCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .scroll,
        allowInConfig: true,
        help: scroll_help_generated,
        flags: [:],
        posArgs: [newMandatoryPosArgParser(\.direction, parseCardinalDirectionArg, placeholder: "(left|right)")],
    )

    public var direction: Lateinit<CardinalDirection> = .uninitialized

    public init(rawArgs: [String], _ direction: CardinalDirection) {
        self.commonState = .init(rawArgs.slice)
        self.direction = .initialized(direction)
    }
}

func parseScrollCmdArgs(_ args: StrArrSlice) -> ParsedCmd<ScrollCmdArgs> {
    parseSpecificCmdArgs(ScrollCmdArgs(rawArgs: args), args)
        .filter("scroll only accepts left or right") {
            $0.direction.val == .left || $0.direction.val == .right
        }
}
