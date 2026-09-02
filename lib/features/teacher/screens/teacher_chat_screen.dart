import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../../../core/widgets/common.dart';
import '../teacher_providers.dart';

final _messagesGroupeProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, ({int classeId, int enseignantId})>((ref, args) async {
  final response = await ApiClient.instance.dio.get('/messages-groupe-classe/', queryParameters: {'classe': args.classeId, 'enseignant': args.enseignantId});
  return (response.data as List).cast<Map<String, dynamic>>();
});

final _discussionProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, ({int classeId, int enseignantId})>((ref, args) async {
  final response = await ApiClient.instance.dio.get('/discussions-classe/', queryParameters: {'classe': args.classeId, 'enseignant': args.enseignantId});
  final list = (response.data as List).cast<Map<String, dynamic>>();
  return list.isEmpty ? null : list.first;
});

/// Miroir de `ChatClassePanel` (frontend/src/components/pedagogie/ChatClassePanel.jsx) —
/// chat de groupe par classe, propre au professeur, avec ouverture/fermeture de la
/// discussion et pièces jointes.
class TeacherChatScreen extends ConsumerStatefulWidget {
  const TeacherChatScreen({super.key});

  @override
  ConsumerState<TeacherChatScreen> createState() => _TeacherChatScreenState();
}

class _TeacherChatScreenState extends ConsumerState<TeacherChatScreen> {
  int? _classeId;
  final _contenuCtrl = TextEditingController();
  PlatformFile? _fichierJoint;
  bool _envoiEnCours = false;
  bool _toggleEnCours = false;

  @override
  void dispose() {
    _contenuCtrl.dispose();
    super.dispose();
  }

  void _ecouterTempsReel(int classeId, int enseignantId) {
    ref.listen(realtimeEventProvider, (previous, next) {
      final event = next.valueOrNull;
      if (event == null) return;
      final args = (classeId: classeId, enseignantId: enseignantId);
      if (event.resource == 'messages-groupe-classe') {
        ref.invalidate(_messagesGroupeProvider(args));
      } else if (event.resource == 'discussions-classe') {
        ref.invalidate(_discussionProvider(args));
      }
    });
  }

  Future<void> _envoyer(int classeId, int enseignantId) async {
    if (_contenuCtrl.text.trim().isEmpty && _fichierJoint == null) return;
    setState(() => _envoiEnCours = true);
    try {
      final form = FormData.fromMap({
        'classe': classeId,
        'enseignant': enseignantId,
        if (_contenuCtrl.text.trim().isNotEmpty) 'contenu': _contenuCtrl.text.trim(),
        if (_fichierJoint != null)
          'fichier': MultipartFile.fromBytes(await _fichierJoint!.readAsBytes(), filename: _fichierJoint!.name),
      });
      await ApiClient.instance.dio.post('/messages-groupe-classe/', data: form);
      _contenuCtrl.clear();
      setState(() => _fichierJoint = null);
      ref.invalidate(_messagesGroupeProvider((classeId: classeId, enseignantId: enseignantId)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de l'envoi.")));
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  Future<void> _basculerDiscussion(int classeId, int enseignantId, bool estOuverte) async {
    setState(() => _toggleEnCours = true);
    try {
      await ApiClient.instance.dio.post('/discussions-classe/definir/', data: {
        'classe': classeId,
        'enseignant': enseignantId,
        'est_ouverte': !estOuverte,
      });
      ref.invalidate(_discussionProvider((classeId: classeId, enseignantId: enseignantId)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(estOuverte ? 'Discussion fermée.' : 'Discussion rouverte.')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors du changement de statut.')));
    } finally {
      if (mounted) setState(() => _toggleEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(teacherClassesProvider);
    final user = ref.watch(authProvider).user;

    return classesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Classes indisponibles', onRetry: () => ref.invalidate(teacherClassesProvider)),
      data: (classes) {
        if (classes.isEmpty || user == null) return const EmptyView(message: 'Aucune classe assignée.');
        final classeId = _classeId ?? classes.first['id'] as int;
        final classe = classes.firstWhere((c) => c['id'] == classeId);
        final args = (classeId: classeId, enseignantId: user.id);
        _ecouterTempsReel(classeId, user.id);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              initialValue: classeId,
              decoration: const InputDecoration(labelText: 'Classe'),
              items: classes.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['nom'].toString()))).toList(),
              onChanged: (v) => setState(() => _classeId = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final discussionAsync = ref.watch(_discussionProvider(args));
                  final messagesAsync = ref.watch(_messagesGroupeProvider(args));
                  final estOuverte = discussionAsync.value?['est_ouverte'] as bool? ?? true;

                  return Card(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(child: Text('Chat — ${classe['nom']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                              OutlinedButton.icon(
                                onPressed: _toggleEnCours ? null : () => _basculerDiscussion(classeId, user.id, estOuverte),
                                icon: Icon(estOuverte ? Icons.lock_outline : Icons.lock_open_outlined, size: 16),
                                label: Text(estOuverte ? 'Fermer' : 'Ouvrir'),
                              ),
                            ],
                          ),
                        ),
                        if (!estOuverte)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            color: Colors.amber.withValues(alpha: 0.15),
                            child: const Text('Discussion fermée — seul vous pouvez écrire.', style: TextStyle(fontSize: 11.5)),
                          ),
                        const Divider(height: 1),
                        Expanded(
                          child: messagesAsync.when(
                            loading: () => const LoadingView(),
                            error: (e, _) => const ErrorView(message: 'Messages indisponibles'),
                            data: (messages) {
                              if (messages.isEmpty) {
                                return const EmptyView(message: "Aucun message pour l'instant.", icon: Icons.forum_outlined);
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.all(10),
                                itemCount: messages.length,
                                itemBuilder: (context, i) {
                                  final m = messages[i];
                                  final estMoi = m['auteur'] == user.id;
                                  return Align(
                                    alignment: estMoi ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      padding: const EdgeInsets.all(10),
                                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                                      decoration: BoxDecoration(
                                        color: estMoi ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (!estMoi)
                                            Text(m['auteur_nom']?.toString() ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                          if (m['fichier'] != null)
                                            InkWell(
                                              onTap: () => launchUrl(Uri.parse(m['fichier'].toString()), mode: LaunchMode.externalApplication),
                                              child: Padding(
                                                padding: const EdgeInsets.only(bottom: 4),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.attach_file, size: 14, color: estMoi ? Theme.of(context).colorScheme.onPrimary : null),
                                                    const SizedBox(width: 4),
                                                    Text('Pièce jointe', style: TextStyle(fontSize: 12, decoration: TextDecoration.underline, color: estMoi ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.primary)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          if ((m['contenu'] as String?)?.isNotEmpty == true)
                                            Text(m['contenu'].toString(), style: TextStyle(color: estMoi ? Theme.of(context).colorScheme.onPrimary : null)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              if (_fichierJoint != null)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Chip(
                                    label: Text(_fichierJoint!.name, style: const TextStyle(fontSize: 11)),
                                    onDeleted: () => setState(() => _fichierJoint = null),
                                  ),
                                ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.attach_file),
                                    onPressed: () async {
                                      final files = await FilePicker.pickFiles();
                                      if (files.isNotEmpty) setState(() => _fichierJoint = files.first);
                                    },
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _contenuCtrl,
                                      decoration: const InputDecoration(hintText: 'Écrire un message...', isDense: true),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  IconButton(
                                    icon: _envoiEnCours ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                                    onPressed: (_envoiEnCours || (_contenuCtrl.text.trim().isEmpty && _fichierJoint == null)) ? null : () => _envoyer(classeId, user.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
