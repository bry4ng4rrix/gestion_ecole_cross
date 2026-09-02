import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import '../../features/parametres/mon_profil_screen.dart';
import '../../models/user.dart';
import 'common.dart';

class NavItem {
  final String id;
  final String label;
  final IconData icon;
  const NavItem({required this.id, required this.label, required this.icon});
}

/// Coquille de navigation partagée par les 4 rôles : reproduit le sidebar (desktop) /
/// menu hamburger de chaque `*Dashboard.jsx` — même liste de sections, même principe de
/// contenu qui change sans perdre l'utilisateur de vue (photo, nom, déconnexion toujours
/// accessibles). Chaque rôle fournit juste sa liste de `NavItem` et son générateur d'écran.
class RoleShell extends ConsumerStatefulWidget {
  final String appTitle;
  final List<NavItem> items;
  final Widget Function(BuildContext context, String id) screenBuilder;

  const RoleShell({
    super.key,
    required this.appTitle,
    required this.items,
    required this.screenBuilder,
  });

  @override
  ConsumerState<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends ConsumerState<RoleShell> {
  late String _selectedId = widget.items.first.id;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final selected = widget.items.firstWhere((e) => e.id == _selectedId, orElse: () => widget.items.first);

    return Scaffold(
      appBar: AppBar(
        title: Text(selected.label),
        actions: [
          IconButton(
            icon: UserAvatar(photoUrl: user?.photo, initials: user?.initials ?? '?', radius: 16),
            tooltip: user?.fullName,
            onPressed: () => _openProfileSheet(context, user),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(context, user),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: widget.screenBuilder(context, _selectedId),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, AppUser? user) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.school_rounded, color: scheme.primary, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.appTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: widget.items.map((item) {
                  final isSelected = item.id == _selectedId;
                  return ListTile(
                    leading: Icon(item.icon, color: isSelected ? scheme.primary : scheme.onSurfaceVariant),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? scheme.primary : scheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    onTap: () {
                      setState(() => _selectedId = item.id);
                      Navigator.of(context).pop();
                    },
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: UserAvatar(photoUrl: user?.photo, initials: user?.initials ?? '?'),
              title: Text(user?.fullName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(user?.matricule ?? user?.email ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Déconnexion',
                onPressed: () => ref.read(authProvider.notifier).logout(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openProfileSheet(BuildContext context, AppUser? user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(photoUrl: user?.photo, initials: user?.initials ?? '?', radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.fullName ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(user?.email ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MonProfilScreen()));
                  },
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Modifier mon profil'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(authProvider.notifier).logout();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Déconnexion'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
