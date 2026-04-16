import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router.dart';
import '../../../auth/presentation/providers/auth_session_controller.dart';
import '../../domain/entities/server_connection.dart';
import '../../domain/entities/server_connection_catalog.dart';
import '../providers/server_connection_controller.dart';

class ConnectServerPage extends ConsumerStatefulWidget {
  const ConnectServerPage({super.key});

  @override
  ConsumerState<ConnectServerPage> createState() => _ConnectServerPageState();
}

class _ConnectServerPageState extends ConsumerState<ConnectServerPage> {
  late final TextEditingController _serverUrlController;
  late final TextEditingController _pairingCodeController;
  bool _showManualForm = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController();
    _pairingCodeController = TextEditingController();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _pairingCodeController.dispose();
    super.dispose();
  }

  Future<void> _pair(_Copy copy) async {
    final serverUrl = _serverUrlController.text.trim();
    final pairingCode = _pairingCodeController.text.trim();

    if (serverUrl.isEmpty) {
      setState(() => _errorText = copy.deviceAddressRequired);
      return;
    }
    if (pairingCode.isEmpty) {
      setState(() => _errorText = copy.pairingCodeRequired);
      return;
    }

    setState(() => _errorText = null);
    try {
      await ref.read(authSessionControllerProvider.notifier).signOut();
      await ref
          .read(serverConnectionControllerProvider.notifier)
          .pair(serverUrl: serverUrl, pairingCode: pairingCode);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(AppRoutes.signIn);
    } catch (error) {
      setState(() => _errorText = error.toString());
    }
  }

  Future<void> _activate(ServerConnection connection) async {
    setState(() => _errorText = null);
    try {
      await ref.read(authSessionControllerProvider.notifier).signOut();
      await ref
          .read(serverConnectionControllerProvider.notifier)
          .activateConnection(connection.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(AppRoutes.signIn);
    } catch (error) {
      setState(() => _errorText = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = _Copy.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 1040;
    final compactPanelHeader = width < 620;
    final connectionAsync = ref.watch(serverConnectionControllerProvider);
    final catalog =
        connectionAsync.valueOrNull ?? const ServerConnectionCatalog();
    final isBusy = connectionAsync.isLoading;

    final introPanel = _FrostPanel(
      padding: EdgeInsets.all(isWide ? 32 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionEyebrow(label: copy.eyebrow),
          const SizedBox(height: 20),
          Text(
            copy.title,
            style:
                (isWide
                        ? theme.textTheme.displaySmall
                        : theme.textTheme.headlineMedium)
                    ?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: isWide ? -1.8 : -1.1,
                    ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Text(
              copy.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 24),
          for (var index = 0; index < copy.steps.length; index++) ...[
            _StepRow(index: index + 1, label: copy.steps[index]),
            if (index < copy.steps.length - 1) const SizedBox(height: 12),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InlinePill(icon: Icons.lan_rounded, label: copy.localNetwork),
              _InlinePill(icon: Icons.shield_rounded, label: copy.remoteAccess),
              _InlinePill(
                icon: Icons.password_rounded,
                label: copy.pairingCode,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.84),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.phone_iphone_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    copy.note,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.82,
                      ),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final devicePanel = _FrostPanel(
      padding: EdgeInsets.all(isWide ? 28 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          compactPanelHeader
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.panelTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      catalog.savedConnections.isEmpty
                          ? copy.emptyState
                          : copy.savedState,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.76,
                        ),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: isBusy
                          ? null
                          : () {
                              setState(() {
                                _showManualForm = !_showManualForm;
                                _errorText = null;
                              });
                            },
                      icon: Icon(
                        _showManualForm
                            ? Icons.close_rounded
                            : Icons.add_rounded,
                      ),
                      label: Text(
                        _showManualForm
                            ? copy.hideManualAction
                            : copy.addDeviceAction,
                      ),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            copy.panelTitle,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            catalog.savedConnections.isEmpty
                                ? copy.emptyState
                                : copy.savedState,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.76,
                              ),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: isBusy
                          ? null
                          : () {
                              setState(() {
                                _showManualForm = !_showManualForm;
                                _errorText = null;
                              });
                            },
                      icon: Icon(
                        _showManualForm
                            ? Icons.close_rounded
                            : Icons.add_rounded,
                      ),
                      label: Text(
                        _showManualForm
                            ? copy.hideManualAction
                            : copy.addDeviceAction,
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 22),
          if (catalog.savedConnections.isNotEmpty)
            ...catalog.savedConnections.map(
              (connection) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DeviceTile(
                  connection: connection,
                  isCurrent: connection.id == catalog.currentConnection?.id,
                  copy: copy,
                  isBusy: isBusy,
                  onUse: () => _activate(connection),
                  onRemove: () {
                    setState(() => _errorText = null);
                    ref
                        .read(serverConnectionControllerProvider.notifier)
                        .removeConnection(connection.id);
                  },
                ),
              ),
            )
          else
            _EmptyHint(copy: copy),
          if (_showManualForm || catalog.savedConnections.isEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.84),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.manualTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    copy.manualDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.76,
                      ),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _serverUrlController,
                    decoration: InputDecoration(
                      labelText: copy.deviceAddress,
                      hintText: copy.deviceAddressHint,
                      prefixIcon: const Icon(Icons.computer_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pairingCodeController,
                    decoration: InputDecoration(
                      labelText: copy.codeLabel,
                      hintText: 'ABCD-7KQ2',
                      prefixIcon: const Icon(Icons.password_rounded),
                    ),
                    onSubmitted: (_) => _pair(copy),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBA3B2F).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(
                            0xFFBA3B2F,
                          ).withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        _errorText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFBA3B2F),
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isBusy ? null : () => _pair(copy),
                      child: Text(
                        isBusy ? copy.connecting : copy.saveAndContinue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.brightness == Brightness.dark
                ? const [
                    Color(0xFF081015),
                    Color(0xFF10191F),
                    Color(0xFF152229),
                  ]
                : const [
                    Color(0xFFF7F9F9),
                    Color(0xFFEEF2F3),
                    Color(0xFFE3EAEC),
                  ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -100,
              top: -80,
              child: _AmbientOrb(
                size: 260,
                color: theme.colorScheme.primary.withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              right: -60,
              bottom: -120,
              child: _AmbientOrb(
                size: 320,
                color: const Color(0xFF3D7EA6).withValues(alpha: 0.1),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1260),
                  child: Padding(
                    padding: EdgeInsets.all(width < 640 ? 18 : 24),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: introPanel),
                              const SizedBox(width: 24),
                              SizedBox(
                                width: 470,
                                child: SingleChildScrollView(
                                  child: devicePanel,
                                ),
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.only(
                              bottom:
                                  MediaQuery.viewInsetsOf(context).bottom + 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                introPanel,
                                const SizedBox(height: 18),
                                devicePanel,
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.connection,
    required this.isCurrent,
    required this.copy,
    required this.isBusy,
    required this.onUse,
    required this.onRemove,
  });

  final ServerConnection connection;
  final bool isCurrent;
  final _Copy copy;
  final bool isBusy;
  final VoidCallback onUse;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.colorScheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrent
              ? theme.colorScheme.primary.withValues(alpha: 0.22)
              : theme.dividerColor.withValues(alpha: 0.82),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.instanceName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      connection.serverOrigin,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.78,
                        ),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isCurrent)
                _InlinePill(
                  icon: Icons.check_circle_rounded,
                  label: copy.currentDevice,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: isBusy ? null : onUse,
                  child: Text(
                    isCurrent ? copy.continueWithDevice : copy.useDevice,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: isBusy ? null : onRemove,
                tooltip: copy.removeDevice,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.copy});

  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.84)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.devices_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              copy.discoveryHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.label});

  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InlinePill extends StatelessWidget {
  const _InlinePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.82)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FrostPanel extends StatelessWidget {
  const _FrostPanel({
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.78 : 0.92,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.84),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: color.a * 0.4),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _Copy {
  const _Copy({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.steps,
    required this.note,
    required this.localNetwork,
    required this.remoteAccess,
    required this.pairingCode,
    required this.panelTitle,
    required this.emptyState,
    required this.savedState,
    required this.discoveryHint,
    required this.manualTitle,
    required this.manualDescription,
    required this.deviceAddress,
    required this.deviceAddressHint,
    required this.deviceAddressRequired,
    required this.codeLabel,
    required this.pairingCodeRequired,
    required this.connecting,
    required this.saveAndContinue,
    required this.currentDevice,
    required this.continueWithDevice,
    required this.useDevice,
    required this.removeDevice,
    required this.addDeviceAction,
    required this.hideManualAction,
  });

  final String eyebrow;
  final String title;
  final String description;
  final List<String> steps;
  final String note;
  final String localNetwork;
  final String remoteAccess;
  final String pairingCode;
  final String panelTitle;
  final String emptyState;
  final String savedState;
  final String discoveryHint;
  final String manualTitle;
  final String manualDescription;
  final String deviceAddress;
  final String deviceAddressHint;
  final String deviceAddressRequired;
  final String codeLabel;
  final String pairingCodeRequired;
  final String connecting;
  final String saveAndContinue;
  final String currentDevice;
  final String continueWithDevice;
  final String useDevice;
  final String removeDevice;
  final String addDeviceAction;
  final String hideManualAction;

  static _Copy of(BuildContext context) {
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';
    if (isChinese) {
      return const _Copy(
        eyebrow: '设备连接',
        title: '先选设备，再进入工作区',
        description: '用户真正要连接的是自己的电脑，不是地址本身。所以首页先展示已保存设备，把常用机器留在第一层。',
        steps: [
          '优先使用已保存设备，避免每次重新输入地址。',
          '新设备只需要录入一次地址和配对码，之后就能快速切换。',
          '远程访问优先使用 Tailscale 地址，不建议直接暴露公网端口。',
        ],
        note: '在同一局域网时填写电脑内网地址；外出时填写 Tailscale IP 或 MagicDNS 名称即可。',
        localNetwork: '同一网络',
        remoteAccess: '远程访问',
        pairingCode: '配对码',
        panelTitle: '我的设备',
        emptyState: '还没有已保存设备。先添加一台电脑，之后手机就能把它当成默认工作入口。',
        savedState: '这里保留你已经配对过的电脑。继续使用当前设备，或者随时切换到另一台机器。',
        discoveryHint: '这一版先把“保存多台设备并快速切换”做好。自动发现可以作为后续增强，不占用户当前主路径。',
        manualTitle: '手动添加设备',
        manualDescription:
            '适合你已经知道设备地址的场景，例如局域网 IP、Tailscale IP，或者 MagicDNS 名称。',
        deviceAddress: '设备地址',
        deviceAddressHint: 'http://100.x.y.z:8080',
        deviceAddressRequired: '请输入设备地址',
        codeLabel: '配对码',
        pairingCodeRequired: '请输入配对码',
        connecting: '连接中...',
        saveAndContinue: '保存并继续',
        currentDevice: '当前设备',
        continueWithDevice: '继续使用',
        useDevice: '切换到这台',
        removeDevice: '移除设备',
        addDeviceAction: '添加设备',
        hideManualAction: '收起',
      );
    }
    return const _Copy(
      eyebrow: 'Device connection',
      title: 'Choose a device before you enter the workspace',
      description:
          'People connect to their computer, not to an address string. This screen starts with saved devices so the common path stays fast.',
      steps: [
        'Start with saved devices instead of typing an address every time.',
        'A new device only needs its address and pairing code once.',
        'For remote access, prefer a Tailscale address over exposing a public port.',
      ],
      note:
          'Use a LAN address when you are on the same network. Use a Tailscale IP or MagicDNS hostname when you are away.',
      localNetwork: 'Local network',
      remoteAccess: 'Remote access',
      pairingCode: 'Pairing code',
      panelTitle: 'My devices',
      emptyState:
          'No saved devices yet. Add one computer first so the app has a default place to connect.',
      savedState:
          'Saved computers appear here. Continue with the current device or switch to another machine.',
      discoveryHint:
          'This release focuses on saving multiple devices and switching fast. Auto-discovery can be layered in later without changing the main flow.',
      manualTitle: 'Add device manually',
      manualDescription:
          'Use this when you already know the device address, such as a LAN IP, Tailscale IP, or MagicDNS hostname.',
      deviceAddress: 'Device address',
      deviceAddressHint: 'http://100.x.y.z:8080',
      deviceAddressRequired: 'Enter the device address',
      codeLabel: 'Pairing code',
      pairingCodeRequired: 'Enter the pairing code',
      connecting: 'Connecting...',
      saveAndContinue: 'Save and continue',
      currentDevice: 'Current device',
      continueWithDevice: 'Continue',
      useDevice: 'Use this device',
      removeDevice: 'Remove device',
      addDeviceAction: 'Add device',
      hideManualAction: 'Hide',
    );
  }
}
