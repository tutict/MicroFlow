import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../shared/widgets/app_pill.dart';
import '../../../chat/domain/entities/channel_summary.dart';

class ChannelList extends StatelessWidget {
  const ChannelList({
    super.key,
    required this.channels,
    required this.selectedChannelId,
    required this.onSelectChannel,
  });

  final List<ChannelSummary> channels;
  final String selectedChannelId;
  final ValueChanged<ChannelSummary> onSelectChannel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pinned = <ChannelSummary>[];
    final automation = <ChannelSummary>[];
    final team = <ChannelSummary>[];

    for (final channel in channels) {
      final normalized = channel.name.toLowerCase();
      final isPinned =
          channel.id == selectedChannelId ||
          channel.unreadCount > 0 ||
          normalized == 'general';
      final isAutomation =
          normalized.contains('agent') ||
          normalized.contains('run') ||
          normalized.contains('bot');

      if (isPinned) {
        pinned.add(channel);
      } else if (isAutomation) {
        automation.add(channel);
      } else {
        team.add(channel);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pinned.isNotEmpty) ...[
          _ChannelSection(
            title: l10n.pinnedChannels,
            channels: pinned,
            selectedChannelId: selectedChannelId,
            onSelectChannel: onSelectChannel,
            icon: Icons.push_pin_rounded,
          ),
        ],
        if (automation.isNotEmpty) ...[
          if (pinned.isNotEmpty) const SizedBox(height: 12),
          _ChannelSection(
            title: l10n.automationChannels,
            channels: automation,
            selectedChannelId: selectedChannelId,
            onSelectChannel: onSelectChannel,
            icon: Icons.bolt_rounded,
          ),
        ],
        if (team.isNotEmpty) ...[
          if (pinned.isNotEmpty || automation.isNotEmpty)
            const SizedBox(height: 12),
          _ChannelSection(
            title: l10n.teamChannels,
            channels: team,
            selectedChannelId: selectedChannelId,
            onSelectChannel: onSelectChannel,
            icon: Icons.forum_rounded,
          ),
        ],
      ],
    );
  }
}

class _ChannelSection extends StatelessWidget {
  const _ChannelSection({
    required this.title,
    required this.channels,
    required this.selectedChannelId,
    required this.onSelectChannel,
    required this.icon,
  });

  final String title;
  final List<ChannelSummary> channels;
  final String selectedChannelId;
  final ValueChanged<ChannelSummary> onSelectChannel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        ...channels.map(
          (channel) => _ChannelTile(
            channel: channel,
            isSelected: channel.id == selectedChannelId,
            onTap: () => onSelectChannel(channel),
          ),
        ),
      ],
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.isSelected,
    required this.onTap,
  });

  final ChannelSummary channel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _InteractiveChannelTile(
      channel: channel,
      isSelected: isSelected,
      onTap: onTap,
    );
  }
}

class _InteractiveChannelTile extends StatefulWidget {
  const _InteractiveChannelTile({
    required this.channel,
    required this.isSelected,
    required this.onTap,
  });

  final ChannelSummary channel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_InteractiveChannelTile> createState() =>
      _InteractiveChannelTileState();
}

class _InteractiveChannelTileState extends State<_InteractiveChannelTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedBackground = theme.colorScheme.primary.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.2 : 0.12,
    );
    final hoverBackground = theme.colorScheme.surface.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.3 : 0.56,
    );
    final leadingBackground = widget.isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.surface.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.32 : 0.68,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? selectedBackground
                : _isHovered
                ? hoverBackground
                : theme.colorScheme.surface.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.24 : 0.44,
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.22)
                  : theme.dividerColor.withValues(alpha: 0.72),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: leadingBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '#',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: widget.isSelected
                              ? Colors.white
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: widget.isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (widget.channel.unreadCount > 0)
                      AppPill(
                        label: '${widget.channel.unreadCount}',
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: theme.brightness == Brightness.dark
                              ? 0.18
                              : 0.1,
                        ),
                        borderColor: theme.colorScheme.primary.withValues(
                          alpha: 0.18,
                        ),
                        labelColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
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
