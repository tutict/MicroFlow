import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router.dart';
import '../../../auth/presentation/providers/auth_session_controller.dart';
import '../providers/server_connection_controller.dart';

class ConnectServerPage extends ConsumerStatefulWidget {
  const ConnectServerPage({super.key});

  @override
  ConsumerState<ConnectServerPage> createState() => _ConnectServerPageState();
}

class _ConnectServerPageState extends ConsumerState<ConnectServerPage> {
  late final TextEditingController _serverUrlController;
  late final TextEditingController _pairingCodeController;
  String? _errorText;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController();
    _pairingCodeController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _ready = true;
      });
    });
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _pairingCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final copy = _ConnectCopy.of(context);
    final serverUrl = _serverUrlController.text.trim();
    final pairingCode = _pairingCodeController.text.trim();

    if (serverUrl.isEmpty) {
      setState(() {
        _errorText = copy.serverUrlRequired;
      });
      return;
    }
    if (pairingCode.isEmpty) {
      setState(() {
        _errorText = copy.pairingCodeRequired;
      });
      return;
    }

    setState(() {
      _errorText = null;
    });
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
      setState(() {
        _errorText = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _ConnectCopy.of(context);
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 960;
    final pairingAsync = ref.watch(serverConnectionControllerProvider);
    final isLoading = pairingAsync.isLoading;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.brightness == Brightness.dark
                ? const [
                    Color(0xFF081015),
                    Color(0xFF101A20),
                    Color(0xFF16242B),
                  ]
                : const [
                    Color(0xFFF4F7F7),
                    Color(0xFFE7EFF0),
                    Color(0xFFDCE7E8),
                  ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(width < 640 ? 18 : 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: isWide
                    ? Row(
                        children: [
                          Expanded(
                            child: _Reveal(
                              ready: _ready,
                              offset: const Offset(-0.08, 0),
                              child: _ConnectHero(copy: copy),
                            ),
                          ),
                          const SizedBox(width: 28),
                          SizedBox(
                            width: 440,
                            child: _Reveal(
                              ready: _ready,
                              offset: const Offset(0.08, 0),
                              child: _ConnectCard(
                                copy: copy,
                                isLoading: isLoading,
                                serverUrlController: _serverUrlController,
                                pairingCodeController: _pairingCodeController,
                                errorText: _errorText,
                                onSubmit: _submit,
                              ),
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            _Reveal(
                              ready: _ready,
                              offset: const Offset(0, 0.05),
                              child: _ConnectHero(copy: copy),
                            ),
                            const SizedBox(height: 22),
                            _Reveal(
                              ready: _ready,
                              offset: const Offset(0, 0.07),
                              child: _ConnectCard(
                                copy: copy,
                                isLoading: isLoading,
                                serverUrlController: _serverUrlController,
                                pairingCodeController: _pairingCodeController,
                                errorText: _errorText,
                                onSubmit: _submit,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectHero extends StatelessWidget {
  const _ConnectHero({required this.copy});

  final _ConnectCopy copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              copy.badge,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            copy.title,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            copy.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          for (final step in copy.steps) ...[
            _InfoRow(label: step),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.82),
              ),
            ),
            child: Text(
              copy.note,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({
    required this.copy,
    required this.isLoading,
    required this.serverUrlController,
    required this.pairingCodeController,
    required this.errorText,
    required this.onSubmit,
  });

  final _ConnectCopy copy;
  final bool isLoading;
  final TextEditingController serverUrlController;
  final TextEditingController pairingCodeController;
  final String? errorText;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F6F5C), Color(0xFF59B29A)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.link_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            copy.formTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            copy.formDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          _ConnectField(
            controller: serverUrlController,
            label: copy.serverUrlLabel,
            icon: Icons.dns_rounded,
            hintText: copy.serverUrlHint,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _ConnectField(
            controller: pairingCodeController,
            label: copy.pairingCodeLabel,
            icon: Icons.password_rounded,
            hintText: 'ABCD-7KQ2',
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFBA3B2F).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFBA3B2F).withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFBA3B2F),
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: isLoading ? null : onSubmit,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(isLoading ? copy.connecting : copy.saveAndContinue),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectField extends StatelessWidget {
  const _ConnectField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.hintText,
    required this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String hintText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 18,
        ),
        fillColor: theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.8 : 0.94,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.82)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.ready,
    required this.offset,
    required this.child,
  });

  final bool ready;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 780),
      curve: Curves.easeOutCubic,
      offset: ready ? Offset.zero : offset,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 720),
        curve: Curves.easeOut,
        opacity: ready ? 1 : 0,
        child: child,
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.72 : 0.8,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.84),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.brightness == Brightness.dark
                    ? const Color(0x33000000)
                    : const Color(0x140E1A22),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ConnectCopy {
  const _ConnectCopy({
    required this.badge,
    required this.title,
    required this.description,
    required this.steps,
    required this.note,
    required this.formTitle,
    required this.formDescription,
    required this.serverUrlLabel,
    required this.serverUrlHint,
    required this.serverUrlRequired,
    required this.pairingCodeLabel,
    required this.pairingCodeRequired,
    required this.connecting,
    required this.saveAndContinue,
  });

  final String badge;
  final String title;
  final String description;
  final List<String> steps;
  final String note;
  final String formTitle;
  final String formDescription;
  final String serverUrlLabel;
  final String serverUrlHint;
  final String serverUrlRequired;
  final String pairingCodeLabel;
  final String pairingCodeRequired;
  final String connecting;
  final String saveAndContinue;

  static _ConnectCopy of(BuildContext context) {
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';
    if (isChinese) {
      return const _ConnectCopy(
        badge: '服务器配对',
        title: '连接你的工作区后端',
        description:
            '在后端所在机器上查看一次性配对码，输入服务器地址和配对码后，应用会保存 API 与 WebSocket 连接地址。',
        steps: ['1. 在后端终端读取配对码', '2. 输入服务器地址和配对码', '3. 配对成功后继续登录'],
        note: '后端首次启动时，会在日志里输出类似 `ABCD-7KQ2` 的一次性配对码。',
        formTitle: '连接服务器',
        formDescription: '输入服务器地址和后端显示的配对码。握手成功后会自动保存连接配置。',
        serverUrlLabel: '服务器地址',
        serverUrlHint: 'https://server.example.com',
        serverUrlRequired: '请输入服务器地址',
        pairingCodeLabel: '配对码',
        pairingCodeRequired: '请输入配对码',
        connecting: '连接中...',
        saveAndContinue: '保存并继续',
      );
    }
    return const _ConnectCopy(
      badge: 'Server pairing',
      title: 'Connect your workspace backend',
      description:
          'Read the one-time pairing code from the backend host, enter the server URL and code, then the app will store the API and WebSocket endpoints.',
      steps: [
        '1. Read the pairing code from the backend terminal',
        '2. Enter the server URL and pairing code',
        '3. Pair successfully, then continue to sign in',
      ],
      note:
          'On first startup the backend logs a one-time pairing code similar to `ABCD-7KQ2`.',
      formTitle: 'Connect server',
      formDescription:
          'Enter the server URL and the pairing code shown by the backend. The app saves the connection after a successful handshake.',
      serverUrlLabel: 'Server URL',
      serverUrlHint: 'https://server.example.com',
      serverUrlRequired: 'Enter the server URL',
      pairingCodeLabel: 'Pairing code',
      pairingCodeRequired: 'Enter the pairing code',
      connecting: 'Connecting...',
      saveAndContinue: 'Save and continue',
    );
  }
}
