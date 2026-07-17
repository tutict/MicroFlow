import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router.dart';
import '../../../../shared/theme/app_tokens.dart';
import '../../../../shared/widgets/app_layout.dart';
import '../../../auth/presentation/providers/auth_session_controller.dart';
import '../../domain/entities/pairing_qr_payload.dart';
import '../../domain/entities/server_connection.dart';
import '../../domain/entities/server_connection_catalog.dart';
import 'pairing_scanner_page.dart';
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

  Future<void> _pair(_ConnectCopy copy) async {
    final serverUrl = _serverUrlController.text.trim();
    final pairingCode = _pairingCodeController.text.trim();
    await _pairCredentials(
      copy,
      serverUrl: serverUrl,
      pairingCode: pairingCode,
    );
  }

  Future<void> _pairCredentials(
    _ConnectCopy copy, {
    required String serverUrl,
    required String pairingCode,
  }) async {
    if (serverUrl.isEmpty || pairingCode.isEmpty) {
      setState(() {
        _errorText = serverUrl.isEmpty
            ? copy.deviceAddressRequired
            : copy.pairingCodeRequired;
      });
      return;
    }

    setState(() => _errorText = null);
    try {
      await ref.read(authSessionControllerProvider.notifier).signOut();
      await ref
          .read(serverConnectionControllerProvider.notifier)
          .pair(serverUrl: serverUrl, pairingCode: pairingCode);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.signIn);
    } catch (error) {
      if (mounted) setState(() => _errorText = error.toString());
    }
  }

  Future<void> _scanQrCode(_ConnectCopy copy) async {
    final payload = await Navigator.of(context).push<PairingQrPayload>(
      MaterialPageRoute<PairingQrPayload>(
        fullscreenDialog: true,
        builder: (context) => const PairingScannerPage(),
      ),
    );
    if (!mounted || payload == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(copy.confirmDevice),
        content: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.computer_rounded),
          title: Text(payload.instanceName),
          subtitle: Text(payload.serverOrigin),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(copy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(copy.connect),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    _serverUrlController.text = payload.serverOrigin;
    _pairingCodeController.text = payload.pairingCode;
    await _pairCredentials(
      copy,
      serverUrl: payload.serverOrigin,
      pairingCode: payload.pairingCode,
    );
  }

  Future<void> _activate(ServerConnection connection) async {
    setState(() => _errorText = null);
    try {
      await ref.read(authSessionControllerProvider.notifier).signOut();
      await ref
          .read(serverConnectionControllerProvider.notifier)
          .activateConnection(connection.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.signIn);
    } catch (error) {
      if (mounted) setState(() => _errorText = error.toString());
    }
  }

  Future<void> _remove(ServerConnection connection) async {
    setState(() => _errorText = null);
    try {
      await ref
          .read(serverConnectionControllerProvider.notifier)
          .removeConnection(connection.id);
    } catch (error) {
      if (mounted) setState(() => _errorText = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _ConnectCopy.of(context);
    final connectionAsync = ref.watch(serverConnectionControllerProvider);
    final catalog = connectionAsync.value ?? const ServerConnectionCatalog();
    final isBusy = connectionAsync.isLoading;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final canScanQr =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final showForm =
        _showManualForm || (catalog.savedConnections.isEmpty && !canScanQr);
    final onScanQr = canScanQr && !isBusy ? () => _scanQrCode(copy) : null;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        titleSpacing: AppSpacing.md,
        title: Text(copy.pageTitle),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              compact ? AppSpacing.sm : AppSpacing.lg,
              AppSpacing.lg,
              compact ? AppSpacing.sm : AppSpacing.lg,
              MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: AppPane(
                padding: EdgeInsets.all(
                  compact ? AppSpacing.md : AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DeviceHeader(
                      copy: copy,
                      hasConnections: catalog.savedConnections.isNotEmpty,
                      showForm: showForm,
                      isBusy: isBusy,
                      onScanQr: onScanQr,
                      onToggleForm: () {
                        setState(() {
                          _showManualForm = !_showManualForm;
                          _errorText = null;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (catalog.savedConnections.isEmpty)
                      AppEmptyState(
                        icon: Icons.devices_outlined,
                        title: copy.emptyTitle,
                        message: copy.emptyMessage,
                        compact: true,
                        action: !canScanQr
                            ? null
                            : Wrap(
                                alignment: WrapAlignment.center,
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  FilledButton.icon(
                                    onPressed: onScanQr,
                                    icon: isBusy
                                        ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.qr_code_scanner_rounded,
                                          ),
                                    label: Text(
                                      isBusy ? copy.connecting : copy.scanQr,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: isBusy
                                        ? null
                                        : () => setState(
                                            () => _showManualForm = true,
                                          ),
                                    child: Text(copy.manualTitle),
                                  ),
                                ],
                              ),
                      )
                    else
                      _DeviceList(
                        catalog: catalog,
                        copy: copy,
                        isBusy: isBusy,
                        onActivate: _activate,
                        onRemove: _remove,
                      ),
                    if (showForm) ...[
                      const SizedBox(height: AppSpacing.md),
                      Divider(color: Theme.of(context).dividerColor),
                      const SizedBox(height: AppSpacing.md),
                      _ManualConnectionForm(
                        serverUrlController: _serverUrlController,
                        pairingCodeController: _pairingCodeController,
                        copy: copy,
                        errorText: _errorText,
                        isBusy: isBusy,
                        onSubmit: () => _pair(copy),
                      ),
                    ] else if (_errorText != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _InlineError(message: _errorText!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceHeader extends StatelessWidget {
  const _DeviceHeader({
    required this.copy,
    required this.hasConnections,
    required this.showForm,
    required this.isBusy,
    required this.onScanQr,
    required this.onToggleForm,
  });

  final _ConnectCopy copy;
  final bool hasConnections;
  final bool showForm;
  final bool isBusy;
  final VoidCallback? onScanQr;
  final VoidCallback onToggleForm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(copy.panelTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                hasConnections ? copy.savedMessage : copy.panelMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (hasConnections) ...[
          if (onScanQr != null) ...[
            const SizedBox(width: AppSpacing.sm),
            IconButton.filledTonal(
              tooltip: copy.scanQr,
              onPressed: onScanQr,
              icon: const Icon(Icons.qr_code_scanner_rounded),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          IconButton.filledTonal(
            tooltip: showForm ? copy.hideManualAction : copy.addDeviceAction,
            onPressed: isBusy ? null : onToggleForm,
            icon: Icon(showForm ? Icons.close_rounded : Icons.add_rounded),
          ),
        ],
      ],
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({
    required this.catalog,
    required this.copy,
    required this.isBusy,
    required this.onActivate,
    required this.onRemove,
  });

  final ServerConnectionCatalog catalog;
  final _ConnectCopy copy;
  final bool isBusy;
  final ValueChanged<ServerConnection> onActivate;
  final ValueChanged<ServerConnection> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final connection in catalog.savedConnections)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: AppListRow(
              title: connection.instanceName,
              subtitle: connection.id == catalog.currentConnection?.id
                  ? '${connection.serverOrigin} - ${copy.currentDevice}'
                  : connection.serverOrigin,
              leading: const Icon(Icons.computer_rounded),
              selected: connection.id == catalog.currentConnection?.id,
              onTap: isBusy ? null : () => onActivate(connection),
              trailing: PopupMenuButton<_DeviceAction>(
                tooltip: copy.deviceActions,
                enabled: !isBusy,
                onSelected: (action) {
                  switch (action) {
                    case _DeviceAction.use:
                      onActivate(connection);
                    case _DeviceAction.remove:
                      onRemove(connection);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _DeviceAction.use,
                    child: Text(copy.useDevice),
                  ),
                  PopupMenuItem(
                    value: _DeviceAction.remove,
                    child: Text(copy.removeDevice),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

enum _DeviceAction { use, remove }

class _ManualConnectionForm extends StatelessWidget {
  const _ManualConnectionForm({
    required this.serverUrlController,
    required this.pairingCodeController,
    required this.copy,
    required this.errorText,
    required this.isBusy,
    required this.onSubmit,
  });

  final TextEditingController serverUrlController;
  final TextEditingController pairingCodeController;
  final _ConnectCopy copy;
  final String? errorText;
  final bool isBusy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(copy.manualTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          copy.manualMessage,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: serverUrlController,
          enabled: !isBusy,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: copy.deviceAddress,
            hintText: copy.deviceAddressHint,
            prefixIcon: const Icon(Icons.link_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: pairingCodeController,
          enabled: !isBusy,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            labelText: copy.codeLabel,
            hintText: 'ABCD-7KQ2',
            prefixIcon: const Icon(Icons.password_rounded),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _InlineError(message: errorText!),
        ],
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: isBusy ? null : onSubmit,
            icon: isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(isBusy ? copy.connecting : copy.saveAndContinue),
          ),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectCopy {
  const _ConnectCopy({
    required this.pageTitle,
    required this.panelTitle,
    required this.panelMessage,
    required this.savedMessage,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.manualTitle,
    required this.manualMessage,
    required this.deviceAddress,
    required this.deviceAddressHint,
    required this.deviceAddressRequired,
    required this.codeLabel,
    required this.pairingCodeRequired,
    required this.connecting,
    required this.saveAndContinue,
    required this.currentDevice,
    required this.useDevice,
    required this.removeDevice,
    required this.addDeviceAction,
    required this.hideManualAction,
    required this.deviceActions,
    required this.scanQr,
    required this.confirmDevice,
    required this.cancel,
    required this.connect,
  });

  final String pageTitle;
  final String panelTitle;
  final String panelMessage;
  final String savedMessage;
  final String emptyTitle;
  final String emptyMessage;
  final String manualTitle;
  final String manualMessage;
  final String deviceAddress;
  final String deviceAddressHint;
  final String deviceAddressRequired;
  final String codeLabel;
  final String pairingCodeRequired;
  final String connecting;
  final String saveAndContinue;
  final String currentDevice;
  final String useDevice;
  final String removeDevice;
  final String addDeviceAction;
  final String hideManualAction;
  final String deviceActions;
  final String scanQr;
  final String confirmDevice;
  final String cancel;
  final String connect;

  static _ConnectCopy of(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'zh') {
      return const _ConnectCopy(
        pageTitle: '设备连接',
        panelTitle: '我的设备',
        panelMessage: '连接一台运行微澜协作的电脑。',
        savedMessage: '选择设备继续，或添加新设备。',
        emptyTitle: '暂无设备',
        emptyMessage: '扫描设备二维码，或手动输入连接信息。',
        manualTitle: '手动添加设备',
        manualMessage: '可使用局域网地址或 Tailscale 地址。',
        deviceAddress: '设备地址',
        deviceAddressHint: 'http://100.x.y.z:8080',
        deviceAddressRequired: '请输入设备地址',
        codeLabel: '配对码',
        pairingCodeRequired: '请输入配对码',
        connecting: '连接中...',
        saveAndContinue: '保存并继续',
        currentDevice: '当前设备',
        useDevice: '使用此设备',
        removeDevice: '移除设备',
        addDeviceAction: '添加设备',
        hideManualAction: '收起',
        deviceActions: '设备操作',
        scanQr: '扫描二维码',
        confirmDevice: '确认设备',
        cancel: '取消',
        connect: '连接',
      );
    }
    return const _ConnectCopy(
      pageTitle: 'Device connection',
      panelTitle: 'My devices',
      panelMessage: 'Connect a computer running MicroFlow.',
      savedMessage: 'Choose a device or add a new one.',
      emptyTitle: 'No devices yet',
      emptyMessage: 'Scan a device QR code or enter connection details.',
      manualTitle: 'Add device manually',
      manualMessage: 'Use a local network or Tailscale address.',
      deviceAddress: 'Device address',
      deviceAddressHint: 'http://100.x.y.z:8080',
      deviceAddressRequired: 'Enter the device address',
      codeLabel: 'Pairing code',
      pairingCodeRequired: 'Enter the pairing code',
      connecting: 'Connecting...',
      saveAndContinue: 'Save and continue',
      currentDevice: 'Current device',
      useDevice: 'Use this device',
      removeDevice: 'Remove device',
      addDeviceAction: 'Add device',
      hideManualAction: 'Hide',
      deviceActions: 'Device actions',
      scanQr: 'Scan QR code',
      confirmDevice: 'Confirm device',
      cancel: 'Cancel',
      connect: 'Connect',
    );
  }
}
