import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../../../domain/services/online_session.dart';

/// Feldarten des generischen Online-Formulars.
enum OnlineFieldType { text, multiline, money, decimal, date, choice, toggle }

/// Beschreibung eines Formularfelds. Werte im Ergebnis:
/// text/multiline → `String?`, money → Cent als `int?`, decimal → `String?`
/// ("2.5"), date → `DateTime?`, choice → gewählter Schlüssel `String?`,
/// toggle → `bool`.
class OnlineField {
  const OnlineField(
    this.key,
    this.label, {
    this.type = OnlineFieldType.text,
    this.required = false,
    this.initial,
    this.options = const {},
    this.helper,
  });
  final String key;
  final String label;
  final OnlineFieldType type;
  final bool required;
  final Object? initial;

  /// Nur für [OnlineFieldType.choice]: Schlüssel → Anzeige; `null`-Schlüssel
  /// ist als „keine Auswahl“ erlaubt, wenn das Feld nicht Pflicht ist.
  final Map<String?, String> options;
  final String? helper;
}

final _dateFormat = DateFormat('dd.MM.yyyy');

String formatOnlineDate(DateTime date) => _dateFormat.format(date);

/// Zeigt ein Formular und liefert die eingegebenen Werte oder `null`
/// bei Abbruch. Pflichtfelder und Zahlformate werden vor dem Schließen
/// geprüft; der Server prüft trotzdem selbst.
Future<Map<String, Object?>?> showOnlineForm(
  BuildContext context, {
  required String title,
  required List<OnlineField> fields,
  String submitLabel = 'Speichern',
}) =>
    showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _OnlineFormDialog(title: title, fields: fields, submitLabel: submitLabel),
    );

class _OnlineFormDialog extends StatefulWidget {
  const _OnlineFormDialog({required this.title, required this.fields, required this.submitLabel});
  final String title;
  final List<OnlineField> fields;
  final String submitLabel;

  @override
  State<_OnlineFormDialog> createState() => _OnlineFormDialogState();
}

class _OnlineFormDialogState extends State<_OnlineFormDialog> {
  final _controllers = <String, TextEditingController>{};
  final _values = <String, Object?>{};
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      switch (f.type) {
        case OnlineFieldType.text || OnlineFieldType.multiline:
          _controllers[f.key] = TextEditingController(text: f.initial as String?);
        case OnlineFieldType.money:
          final cents = f.initial as int?;
          _controllers[f.key] = TextEditingController(text: cents == null ? '' : Money.fromCents(cents).formatEuro());
        case OnlineFieldType.decimal:
          _controllers[f.key] = TextEditingController(text: (f.initial as String?)?.replaceAll('.', ','));
        case OnlineFieldType.date || OnlineFieldType.choice:
          _values[f.key] = f.initial;
        case OnlineFieldType.toggle:
          _values[f.key] = f.initial as bool? ?? false;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, Object?>? _collect() {
    final result = <String, Object?>{};
    for (final f in widget.fields) {
      final text = _controllers[f.key]?.text.trim();
      Object? value;
      switch (f.type) {
        case OnlineFieldType.text || OnlineFieldType.multiline:
          value = (text == null || text.isEmpty) ? null : text;
        case OnlineFieldType.money:
          if (text != null && text.isNotEmpty) {
            try {
              value = Money.fromEuroString(text).cents;
            } on FormatException {
              setState(() => _error = '${f.label}: kein gültiger Betrag.');
              return null;
            }
          }
        case OnlineFieldType.decimal:
          if (text != null && text.isNotEmpty) {
            final normalized = text.replaceAll(',', '.');
            if (double.tryParse(normalized) == null) {
              setState(() => _error = '${f.label}: keine gültige Zahl.');
              return null;
            }
            value = normalized;
          }
        case OnlineFieldType.date || OnlineFieldType.choice || OnlineFieldType.toggle:
          value = _values[f.key];
      }
      if (f.required && value == null) {
        setState(() => _error = '${f.label} ist Pflicht.');
        return null;
      }
      result[f.key] = value;
    }
    return result;
  }

  Widget _field(OnlineField f) {
    final key = Key('online-form-${f.key}');
    switch (f.type) {
      case OnlineFieldType.text || OnlineFieldType.multiline || OnlineFieldType.money || OnlineFieldType.decimal:
        return TextField(
          key: key,
          controller: _controllers[f.key],
          maxLines: f.type == OnlineFieldType.multiline ? 3 : 1,
          keyboardType: f.type == OnlineFieldType.money || f.type == OnlineFieldType.decimal
              ? const TextInputType.numberWithOptions(decimal: true, signed: true)
              : null,
          decoration: InputDecoration(
            labelText: f.required ? '${f.label} *' : f.label,
            helperText: f.helper,
            suffixText: f.type == OnlineFieldType.money ? '€' : null,
          ),
        );
      case OnlineFieldType.date:
        final value = _values[f.key] as DateTime?;
        return ListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          title: Text(f.required ? '${f.label} *' : f.label),
          subtitle: Text(value == null ? 'nicht gesetzt' : formatOnlineDate(value)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null && !f.required)
                IconButton(
                  tooltip: 'Leeren',
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _values[f.key] = null),
                ),
              const Icon(Icons.calendar_today_outlined),
            ],
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setState(() => _values[f.key] = DateTime.utc(picked.year, picked.month, picked.day));
            }
          },
        );
      case OnlineFieldType.choice:
        return DropdownButtonFormField<String?>(
          key: key,
          initialValue: _values[f.key] as String?,
          decoration: InputDecoration(labelText: f.required ? '${f.label} *' : f.label, helperText: f.helper),
          items: [
            if (!f.required && !f.options.containsKey(null)) const DropdownMenuItem<String?>(child: Text('—')),
            for (final e in f.options.entries) DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => _values[f.key] = v),
        );
      case OnlineFieldType.toggle:
        return SwitchListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          subtitle: f.helper == null ? null : Text(f.helper!),
          value: _values[f.key] as bool,
          onChanged: (v) => setState(() => _values[f.key] = v),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in widget.fields) Padding(padding: const EdgeInsets.only(bottom: 8), child: _field(f)),
              if (_error != null)
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final values = _collect();
            if (values != null) Navigator.pop(context, values);
          },
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}

/// Liste mit Laden, Leerzustand, Fehleranzeige, Pull-to-Refresh und
/// optionaler Suche — gemeinsamer Rahmen der Online-Stammdatenlisten.
class OnlineListView<T> extends StatefulWidget {
  const OnlineListView({
    super.key,
    required this.load,
    required this.itemBuilder,
    required this.emptyText,
    this.searchHint,
    this.header,
    this.floatingActionButton,
  });

  final Future<List<T>> Function(String query) load;
  final Widget Function(BuildContext context, T item, VoidCallback reload) itemBuilder;
  final String emptyText;
  final String? searchHint;

  /// Zusatz über der Liste (z. B. Summen), bekommt `reload` mit.
  final Widget Function(BuildContext context, List<T> items, VoidCallback reload)? header;
  final Widget Function(VoidCallback reload)? floatingActionButton;

  @override
  State<OnlineListView<T>> createState() => OnlineListViewState<T>();
}

class OnlineListViewState<T> extends State<OnlineListView<T>> {
  late Future<List<T>> _future = widget.load('');
  String _query = '';

  void reload() => setState(() {
        _future = widget.load(_query);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (widget.searchHint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: widget.searchHint),
                onSubmitted: (value) {
                  _query = value.trim();
                  reload();
                },
              ),
            ),
          Expanded(
            child: FutureBuilder<List<T>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(padding: const EdgeInsets.all(24), child: Text(describeOnlineError(snapshot.error!))),
                  );
                }
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: () async => reload(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                    children: [
                      if (widget.header != null) widget.header!(context, items, reload),
                      if (items.isEmpty)
                        Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(widget.emptyText))),
                      for (final item in items)
                        Padding(padding: const EdgeInsets.only(bottom: 8), child: widget.itemBuilder(context, item, reload)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton?.call(reload),
    );
  }
}

/// Führt eine Server-Aktion aus und zeigt Fehler als Snackbar; liefert
/// `true` bei Erfolg.
Future<bool> runOnline(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
    }
    return true;
  } on Exception catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
    return false;
  }
}

/// Bestätigungsdialog für Löschen u. Ä.
Future<bool> confirmOnline(BuildContext context, String title, String message, {String confirm = 'Löschen'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirm)),
        ],
      ),
    ) ??
    false;
