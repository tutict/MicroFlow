import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../shared/widgets/app_pill.dart';

class ContactSidebar extends StatefulWidget {
  const ContactSidebar({
    super.key,
    required this.contacts,
    required this.selectedContactId,
    this.onSelectContact,
  });

  final List<ContactSidebarEntry> contacts;
  final String? selectedContactId;
  final ValueChanged<ContactSidebarEntry>? onSelectContact;

  @override
  State<ContactSidebar> createState() => _ContactSidebarState();
}

class _ContactSidebarState extends State<ContactSidebar> {
  final TextEditingController _searchController = TextEditingController();
  String? _hoveredContactId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ContactSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedContactId != null &&
        widget.contacts.every((entry) => entry.id != widget.selectedContactId)) {
      _hoveredContactId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final query = _searchController.text.trim().toLowerCase();
    final filteredContacts = widget.contacts.where((entry) {
      if (query.isEmpty) {
        return true;
      }
      return entry.displayName.toLowerCase().contains(query) ||
          entry.subtitle.toLowerCase().contains(query);
    }).toList();
    final memberContacts = filteredContacts
        .where((entry) => !entry.isAgent)
        .toList();
    final agentContacts = filteredContacts
        .where((entry) => entry.isAgent)
        .toList();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.brightness == Brightness.dark
              ? const [
                  Color(0xFF162229),
                  Color(0xFF111C22),
                ]
              : const [
                  Color(0xFFFCFDFD),
                  Color(0xFFF2F6F7),
                ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark
                ? const Color(0x26000000)
                : const Color(0x140E1A22),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 4,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  const Color(0xFF3D7EA6).withValues(alpha: 0.78),
                  theme.colorScheme.primary.withValues(alpha: 0.18),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1F6F5C),
                        Color(0xFF2F8F78),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'MF',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.workspaceHub,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.contacts,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                AppPill(
                  label: l10n.contactsCount(filteredContacts.length),
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.18 : 0.08,
                  ),
                  borderColor: theme.colorScheme.primary.withValues(alpha: 0.14),
                  labelColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.searchContacts,
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    fillColor: theme.colorScheme.surface.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.34 : 0.68,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: [
                if (memberContacts.isNotEmpty) ...[
                  _ContactSectionLabel(label: l10n.membersGroup),
                  const SizedBox(height: 8),
                  ...memberContacts.map(
                    (contact) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ContactTile(
                        entry: contact,
                        initials: _initialsFor(contact.displayName),
                        isSelected: contact.id == widget.selectedContactId,
                        isHovered: contact.id == _hoveredContactId,
                        onHoverChanged: (isHovered) {
                          setState(() {
                            _hoveredContactId = isHovered ? contact.id : null;
                          });
                        },
                        onTap: () {
                          widget.onSelectContact?.call(contact);
                        },
                      ),
                    ),
                  ),
                ],
                if (agentContacts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ContactSectionLabel(label: l10n.agentsGroup),
                  const SizedBox(height: 8),
                  ...agentContacts.map(
                    (contact) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ContactTile(
                        entry: contact,
                        initials: _initialsFor(contact.displayName),
                        isSelected: contact.id == widget.selectedContactId,
                        isHovered: contact.id == _hoveredContactId,
                        onHoverChanged: (isHovered) {
                          setState(() {
                            _hoveredContactId = isHovered ? contact.id : null;
                          });
                        },
                        onTap: () {
                          widget.onSelectContact?.call(contact);
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ContactSidebarEntry {
  const ContactSidebarEntry({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.accent,
    required this.isOnline,
    required this.isAgent,
  });

  final String id;
  final String displayName;
  final String subtitle;
  final Color accent;
  final bool isOnline;
  final bool isAgent;
}

class _ContactSectionLabel extends StatelessWidget {
  const _ContactSectionLabel({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.entry,
    required this.initials,
    required this.isSelected,
    required this.isHovered,
    required this.onHoverChanged,
    required this.onTap,
  });

  final ContactSidebarEntry entry;
  final String initials;
  final bool isSelected;
  final bool isHovered;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = isSelected
        ? theme.colorScheme.primary.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.18 : 0.1,
          )
        : isHovered
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42)
            : theme.colorScheme.surface.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.3 : 0.56,
              );

    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? entry.accent.withValues(alpha: 0.35)
                : theme.dividerColor.withValues(alpha: 0.72),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? entry.accent.withValues(alpha: 0.22)
                              : entry.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: entry.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: entry.isOnline ? const Color(0xFF1F8A5C) : const Color(0xFF9AA7AF),
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).cardColor, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    entry.displayName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isSelected ? entry.accent : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _initialsFor(String value) {
  final cleaned = value.replaceAll('@', '').trim();
  if (cleaned.isEmpty) {
    return 'MF';
  }
  final parts = cleaned.split(RegExp(r'[\s_-]+')).where((part) => part.isNotEmpty).toList();
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
  return cleaned.substring(0, cleaned.length >= 2 ? 2 : 1).toUpperCase();
}
