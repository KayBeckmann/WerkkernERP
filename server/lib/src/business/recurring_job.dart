import 'package:uuid/uuid.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../models.dart';
import '../repository.dart';
import 'models.dart';
import 'repository.dart';

const _uuid = Uuid();

/// Tagesjob wiederkehrender Rechnungen: für jede aktive, fällige Vorlage
/// einer Firma mit Modul `recurringInvoices` **ein Entwurf je fälliger
/// Periode** (holt verpasste Tage nach, wie offline). Idempotent und
/// mehrinstanzfähig — jede Periode wird über `generateRecurringDraft`
/// atomar beansprucht. Liefert die Zahl erzeugter Entwürfe.
///
/// [onlyCompanyId] beschränkt den Lauf auf eine Firma (manueller
/// Auslöser über die API).
Future<int> runRecurringInvoiceJob({
  required PhaseBRepository repository,
  required BusinessRepository business,
  required DateTime now,
  String? onlyCompanyId,
}) async {
  final today = DateTime.utc(now.year, now.month, now.day);
  final templates = onlyCompanyId == null
      ? await business.listDueRecurringTemplatesForJob(today)
      : [
          for (final t in await business.listRecurringTemplates(onlyCompanyId))
            if (!t.nextDueDate.isAfter(today)) t,
        ];
  final moduleEnabled = <String, bool>{};
  var created = 0;
  for (final template in templates) {
    final enabled = moduleEnabled[template.companyId] ??=
        (await repository.findCompanyById(template.companyId))?.enabledModules.contains('recurringInvoices') ?? false;
    if (!enabled) continue;
    final items = await business.recurringTemplateItems(template.companyId, template.id);
    var due = template.nextDueDate;
    while (!due.isAfter(today)) {
      final next = nextRecurrenceDate(due, template.interval);
      final documentId = _uuid.v4();
      final ok = await business.generateRecurringDraft(
        template,
        expectedDueDate: due,
        nextDueDate: next,
        draft: Document(
          id: documentId,
          companyId: template.companyId,
          customerId: template.customerId,
          kind: 'invoice',
          status: 'draft',
          issueDate: today,
          serviceDate: today,
          paymentTerms: template.paymentTerms,
          notes: template.notes,
          createdByUserId: template.createdByUserId,
          createdAt: now,
          updatedAt: now,
          version: 1,
          projectId: template.projectId,
        ),
        items: [
          for (final i in items)
            DocumentItem(
              id: _uuid.v4(),
              documentId: documentId,
              kind: i.kind,
              articleId: i.articleId,
              description: i.description,
              quantity: i.quantity,
              unitPriceCents: i.unitPriceCents,
              vatRatePercent: i.vatRatePercent,
              unit: i.unit,
              discountPercent: i.discountPercent,
              groupLabel: i.groupLabel,
              sortOrder: i.sortOrder,
            ),
        ],
      );
      // Eine andere Instanz war schneller — sie erzeugt den Rest.
      if (!ok) break;
      created++;
      await repository.recordAudit(AuditEntry(
        companyId: template.companyId,
        userId: template.createdByUserId,
        action: 'recurring.generate [job]',
        entityType: 'invoice',
        entityId: documentId,
        at: now,
      ));
      due = next;
    }
  }
  return created;
}
