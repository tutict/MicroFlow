import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../app/router.dart';
import '../../../../core/providers/locale_controller.dart';
import '../../../../core/providers/theme_mode_controller.dart';
import '../../../../shared/theme/app_tokens.dart';
import '../../../../shared/widgets/app_layout.dart';
import '../../../bootstrap/presentation/providers/server_connection_controller.dart';
import '../providers/auth_session_controller.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  String? _errorText;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorText = null);
    try {
      await ref
          .read(authSessionControllerProvider.notifier)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(AppRoutes.workspace);
    } catch (error) {
      if (mounted) {
        setState(() => _errorText = error.toString());
      }
    }
  }

  Future<void> _changeServer() async {
    await ref.read(authSessionControllerProvider.notifier).signOut();
    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.connect, (route) => false);
  }

  void _handleSettingsSelection(int value) {
    switch (value) {
      case 1:
        ref
            .read(themeModeControllerProvider.notifier)
            .setThemeMode(ThemeMode.light);
      case 2:
        ref
            .read(themeModeControllerProvider.notifier)
            .setThemeMode(ThemeMode.dark);
      case 3:
        ref
            .read(localeControllerProvider.notifier)
            .setLocale(const Locale('zh'));
      case 4:
        ref
            .read(localeControllerProvider.notifier)
            .setLocale(const Locale('en'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final copy = _SignInCopy.of(context);
    final authState = ref.watch(authSessionControllerProvider);
    final connection = ref
        .watch(serverConnectionControllerProvider)
        .value
        ?.currentConnection;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 760;
    final theme = Theme.of(context);

    final form = _SignInForm(
      emailController: _emailController,
      passwordController: _passwordController,
      obscurePassword: _obscurePassword,
      isLoading: authState.isLoading,
      errorText: _errorText,
      connectionName: connection?.instanceName,
      connectionOrigin: connection?.serverOrigin,
      copy: copy,
      l10n: l10n,
      onTogglePassword: () {
        setState(() => _obscurePassword = !_obscurePassword);
      },
      onChangeServer: _changeServer,
      onSubmit: _submit,
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        titleSpacing: AppSpacing.md,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BrandMark(label: l10n.appTitle),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l10n.appTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<int>(
            tooltip: copy.preferences,
            onSelected: _handleSettingsSelection,
            itemBuilder: (context) => [
              PopupMenuItem(value: 1, child: Text(l10n.lightMode)),
              PopupMenuItem(value: 2, child: Text(l10n.darkMode)),
              const PopupMenuDivider(),
              PopupMenuItem(value: 3, child: Text(l10n.simplifiedChinese)),
              PopupMenuItem(value: 4, child: Text(l10n.english)),
            ],
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: compact
                  ? form
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.md,
                              right: AppSpacing.xl,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.appTitle,
                                  style: theme.textTheme.displayLarge,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 440,
                                  ),
                                  child: Text(
                                    l10n.signInDescription,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 420, child: form),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInForm extends StatelessWidget {
  const _SignInForm({
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.errorText,
    required this.connectionName,
    required this.connectionOrigin,
    required this.copy,
    required this.l10n,
    required this.onTogglePassword,
    required this.onChangeServer,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final String? errorText;
  final String? connectionName;
  final String? connectionOrigin;
  final _SignInCopy copy;
  final AppLocalizations l10n;
  final VoidCallback onTogglePassword;
  final VoidCallback onChangeServer;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPane(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.signInTitle, style: theme.textTheme.headlineMedium),
            if (connectionName != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppListRow(
                title: connectionName!,
                subtitle: connectionOrigin,
                leading: const Icon(Icons.computer_rounded),
                selected: true,
                trailing: TextButton(
                  onPressed: isLoading ? null : onChangeServer,
                  child: Text(copy.manageDevice),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: emailController,
              enabled: !isLoading,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.email,
                prefixIcon: const Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: passwordController,
              enabled: !isLoading,
              autofillHints: const [AutofillHints.password],
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: l10n.password,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: copy.togglePassword,
                  onPressed: onTogglePassword,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                ),
              ),
            ),
            if (errorText != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
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
                        errorText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: isLoading ? null : onSubmit,
                child: isLoading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.enterWorkspace),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: label,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        child: Text(
          'MF',
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SignInCopy {
  const _SignInCopy({
    required this.manageDevice,
    required this.preferences,
    required this.togglePassword,
  });

  final String manageDevice;
  final String preferences;
  final String togglePassword;

  static _SignInCopy of(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'zh') {
      return const _SignInCopy(
        manageDevice: '管理设备',
        preferences: '显示设置',
        togglePassword: '显示或隐藏密码',
      );
    }
    return const _SignInCopy(
      manageDevice: 'Manage device',
      preferences: 'Display settings',
      togglePassword: 'Show or hide password',
    );
  }
}
