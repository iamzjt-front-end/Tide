<div align="center">

# Tide

**一款安静、可靠、完全本地的 macOS 菜单栏番茄钟。**

专注计时、休息循环、标签与统计，都留在你的 Mac 上。

[![Release](https://img.shields.io/github/v/release/iamzjt-front-end/Tide?style=flat-square&label=release)](https://github.com/iamzjt-front-end/Tide/releases/latest)
![macOS](https://img.shields.io/badge/macOS-14%2B-000000?style=flat-square&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white)
![Architecture](https://img.shields.io/badge/architecture-Apple%20Silicon%20%7C%20Intel-555555?style=flat-square)

[下载最新版](https://github.com/iamzjt-front-end/Tide/releases/latest) · [功能概览](#功能概览) · [参与开发](#参与开发)

</div>

## 为什么选择 Tide

Tide 专注于番茄钟最重要的部分：计时准确、状态可靠、操作自然。它常驻菜单栏，不占用 Dock；即使 Mac 休眠、应用挂起或重新启动，也会根据绝对时间恢复正确进度，而不是依赖容易漂移的逐秒累加。

所有设置、标签和专注记录都保存在本机。Tide 不要求注册账号，不包含云同步、行为分析或遥测。

## 功能概览

| 能力 | 说明 |
| --- | --- |
| 菜单栏计时 | 在菜单栏实时显示当前阶段、状态和剩余时间，不显示 Dock 图标 |
| 两种计时模式 | 支持番茄钟和正计时，可开始、暂停、继续、提前完成或重置 |
| 手动阶段衔接 | 专注或休息结束后切换到下一阶段待开始，由你决定何时手动启动 |
| 柔和提醒 | 阶段结束前 1 分钟无声提示，结束时播放提示音；设置中可随时发送测试提醒 |
| 可靠状态恢复 | 使用基于 `Date` 的状态机处理休眠、唤醒、挂起和重启后的时间推进 |
| 灵活配置 | 可调整专注时长、每轮番茄数、休息时长、通知和外观 |
| 专注标签 | 创建、编辑和选择彩色标签；计时进行中也可切换，并同步更新当次记录的标签快照 |
| 本地统计 | 查看日、周、月、年、全部或自定义范围的专注趋势和标签分布 |
| 数据管理 | 将专注记录导出为 CSV 或 JSON；清空历史前提供二次确认 |
| 原生体验 | 使用 SwiftUI、AppKit 和 Swift Charts；支持浅色、深色与跟随系统 |
| Liquid Glass | macOS 26 使用原生 Liquid Glass，macOS 14–15 自动回退到系统 Material |

## 下载与安装

1. 前往 [Releases](https://github.com/iamzjt-front-end/Tide/releases/latest) 下载最新的 `Tide-*-macos.dmg`。
2. 打开 DMG，将 `Tide.app` 拖入 `Applications` 文件夹。
3. 从“应用程序”启动 Tide；应用图标随后会出现在系统菜单栏。

当前公开构建采用 ad-hoc 签名，尚未经过 Apple 公证。如果 macOS 首次启动时提示无法验证开发者，请在 Finder 中右键 Tide，选择“打开”，然后再次确认。

### 系统要求

- macOS 14 Sonoma 或更高版本
- Apple Silicon 或 Intel Mac
- 系统通知权限为可选项，仅用于阶段结束提醒

## 使用方式

1. 点击菜单栏中的 Tide 图标打开计时面板。
2. 选择番茄钟或正计时模式，并按需选择专注标签。
3. 点击开始；计时过程中可以暂停、继续或提前完成。
4. 点击今日摘要进入统计页，查看趋势、完成次数和标签分布。
5. 从顶部设置入口调整时长、通知、外观，或导出本地记录。

## 数据与隐私

- 配置、计时状态和历史记录通过 `UserDefaults` 以 JSON 数据保存在本机。
- Tide 不需要账号，不包含云同步、广告、分析 SDK 或遥测。
- CSV / JSON 导出文件只会写入你在系统保存面板中选择的位置。
- 清空历史只删除专注与轮次记录，保留标签和计时设置。

## 从源码运行

### 开发环境

- Xcode 16 或更新版本
- Swift 6
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（仅在修改 `project.yml` 后重新生成工程时需要）

### 获取并运行

```sh
git clone https://github.com/iamzjt-front-end/Tide.git
cd Tide
open Tide.xcodeproj
```

在 Xcode 中选择 `Tide` Scheme 和 `My Mac`，按 `⌘R` 运行。

也可以从终端构建：

```sh
xcodebuild \
  -project Tide.xcodeproj \
  -scheme Tide \
  -destination 'platform=macOS' \
  build
```

修改 `project.yml` 后，重新生成 Xcode 工程：

```sh
xcodegen generate
```

## 测试

```sh
xcodebuild \
  -project Tide.xcodeproj \
  -scheme Tide \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

测试覆盖计时状态机、暂停与恢复、手动阶段衔接、跨重启恢复、防重复写入、标签快照、跨天统计、圆盘刻度、持久化以及 CSV / JSON 导出。

## 项目结构

```text
Tide/
├── App/          # App 入口、菜单栏状态项和 Popover 生命周期
├── Models/       # 配置、计时快照、标签、专注记录和归档模型
├── Resources/    # 完整尺寸的 macOS 应用图标
├── Services/     # 状态机、持久化、通知、统计和导出
├── Utilities/    # 时间、颜色与显示格式化
└── Views/        # 计时、统计、设置及通用视觉组件

TideTests/        # 业务逻辑和数据计算测试
project.yml       # XcodeGen 工程定义
```

核心状态由 `PomodoroController` 统一管理。UI 只负责呈现状态和发送用户意图；持久化、通知、统计与导出则通过独立服务隔离，便于测试和演进。

## 参与开发

欢迎提交 Issue 和 Pull Request。

1. Fork 仓库并从 `main` 创建功能分支。
2. 保持改动聚焦，并为业务逻辑补充相应测试。
3. 提交前运行完整测试，确认 `xcodegen generate` 不会产生未提交差异。
4. 在 Pull Request 中说明问题、解决方式、用户影响和验证结果。

如果准备处理较大的功能或交互调整，建议先创建 Issue 对齐设计方向。

---

<div align="center">

Made for focused work on macOS.

</div>
