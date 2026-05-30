@testable import AppBundle
import Common
import XCTest

@MainActor
final class ScrollingColumnCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParseScrollingCommands() {
        testParseCommandSucc("layout scrolling", LayoutCmdArgs(rawArgs: [], toggleBetween: [.scrolling]))
        testParseCommandSucc("center-column", CenterColumnCmdArgs(rawArgs: []))
        testParseCommandSucc("scroll left", ScrollCmdArgs(rawArgs: [], .left))
        testParseCommandSucc("scroll right", ScrollCmdArgs(rawArgs: [], .right))
        testParseCommandSucc("move-column left", MoveColumnCmdArgs(rawArgs: [], .left))
        testParseCommandSucc("move-column right", MoveColumnCmdArgs(rawArgs: [], .right))
        testParseCommandSucc("set-column-width reset", SetColumnWidthCmdArgs(rawArgs: [], .reset))
        testParseCommandSucc("set-column-width 700", SetColumnWidthCmdArgs(rawArgs: [], .points(700)))
        testParseCommandSucc("set-column-width 50%", SetColumnWidthCmdArgs(rawArgs: [], .percent(50)))
        testParseCommandSucc("set-column-width +10%", SetColumnWidthCmdArgs(rawArgs: [], .adjustPercent(10)))
        testParseCommandSucc("set-column-width -10%", SetColumnWidthCmdArgs(rawArgs: [], .adjustPercent(-10)))

        testParseCommandFail("scroll up", msg: "scroll only accepts left or right", exitCode: 2)
        testParseCommandFail("move-column down", msg: "move-column only accepts left or right", exitCode: 2)
    }

    func testScrollFocusesAdjacentColumn() async throws {
        let root = scrollingRoot()
        let window1 = TestWindow.new(id: 1, parent: root)
        let window2 = TestWindow.new(id: 2, parent: root)
        let window3 = TestWindow.new(id: 3, parent: root)
        assertEquals(window2.focusWindow(), true)

        assertEquals(try await ScrollCommand(args: ScrollCmdArgs(rawArgs: [], .right)).run(.defaultEnv, .emptyStdin).exitCode.rawValue, 0)
        assertEquals(focus.windowOrNil?.windowId, window3.windowId)

        assertEquals(try await ScrollCommand(args: ScrollCmdArgs(rawArgs: [], .left)).run(.defaultEnv, .emptyStdin).exitCode.rawValue, 0)
        assertEquals(focus.windowOrNil?.windowId, window2.windowId)

        assertEquals(window1.focusWindow(), true)
        assertEquals(try await ScrollCommand(args: ScrollCmdArgs(rawArgs: [], .left)).run(.defaultEnv, .emptyStdin).exitCode.rawValue, 2)
        assertEquals(focus.windowOrNil?.windowId, window1.windowId)
    }

    func testMoveColumnReordersRootChildren() async throws {
        let root = scrollingRoot()
        TestWindow.new(id: 1, parent: root)
        let window2 = TestWindow.new(id: 2, parent: root)
        TestWindow.new(id: 3, parent: root)
        assertEquals(window2.focusWindow(), true)

        assertEquals(try await MoveColumnCommand(args: MoveColumnCmdArgs(rawArgs: [], .right)).run(.defaultEnv, .emptyStdin).exitCode.rawValue, 0)
        assertEquals(root.layoutDescription, .scrolling([.window(1), .window(3), .window(2)]))

        assertEquals(try await MoveColumnCommand(args: MoveColumnCmdArgs(rawArgs: [], .left)).run(.defaultEnv, .emptyStdin).exitCode.rawValue, 0)
        assertEquals(root.layoutDescription, .scrolling([.window(1), .window(2), .window(3)]))
    }

    func testSetColumnWidthStoresPointWidthOnFocusedColumn() async throws {
        let root = scrollingRoot()
        TestWindow.new(id: 1, parent: root)
        let window2 = TestWindow.new(id: 2, parent: root)
        assertEquals(window2.focusWindow(), true)

        assertEquals(try await SetColumnWidthCommand(args: SetColumnWidthCmdArgs(rawArgs: [], .points(640))).run(.defaultEnv, .emptyStdin).exitCode.rawValue, 0)
        assertEquals(window2.hWeight, 640)

        assertEquals(try await SetColumnWidthCommand(args: SetColumnWidthCmdArgs(rawArgs: [], .reset)).run(.defaultEnv, .emptyStdin).exitCode.rawValue, 0)
        assertEquals(window2.hWeight, 1)
    }

    func testScrollingLayoutCentersFocusedColumn() async throws {
        config.scrollingFocusAlignment = .center
        let root = scrollingRoot()
        let window1 = TestWindow.new(id: 1, parent: root)
        let window2 = TestWindow.new(id: 2, parent: root)
        let window3 = TestWindow.new(id: 3, parent: root)
        assertEquals(window2.focusWindow(), true)

        try await focus.workspace.layoutWorkspace()

        assertRect(window1.lastAppliedLayoutPhysicalRect, Rect(topLeftX: -1344, topLeftY: 0, width: 1536, height: 1079))
        assertRect(window2.lastAppliedLayoutPhysicalRect, Rect(topLeftX: 192, topLeftY: 0, width: 1536, height: 1079))
        assertRect(window3.lastAppliedLayoutPhysicalRect, Rect(topLeftX: 1728, topLeftY: 0, width: 1536, height: 1079))
        assertRect(try await window2.getAxRect(), Rect(topLeftX: 192, topLeftY: 0, width: 1536, height: 1079))
    }

    func testSetColumnWidthChangesScrollingLayoutWidth() async throws {
        config.scrollingFocusAlignment = .center
        let root = scrollingRoot()
        TestWindow.new(id: 1, parent: root)
        let window2 = TestWindow.new(id: 2, parent: root)
        TestWindow.new(id: 3, parent: root)
        assertEquals(window2.focusWindow(), true)

        assertEquals(try await SetColumnWidthCommand(args: SetColumnWidthCmdArgs(rawArgs: [], .percent(50))).run(.defaultEnv, .emptyStdin).exitCode.rawValue, 0)
        try await focus.workspace.layoutWorkspace()

        assertRect(window2.lastAppliedLayoutPhysicalRect, Rect(topLeftX: 480, topLeftY: 0, width: 960, height: 1079))
    }

    private func scrollingRoot() -> TilingContainer {
        let root = Workspace.get(byName: name).rootTilingContainer
        root.layout = .scrolling
        return root
    }

    private func assertRect(_ actual: Rect?, _ expected: Rect, file: String = #filePath, line: Int = #line) {
        guard let actual else {
            XCTFail("Expected rect \(expected), got nil")
            return
        }
        assertEquals(actual.topLeftX, expected.topLeftX, file: file, line: line)
        assertEquals(actual.topLeftY, expected.topLeftY, file: file, line: line)
        assertEquals(actual.width, expected.width, file: file, line: line)
        assertEquals(actual.height, expected.height, file: file, line: line)
    }
}
