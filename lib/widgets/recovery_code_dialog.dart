import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> showRecoveryCodeDialog(
  BuildContext context, {
  required String code,
  bool passwordWasReset = false,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Қалпына келтіру коды'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              passwordWasReset
                  ? 'Құпия сөз жаңартылды. Алдыңғы код жарамсыз. '
                        'Келесі қалпына келтіру үшін осы жаңа кодты сақтаңыз.'
                  : 'Құпия сөзіңізді ұмытсаңыз, аккаунтты осы кодпен '
                        'қалпына келтіре аласыз.',
            ),
            const SizedBox(height: 20),
            SelectableText(
              code,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Код көшірілді')),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Кодты көшіру'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Кодты қауіпсіз жерге сақтап, ешкімге бермеңіз. '
              'Ол қайта көрсетілмейді. Қалпына келтіру осы құрылғыда ғана '
              'жұмыс істейді.',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Кодты сақтадым'),
          ),
        ],
      ),
    ),
  );
}
