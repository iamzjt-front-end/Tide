# Tide

Tide 是一款面向 macOS 14+ 的本地菜单栏番茄钟。它使用 SwiftUI、AppKit 和 Swift Charts，实现圆盘计时界面、基于绝对时间的可靠倒计时与本地专注统计。

## 功能

- 菜单栏实时显示图标和剩余时间，不显示 Dock 图标
- 番茄钟与正计时模式
- 开始、暂停、继续、确认停止；专注结束自动休息，休息结束自动开始下一轮
- 休眠、挂起或重启后的 Date 驱动恢复
- 本地通知、JSON 持久化和单一专注标签体系
- `420×610` 圆盘弹层与可置顶模式
- 跟随系统、浅色和深色三种外观；macOS 26 使用原生 Liquid Glass，macOS 14–15 使用原生 Material 回退
- 计时为主界面，今日摘要直接进入统计，设置由顶部按钮打开锚定弹层
- 日、周、月、年、全部和自定义范围统计
- 标签时间分布、完成数和放弃数
- CSV / JSON 导出及二次确认清空历史

## 运行

1. 使用 Xcode 16 或更新版本打开 `Tide.xcodeproj`。
2. 选择 `Tide` Scheme 和 `My Mac`。
3. 按 `⌘R` 运行；App 会出现在系统菜单栏中。

也可以在终端构建：

```sh
xcodebuild -project Tide.xcodeproj -scheme Tide -destination 'platform=macOS' build
```

如果修改了 `project.yml`，先安装并运行 XcodeGen：

```sh
xcodegen generate
```

## 测试

```sh
xcodebuild -project Tide.xcodeproj -scheme Tide -destination 'platform=macOS' test
```

测试覆盖计时状态机、暂停/继续、停止、自动休息、到期恢复、防重复写入、跨天统计、标签快照和 CSV/JSON 导出。

## 主要目录

- `Tide/App`：AppKit 菜单栏状态项、Popover 生命周期和 App 入口
- `Tide/Models`：计时快照、设置、会话与兼容旧数据的标签模型
- `Tide/Services`：Date 状态机、JSON 存储、通知、统计和导出
- `Tide/Views`：Liquid Glass 视觉组件、计时圆盘、统计、设置和统一标签交互
- `TideTests`：业务逻辑与数据计算单元测试
