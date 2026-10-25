import 'package:werkkern_core/werkkern_core.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';

export 'package:werkkern_core/werkkern_core.dart'
    show DunningConfig, DunningLevel, dunningInterestFor, dunningLetterTitle, dunningLevelLabel;

/// C12 Mahnwesen — Rechenkern seit Phase B in `werkkern_core`
/// (gemeinsam mit dem Server); hier nur die Anbindung an die Offline-
/// Tabellen.
DunningConfig dunningConfigFromCompany(Company company) => DunningConfig(
      reminder2AfterDays: company.dunningReminder2AfterDays,
      reminder3AfterDays: company.dunningReminder3AfterDays,
      feeLevel1: Money.fromCents(company.dunningFeeLevel1Cents),
      feeLevel2: Money.fromCents(company.dunningFeeLevel2Cents),
      feeLevel3: Money.fromCents(company.dunningFeeLevel3Cents),
      interestRatePercent: company.dunningInterestRatePercent,
    );

/// Mahnstufe eines Offline-Dokuments — siehe `dunningLevelForDue`.
DunningLevel dunningLevelFor(Invoice invoice, DateTime now, DunningConfig config) => dunningLevelForDue(
      isFinalized: invoice.status == InvoiceStatus.finalized,
      isPaid: invoice.paymentStatus == PaymentStatus.paid,
      dueDate: invoice.dueDate,
      now: now,
      config: config,
    );
