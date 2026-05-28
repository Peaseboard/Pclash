# 🐌 PClash - Pease Proxy Client

> A modern, cross-platform proxy client powered by [Mihomo](https://github.com/MetaCubeX/mihomo) (formerly Clash.Meta).

**Pease 家族成员** — 与 Pboard、PeaseAPI 无缝集成。

---

## ✨ 特性

- **全协议支持** — SS / VMess / VLESS / Trojan / Hysteria2 / TUIC / Snell
- **多平台** — macOS、Android（Windows / Linux 开发中）
- **订阅管理** — 兼容 Xboard / Pboard 标准订阅格式
- **规则引擎** — 智能分流，GEOSITE/GEOIP 规则
- **实时流量** — WebSocket 实时上行/下行监控
- **暗色主题** — Material 3 设计，跟随系统

## 📱 平台状态

| 平台 | 状态 | 模式 | 说明 |
|------|------|------|------|
| **macOS** | 🟡 开发中 | HTTP/SOCKS 系统代理 | Apple Silicon + Intel |
| **Android** | 🟡 开发中 | VpnService + TUN | arm64 + x86_64 |
| **Windows** | ⬜ 计划中 | 待定 | 延后 |
| **Linux** | ⬜ 计划中 | 待定 | 延后 |

## 🏗️ 架构

```
┌──────────────────────────────────────┐
│         Flutter UI (Dart)            │
│   Riverpod · Material 3 · Dio       │
├──────────────────────────────────────┤
│    Mihomo REST API (localhost)       │
├──────────────────────────────────────┤
│     Mihomo Core (Go Binary)          │
│   SS/VMess/VLESS/Trojan/HY2/TUIC     │
├──────────────────────────────────────┤
│        Platform Adapter              │
│  macOS: SystemConfiguration          │
│  Android: VpnService + TUN           │
└──────────────────────────────────────┘
```

## 🚀 快速开始

### 前置要求

- Flutter 3.2+
- Dart 3.2+
- Mihomo 预编译二进制（放在 `assets/mihomo/` 目录）

### 构建

```bash
# 1. 获取依赖
flutter pub get

# 2. macOS
flutter build macos --release

# 3. Android
flutter build apk --release
# 或 App Bundle（用于 Google Play）
flutter build appbundle --release
```

### Mihomo 二进制下载

从 [Mihomo Releases](https://github.com/MetaCubeX/mihomo/releases) 下载对应平台二进制：

```
assets/mihomo/
├── mihomo-darwin-arm64    # macOS Apple Silicon
├── mihomo-darwin-amd64    # macOS Intel
├── mihomo-android-arm64   # Android arm64-v8a
└── mihomo-android-amd64   # Android x86_64
```

## 📋 订阅格式

PClash 兼容 Clash/Mihomo 标准订阅格式：

```yaml
# Clash 订阅示例
proxies:
  - name: "US Node"
    type: vmess
    server: example.com
    port: 443
    uuid: your-uuid
    alterId: 0
    cipher: auto
    tls: true
    network: ws

proxy-groups:
  - name: "🚀 节点选择"
    type: select
    proxies:
      - "US Node"
      - DIRECT

rules:
  - GEOSITE,cn,DIRECT
  - MATCH,🚀 节点选择
```

## 📂 项目结构

```
pclash/
├── lib/
│   ├── main.dart                     # 入口
│   ├── core/
│   │   ├── mihomo_api.dart           # Mihomo REST API 客户端
│   │   ├── mihomo_manager.dart       # 内核进程管理
│   │   ├── config_manager.dart       # 配置生成器
│   │   ├── subscription_manager.dart # 订阅管理
│   │   └── platform/
│   │       ├── vpn_channel.dart      # Android VPN 平台通道
│   │       └── macos_proxy_channel.dart  # macOS 代理平台通道
│   ├── models/
│   │   ├── proxy.dart                # 代理节点模型
│   │   ├── traffic_stats.dart        # 流量统计
│   │   └── subscription.dart         # 订阅模型
│   ├── providers/
│   │   └── app_providers.dart        # Riverpod 状态管理
│   ├── screens/
│   │   ├── home_screen.dart          # 首页（连接开关 + 流量）
│   │   ├── proxy_screen.dart         # 节点管理
│   │   ├── subscription_screen.dart  # 订阅管理
│   │   └── settings_screen.dart      # 设置
│   └── utils/
│       └── constants.dart            # 常量定义
├── android/                          # Android 原生代码
│   └── app/src/main/kotlin/.../
│       ├── MainActivity.kt           # 入口 + MethodChannel
│       ├── PClashVpnService.kt       # VpnService 实现
│       └── BootReceiver.kt           # 开机自启
├── macos/                            # macOS 原生代码
│   └── Sources/
│       └── ProxyHelper.swift         # 系统代理设置
└── assets/
    └── mihomo/                       # 预编译内核
```

## 🔧 开发

### 添加新平台支持

1. 在 `lib/core/platform/` 创建平台通道封装
2. 在对应平台的原生代码中实现 MethodChannel
3. 在 `MihomoManager` 中集成

### API 端点

PClash 通过 Mihomo 的 `external-controller` API 控制内核：

| 端点 | 方法 | 说明 |
|------|------|------|
| `/proxies` | GET | 获取所有代理节点 |
| `/proxies/{name}` | PUT | 选择节点 |
| `/proxies/{name}/delay` | GET | 测试延迟 |
| `/configs` | GET/PATCH | 获取/修改配置 |
| `/traffic` | WS | 实时流量 |
| `/connections` | WS | 连接信息 |
| `/logs` | WS | 实时日志 |

详见 [Mihomo API 文档](https://wiki.metacubex.one/en/api)

## 🤝 与 Pboard 集成

PClash 原生支持 Pboard（Pease Board）订阅格式：

1. 在 Pboard 面板获取订阅 URL
2. 在 PClash → 订阅 页面添加 URL
3. 自动解析节点、流量信息、过期时间

## 📄 许可证

GPL-3.0 License

Copyright © 2024-2026 连冰 / Peaseboard

---

**Powered by Mihomo · Built with Flutter · Pease Ecosystem**
