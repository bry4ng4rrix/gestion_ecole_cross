import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/file_download.dart';
import '../../../core/widgets/common.dart';
import '../parent_providers.dart';

/// QR code de sortie de chaque enfant, imprimable, à présenter au gardien pour le contrôle
/// de sortie — un QR distinct par enfant (miroir de `qrcode-sortie`/`carte-sortie` du backend).
class ParentQrCodesScreen extends ConsumerWidget {
  const ParentQrCodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enfantsAsync = ref.watch(mesEnfantsProvider);

    return enfantsAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Enfants indisponibles', onRetry: () => ref.invalidate(mesEnfantsProvider)),
      data: (enfants) {
        if (enfants.isEmpty) return const EmptyView(message: 'Aucun enfant rattaché à votre compte.');
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(mesEnfantsProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionHeader(title: 'QR code de sortie', subtitle: 'À présenter au gardien pour récupérer votre enfant.'),
              const SizedBox(height: 12),
              ...enfants.map((enfant) => _CarteQrEnfant(enfant: enfant)),
            ],
          ),
        );
      },
    );
  }
}

class _CarteQrEnfant extends ConsumerStatefulWidget {
  final Map<String, dynamic> enfant;
  const _CarteQrEnfant({required this.enfant});

  @override
  ConsumerState<_CarteQrEnfant> createState() => _CarteQrEnfantState();
}

class _CarteQrEnfantState extends ConsumerState<_CarteQrEnfant> {
  bool _impressionEnCours = false;

  Future<void> _imprimer() async {
    setState(() => _impressionEnCours = true);
    try {
      final id = widget.enfant['id'];
      final matricule = widget.enfant['matricule'] ?? id;
      await downloadAndOpen('/etudiants/$id/carte-sortie/', 'qr_sortie_$matricule.pdf');
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la génération du QR code.')));
    } finally {
      if (mounted) setState(() => _impressionEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enfant = widget.enfant;
    final id = enfant['id'] as int;
    final qrAsync = ref.watch(qrSortieBytesProvider(id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                UserAvatar(photoUrl: enfant['photo'] as String?, initials: _initiales(enfant), radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${enfant['prenom']} ${enfant['nom']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(enfant['classe_actuelle']?.toString() ?? 'Classe non renseignée', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            qrAsync.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator()),
              error: (e, _) => const Text('QR code indisponible', style: TextStyle(fontSize: 12)),
              data: (bytes) => Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(8)),
                child: Image.memory(bytes, width: 160, height: 160),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _impressionEnCours ? null : _imprimer,
                icon: _impressionEnCours
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.print_rounded, size: 18),
                label: const Text('Imprimer le QR Code'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initiales(Map<String, dynamic> enfant) {
    final p = enfant['prenom'] as String? ?? '';
    final n = enfant['nom'] as String? ?? '';
    final r = '${p.isNotEmpty ? p[0] : ''}${n.isNotEmpty ? n[0] : ''}'.toUpperCase();
    return r.isEmpty ? '?' : r;
  }
}
