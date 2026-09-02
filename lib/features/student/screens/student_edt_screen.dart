import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common.dart';
import '../../../core/widgets/edt_agenda.dart';
import '../student_providers.dart';

/// Miroir de `StudentEmploiDuTemps` (frontend/src/pages/StudentDashboard.jsx).
class StudentEdtScreen extends ConsumerWidget {
  const StudentEdtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edtAsync = ref.watch(emploiDuTempsProvider);

    return edtAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Emploi du temps indisponible', onRetry: () => ref.invalidate(emploiDuTempsProvider)),
      data: (creneaux) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(emploiDuTempsProvider),
        child: ListView(
          children: [
            const SectionHeader(title: 'Emploi du Temps', subtitle: 'Votre planning hebdomadaire'),
            EdtWeekGrid(creneaux: creneaux),
          ],
        ),
      ),
    );
  }
}
