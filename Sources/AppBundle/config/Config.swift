import AppKit
import Common
import HotKey
import OrderedCollections

func getDefaultConfigUrlFromProject() -> URL {
    var url = URL(filePath: #filePath)
    check(FileManager.default.fileExists(atPath: url.path))
    while !FileManager.default.fileExists(atPath: url.appending(component: ".git").path) {
        url.deleteLastPathComponent()
    }
    let projectRoot: URL = url
    return projectRoot.appending(component: "docs/config-examples/default-config.toml")
}

var defaultConfigUrl: URL {
    if isUnitTest {
        return getDefaultConfigUrlFromProject()
    } else {
        return Bundle.main.url(forResource: "default-config", withExtension: "toml")
            // Useful for debug builds that are not app bundles
            ?? getDefaultConfigUrlFromProject()
    }
}
@MainActor let defaultConfig: Config = {
    let parsedConfig = parseConfig(Result { try String(contentsOf: defaultConfigUrl, encoding: .utf8) }.getOrDie())
    if !parsedConfig.errors.isEmpty {
        die("Can't parse default config: \(parsedConfig.errors)")
    }
    return parsedConfig.config
}()
@MainActor var config: Config = defaultConfig // todo move to Ctx?
@MainActor var configUrl: URL = defaultConfigUrl

struct Config: ConvenienceCopyable {
    var configVersion: Int = 1
    var afterStartupCommand: [any Command] = []
    var enableNormalizationFlattenContainers: Bool = true
    var defaultRootContainerLayout: Layout = .scrolling
    var startAtLogin: Bool = false
    var automaticallyUnhideMacosHiddenApps: Bool = false
    var scrollingColumnWidth: Int = 80
    var scrollingFocusAlignment: ScrollFocusAlignment = .smart
    var enableNormalizationOppositeOrientationForNestedContainers: Bool = true
    var persistentWorkspaces: OrderedSet<String> = []
    var keyMapping = KeyMapping()
    var execConfig: ExecConfig = ExecConfig()

    var onFocusedMonitorChanged: [any Command] = []

    var gaps: Gaps = .zero
    var modes: [String: Mode] = [:]
    var onModeChanged: [any Command] = []
}

enum ScrollFocusAlignment: String {
    case center, smart
}
