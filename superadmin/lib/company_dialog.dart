import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'app.dart';

class CompanyDialogResult {
  const CompanyDialogResult.updated(PlatformCompanyInfo this.company) : unauthorized = false;
  const CompanyDialogResult.unauthorized()
      : company = null,
        unauthorized = true;
  final PlatformCompanyInfo? company;
  final bool unauthorized;
}

/// Abo pflegen (Tarif, bezahlt bis, Notiz) und Firma sperren/entsperren.
class CompanyDialog extends StatefulWidget {
  const CompanyDialog({super.key, required this.client, required this.company});

  final WerkkernApiClient client;
  final PlatformCompanyInfo company;

  @override
  State<CompanyDialog> createState() => _CompanyDialogState();
}

class _CompanyDialogState extends State<CompanyDialog> {
  late final _plan = TextEditingController(text: widget.company.plan);
  late final _note = TextEditingController(text: widget.company.note);
  late DateTime? _paidUntil = widget.company.paidUntil;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _plan.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _run(Future<PlatformCompanyInfo> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await action();
      if (mounted) Navigator.of(context).pop(CompanyDialogResult.updated(updated));
    } on Exception catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.isUnauthorized) {
        Navigator.of(context).pop(const CompanyDialogResult.unauthorized());
        return;
      }
      setState(() {
        _busy = false;
        _error = describeError(e);
      });
    }
  }

  Future<void> _save() => _run(
        () => widget.client.setPlatformBilling(
          widget.company.id,
          plan: _text(_plan),
          paidUntil: _paidUntil,
          note: _text(_note),
        ),
      );

  Future<void> _suspend() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _SuspendDialog(companyName: widget.company.name),
    );
    if (reason == null) return;
    await _run(() => widget.client.suspendCompany(widget.company.id, reason: reason.isEmpty ? null : reason));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidUntil ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _paidUntil = DateTime.utc(picked.year, picked.month, picked.day));
  }

  /// Verlängert ab „bezahlt bis“ (oder heute, falls leer/überschritten).
  void _extend(int months) {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final base = _paidUntil == null || _paidUntil!.isBefore(today) ? today : _paidUntil!;
    // Gleicher Tag im Zielmonat, gekappt aufs Monatsende (31.01. -> 28.02.).
    final lastDay = DateTime.utc(base.year, base.month + months + 1, 0).day;
    setState(() => _paidUntil = DateTime.utc(base.year, base.month + months, base.day.clamp(1, lastDay)));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.company;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(c.name),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (c.suspended)
                Card(
                  color: scheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text('Gesperrt seit ${formatDate(c.suspendedAt!.toLocal())}'),
                    subtitle: c.suspendReason == null ? null : Text(c.suspendReason!),
                  ),
                ),
              Text('Admins: ${c.adminEmails.isEmpty ? '–' : c.adminEmails.join(', ')}'),
              Text('Aktive Mitglieder: ${c.activeMembers} · angelegt ${formatDate(c.createdAt.toLocal())}'),
              const SizedBox(height: 16),
              TextField(
                key: const Key('billing-plan'),
                controller: _plan,
                decoration: const InputDecoration(labelText: 'Tarif', hintText: 'z. B. Basis', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Bezahlt bis', border: OutlineInputBorder()),
                      child: Text(
                        _paidUntil == null ? '–' : formatDate(_paidUntil!),
                        key: const Key('billing-paid-until'),
                        style: c.overdue && _paidUntil == c.paidUntil ? TextStyle(color: scheme.error) : null,
                      ),
                    ),
                  ),
                  IconButton(tooltip: 'Datum wählen', onPressed: _busy ? null : _pickDate, icon: const Icon(Icons.event)),
                  if (_paidUntil != null)
                    IconButton(
                      tooltip: 'Datum leeren',
                      onPressed: _busy ? null : () => setState(() => _paidUntil = null),
                      icon: const Icon(Icons.clear),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(label: const Text('+1 Monat'), onPressed: _busy ? null : () => _extend(1)),
                  ActionChip(label: const Text('+1 Jahr'), onPressed: _busy ? null : () => _extend(12)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('billing-note'),
                controller: _note,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Notiz (intern)', border: OutlineInputBorder()),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
            ],
          ),
        ),
      ),
      actionsOverflowButtonSpacing: 8,
      actions: [
        if (c.suspended)
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(() => widget.client.resumeCompany(c.id)),
            icon: const Icon(Icons.lock_open),
            label: const Text('Entsperren'),
          )
        else
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
            onPressed: _busy ? null : _suspend,
            icon: const Icon(Icons.lock_outline),
            label: const Text('Sperren'),
          ),
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Schließen')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Abo speichern')),
      ],
    );
  }
}

/// Bestätigung mit internem Grund; liefert den Grund ('' = keiner) oder
/// `null` bei Abbruch.
class _SuspendDialog extends StatefulWidget {
  const _SuspendDialog({required this.companyName});
  final String companyName;

  @override
  State<_SuspendDialog> createState() => _SuspendDialogState();
}

class _SuspendDialogState extends State<_SuspendDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('„${widget.companyName}“ sperren?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alle Nutzer werden sofort abgemeldet und können sich bei dieser Firma nicht mehr anmelden. '
              'Die Daten bleiben erhalten; Entsperren stellt den Zugang wieder her.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('suspend-reason'),
              controller: _reason,
              decoration: const InputDecoration(
                labelText: 'Grund (nur intern sichtbar)',
                hintText: 'z. B. Abo seit März offen',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, _reason.text.trim()),
            child: const Text('Sperren'),
          ),
        ],
      );
}
