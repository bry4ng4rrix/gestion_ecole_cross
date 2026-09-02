import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common.dart';
import '../admin_providers.dart';

const _relationLabels = {'PERE': 'Père', 'MERE': 'Mère', 'TUTEUR': 'Tuteur légal', 'AUTRE': 'Autre'};

/// Affiche les informations personnelles d'un élève et la liste de ses parents/tuteurs.
/// Miroir exact de `InfosEtudiantParentsDialog` (frontend/src/components/etudiants/EtudiantsPanel.jsx)
/// — le dossier financier a sa propre action dédiée ("Paiements", voir `paiements_etudiant_sheet.dart`).
Future<void> ouvrirDetailEtudiant(BuildContext context, Map<String, dynamic> etudiant, {int? anneeScolaireId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => _EtudiantDetailContent(etudiant: etudiant, scrollController: scrollController),
    ),
  );
}

class _EtudiantDetailContent extends ConsumerWidget {
  final Map<String, dynamic> etudiant;
  final ScrollController scrollController;

  const _EtudiantDetailContent({required this.etudiant, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final etudiantId = etudiant['id'] as int;
    final tuteursAsync = ref.watch(tuteursDeLetudiantProvider(etudiantId));

    return SafeArea(
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              UserAvatar(photoUrl: etudiant['photo'] as String?, initials: _initiales(etudiant), radius: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${etudiant['prenom']} ${etudiant['nom']}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    Text('Infos élève et parents', style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Élève', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _champ(context, 'Matricule', etudiant['matricule']?.toString())),
                      Expanded(child: _champ(context, 'Classe', etudiant['classe_actuelle']?.toString())),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _champ(context, 'Téléphone', etudiant['telephone']?.toString())),
                      Expanded(child: _champ(context, 'Email', etudiant['email']?.toString())),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _champ(context, 'Adresse', etudiant['adresse']?.toString()),
                  const SizedBox(height: 10),
                  _champ(
                    context,
                    "Contact d'urgence",
                    (etudiant['contact_urgence_nom'] as String?)?.isNotEmpty == true
                        ? '${etudiant['contact_urgence_nom']} — ${(etudiant['contact_urgence_telephone'] as String?)?.isNotEmpty == true ? etudiant['contact_urgence_telephone'] : '—'}'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Parents / tuteurs', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          tuteursAsync.when(
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator()),
            error: (e, _) => const Text('Parents indisponibles.'),
            data: (tuteurs) {
              if (tuteurs.isEmpty) return const Text('Aucun parent/tuteur rattaché à cet élève.', style: TextStyle(fontSize: 13));
              return Column(
                children: tuteurs.map((t) {
                  final estPrincipal = t['est_contact_principal'] == true;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: UserAvatar(photoUrl: t['parent_photo'] as String?, initials: _initialesNom(t['parent_nom']?.toString())),
                      title: Row(
                        children: [
                          Flexible(child: Text(t['parent_nom']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w700))),
                          if (estPrincipal) ...[const SizedBox(width: 6), Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade700)],
                        ],
                      ),
                      subtitle: Text('${_relationLabels[t['relation']] ?? t['relation'] ?? ''}${estPrincipal ? ' · Contact principal' : ''}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if ((t['parent_telephone'] as String?)?.isNotEmpty == true)
                            Text(t['parent_telephone'].toString(), style: const TextStyle(fontSize: 11)),
                          if ((t['parent_email'] as String?)?.isNotEmpty == true)
                            Text(t['parent_email'].toString(), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _champ(BuildContext context, String label, String? valeur) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(valeur?.isNotEmpty == true ? valeur! : '—'),
      ],
    );
  }

  String _initiales(Map<String, dynamic> e) {
    final p = (e['prenom'] as String? ?? '').isNotEmpty ? (e['prenom'] as String)[0] : '';
    final n = (e['nom'] as String? ?? '').isNotEmpty ? (e['nom'] as String)[0] : '';
    final result = '$p$n'.toUpperCase();
    return result.isEmpty ? '?' : result;
  }

  String _initialesNom(String? nomComplet) {
    if (nomComplet == null || nomComplet.trim().isEmpty) return '?';
    final parts = nomComplet.trim().split(RegExp(r'\s+'));
    final result = parts.map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase();
    return result.isEmpty ? '?' : result.substring(0, result.length > 2 ? 2 : result.length);
  }
}
