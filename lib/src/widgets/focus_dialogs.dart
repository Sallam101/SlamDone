import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/models.dart';

Future<void> showQuickFocusDialog(
  BuildContext context,
  AppController controller, {
  WorkItem? item,
}) async {
  final minutesController = TextEditingController(
    text: (item?.timerMinutes ?? controller.defaultSessionMinutes).toString(),
  );
  var autoRepeat = false;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        title: Text(
          item == null ? 'Start general focus' : 'Focus on ${item.title}',
        ),
        content: SizedBox(
          width: (MediaQuery.sizeOf(context).width - 48)
              .clamp(240, 420)
              .toDouble(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Minutes',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: autoRepeat,
                onChanged: (value) => setState(() => autoRepeat = value),
                title: const Text('Auto repeat'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start'),
          ),
        ],
      ),
    ),
  );
  if (result == true) {
    // Avoid changing the IndexedStack while the dialog overlay is still
    // completing its exit animation.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await controller.timerEngine.start(
      mode: item == null ? TimerMode.general : TimerMode.focus,
      title: item?.title ?? 'General focus',
      workItemId: item?.id,
      durationMinutes:
          (int.tryParse(minutesController.text) ??
                  controller.defaultSessionMinutes)
              .clamp(1, 720)
              .toInt(),
      autoRepeat: autoRepeat,
    );
    controller.selectSection(AppSection.focus);
  }
  Future<void>.delayed(const Duration(milliseconds: 650), () {
    minutesController.dispose();
  });
}
