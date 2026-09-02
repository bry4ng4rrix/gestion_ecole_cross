import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/resource_service.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/widgets/common.dart';

const _porteeLabels = {
  'ETABLISSEMENT': "Tout l'établissement",
  'CLASSE': 'Une classe',
  'ENSEIGNANTS': 'Les enseignants',
  'PARENTS': 'Les parents',
};

final _annoncesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/annonces').list());
final _classesForAnnoncesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/classes').list());

/// Miroir de `AnnoncesPanel` (frontend/src/components/communication/AnnoncesPanel.jsx) —
/// partagé par les 4 rôles.
class AnnoncesPanel extends ConsumerStatefulWidget {
  const AnnoncesPanel({super.key});

  @override
  ConsumerState<AnnoncesPanel> createState() => _AnnoncesPanelState();
}

class _AnnoncesPanelState extends ConsumerState<AnnoncesPanel> {
  bool _showForm = false;
  final _titreCtrl = TextEditingController();
  final _contenuCtrl = TextEditingController();
  String _portee = 'ETABLISSEMENT';
  int? _classeId;
  bool _envoiEnCours = false;

  @override
  void dispose() {
    _titreCtrl.dispose();
    _contenuCtrl.dispose();
    super.dispose();
  }

  Future<void> _publier() async {
    if (_titreCtrl.text.trim().isEmpty || _contenuCtrl.text.trim().isEmpty) return;
    setState(() => _envoiEnCours = true);
    try {
      await ResourceService('/annonces').create({
        'titre': _titreCtrl.text.trim(),
        'contenu': _contenuCtrl.text.trim(),
        'portee': _portee,
        'classe': _portee == 'CLASSE' ? _classeId : null,
      });
      _titreCtrl.clear();
      _contenuCtrl.clear();
      setState(() {
        _showForm = false;
        _portee = 'ETABLISSEMENT';
        _classeId = null;
      });
      ref.invalidate(_annoncesProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Annonce publiée.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la publication.')));
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final peutPublier = user?.estPersonnel ?? false;
    final annoncesAsync = ref.watch(_annoncesProvider);
    final classesAsync = ref.watch(_classesForAnnoncesProvider);

    return ListView(
      children: [
        if (peutPublier) ...[
          FilledButton.icon(
            onPressed: () => setState(() => _showForm = !_showForm),
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle annonce'),
          ),
          const SizedBox(height: 12),
        ],
        if (_showForm)
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(controller: _titreCtrl, decoration: const InputDecoration(labelText: 'Titre')),
                  const SizedBox(height: 10),
                  TextField(controller: _contenuCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Contenu')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _portee,
                    decoration: const InputDecoration(labelText: 'Portée'),
                    items: _porteeLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setState(() => _portee = v!),
                  ),
                  if (_portee == 'CLASSE') ...[
                    const SizedBox(height: 10),
                    classesAsync.when(
                      data: (classes) => DropdownButtonFormField<int>(
                        initialValue: _classeId,
                        decoration: const InputDecoration(labelText: 'Classe'),
                        items: classes.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['nom'].toString()))).toList(),
                        onChanged: (v) => setState(() => _classeId = v),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => const Text('Classes indisponibles'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _envoiEnCours ? null : _publier,
                      child: _envoiEnCours ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Publier'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        annoncesAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: 'Annonces indisponibles', onRetry: () => ref.invalidate(_annoncesProvider)),
          data: (annonces) {
            if (annonces.isEmpty) return const EmptyView(message: 'Aucune annonce.', icon: Icons.campaign_outlined);
            return Column(
              children: annonces.map((a) {
                final date = DateTime.tryParse(a['date_publication']?.toString() ?? '');
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(a['titre']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
                              child: Text(_porteeLabels[a['portee']] ?? '${a['portee']}', style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(a['contenu']?.toString() ?? ''),
                        const SizedBox(height: 8),
                        Text(
                          '${a['auteur_nom'] ?? 'Système'} · ${date != null ? DateFormat('dd/MM/yyyy').format(date) : ''}',
                          style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
