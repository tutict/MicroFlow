# MicroFlow Frontend

这是 SoloFlow / MicroFlow 的 Flutter 客户端。

它负责：

- 服务器配对
- 用户登录
- 工作区会话展示
- 频道实时消息
- Agent 列表、运行状态与诊断视图

## 开发启动

```powershell
flutter pub get
flutter run -d chrome
```

## 可选环境变量

```powershell
flutter run -d chrome `
  --dart-define=MICROFLOW_API_BASE_URL=http://localhost:8080/api/v1 `
  --dart-define=MICROFLOW_WS_BASE_URL=ws://localhost:8080/ws
```

当前更推荐通过应用内配对页连接后端，而不是长期依赖固定地址。

## 主要依赖

- Flutter
- Riverpod
- `http`
- `web_socket_channel`
- `flutter_secure_storage`

## 本地化

本项目使用 Flutter `gen-l10n`。

本地化源文件位于：

- `lib/l10n/app_en.arb`
- `lib/l10n/app_zh.arb`

生成命令：

```powershell
flutter gen-l10n
```

## 校验

```powershell
flutter analyze
```

根目录项目说明见 [../README.md](/C:/Users/tutic/IdeaProjects/SoloFlow/README.md)。
