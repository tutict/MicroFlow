# 依赖升级记录

日期：2026-11-26。范围包括前端、后端、Android 构建链、项目 Maven wrapper 与容器镜像。此前的前端体验改进保留在当前工作区。

## 前端

版本来自实际 Pub 锁文件；SDK 依赖按当前 Flutter 版本管理。

| 依赖 | 原锁定版本 | 新版本 |
| --- | --- | --- |
| file_picker | 11.0.2 | 13.4.1 |
| flex_color_scheme | 8.4.0 | 9.0.0 |
| flutter_riverpod | 3.3.2 | 3.5.0 |
| flutter_secure_storage | 9.2.4 | 10.3.4 |
| mobile_scanner | 7.3.0 | 7.5.0 |
| shared_preferences | 2.5.5 | 2.5.6 |
| skeletonizer | 2.1.3 | 3.0.0 |
| cupertino_icons | 1.0.9 | 2.0.0 |
| material_ui | 新增直接依赖 | 1.11.1 |
| cupertino_ui | 新增直接依赖 | 1.1.7 |
| http | 1.6.0 | 1.6.0，约束更新为 ^1.6.0 |
| intl | 0.20.3 | 0.20.3，移除 any 约束 |
| web_socket_channel | 3.0.3 | 当前稳定版本，保持 |
| flutter_lints | 6.0.0 | 当前稳定版本，保持 |

最低环境更新为 Flutter 3.47 / Dart 3.13，验证环境为现有 Flutter 3.47.5 / Dart 3.13.4。Pub 更新了可兼容的传递依赖和锁文件。

FlexColorScheme 9 使用独立 Material / Cupertino 类型，应用与测试同步迁移导入。`app_localization_delegates.dart` 集中提供匹配的本地化委托，避免 Flutter 生成器重新生成旧委托后影响中文界面。扫码插件 7.5.0 仍使用旧 Material 类型，因此应用入口保留官方兼容桥接，并有中英文主题与交互回归覆盖。

文件选择改为 `pickFile()` 与 `readAsBytes()`，上传和取消在桌面、手机尺寸均有回归用例。Skeletonizer 3 的亮度由应用主题明确提供。

## 后端与构建链

| 依赖 | 原版本 | 新版本 |
| --- | --- | --- |
| Quarkus BOM / Maven plugin | 3.35.4 | 4.0.1 |
| Jackson | 2.x | 3.1.8，由 Quarkus BOM 管理 |
| SQLite JDBC | 3.51.3.0 | 3.54.1.0 |
| Spring 测试依赖 | 6.2.12 | 7.1.0 |
| AssertJ | 3.27.3 | 3.27.7 |
| Mockito | 5.18.0 | 5.24.0 |
| ZXing core / javase | 3.5.3 | 3.5.4 |
| Maven compiler plugin | 3.14.1 | 3.16.0 |
| Surefire / Failsafe | 3.5.4 | 3.6.1 |
| Maven wrapper | 3.9.12 | 3.10.2 |
| Android Gradle Plugin | 8.11.1 | 9.5.3 |
| Gradle | 8.14 | 9.9.2 |
| Kotlin plugin | 2.2.20 | 2.4.21 |
| 容器 Maven 构建镜像 | 3.9.11 / Temurin 21 | 3.10.2 / Temurin 21 |
| Nginx 镜像 | 1.27-alpine | 1.30.8-alpine |

Java 编译目标保持 21；实际使用已安装的 JDK 21.0.8 验证。Quarkus 4 运行类的字节码版本 65 与 Java 21 对应。

生产代码与测试同步迁移至 `tools.jackson` 命名空间；节点读取使用新接口，HTTP 头遍历适配 Spring 7。会计请求的 `@Valid` 放在列表元素上。两个测试夹具分别改用显式 SQLite 数据源和受控模型同步点，原业务断言保留。使用旧 JwtService / Jackson 2 生成的凭据验证了新版本对身份和原到期时间的兼容。

Maven wrapper 移除了优先运行全局 Maven 的捷径，实际使用声明的版本。Maven、Gradle 下载配置附有校验和。Mockito 以测试 JVM agent 加载，避免依赖运行时自动附加。

Android 使用 `compilerOptions` 指定 JVM 17。Flutter 迁移期的 AGP 兼容设置支持尚未迁移至内置 Kotlin 的插件；构建中仍有 Flutter 关于后续内置 Kotlin 迁移的提示。APK 已实际构建成功。

## 保留的版本约束

- 安全存储 11.x 移除了从 9.x Android 存储迁移的实现。保留最新 10.x 的 10.3.4，启用迁移与备份，关闭出错时自动清空。所有已有安装完成此迁移后再考虑 11.x。
- `flutter_secure_storage_darwin` 与 `cross_file` 按上层插件的兼容范围解析。
- `material_color_utilities` 与 `test_api` 遵循 Flutter SDK 固定版本。
- Maven 4、compiler plugin 4、AssertJ 4、Kotlin 2.5 的预发布版本未选用。

## 验证结果

| 验证 | 实际结果 |
| --- | --- |
| 前端完整测试 | 203 项通过 |
| Flutter 静态分析 | 无问题 |
| Java 21 / Quarkus 4 完整验证 | 241 项通过，打包成功 |
| Web 发布构建 | 成功 |
| 实际 Wasm 发布构建 | 成功 |
| Android 调试 APK | 成功，Gradle 9.9.2 / AGP 9.5.3 / Kotlin 2.4.21 |
| 原生 Flutter 渲染 | 15 个桌面、平板、手机、双语、深色及大字体场景通过 |
| 本地浏览器 | 配对登录、工作区、草稿跨页保留与发送、刷新恢复会话、390×844 手机导航、语言与主题切换通过 |

Android 验证按用户授权在项目临时 SDK 中接受 Google SDK 许可，使用 NDK 28.2.13676358、Android 35/36、build-tools 36/37、CMake 3.22.1。已有全局 Flutter / JDK 安装保持原版本。构建产物位于 `frontend/build/app/outputs/flutter-apk/app-debug.apk`；Web / Wasm 分别位于 `frontend/build/web`、`frontend/build/web-wasm`。

APK 大小为 194,598,530 字节，SHA-256 为 `022EEEC222BBAC44CC41135F5C0CBC21FFCE1CF450DE8B6A0409858FB5FE8585`。构建后已按备份恢复 Android `local.properties`，临时 SDK 与构建日志保留在忽略目录中。

浏览器使用 Playwright 独立会话，前端 `http://127.0.0.1:18031/`，后端 `http://127.0.0.1:18080`，数据保存在独立演示库。应用无控制台错误；临时静态服务器缺少 COOP / COEP 头，因此 Wasm 以单线程运行并有对应性能提示。配对控制台另有缺失 favicon 请求返回 500 的问题，应用主入口的检查未出现此错误。

浏览器截图、原生渲染、命令日志及版本元数据保存在忽略目录 `.codex-tmp/dependency-upgrade/`。真机摄像头与旧系统密钥库数据迁移、iOS/macOS 编译及 Docker 镜像构建尚未验证；本机 Docker daemon 未运行。

桌面、手机上传回归使用文件选择器的平台替身，覆盖取消与完整二进制内容；原生系统文件选择对话框尚未实际操作。浏览器验证没有使用真实读屏软件，也未验证多线程 Skwasm 的性能。

验证结束后已关闭本轮独立 Playwright 会话、演示后端和前端预览服务，确认 18080、18031 端口无监听。构建生成的顶层标记和 Gradle 问题报告移至忽略目录。源码在用户授权后按功能组织提交，完整接受结论见 [四维独立审阅](reviews/2026-11-26-four-axis-review.md)。

APK 重新生成本地化文件后再次运行了完整前端测试与静态分析，仍为 203 项通过、无分析问题。独立审阅的规格、规范、实现质量及验证证据四个维度均在上述范围内通过，没有 Critical / Important 问题。首次审阅的非阻塞建议已修正：Surefire 初始化空 `argLine`，并在 Mockito 参数前保留 Quarkus 的 `@{argLine}`。修正后使用 Java 21 再次执行完整 `clean verify`，241 项测试通过、打包成功，缺失参数注入的提示未再出现。

## 官方依据

- [Pub 包与版本信息](https://pub.dev/packages)
- [FlexColorScheme 9 更新说明](https://pub.dev/packages/flex_color_scheme/changelog)
- [安全存储迁移说明](https://pub.dev/packages/flutter_secure_storage/changelog)
- [Material UI 迁移指南](https://pub.dev/packages/material_ui)
- [Quarkus 平台发布元数据](https://repo.maven.apache.org/maven2/io/quarkus/platform/quarkus-bom/maven-metadata.xml)
- [Gradle 发布信息](https://services.gradle.org/versions/all)
- [Flutter 内置 Kotlin 迁移指南](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)
