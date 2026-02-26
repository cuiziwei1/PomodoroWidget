# 🍅 PomodoroWidget

一个轻量的 macOS 桌面番茄钟应用，透明窗口风格，支持任务管理。

## 功能

- 番茄钟倒计时（25/30/45分钟 + 自定义时长）
- 专注完成后自动切换 5 分钟休息倒计时
- 系统通知提醒（专注完成 / 休息结束）
- 今日累计专注时长统计
- 任务管理：添加、完成、删除、拖拽排序
- 子任务支持
- 按日期切换查看任务
- 任务数据本地持久化
- 透明无边框窗口，右键退出

## 截图

<!-- 可以在这里添加截图 -->

## 环境要求

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

## 安装运行

### 方式一：直接下载使用

1. 从 [Releases](https://github.com/cuiziwei1/PomodoroWidget/releases) 下载最新的 `PomodoroWidget.app.zip`
2. 解压后将 `PomodoroWidget.app` 拖到"应用程序"文件夹
3. 打开终端，执行以下命令进行签名和解除隔离：
```bash
sudo codesign --force --sign - /Applications/PomodoroWidget.app
sudo xattr -dr com.apple.quarantine /Applications/PomodoroWidget.app
```
4. 双击运行

### 方式二：源码编译

1. 克隆项目
```bash
git clone https://github.com/cuiziwei1/PomodoroWidget.git
```

2. 用 Xcode 打开项目，`Command + R` 运行

## 使用说明

- 选择时长 → 选择任务 → 点击"开始"
- 专注完成后自动显示 5 分钟休息倒计时，点"开始"进入休息
- 点"重置"跳过休息
- 右键窗口可退出应用

## License

MIT
