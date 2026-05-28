# Changelog

All notable changes to PClash will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-05-28

### Added
- 🎉 项目初始化
- Flutter UI 框架（Material 3、暗色主题）
- Mihomo REST API 完整客户端
- Mihomo 进程生命周期管理（启动/停止/重启）
- 订阅管理（添加/删除/刷新）
- 实时流量监控（WebSocket）
- 节点选择与延迟测试
- 代理模式切换（规则/全局/直连）
- macOS 系统代理设置（HTTP/SOCKS）
- Android VpnService + TUN 模式
- Android 开机自启支持
- Riverpod 状态管理
- 本地配置持久化

### Platform Support
- 🟡 macOS (Apple Silicon + Intel) — 系统代理模式
- 🟡 Android (arm64 + x86_64) — VpnService + TUN 模式
