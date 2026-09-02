import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common.dart';
import '../../../core/widgets/edt_agenda.dart';
import '../teacher_providers.dart';

/// Miroir de `MonEmploiDuTempsPanel` (frontend/src/pages/TeacherDashboard.jsx).
class TeacherEdtScreen extends ConsumerWidget {
  const TeacherEdtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edtAsync = ref.watch(teacherEmploiDuTempsProvider);

    return edtAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Emploi du temps indisponible', onRetry: () => ref.invalidate(teacherEmploiDuTempsProvider)),
      data: (creneaux) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(teacherEmploiDuTempsProvider),
        child: ListView(
          children: [
            const SectionHeader(title: 'Emploi du Temps', subtitle: 'Votre planning hebdomadaire'),
            EdtWeekGrid(creneaux: creneaux, showEnseignant: false, showClasse: true),
          ],
        ),
      ),
    );
  }
}
