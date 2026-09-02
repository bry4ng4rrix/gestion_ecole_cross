import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/resource_service.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/widgets/common.dart';

final _messagesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/messages').list());
final _personnelForMessagerieProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ResourceService('/personnel').list());

/// Miroir de `MessageriePanel` (frontend/src/components/communication/MessageriePanel.jsx)
/// — partagé par les 4 rôles. La messagerie déléguée (délégué de classe pour un enseignant)
/// n'est pas reprise ici pour l'instant : seul l'annuaire du personnel l'est.
class MessageriePanel extends ConsumerStatefulWidget {
  const MessageriePanel({super.key});

  @override
  ConsumerState<MessageriePanel> createState() => _MessageriePanelState();
}

class _MessageriePanelState extends ConsumerState<MessageriePanel> {
  Map<String, dynamic>? _replyTo;
  int? _destinataireId;
  final _objetCtrl = TextEditingController();
  final _contenuCtrl = TextEditingController();
  bool _envoiEnCours = false;

  @override
  void dispose() {
    _objetCtrl.dispose();
    _contenuCtrl.dispose();
    super.dispose();
  }

  void _ouvrirReponse(Map<String, dynamic> m, int userId) {
    final estExpediteur = m['expediteur'] == userId;
    final autreId = estExpediteur ? m['destinataire'] as int : m['expediteur'] as int;
    final autreNom = estExpediteur ? m['destinataire_nom'] : m['expediteur_nom'];
    setState(() {
      _replyTo = {'id': autreId, 'nom': autreNom};
      _destinataireId = autreId;
      _objetCtrl.text = 'Re: ${m['objet'] ?? ''}';
      _contenuCtrl.clear();
    });
  }

  Future<void> _envoyer() async {
    if (_destinataireId == null || _objetCtrl.text.trim().isEmpty || _contenuCtrl.text.trim().isEmpty) return;
    setState(() => _envoiEnCours = true);
    try {
      await ResourceService('/messages').create({
        'destinataire': _destinataireId,
        'objet': _objetCtrl.text.trim(),
        'contenu': _contenuCtrl.text.trim(),
      });
      setState(() {
        _replyTo = null;
        _destinataireId = null;
        _objetCtrl.clear();
        _contenuCtrl.clear();
      });
      ref.invalidate(_messagesProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message envoyé.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de l'envoi.")));
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final peutComposer = user?.estPersonnel ?? false;
    final messagesAsync = ref.watch(_messagesProvider);
    final personnelAsync = peutComposer ? ref.watch(_personnelForMessagerieProvider) : const AsyncValue<List<Map<String, dynamic>>>.data([]);

    return ListView(
      children: [
        if (peutComposer || _replyTo != null)
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_replyTo != null ? 'Répondre à ${_replyTo!['nom']}' : 'Nouveau message', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (peutComposer && _replyTo == null)
                    personnelAsync.when(
                      data: (personnel) {
                        final annuaire = personnel.where((p) => p['id'] != user?.id).toList();
                        return DropdownButtonFormField<int>(
                          initialValue: _destinataireId,
                          decoration: const InputDecoration(labelText: 'Destinataire'),
                          items: annuaire
                              .map((p) => DropdownMenuItem(value: p['id'] as int, child: Text('${p['first_name']} ${p['last_name']} (${p['role']})')))
                              .toList(),
                          onChanged: (v) => setState(() => _destinataireId = v),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => const Text('Annuaire indisponible'),
                    ),
                  const SizedBox(height: 10),
                  TextField(controller: _objetCtrl, decoration: const InputDecoration(labelText: 'Objet')),
                  const SizedBox(height: 10),
                  TextField(controller: _contenuCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Votre message...')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _envoiEnCours ? null : _envoyer,
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('Envoyer'),
                      ),
                      if (_replyTo != null) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => setState(() {
                            _replyTo = null;
                            _destinataireId = null;
                            _objetCtrl.clear();
                            _contenuCtrl.clear();
                          }),
                          child: const Text('Annuler'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        messagesAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: 'Messages indisponibles', onRetry: () => ref.invalidate(_messagesProvider)),
          data: (messages) {
            if (messages.isEmpty) return const EmptyView(message: 'Aucun message.', icon: Icons.mail_outline);
            return Column(
              children: messages.map((m) {
                final recu = m['destinataire'] == user?.id;
                final nonLu = recu && m['est_lu'] != true;
                final date = DateTime.tryParse(m['date_envoi']?.toString() ?? '');
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: nonLu
                      ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5))
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(recu ? 'De : ${m['expediteur_nom']}' : 'À : ${m['destinataire_nom']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                            Text(date != null ? DateFormat('dd/MM/yyyy').format(date) : '', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(m['objet']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        const SizedBox(height: 2),
                        Text(m['contenu']?.toString() ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        if (recu) ...[
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: user != null ? () => _ouvrirReponse(m, user.id) : null,
                            child: Text('Répondre', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ),
                        ],
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
