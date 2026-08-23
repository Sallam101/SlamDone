import 'package:flutter/material.dart';

import '../controllers/app_scope.dart';
import '../models/models.dart';
import '../utils/app_utils.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final ranks = [...controller.rewardRanks]
      ..sort((a, b) => a.minimumPoints.compareTo(b.minimumPoints));
    final points = controller.totalRewardPoints;
    final current = controller.currentRewardRank;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 650;
                final summary = Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      child: Text(
                        current?.icon ?? '⭐',
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rewards & Ranks',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Text(
                            '$points points • ${current?.name ?? 'No rank'}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final actions = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _editRank(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Rank'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _rules(context),
                      icon: const Icon(Icons.tune),
                      label: const Text('Point rules'),
                    ),
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summary,
                      const SizedBox(height: 12),
                      actions,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: summary),
                    const SizedBox(width: 12),
                    actions,
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...ranks.map((rank) {
          final reached = points >= rank.minimumPoints;
          final next = ranks
              .where((value) => value.minimumPoints > rank.minimumPoints)
              .firstOrNull;
          final progress = next == null
              ? 1.0
              : ((points - rank.minimumPoints) /
                        (next.minimumPoints - rank.minimumPoints))
                    .clamp(0.0, 1.0)
                    .toDouble();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              color: reached
                  ? (parseHexColor(rank.colorHex) ??
                            Theme.of(context).colorScheme.primary)
                        .withValues(alpha: .22)
                  : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: parseHexColor(rank.colorHex),
                  child: Text(rank.icon),
                ),
                title: Text(
                  rank.name,
                  style: TextStyle(
                    fontWeight: reached ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${rank.minimumPoints} points'),
                    if (reached && next != null)
                      LinearProgressIndicator(value: progress),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editRank(context, rank: rank),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _editRank(BuildContext context, {RewardRank? rank}) async {
    final controller = AppScope.of(context);
    final name = TextEditingController(text: rank?.name ?? 'New rank');
    final points = TextEditingController(text: '${rank?.minimumPoints ?? 0}');
    final icon = TextEditingController(text: rank?.icon ?? '⭐');
    var color = parseHexColor(rank?.colorHex) ?? Colors.purple;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 24,
          ),
          title: Text(rank == null ? 'Add rank' : 'Edit rank'),
          content: SizedBox(
            width: (MediaQuery.sizeOf(context).width - 72)
                .clamp(240, 440)
                .toDouble(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Rank name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: points,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Points required',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: icon,
                  decoration: const InputDecoration(labelText: 'Emoji icon'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children:
                      const [
                            Colors.purple,
                            Colors.blue,
                            Colors.green,
                            Colors.orange,
                            Colors.red,
                            Colors.brown,
                            Colors.teal,
                          ]
                          .map(
                            (value) => InkWell(
                              onTap: () => setDialogState(() => color = value),
                              child: CircleAvatar(
                                backgroundColor: value,
                                child: color == value
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
          actions: [
            if (rank != null)
              TextButton(
                onPressed: () async {
                  await controller.deleteRewardRank(rank);
                  if (dialogContext.mounted)
                    Navigator.pop(dialogContext, false);
                },
                child: const Text('Delete'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || name.text.trim().isEmpty) return;
    if (rank == null) {
      await controller.createRewardRank(
        name: name.text.trim(),
        minimumPoints: int.tryParse(points.text) ?? 0,
        icon: icon.text.trim().isEmpty ? '⭐' : icon.text.trim(),
        colorHex: toHexColor(color),
      );
    } else {
      await controller.updateRewardRank(
        rank.copyWith(
          name: name.text.trim(),
          minimumPoints: int.tryParse(points.text) ?? rank.minimumPoints,
          icon: icon.text.trim(),
          colorHex: toHexColor(color),
        ),
      );
    }
  }

  Future<void> _rules(BuildContext context) async {
    final controller = AppScope.of(context);
    final perMinute = TextEditingController(
      text: '${controller.pointsPerFocusMinute}',
    );
    final perHabit = TextEditingController(
      text: '${controller.pointsPerHabitCheckIn}',
    );
    final fields = {
      for (final type in WorkItemType.values)
        type: TextEditingController(
          text: '${controller.itemPointValues[type] ?? 0}',
        ),
    };
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        title: const Text('Customize point rules'),
        content: SizedBox(
          width: (MediaQuery.sizeOf(context).width - 72)
              .clamp(240, 500)
              .toDouble(),
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: perMinute,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Points per completed focus minute',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: perHabit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Points per habit check-in day',
                  ),
                ),
                const SizedBox(height: 10),
                ...WorkItemType.values.map(
                  (type) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: fields[type],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Points for completed ${type.name}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await controller.setRewardRules(
        perMinute: int.tryParse(perMinute.text) ?? 1,
        perHabitCheckIn:
            int.tryParse(perHabit.text) ?? controller.pointsPerHabitCheckIn,
        itemValues: {
          for (final type in WorkItemType.values)
            type: int.tryParse(fields[type]!.text) ?? 0,
        },
      );
    }
  }
}
