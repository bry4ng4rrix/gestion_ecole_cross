import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common.dart';
import '../student_providers.dart';

/// Miroir de `StudentProfile` (frontend/src/pages/StudentDashboard.jsx).
class StudentProfilScreen extends ConsumerWidget {
  const StudentProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dossierAsync = ref.watch(monDossierProvider);

    return dossierAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Impossible de charger le profil.', onRetry: () => ref.invalidate(monDossierProvider)),
      data: (dossier) {
        if (dossier == null) return const EmptyView(message: 'Profil introuvable.');
        final scheme = Theme.of(context).colorScheme;
        return ListView(
          children: [
            const SectionHeader(title: 'Mon Profil', subtitle: 'Informations personnelles et académiques'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    UserAvatar(
                      photoUrl: dossier['photo'] as String?,
                      initials: '${(dossier['prenom'] as String? ?? '?').isNotEmpty ? dossier['prenom'][0] : '?'}${(dossier['nom'] as String? ?? '').isNotEmpty ? dossier['nom'][0] : ''}',
                      radius: 36,
                    ),
                    const SizedBox(height: 12),
                    Text('${dossier['prenom']} ${dossier['nom']}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    Text('Étudiant', style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 16),
                    _row(context, 'Matricule', dossier['matricule']?.toString() ?? '—'),
                    _row(context, 'Classe', dossier['classe_actuelle']?.toString() ?? '—'),
                    _row(context, 'Âge', dossier['age'] != null ? '${dossier['age']} ans' : '—'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Informations personnelles', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    _infoTile(context, 'Prénom', dossier['prenom']?.toString()),
                    _infoTile(context, 'Nom', dossier['nom']?.toString()),
                    _infoTile(context, 'Email', dossier['email']?.toString()),
                    _infoTile(context, 'Téléphone', dossier['telephone']?.toString()),
                    _infoTile(context, "Date d'inscription", dossier['date_inscription']?.toString()),
                    _infoTile(context, 'Statut', dossier['statut']?.toString()),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _infoTile(BuildContext context, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value?.isNotEmpty == true ? value! : '—', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
