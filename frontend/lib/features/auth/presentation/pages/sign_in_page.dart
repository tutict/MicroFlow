import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../app/router.dart';
import '../../../../core/providers/locale_controller.dart';
import '../../../../core/providers/theme_mode_controller.dart';
import '../../../bootstrap/presentation/providers/server_connection_controller.dart';
import '../../../../shared/widgets/language_switcher.dart';
import '../../../../shared/widgets/theme_mode_switcher.dart';
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
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errorText = null;
    });
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
      setState(() {
        _errorText = error.toString();
      });
    }
  }

  Future<void> _changeServer() async {
    await ref.read(authSessionControllerProvider.notifier).signOut();
    await ref
        .read(serverConnectionControllerProvider.notifier)
        .clearConnection();
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
        break;
      case 2:
        ref
            .read(themeModeControllerProvider.notifier)
            .setThemeMode(ThemeMode.dark);
        break;
      case 3:
        ref
            .read(localeControllerProvider.notifier)
            .setLocale(const Locale('zh'));
        break;
      case 4:
        ref
            .read(localeControllerProvider.notifier)
            .setLocale(const Locale('en'));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pageCopy = _SignInPageCopy.of(context);
    final authAsync = ref.watch(authSessionControllerProvider);
    final serverConnection = ref
        .watch(serverConnectionControllerProvider)
        .valueOrNull;
    final isLoading = authAsync.isLoading;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isWide = width >= 980;
    final isCompactHeader = width < 560;
    final isCondensedMobile = !isWide && (height < 800 || keyboardVisible);
    final sidePadding = width < 640 ? 18.0 : 28.0;
    final titleStyle =
        ((isWide || !isCondensedMobile)
                ? (isWide
                      ? theme.textTheme.displayMedium
                      : theme.textTheme.headlineLarge)
                : theme.textTheme.headlineMedium)
            ?.copyWith(
              fontSize: isWide ? 76 : (isCondensedMobile ? 40 : 48),
              height: 0.95,
              fontWeight: FontWeight.w800,
              letterSpacing: isWide ? -3 : (isCondensedMobile ? -1.2 : -1.8),
              color: theme.colorScheme.onSurface,
            );

    final hero = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.18 : 0.1,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            l10n.workspaceHub,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(height: isWide ? 24 : 18),
        Text(l10n.appTitle, style: titleStyle),
        SizedBox(height: isWide ? 16 : 14),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWide ? 620 : 540),
          child: Text(
            l10n.workspaceDescription,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              height: 1.5,
            ),
          ),
        ),
        SizedBox(height: isCondensedMobile ? 12 : 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in [
              l10n.localFirst,
              l10n.sqlite,
              l10n.virtualThreads,
            ])
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.42 : 0.66,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.82),
                  ),
                ),
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        if (!isCondensedMobile) ...[
          SizedBox(height: isWide ? 28 : 20),
          SizedBox(
            height: isWide ? 500 : 320,
            child: _HeroStage(isWide: isWide, l10n: l10n),
          ),
        ],
      ],
    );

    final form = _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1F6F5C), Color(0xFF59B29A)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.lock_open_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            l10n.signInTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.signInDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              height: 1.5,
            ),
          ),
          if (serverConnection != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.78 : 0.92,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.82),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pageCopy.connectedServer,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: isLoading ? null : _changeServer,
                        child: Text(pageCopy.changeServer),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    serverConnection.instanceName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    serverConnection.serverOrigin,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.68,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          _Field(
            controller: _emailController,
            label: l10n.email,
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _Field(
            controller: _passwordController,
            label: l10n.password,
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
            suffix: IconButton(
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 18,
              ),
            ),
          ),
          if (_errorText != null) ...[
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
                _errorText!,
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
              onPressed: isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(isLoading ? l10n.signingIn : l10n.enterWorkspace),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.15 : 0.08,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F8A5C),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.workspaceDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.72,
                      ),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                    Color(0xFF0F171C),
                    Color(0xFF142129),
                  ]
                : const [
                    Color(0xFFF4F7F7),
                    Color(0xFFE8EFF0),
                    Color(0xFFDDE7E8),
                  ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -120,
              top: -100,
              child: _Orb(
                size: 320,
                color: theme.colorScheme.primary.withValues(alpha: 0.22),
              ),
            ),
            Positioned(
              right: -100,
              top: 120,
              child: _Orb(
                size: 260,
                color: const Color(0xFF3D7EA6).withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              right: 60,
              bottom: -180,
              child: _Orb(
                size: 420,
                color: Colors.white.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.06 : 0.22,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  sidePadding,
                  width < 640 ? 18 : 24,
                  sidePadding,
                  width < 640 ? 18 : 24,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _GlassPanel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          radius: 18,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1F6F5C),
                                      Color(0xFF54A690),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'MF',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.appTitle,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    l10n.workspaceHub,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.62),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (isCompactHeader)
                          PopupMenuButton<int>(
                            tooltip: l10n.language,
                            onSelected: _handleSettingsSelection,
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 1,
                                child: Text(l10n.lightMode),
                              ),
                              PopupMenuItem(
                                value: 2,
                                child: Text(l10n.darkMode),
                              ),
                              PopupMenuItem(
                                value: 3,
                                child: Text(l10n.simplifiedChinese),
                              ),
                              PopupMenuItem(
                                value: 4,
                                child: Text(l10n.english),
                              ),
                            ],
                            icon: const Icon(Icons.tune_rounded),
                          )
                        else ...[
                          const ThemeModeSwitcher(),
                          const SizedBox(width: 8),
                          const LanguageSwitcher(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1320),
                          child: isWide
                              ? Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _Reveal(
                                        ready: _ready,
                                        offset: const Offset(-0.08, 0),
                                        child: hero,
                                      ),
                                    ),
                                    const SizedBox(width: 28),
                                    SizedBox(
                                      width: 430,
                                      child: _Reveal(
                                        ready: _ready,
                                        offset: const Offset(0.08, 0),
                                        child: form,
                                      ),
                                    ),
                                  ],
                                )
                              : SingleChildScrollView(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: EdgeInsets.only(
                                    bottom:
                                        MediaQuery.viewInsetsOf(
                                          context,
                                        ).bottom +
                                        20,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _Reveal(
                                        ready: _ready,
                                        offset: const Offset(0, 0.05),
                                        child: hero,
                                      ),
                                      const SizedBox(height: 22),
                                      _Reveal(
                                        ready: _ready,
                                        offset: const Offset(0, 0.07),
                                        child: form,
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(28),
    this.radius = 32,
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.72 : 0.8,
            ),
            borderRadius: BorderRadius.circular(radius),
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

class _HeroStage extends StatelessWidget {
  const _HeroStage({required this.isWide, required this.l10n});
  final bool isWide;
  final AppLocalizations l10n;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _GlassPanel(
      padding: EdgeInsets.all(isWide ? 28 : 18),
      radius: isWide ? 36 : 28,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: theme.brightness == Brightness.dark
                      ? const [
                          Color(0x331F6F5C),
                          Color(0x141E3038),
                          Color(0x2616242C),
                        ]
                      : const [
                          Color(0x66FFFFFF),
                          Color(0x2FDCE8E8),
                          Color(0x55F6FBFB),
                        ],
                ),
                borderRadius: BorderRadius.circular(isWide ? 28 : 22),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: _MetricPill(
              icon: Icons.radio_button_checked_rounded,
              label: l10n.connected,
              color: const Color(0xFF1F8A5C),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              height: isWide ? 180 : 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Stack(
                children: [
                  for (final top in [18.0, 56.0, 94.0, 132.0])
                    Positioned(
                      left: 16,
                      right: 16,
                      top: isWide ? top : top * 0.68,
                      child: Container(
                        height: 1,
                        color: theme.dividerColor.withValues(alpha: 0.6),
                      ),
                    ),
                  for (final left in [42.0, 140.0, 260.0, 392.0, 510.0])
                    Positioned(
                      top: 16,
                      bottom: 16,
                      left: isWide ? left : left * 0.54,
                      child: Container(
                        width: 1,
                        color: theme.dividerColor.withValues(alpha: 0.42),
                      ),
                    ),
                  for (final dot in [
                    const _Dot(0.18, 0.24, Color(0xFF3D7EA6)),
                    const _Dot(0.38, 0.16, Color(0xFF1F6F5C)),
                    const _Dot(0.62, 0.32, Color(0xFF1F8A5C)),
                    const _Dot(0.74, 0.18, Color(0xFF52796F)),
                    const _Dot(0.28, 0.62, Color(0xFF1F6F5C)),
                    const _Dot(0.54, 0.54, Color(0xFF3D7EA6)),
                    const _Dot(0.72, 0.76, Color(0xFF1F8A5C)),
                  ])
                    Positioned(
                      left: dot.x * (isWide ? 560 : 300),
                      top: dot.y * (isWide ? 180 : 120),
                      child: Container(
                        width: isWide ? 18 : 14,
                        height: isWide ? 18 : 14,
                        decoration: BoxDecoration(
                          color: dot.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: dot.color.withValues(alpha: 0.45),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StageCard(
                  title: l10n.collaboration,
                  subtitle: l10n.workspaceHub,
                  icon: Icons.forum_rounded,
                ),
                _StageCard(
                  title: l10n.contacts,
                  subtitle: l10n.memberConversationHint,
                  icon: Icons.groups_2_rounded,
                ),
                _StageCard(
                  title: l10n.recentActivityLabel,
                  subtitle: l10n.agentConversationHint,
                  icon: Icons.bolt_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.46 : 0.68,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.52 : 0.76,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.84)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.textInputAction,
    this.keyboardType,
    this.obscureText = false,
    this.onSubmitted,
    this.suffix,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
        ),
        suffixIcon: suffix,
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

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});
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

class _Dot {
  const _Dot(this.x, this.y, this.color);
  final double x;
  final double y;
  final Color color;
}

class _SignInPageCopy {
  const _SignInPageCopy({
    required this.connectedServer,
    required this.changeServer,
  });

  final String connectedServer;
  final String changeServer;

  static _SignInPageCopy of(BuildContext context) {
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';
    if (isChinese) {
      return const _SignInPageCopy(
        connectedServer: '已连接服务器',
        changeServer: '更换',
      );
    }
    return const _SignInPageCopy(
      connectedServer: 'Connected server',
      changeServer: 'Change',
    );
  }
}
