import 'package:flutter/material.dart';

/// Einzeiliger Eingabedialog. Der Controller gehört dem Dialog-State —
/// ein vom Aufrufer direkt nach `showDialog` entsorgter Controller würde
/// während der Schließen-Animation noch benutzt ("used after being
/// disposed", per Widget-Test gefunden).
Future<String?> showOnlineTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  required String confirm,
  String? intro,
  Key? fieldKey,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TextPromptDialog(title: title, label: label, confirm: confirm, intro: intro, fieldKey: fieldKey),
    );

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({required this.title, required this.label, required this.confirm, this.intro, this.fieldKey});
  final String title;
  final String label;
  final String confirm;
  final String? intro;
  final Key? fieldKey;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.intro != null) Text(widget.intro!),
          TextField(
            key: widget.fieldKey,
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(labelText: widget.label),
            onSubmitted: (value) => Navigator.pop(context, value.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text.trim()), child: Text(widget.confirm)),
      ],
    );
  }
}
