@testable import AppBundle
import Common
import XCTest

@MainActor
final class ConfigTest: XCTestCase {
    func testParseI3Config() {
        let toml = try! String(contentsOf: projectRoot.appending(component: "docs/config-examples/i3-like-config-example.toml"), encoding: .utf8)
        let (i3Config, errors) = parseConfig(toml)
        assertEquals(errors, [])
        assertEquals(i3Config.execConfig, defaultConfig.execConfig)
        assertEquals(i3Config.enableNormalizationFlattenContainers, false)
        assertEquals(i3Config.enableNormalizationOppositeOrientationForNestedContainers, false)
    }

    func testParseDefaultConfig() {
        let toml = try! String(contentsOf: projectRoot.appending(component: "docs/config-examples/default-config.toml"), encoding: .utf8)
        let (_, errors) = parseConfig(toml)
        assertEquals(errors, [])
    }

    func testConfigVersionOutOfBounds() {
        let (_, errors) = parseConfig(
            """
            config-version = 0
            """,
        )
        assertEquals(errors, ["config-version: Must be in [1, 2] range"])
    }

    func testDuplicatedPersistentWorkspaces() {
        let (_, errors) = parseConfig(
            """
            config-version = 2
            persistent-workspaces = ['a', 'a']
            """,
        )
        assertEquals(errors, ["persistent-workspaces: Contains duplicated workspace names"])
    }

    func testPersistentWorkspacesAreAvailableOnlySinceVersion2() {
        let (_, errors) = parseConfig(
            """
            persistent-workspaces = ['a']
            """,
        )
        assertEquals(errors, ["persistent-workspaces: This config option is only available since \'config-version = 2\'"])
    }

    func testQueryCantBeUsedInConfig() {
        let (_, errors) = parseConfig(
            """
            [mode.main.binding]
                alt-a = 'list-apps'
            """,
        )
        XCTAssertTrue(errors.singleOrNil()?.contains("cannot be used in config") == true)
    }

    func testDropBindings() {
        let (config, errors) = parseConfig(
            """
            mode.main = {}
            """,
        )
        assertEquals(errors, [])
        XCTAssertTrue(config.modes[mainModeId]?.bindings.isEmpty == true)
    }

    func testParseMode() {
        let (config, errors) = parseConfig(
            """
            [mode.main.binding]
                alt-h = 'focus left'
            """,
        )
        assertEquals(errors, [])
        let binding = HotkeyBinding(.option, .h, [FocusCommand.new(direction: .left)])
        assertEquals(
            config.modes[mainModeId],
            Mode(bindings: [binding.descriptionWithKeyCode: binding]),
        )
    }

    func testModesMustContainDefaultModeError() {
        let (config, errors) = parseConfig(
            """
            [mode.foo.binding]
                alt-h = 'focus left'
            """,
        )
        assertEquals(
            errors,
            ["mode: Please specify \'main\' mode"],
        )
        assertEquals(config.modes[mainModeId], nil)
    }

    func testHotkeyParseError() {
        let (config, errors) = parseConfig(
            """
            [mode.main.binding]
                alt-hh = 'focus left'
                aalt-j = 'focus down'
                alt-k = 'focus up'
            """,
        )
        assertEquals(
            errors,
            [
                "mode.main.binding.aalt-j: Can\'t parse modifiers in \'aalt-j\' binding",
                "mode.main.binding.alt-hh: Can\'t parse the key in \'alt-hh\' binding",
            ],
        )
        let binding = HotkeyBinding(.option, .k, [FocusCommand.new(direction: .up)])
        assertEquals(
            config.modes[mainModeId],
            Mode(bindings: [binding.descriptionWithKeyCode: binding]),
        )
    }

    func testUnknownTopLevelKeyParseError() {
        let (config, errors) = parseConfig(
            """
            unknownKey = true
            enable-normalization-flatten-containers = false
            """,
        )
        assertEquals(
            errors,
            ["unknownKey: Unknown top-level key"],
        )
        assertEquals(config.enableNormalizationFlattenContainers, false)
    }

    func testUnknownKeyParseError() {
        let (config, errors) = parseConfig(
            """
            enable-normalization-flatten-containers = false
            [gaps]
                unknownKey = true
            """,
        )
        assertEquals(
            errors,
            ["gaps.unknownKey: Unknown key"],
        )
        assertEquals(config.enableNormalizationFlattenContainers, false)
    }

    func testTypeMismatch() {
        let (_, errors) = parseConfig(
            """
            enable-normalization-flatten-containers = 'true'
            """,
        )
        assertEquals(
            errors,
            ["enable-normalization-flatten-containers: Expected type is \'bool\'. But actual type is \'string\'"],
        )
    }

    func testConfigParseError() {
        assertEquals(
            parseConfig("true").errors,
            ["(Line 1) Syntax error: missing =."],
        )

        assertEquals(
            parseConfig("\n1").errors,
            ["(Line 2) Syntax error: missing =."],
        )

        assertEquals(
            parseConfig("foo: 1").errors,
            ["(Line 1) Syntax error: missing =."],
        )

        assertEquals(
            parseConfig("foo = 1.0").errors,
            ["foo: Unsupported TOML type: Double"],
        )

        assertEquals(
            parseConfig("foo.bar = 1979-05-27").errors,
            ["foo.bar: Unsupported TOML type: LocalDate"],
        )
    }

    func testMoveWorkspaceToMonitorCommandParsing() {
        XCTAssertTrue(parseCommand("move-workspace-to-monitor --wrap-around next").cmdOrNil is MoveWorkspaceToMonitorCommand)
        XCTAssertTrue(parseCommand("move-workspace-to-display --wrap-around next").cmdOrNil is MoveWorkspaceToMonitorCommand)
    }

    func testScrollingLayoutConfig() {
        let (config, errors) = parseConfig(
            """
            default-root-container-layout = 'scrolling'
            """,
        )
        assertEquals(errors, [])
        assertEquals(config.defaultRootContainerLayout, .scrolling)
    }

    func testRegex() {
        var devNull: [String] = []
        XCTAssertTrue("System Settings".contains(caseInsensitiveRegex: CaseInsensitiveRegex.new("settings").getOrNil(appendErrorTo: &devNull)!))
        XCTAssertTrue(!"System Settings".contains(caseInsensitiveRegex: CaseInsensitiveRegex.new("^settings^").getOrNil(appendErrorTo: &devNull)!))
    }

    func testParseGaps() {
        let (config, errors1) = parseConfig(
            """
            [gaps]
                inner.horizontal = 10
                inner.vertical = [{ monitor."main" = 1 }, { monitor."secondary" = 2 }, 5]
                outer.left = 12
                outer.bottom = 13
                outer.top = [{ monitor."built-in" = 3 }, { monitor."secondary" = 4 }, 6]
                outer.right = [{ monitor.2 = 7 }, 8]
            """,
        )
        assertEquals(errors1, [])
        assertEquals(
            config.gaps,
            Gaps(
                inner: .init(
                    vertical: .perMonitor(
                        [PerMonitorValue(description: .main, value: 1), PerMonitorValue(description: .secondary, value: 2)],
                        default: 5,
                    ),
                    horizontal: .constant(10),
                ),
                outer: .init(
                    left: .constant(12),
                    bottom: .constant(13),
                    top: .perMonitor(
                        [
                            PerMonitorValue(description: .pattern("built-in")!, value: 3),
                            PerMonitorValue(description: .secondary, value: 4),
                        ],
                        default: 6,
                    ),
                    right: .perMonitor([PerMonitorValue(description: .sequenceNumber(2), value: 7)], default: 8),
                ),
            ),
        )

        let (_, errors2) = parseConfig(
            """
            [gaps]
                inner.horizontal = [true]
                inner.vertical = [{ foo.main = 1 }, { monitor = { foo = 2, bar = 3 } }, 1]
            """,
        )
        assertEquals(errors2, [
            "gaps.inner.horizontal: The last item in the array must be of type Int",
            "gaps.inner.vertical[0]: The table is expected to have a single key \'monitor\'",
            "gaps.inner.vertical[1].monitor: The table is expected to have a single key",
        ])
    }

    func testParseKeyMapping() {
        let (config, errors) = parseConfig(
            """
            [key-mapping.key-notation-to-key-code]
                q = 'q'
                unicorn = 'u'

            [mode.main.binding]
                alt-unicorn = 'workspace wonderland'
            """,
        )
        assertEquals(errors, [])
        assertEquals(config.keyMapping, KeyMapping(preset: .qwerty, rawKeyNotationToKeyCode: [
            "q": .q,
            "unicorn": .u,
        ]))
        let binding = HotkeyBinding(.option, .u, [WorkspaceCommand(args: WorkspaceCmdArgs(target: .direct(.parse("unicorn").getOrDie())))])
        assertEquals(config.modes[mainModeId]?.bindings, [binding.descriptionWithKeyCode: binding])

        let (_, errors1) = parseConfig(
            """
            [key-mapping.key-notation-to-key-code]
                q = 'qw'
                ' f' = 'f'
            """,
        )
        assertEquals(errors1, [
            "key-mapping.key-notation-to-key-code.q: 'qw' is invalid key code",
            "key-mapping.key-notation-to-key-code: ' f' is invalid key notation",
        ])

        let (dvorakConfig, dvorakErrors) = parseConfig(
            """
            key-mapping.preset = 'dvorak'
            """,
        )
        assertEquals(dvorakErrors, [])
        assertEquals(dvorakConfig.keyMapping, KeyMapping(preset: .dvorak, rawKeyNotationToKeyCode: [:]))
        assertEquals(dvorakConfig.keyMapping.resolve()["quote"], .q)
        let (colemakConfig, colemakErrors) = parseConfig(
            """
            key-mapping.preset = 'colemak'
            """,
        )
        assertEquals(colemakErrors, [])
        assertEquals(colemakConfig.keyMapping, KeyMapping(preset: .colemak, rawKeyNotationToKeyCode: [:]))
        assertEquals(colemakConfig.keyMapping.resolve()["f"], .e)
    }
}
