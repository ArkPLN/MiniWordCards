# 小小词卡

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10+-0175C2?style=flat&logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/License-Private-lightgrey?style=flat)](#)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20Windows-blue?style=flat)](#)

English documentation: [README.md](README.md)

小小词卡是一个基于 Flutter 的轻量学习工具，支持从 CSV 导入词典、检索单词，并通过翻卡进行记忆训练。

## 功能概览

- 单词卡学习
- 3D 翻牌动画（正反面切换）
- 单词/释义独立黑条遮盖（按钮切换 + 点击文本切换）
- 左右滑动切卡
- 两种模式：
  - 自由翻阅
  - 一次 N 张
- 大词库自动懒加载（>300 条时按批次加载）
- 本地词典管理：
  - 导入 CSV
  - 启用/禁用词典
  - 导出词典
  - 删除词典
- 设置项：
  - 主题模式
  - 懒加载优化开关（默认开启，自动记忆）
  - GitHub 入口（设置 -> 关于）

## 项目结构

```text
lib/
  data/            默认词典数据
  dto/             数据对象
  pages/           页面与组件
  repositories/    仓库层
  services/        服务层（数据库、设置、文件等）
test/              测试
```

## 开发环境

- Flutter: 3.x（建议与本地项目 SDK 保持一致）
- Dart: ^3.10.4
- Android 构建链：AGP 8.9.1

## 快速开始

```bash
flutter pub get
flutter run
```

## 常用命令

```bash
flutter analyze
flutter test
flutter run -d windows
flutter run -d chrome
flutter build apk --release --target-platform android-arm64
```

## CSV 字段建议

- `word`
- `meaning`
- `abbreviation`（可选）

## 常见问题

- `Could not acquire the lock to .dart_tool/.../.lock`
  - 先结束残留 `dart/flutter` 进程，再删除 lock 文件后重试。
- Android 构建报 AAR metadata / AGP 兼容问题
  - 使用当前仓库中已配置的 Android 构建链（AGP 8.9.1）。
