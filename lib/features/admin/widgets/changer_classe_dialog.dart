import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/resource_service.dart';
import '../admin_providers.dart';

/// Miroir de `ChangerClasseDialog` (frontend/src/components/etudiants/EtudiantsPanel.jsx) :
/// affecte ou change la classe d'un étudiant pour l'année active (crée ou met à jour son
/// inscription).
Future<void> ouvrirChangerClasse(BuildContext context, WidgetRef ref, Map<String, dynamic> etudiant, int? anneeScolaireId) {
  return showDialog(
    context: context,
    builder: (context) => _ChangerClasseDialog(etudiant: etudiant, anneeScolaireId: anneeScolaireId),
  );
}

class _ChangerClasseDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> etudiant;
  final int? anneeScolaireId;
  const _ChangerClasseDialog({required this.etudiant, required this.anneeScolaireId});

  @override
  ConsumerState<_ChangerClasseDialog> createState() => _ChangerClasseDialogState();
}

class _ChangerClasseDialogState extends ConsumerState<_ChangerClasseDialog> {
  int? _classeId;
  bool _enCours = false;
  bool _initialise = false;

  Future<void> _enregistrer(Map<String, dynamic>? inscriptionActive) async {
    if (_classeId == null || widget.anneeScolaireId == null) return;
    setState(() => _enCours = true);
    try {
      if (inscriptionActive != null) {
        await ResourceService('/inscriptions').update(inscriptionActive['id'], {'classe': _classeId});
      } else {
        await ResourceService('/inscriptions').create({
          'etudiant': widget.etudiant['id'],
          'classe': _classeId,
          'annee_scolaire': widget.anneeScolaireId,
        });
      }
      ref.invalidate(adminEtudiantsProvider);
      ref.invalidate(inscriptionActiveProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Classe mise à jour.')));
      }
    } on DioException catch (err) {
      final data = err.response?.data;
      final message = data is Map ? data.values.expand((v) => v is List ? v : [v]).join(' ') : 'Erreur lors du changement de classe.';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors du changement de classe.')));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(adminClassesProvider);
    final inscriptionAsync = ref.watch(inscriptionActiveProvider((etudiantId: widget.etudiant['id'] as int, anneeScolaireId: widget.anneeScolaireId)));

    return AlertDialog(
      title: Text('Changer de classe — ${widget.etudiant['prenom']} ${widget.etudiant['nom']}'),
      content: widget.anneeScolaireId == null
          ? const Text('Aucune année scolaire active.')
          : SizedBox(
              width: 380,
              child: classesAsync.when(
                loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => const Text('Classes indisponibles.'),
                data: (classes) {
                  return inscriptionAsync.when(
                    loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => const Text('Inscription indisponible.'),
                    data: (inscriptionActive) {
                      if (!_initialise && inscriptionActive != null) {
                        _classeId = inscriptionActive['classe'] as int?;
                        _initialise = true;
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Classe actuelle : ${widget.etudiant['classe_actuelle'] ?? 'Aucune'}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            initialValue: _classeId,
                            decoration: const InputDecoration(labelText: 'Nouvelle classe'),
                            items: classes.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['nom']?.toString() ?? ''))).toList(),
                            onChanged: (v) => setState(() => _classeId = v),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: (_classeId == null || _enCours) ? null : () => _enregistrer(inscriptionActive),
                              child: _enCours
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Enregistrer'),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
      ],
    );
  }
}
