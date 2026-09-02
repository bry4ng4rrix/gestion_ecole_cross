import 'package:flutter/material.dart';

import '../../../core/api/error_message.dart';
import '../../../core/api/resource_service.dart';

/// Formulaire de saisie d'une sortie de caisse (dépense) : titre, montant, date, note
/// facultative. Miroir simplifié de `_PersonnelFormDialog` (pas d'affectations à gérer ici).
Future<void> ouvrirFormulaireDepense(BuildContext context, {required VoidCallback onEnregistre}) {
  return showDialog(context: context, builder: (context) => _DepenseFormDialog(onEnregistre: onEnregistre));
}

class _DepenseFormDialog extends StatefulWidget {
  final VoidCallback onEnregistre;
  const _DepenseFormDialog({required this.onEnregistre});

  @override
  State<_DepenseFormDialog> createState() => _DepenseFormDialogState();
}

class _DepenseFormDialogState extends State<_DepenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titreCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _enCours = false;

  @override
  void dispose() {
    _titreCtrl.dispose();
    _montantCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final choisie = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (choisie != null) setState(() => _date = choisie);
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enCours = true);
    try {
      await ResourceService('/depenses').create({
        'titre': _titreCtrl.text.trim(),
        'montant': _montantCtrl.text.trim(),
        'date_depense': _date.toIso8601String().split('T').first,
        if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
      });
      widget.onEnregistre();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dépense enregistrée.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageErreurChamps(e, "Erreur lors de l'enregistrement de la dépense."))));
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle dépense'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titreCtrl,
                decoration: const InputDecoration(labelText: 'Titre *', hintText: 'Ex: Loyer, Facturation...'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _montantCtrl,
                decoration: const InputDecoration(labelText: 'Montant (Ar) *'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Montant invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _choisirDate,
                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                label: Text('Date : ${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: 'Note (optionnel)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _enCours ? null : () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(
          onPressed: _enCours ? null : _enregistrer,
          child: _enCours
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
