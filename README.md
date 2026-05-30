# AeroSpace Scrolling Fork

> 基于 [AeroSpace](https://github.com/nikitabobko/AeroSpace) 的个人 fork，专注于 scrolling layout。

## 与原版的区别

- **仅保留 scrolling 布局**：删除了 `tiles` 和 `accordion` 布局及其相关代码
- **删除未使用的命令**：`balance-sizes`、`split`、`join-with`、`resize`
- **删除未使用的配置项**：`auto-reload-config`、`on-focus-changed`、`on-window-detected`、`workspace-to-monitor-force-assignment`、`accordion-padding`、`default-root-container-orientation` 及所有废弃项
- **新增 scroll focus alignment**：`smart`（类似 niri，视口不动除非焦点列超出屏幕）和 `center`（始终居中），`toggle-scroll-focus-alignment` 命令切换
- **新增可配置列宽**：`scrolling-column-width`（百分比，30-100，默认 80）
- **新增滚动列命令**：`scroll left/right`、`center-column`、`move-column left/right`、`set-column-width`

## 安装

```bash
# CLI
sudo cp .build/arm64-apple-macosx/release/aerospace /opt/homebrew/bin/aerospace

# App Bundle
sudo cp -r .xcode-build/Build/Products/Release/AeroSpace.app /Applications/
```

## 构建

```bash
swift build -c release --arch arm64 --product aerospace
xcodebuild -scheme AeroSpace -destination "generic/platform=macOS" -configuration Release -derivedDataPath .xcode-build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
codesign --force --deep --sign - .xcode-build/Build/Products/Release/AeroSpace.app
```

