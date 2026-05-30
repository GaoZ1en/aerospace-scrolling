public enum ColumnWidthChange: Equatable, Sendable {
    case reset
    case points(Double)
    case percent(Double)
    case adjustPercent(Double)
}

public struct SetColumnWidthCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .setColumnWidth,
        allowInConfig: true,
        help: set_column_width_help_generated,
        flags: [:],
        posArgs: [newMandatoryPosArgParser(\.change, parseColumnWidthChange, placeholder: "(reset|<points>|<percent>%|[+|-]<percent>%)")],
    )

    public var change: Lateinit<ColumnWidthChange> = .uninitialized

    public init(rawArgs: [String], _ change: ColumnWidthChange) {
        self.commonState = .init(rawArgs.slice)
        self.change = .initialized(change)
    }
}

func parseSetColumnWidthCmdArgs(_ args: StrArrSlice) -> ParsedCmd<SetColumnWidthCmdArgs> {
    parseSpecificCmdArgs(SetColumnWidthCmdArgs(rawArgs: args), args)
}

private func parseColumnWidthChange(i: PosArgParserInput) -> ParsedCliArgs<ColumnWidthChange> {
    let arg = i.arg
    if arg == "reset" {
        return .succ(.reset, advanceBy: 1)
    }
    if arg.hasSuffix("%") {
        let rawNumber = String(arg.dropLast())
        guard let value = Double(rawNumber) else {
            return .fail("Can't parse column width percentage '\(arg)'", advanceBy: 1)
        }
        if rawNumber.starts(with: "+") || rawNumber.starts(with: "-") {
            return .succ(.adjustPercent(value), advanceBy: 1)
        }
        return .succ(.percent(value), advanceBy: 1)
    }
    guard let points = Double(arg) else {
        return .fail("Can't parse column width '\(arg)'", advanceBy: 1)
    }
    return .succ(.points(points), advanceBy: 1)
}
