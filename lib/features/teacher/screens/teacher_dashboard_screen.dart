import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common.dart';
import '../teacher_providers.dart';

/// Miroir de `TeacherDashboardOverview` (frontend/src/pages/TeacherDashboard.jsx).
class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(teacherClassesProvider);

    return classesAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Classes indisponibles', onRetry: () => ref.invalidate(teacherClassesProvider)),
      data: (classes) {
        final totalEleves = classes.fold<int>(0, (sum, c) => sum + ((c['effectif'] as num?)?.toInt() ?? 0));
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(teacherClassesProvider),
          child: ListView(
            children: [
              const SectionHeader(title: 'Tableau de bord', subtitle: "Vue d'ensemble de vos classes et tâches"),
              Row(
                children: [
                  Expanded(child: StatCard(title: 'Classes', value: '${classes.length}', icon: Icons.class_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: StatCard(title: 'Élèves total', value: '$totalEleves', icon: Icons.groups_rounded)),
                ],
              ),
              const SizedBox(height: 20),
              if (classes.isEmpty)
                const EmptyView(message: 'Aucune classe assignée pour l\'instant.', icon: Icons.class_outlined)
              else
                ...classes.map((cls) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cls['nom']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Nombre d'élèves", style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                      Text('${cls['effectif']} / ${cls['capacite_max']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Niveau', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                      Text(cls['niveau_intitule']?.toString() ?? '—', style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
