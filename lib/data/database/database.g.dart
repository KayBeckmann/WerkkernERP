// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CompaniesTable extends Companies
    with TableInfo<$CompaniesTable, Company> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompaniesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taxNumberMeta = const VerificationMeta(
    'taxNumber',
  );
  @override
  late final GeneratedColumn<String> taxNumber = GeneratedColumn<String>(
    'tax_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vatIdMeta = const VerificationMeta('vatId');
  @override
  late final GeneratedColumn<String> vatId = GeneratedColumn<String>(
    'vat_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ibanMeta = const VerificationMeta('iban');
  @override
  late final GeneratedColumn<String> iban = GeneratedColumn<String>(
    'iban',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quotesEnabledMeta = const VerificationMeta(
    'quotesEnabled',
  );
  @override
  late final GeneratedColumn<bool> quotesEnabled = GeneratedColumn<bool>(
    'quotes_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("quotes_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _ordersEnabledMeta = const VerificationMeta(
    'ordersEnabled',
  );
  @override
  late final GeneratedColumn<bool> ordersEnabled = GeneratedColumn<bool>(
    'orders_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("orders_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deliveryNotesEnabledMeta =
      const VerificationMeta('deliveryNotesEnabled');
  @override
  late final GeneratedColumn<bool> deliveryNotesEnabled = GeneratedColumn<bool>(
    'delivery_notes_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("delivery_notes_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _proformaEnabledMeta = const VerificationMeta(
    'proformaEnabled',
  );
  @override
  late final GeneratedColumn<bool> proformaEnabled = GeneratedColumn<bool>(
    'proforma_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("proforma_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _projectsEnabledMeta = const VerificationMeta(
    'projectsEnabled',
  );
  @override
  late final GeneratedColumn<bool> projectsEnabled = GeneratedColumn<bool>(
    'projects_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("projects_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _fleetEnabledMeta = const VerificationMeta(
    'fleetEnabled',
  );
  @override
  late final GeneratedColumn<bool> fleetEnabled = GeneratedColumn<bool>(
    'fleet_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("fleet_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _recurringInvoicesEnabledMeta =
      const VerificationMeta('recurringInvoicesEnabled');
  @override
  late final GeneratedColumn<bool> recurringInvoicesEnabled =
      GeneratedColumn<bool>(
        'recurring_invoices_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("recurring_invoices_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _advancePaymentInvoicesEnabledMeta =
      const VerificationMeta('advancePaymentInvoicesEnabled');
  @override
  late final GeneratedColumn<bool> advancePaymentInvoicesEnabled =
      GeneratedColumn<bool>(
        'advance_payment_invoices_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("advance_payment_invoices_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _dunningEnabledMeta = const VerificationMeta(
    'dunningEnabled',
  );
  @override
  late final GeneratedColumn<bool> dunningEnabled = GeneratedColumn<bool>(
    'dunning_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dunning_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dunningReminder2AfterDaysMeta =
      const VerificationMeta('dunningReminder2AfterDays');
  @override
  late final GeneratedColumn<int> dunningReminder2AfterDays =
      GeneratedColumn<int>(
        'dunning_reminder2_after_days',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(14),
      );
  static const VerificationMeta _dunningReminder3AfterDaysMeta =
      const VerificationMeta('dunningReminder3AfterDays');
  @override
  late final GeneratedColumn<int> dunningReminder3AfterDays =
      GeneratedColumn<int>(
        'dunning_reminder3_after_days',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(28),
      );
  static const VerificationMeta _dunningFeeLevel1CentsMeta =
      const VerificationMeta('dunningFeeLevel1Cents');
  @override
  late final GeneratedColumn<int> dunningFeeLevel1Cents = GeneratedColumn<int>(
    'dunning_fee_level1_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dunningFeeLevel2CentsMeta =
      const VerificationMeta('dunningFeeLevel2Cents');
  @override
  late final GeneratedColumn<int> dunningFeeLevel2Cents = GeneratedColumn<int>(
    'dunning_fee_level2_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dunningFeeLevel3CentsMeta =
      const VerificationMeta('dunningFeeLevel3Cents');
  @override
  late final GeneratedColumn<int> dunningFeeLevel3Cents = GeneratedColumn<int>(
    'dunning_fee_level3_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dunningInterestRatePercentMeta =
      const VerificationMeta('dunningInterestRatePercent');
  @override
  late final GeneratedColumn<double> dunningInterestRatePercent =
      GeneratedColumn<double>(
        'dunning_interest_rate_percent',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _pdfIntroTextDunningMeta =
      const VerificationMeta('pdfIntroTextDunning');
  @override
  late final GeneratedColumn<String> pdfIntroTextDunning =
      GeneratedColumn<String>(
        'pdf_intro_text_dunning',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pdfClosingTextDunningMeta =
      const VerificationMeta('pdfClosingTextDunning');
  @override
  late final GeneratedColumn<String> pdfClosingTextDunning =
      GeneratedColumn<String>(
        'pdf_closing_text_dunning',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pdfIntroTextMeta = const VerificationMeta(
    'pdfIntroText',
  );
  @override
  late final GeneratedColumn<String> pdfIntroText = GeneratedColumn<String>(
    'pdf_intro_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pdfClosingTextMeta = const VerificationMeta(
    'pdfClosingText',
  );
  @override
  late final GeneratedColumn<String> pdfClosingText = GeneratedColumn<String>(
    'pdf_closing_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pdfIntroTextQuoteMeta = const VerificationMeta(
    'pdfIntroTextQuote',
  );
  @override
  late final GeneratedColumn<String> pdfIntroTextQuote =
      GeneratedColumn<String>(
        'pdf_intro_text_quote',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pdfClosingTextQuoteMeta =
      const VerificationMeta('pdfClosingTextQuote');
  @override
  late final GeneratedColumn<String> pdfClosingTextQuote =
      GeneratedColumn<String>(
        'pdf_closing_text_quote',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pdfIntroTextOrderMeta = const VerificationMeta(
    'pdfIntroTextOrder',
  );
  @override
  late final GeneratedColumn<String> pdfIntroTextOrder =
      GeneratedColumn<String>(
        'pdf_intro_text_order',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pdfClosingTextOrderMeta =
      const VerificationMeta('pdfClosingTextOrder');
  @override
  late final GeneratedColumn<String> pdfClosingTextOrder =
      GeneratedColumn<String>(
        'pdf_closing_text_order',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pdfIntroTextDeliveryNoteMeta =
      const VerificationMeta('pdfIntroTextDeliveryNote');
  @override
  late final GeneratedColumn<String> pdfIntroTextDeliveryNote =
      GeneratedColumn<String>(
        'pdf_intro_text_delivery_note',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pdfClosingTextDeliveryNoteMeta =
      const VerificationMeta('pdfClosingTextDeliveryNote');
  @override
  late final GeneratedColumn<String> pdfClosingTextDeliveryNote =
      GeneratedColumn<String>(
        'pdf_closing_text_delivery_note',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pdfIntroTextProformaMeta =
      const VerificationMeta('pdfIntroTextProforma');
  @override
  late final GeneratedColumn<String> pdfIntroTextProforma =
      GeneratedColumn<String>(
        'pdf_intro_text_proforma',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pdfClosingTextProformaMeta =
      const VerificationMeta('pdfClosingTextProforma');
  @override
  late final GeneratedColumn<String> pdfClosingTextProforma =
      GeneratedColumn<String>(
        'pdf_closing_text_proforma',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pdfFooterTextMeta = const VerificationMeta(
    'pdfFooterText',
  );
  @override
  late final GeneratedColumn<String> pdfFooterText = GeneratedColumn<String>(
    'pdf_footer_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _smtpEnabledMeta = const VerificationMeta(
    'smtpEnabled',
  );
  @override
  late final GeneratedColumn<bool> smtpEnabled = GeneratedColumn<bool>(
    'smtp_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("smtp_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _smtpHostMeta = const VerificationMeta(
    'smtpHost',
  );
  @override
  late final GeneratedColumn<String> smtpHost = GeneratedColumn<String>(
    'smtp_host',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _smtpPortMeta = const VerificationMeta(
    'smtpPort',
  );
  @override
  late final GeneratedColumn<int> smtpPort = GeneratedColumn<int>(
    'smtp_port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(587),
  );
  static const VerificationMeta _smtpUsernameMeta = const VerificationMeta(
    'smtpUsername',
  );
  @override
  late final GeneratedColumn<String> smtpUsername = GeneratedColumn<String>(
    'smtp_username',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _smtpFromAddressMeta = const VerificationMeta(
    'smtpFromAddress',
  );
  @override
  late final GeneratedColumn<String> smtpFromAddress = GeneratedColumn<String>(
    'smtp_from_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _smtpFromNameMeta = const VerificationMeta(
    'smtpFromName',
  );
  @override
  late final GeneratedColumn<String> smtpFromName = GeneratedColumn<String>(
    'smtp_from_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _smtpUseTlsMeta = const VerificationMeta(
    'smtpUseTls',
  );
  @override
  late final GeneratedColumn<bool> smtpUseTls = GeneratedColumn<bool>(
    'smtp_use_tls',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("smtp_use_tls" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _smtpInvoiceSubjectTemplateMeta =
      const VerificationMeta('smtpInvoiceSubjectTemplate');
  @override
  late final GeneratedColumn<String> smtpInvoiceSubjectTemplate =
      GeneratedColumn<String>(
        'smtp_invoice_subject_template',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _smtpInvoiceBodyTemplateMeta =
      const VerificationMeta('smtpInvoiceBodyTemplate');
  @override
  late final GeneratedColumn<String> smtpInvoiceBodyTemplate =
      GeneratedColumn<String>(
        'smtp_invoice_body_template',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _smtpDunningSubjectTemplateMeta =
      const VerificationMeta('smtpDunningSubjectTemplate');
  @override
  late final GeneratedColumn<String> smtpDunningSubjectTemplate =
      GeneratedColumn<String>(
        'smtp_dunning_subject_template',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _smtpDunningBodyTemplateMeta =
      const VerificationMeta('smtpDunningBodyTemplate');
  @override
  late final GeneratedColumn<String> smtpDunningBodyTemplate =
      GeneratedColumn<String>(
        'smtp_dunning_body_template',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _buchhaltungEnabledMeta =
      const VerificationMeta('buchhaltungEnabled');
  @override
  late final GeneratedColumn<bool> buchhaltungEnabled = GeneratedColumn<bool>(
    'buchhaltung_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("buchhaltung_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _bankCsvDelimiterMeta = const VerificationMeta(
    'bankCsvDelimiter',
  );
  @override
  late final GeneratedColumn<String> bankCsvDelimiter = GeneratedColumn<String>(
    'bank_csv_delimiter',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(';'),
  );
  static const VerificationMeta _bankCsvHasHeaderRowMeta =
      const VerificationMeta('bankCsvHasHeaderRow');
  @override
  late final GeneratedColumn<bool> bankCsvHasHeaderRow = GeneratedColumn<bool>(
    'bank_csv_has_header_row',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("bank_csv_has_header_row" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _bankCsvDateColumnMeta = const VerificationMeta(
    'bankCsvDateColumn',
  );
  @override
  late final GeneratedColumn<String> bankCsvDateColumn =
      GeneratedColumn<String>(
        'bank_csv_date_column',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _bankCsvAmountColumnMeta =
      const VerificationMeta('bankCsvAmountColumn');
  @override
  late final GeneratedColumn<String> bankCsvAmountColumn =
      GeneratedColumn<String>(
        'bank_csv_amount_column',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _bankCsvPurposeColumnMeta =
      const VerificationMeta('bankCsvPurposeColumn');
  @override
  late final GeneratedColumn<String> bankCsvPurposeColumn =
      GeneratedColumn<String>(
        'bank_csv_purpose_column',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _bankCsvCounterpartyColumnMeta =
      const VerificationMeta('bankCsvCounterpartyColumn');
  @override
  late final GeneratedColumn<String> bankCsvCounterpartyColumn =
      GeneratedColumn<String>(
        'bank_csv_counterparty_column',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _bankCsvDateFormatMeta = const VerificationMeta(
    'bankCsvDateFormat',
  );
  @override
  late final GeneratedColumn<String> bankCsvDateFormat =
      GeneratedColumn<String>(
        'bank_csv_date_format',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('dd.MM.yyyy'),
      );
  static const VerificationMeta _bankCsvDecimalSeparatorMeta =
      const VerificationMeta('bankCsvDecimalSeparator');
  @override
  late final GeneratedColumn<String> bankCsvDecimalSeparator =
      GeneratedColumn<String>(
        'bank_csv_decimal_separator',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(','),
      );
  static const VerificationMeta _datevBeraterNummerMeta =
      const VerificationMeta('datevBeraterNummer');
  @override
  late final GeneratedColumn<String> datevBeraterNummer =
      GeneratedColumn<String>(
        'datev_berater_nummer',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _datevMandantNummerMeta =
      const VerificationMeta('datevMandantNummer');
  @override
  late final GeneratedColumn<String> datevMandantNummer =
      GeneratedColumn<String>(
        'datev_mandant_nummer',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _datevBankGegenkontoMeta =
      const VerificationMeta('datevBankGegenkonto');
  @override
  late final GeneratedColumn<String> datevBankGegenkonto =
      GeneratedColumn<String>(
        'datev_bank_gegenkonto',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _datevSachkontenlaengeMeta =
      const VerificationMeta('datevSachkontenlaenge');
  @override
  late final GeneratedColumn<int> datevSachkontenlaenge = GeneratedColumn<int>(
    'datev_sachkontenlaenge',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
  );
  static const VerificationMeta _creditNotesEnabledMeta =
      const VerificationMeta('creditNotesEnabled');
  @override
  late final GeneratedColumn<bool> creditNotesEnabled = GeneratedColumn<bool>(
    'credit_notes_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("credit_notes_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pdfIntroTextCreditNoteMeta =
      const VerificationMeta('pdfIntroTextCreditNote');
  @override
  late final GeneratedColumn<String> pdfIntroTextCreditNote =
      GeneratedColumn<String>(
        'pdf_intro_text_credit_note',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pdfClosingTextCreditNoteMeta =
      const VerificationMeta('pdfClosingTextCreditNote');
  @override
  late final GeneratedColumn<String> pdfClosingTextCreditNote =
      GeneratedColumn<String>(
        'pdf_closing_text_credit_note',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isSmallBusinessExemptMeta =
      const VerificationMeta('isSmallBusinessExempt');
  @override
  late final GeneratedColumn<bool> isSmallBusinessExempt =
      GeneratedColumn<bool>(
        'is_small_business_exempt',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_small_business_exempt" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    address,
    taxNumber,
    vatId,
    iban,
    email,
    phone,
    createdAt,
    quotesEnabled,
    ordersEnabled,
    deliveryNotesEnabled,
    proformaEnabled,
    projectsEnabled,
    fleetEnabled,
    recurringInvoicesEnabled,
    advancePaymentInvoicesEnabled,
    dunningEnabled,
    dunningReminder2AfterDays,
    dunningReminder3AfterDays,
    dunningFeeLevel1Cents,
    dunningFeeLevel2Cents,
    dunningFeeLevel3Cents,
    dunningInterestRatePercent,
    pdfIntroTextDunning,
    pdfClosingTextDunning,
    pdfIntroText,
    pdfClosingText,
    pdfIntroTextQuote,
    pdfClosingTextQuote,
    pdfIntroTextOrder,
    pdfClosingTextOrder,
    pdfIntroTextDeliveryNote,
    pdfClosingTextDeliveryNote,
    pdfIntroTextProforma,
    pdfClosingTextProforma,
    pdfFooterText,
    smtpEnabled,
    smtpHost,
    smtpPort,
    smtpUsername,
    smtpFromAddress,
    smtpFromName,
    smtpUseTls,
    smtpInvoiceSubjectTemplate,
    smtpInvoiceBodyTemplate,
    smtpDunningSubjectTemplate,
    smtpDunningBodyTemplate,
    buchhaltungEnabled,
    bankCsvDelimiter,
    bankCsvHasHeaderRow,
    bankCsvDateColumn,
    bankCsvAmountColumn,
    bankCsvPurposeColumn,
    bankCsvCounterpartyColumn,
    bankCsvDateFormat,
    bankCsvDecimalSeparator,
    datevBeraterNummer,
    datevMandantNummer,
    datevBankGegenkonto,
    datevSachkontenlaenge,
    creditNotesEnabled,
    pdfIntroTextCreditNote,
    pdfClosingTextCreditNote,
    isSmallBusinessExempt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'companies';
  @override
  VerificationContext validateIntegrity(
    Insertable<Company> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('tax_number')) {
      context.handle(
        _taxNumberMeta,
        taxNumber.isAcceptableOrUnknown(data['tax_number']!, _taxNumberMeta),
      );
    }
    if (data.containsKey('vat_id')) {
      context.handle(
        _vatIdMeta,
        vatId.isAcceptableOrUnknown(data['vat_id']!, _vatIdMeta),
      );
    }
    if (data.containsKey('iban')) {
      context.handle(
        _ibanMeta,
        iban.isAcceptableOrUnknown(data['iban']!, _ibanMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('quotes_enabled')) {
      context.handle(
        _quotesEnabledMeta,
        quotesEnabled.isAcceptableOrUnknown(
          data['quotes_enabled']!,
          _quotesEnabledMeta,
        ),
      );
    }
    if (data.containsKey('orders_enabled')) {
      context.handle(
        _ordersEnabledMeta,
        ordersEnabled.isAcceptableOrUnknown(
          data['orders_enabled']!,
          _ordersEnabledMeta,
        ),
      );
    }
    if (data.containsKey('delivery_notes_enabled')) {
      context.handle(
        _deliveryNotesEnabledMeta,
        deliveryNotesEnabled.isAcceptableOrUnknown(
          data['delivery_notes_enabled']!,
          _deliveryNotesEnabledMeta,
        ),
      );
    }
    if (data.containsKey('proforma_enabled')) {
      context.handle(
        _proformaEnabledMeta,
        proformaEnabled.isAcceptableOrUnknown(
          data['proforma_enabled']!,
          _proformaEnabledMeta,
        ),
      );
    }
    if (data.containsKey('projects_enabled')) {
      context.handle(
        _projectsEnabledMeta,
        projectsEnabled.isAcceptableOrUnknown(
          data['projects_enabled']!,
          _projectsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('fleet_enabled')) {
      context.handle(
        _fleetEnabledMeta,
        fleetEnabled.isAcceptableOrUnknown(
          data['fleet_enabled']!,
          _fleetEnabledMeta,
        ),
      );
    }
    if (data.containsKey('recurring_invoices_enabled')) {
      context.handle(
        _recurringInvoicesEnabledMeta,
        recurringInvoicesEnabled.isAcceptableOrUnknown(
          data['recurring_invoices_enabled']!,
          _recurringInvoicesEnabledMeta,
        ),
      );
    }
    if (data.containsKey('advance_payment_invoices_enabled')) {
      context.handle(
        _advancePaymentInvoicesEnabledMeta,
        advancePaymentInvoicesEnabled.isAcceptableOrUnknown(
          data['advance_payment_invoices_enabled']!,
          _advancePaymentInvoicesEnabledMeta,
        ),
      );
    }
    if (data.containsKey('dunning_enabled')) {
      context.handle(
        _dunningEnabledMeta,
        dunningEnabled.isAcceptableOrUnknown(
          data['dunning_enabled']!,
          _dunningEnabledMeta,
        ),
      );
    }
    if (data.containsKey('dunning_reminder2_after_days')) {
      context.handle(
        _dunningReminder2AfterDaysMeta,
        dunningReminder2AfterDays.isAcceptableOrUnknown(
          data['dunning_reminder2_after_days']!,
          _dunningReminder2AfterDaysMeta,
        ),
      );
    }
    if (data.containsKey('dunning_reminder3_after_days')) {
      context.handle(
        _dunningReminder3AfterDaysMeta,
        dunningReminder3AfterDays.isAcceptableOrUnknown(
          data['dunning_reminder3_after_days']!,
          _dunningReminder3AfterDaysMeta,
        ),
      );
    }
    if (data.containsKey('dunning_fee_level1_cents')) {
      context.handle(
        _dunningFeeLevel1CentsMeta,
        dunningFeeLevel1Cents.isAcceptableOrUnknown(
          data['dunning_fee_level1_cents']!,
          _dunningFeeLevel1CentsMeta,
        ),
      );
    }
    if (data.containsKey('dunning_fee_level2_cents')) {
      context.handle(
        _dunningFeeLevel2CentsMeta,
        dunningFeeLevel2Cents.isAcceptableOrUnknown(
          data['dunning_fee_level2_cents']!,
          _dunningFeeLevel2CentsMeta,
        ),
      );
    }
    if (data.containsKey('dunning_fee_level3_cents')) {
      context.handle(
        _dunningFeeLevel3CentsMeta,
        dunningFeeLevel3Cents.isAcceptableOrUnknown(
          data['dunning_fee_level3_cents']!,
          _dunningFeeLevel3CentsMeta,
        ),
      );
    }
    if (data.containsKey('dunning_interest_rate_percent')) {
      context.handle(
        _dunningInterestRatePercentMeta,
        dunningInterestRatePercent.isAcceptableOrUnknown(
          data['dunning_interest_rate_percent']!,
          _dunningInterestRatePercentMeta,
        ),
      );
    }
    if (data.containsKey('pdf_intro_text_dunning')) {
      context.handle(
        _pdfIntroTextDunningMeta,
        pdfIntroTextDunning.isAcceptableOrUnknown(
          data['pdf_intro_text_dunning']!,
          _pdfIntroTextDunningMeta,
        ),
      );
    }
    if (data.containsKey('pdf_closing_text_dunning')) {
      context.handle(
        _pdfClosingTextDunningMeta,
        pdfClosingTextDunning.isAcceptableOrUnknown(
          data['pdf_closing_text_dunning']!,
          _pdfClosingTextDunningMeta,
        ),
      );
    }
    if (data.containsKey('pdf_intro_text')) {
      context.handle(
        _pdfIntroTextMeta,
        pdfIntroText.isAcceptableOrUnknown(
          data['pdf_intro_text']!,
          _pdfIntroTextMeta,
        ),
      );
    }
    if (data.containsKey('pdf_closing_text')) {
      context.handle(
        _pdfClosingTextMeta,
        pdfClosingText.isAcceptableOrUnknown(
          data['pdf_closing_text']!,
          _pdfClosingTextMeta,
        ),
      );
    }
    if (data.containsKey('pdf_intro_text_quote')) {
      context.handle(
        _pdfIntroTextQuoteMeta,
        pdfIntroTextQuote.isAcceptableOrUnknown(
          data['pdf_intro_text_quote']!,
          _pdfIntroTextQuoteMeta,
        ),
      );
    }
    if (data.containsKey('pdf_closing_text_quote')) {
      context.handle(
        _pdfClosingTextQuoteMeta,
        pdfClosingTextQuote.isAcceptableOrUnknown(
          data['pdf_closing_text_quote']!,
          _pdfClosingTextQuoteMeta,
        ),
      );
    }
    if (data.containsKey('pdf_intro_text_order')) {
      context.handle(
        _pdfIntroTextOrderMeta,
        pdfIntroTextOrder.isAcceptableOrUnknown(
          data['pdf_intro_text_order']!,
          _pdfIntroTextOrderMeta,
        ),
      );
    }
    if (data.containsKey('pdf_closing_text_order')) {
      context.handle(
        _pdfClosingTextOrderMeta,
        pdfClosingTextOrder.isAcceptableOrUnknown(
          data['pdf_closing_text_order']!,
          _pdfClosingTextOrderMeta,
        ),
      );
    }
    if (data.containsKey('pdf_intro_text_delivery_note')) {
      context.handle(
        _pdfIntroTextDeliveryNoteMeta,
        pdfIntroTextDeliveryNote.isAcceptableOrUnknown(
          data['pdf_intro_text_delivery_note']!,
          _pdfIntroTextDeliveryNoteMeta,
        ),
      );
    }
    if (data.containsKey('pdf_closing_text_delivery_note')) {
      context.handle(
        _pdfClosingTextDeliveryNoteMeta,
        pdfClosingTextDeliveryNote.isAcceptableOrUnknown(
          data['pdf_closing_text_delivery_note']!,
          _pdfClosingTextDeliveryNoteMeta,
        ),
      );
    }
    if (data.containsKey('pdf_intro_text_proforma')) {
      context.handle(
        _pdfIntroTextProformaMeta,
        pdfIntroTextProforma.isAcceptableOrUnknown(
          data['pdf_intro_text_proforma']!,
          _pdfIntroTextProformaMeta,
        ),
      );
    }
    if (data.containsKey('pdf_closing_text_proforma')) {
      context.handle(
        _pdfClosingTextProformaMeta,
        pdfClosingTextProforma.isAcceptableOrUnknown(
          data['pdf_closing_text_proforma']!,
          _pdfClosingTextProformaMeta,
        ),
      );
    }
    if (data.containsKey('pdf_footer_text')) {
      context.handle(
        _pdfFooterTextMeta,
        pdfFooterText.isAcceptableOrUnknown(
          data['pdf_footer_text']!,
          _pdfFooterTextMeta,
        ),
      );
    }
    if (data.containsKey('smtp_enabled')) {
      context.handle(
        _smtpEnabledMeta,
        smtpEnabled.isAcceptableOrUnknown(
          data['smtp_enabled']!,
          _smtpEnabledMeta,
        ),
      );
    }
    if (data.containsKey('smtp_host')) {
      context.handle(
        _smtpHostMeta,
        smtpHost.isAcceptableOrUnknown(data['smtp_host']!, _smtpHostMeta),
      );
    }
    if (data.containsKey('smtp_port')) {
      context.handle(
        _smtpPortMeta,
        smtpPort.isAcceptableOrUnknown(data['smtp_port']!, _smtpPortMeta),
      );
    }
    if (data.containsKey('smtp_username')) {
      context.handle(
        _smtpUsernameMeta,
        smtpUsername.isAcceptableOrUnknown(
          data['smtp_username']!,
          _smtpUsernameMeta,
        ),
      );
    }
    if (data.containsKey('smtp_from_address')) {
      context.handle(
        _smtpFromAddressMeta,
        smtpFromAddress.isAcceptableOrUnknown(
          data['smtp_from_address']!,
          _smtpFromAddressMeta,
        ),
      );
    }
    if (data.containsKey('smtp_from_name')) {
      context.handle(
        _smtpFromNameMeta,
        smtpFromName.isAcceptableOrUnknown(
          data['smtp_from_name']!,
          _smtpFromNameMeta,
        ),
      );
    }
    if (data.containsKey('smtp_use_tls')) {
      context.handle(
        _smtpUseTlsMeta,
        smtpUseTls.isAcceptableOrUnknown(
          data['smtp_use_tls']!,
          _smtpUseTlsMeta,
        ),
      );
    }
    if (data.containsKey('smtp_invoice_subject_template')) {
      context.handle(
        _smtpInvoiceSubjectTemplateMeta,
        smtpInvoiceSubjectTemplate.isAcceptableOrUnknown(
          data['smtp_invoice_subject_template']!,
          _smtpInvoiceSubjectTemplateMeta,
        ),
      );
    }
    if (data.containsKey('smtp_invoice_body_template')) {
      context.handle(
        _smtpInvoiceBodyTemplateMeta,
        smtpInvoiceBodyTemplate.isAcceptableOrUnknown(
          data['smtp_invoice_body_template']!,
          _smtpInvoiceBodyTemplateMeta,
        ),
      );
    }
    if (data.containsKey('smtp_dunning_subject_template')) {
      context.handle(
        _smtpDunningSubjectTemplateMeta,
        smtpDunningSubjectTemplate.isAcceptableOrUnknown(
          data['smtp_dunning_subject_template']!,
          _smtpDunningSubjectTemplateMeta,
        ),
      );
    }
    if (data.containsKey('smtp_dunning_body_template')) {
      context.handle(
        _smtpDunningBodyTemplateMeta,
        smtpDunningBodyTemplate.isAcceptableOrUnknown(
          data['smtp_dunning_body_template']!,
          _smtpDunningBodyTemplateMeta,
        ),
      );
    }
    if (data.containsKey('buchhaltung_enabled')) {
      context.handle(
        _buchhaltungEnabledMeta,
        buchhaltungEnabled.isAcceptableOrUnknown(
          data['buchhaltung_enabled']!,
          _buchhaltungEnabledMeta,
        ),
      );
    }
    if (data.containsKey('bank_csv_delimiter')) {
      context.handle(
        _bankCsvDelimiterMeta,
        bankCsvDelimiter.isAcceptableOrUnknown(
          data['bank_csv_delimiter']!,
          _bankCsvDelimiterMeta,
        ),
      );
    }
    if (data.containsKey('bank_csv_has_header_row')) {
      context.handle(
        _bankCsvHasHeaderRowMeta,
        bankCsvHasHeaderRow.isAcceptableOrUnknown(
          data['bank_csv_has_header_row']!,
          _bankCsvHasHeaderRowMeta,
        ),
      );
    }
    if (data.containsKey('bank_csv_date_column')) {
      context.handle(
        _bankCsvDateColumnMeta,
        bankCsvDateColumn.isAcceptableOrUnknown(
          data['bank_csv_date_column']!,
          _bankCsvDateColumnMeta,
        ),
      );
    }
    if (data.containsKey('bank_csv_amount_column')) {
      context.handle(
        _bankCsvAmountColumnMeta,
        bankCsvAmountColumn.isAcceptableOrUnknown(
          data['bank_csv_amount_column']!,
          _bankCsvAmountColumnMeta,
        ),
      );
    }
    if (data.containsKey('bank_csv_purpose_column')) {
      context.handle(
        _bankCsvPurposeColumnMeta,
        bankCsvPurposeColumn.isAcceptableOrUnknown(
          data['bank_csv_purpose_column']!,
          _bankCsvPurposeColumnMeta,
        ),
      );
    }
    if (data.containsKey('bank_csv_counterparty_column')) {
      context.handle(
        _bankCsvCounterpartyColumnMeta,
        bankCsvCounterpartyColumn.isAcceptableOrUnknown(
          data['bank_csv_counterparty_column']!,
          _bankCsvCounterpartyColumnMeta,
        ),
      );
    }
    if (data.containsKey('bank_csv_date_format')) {
      context.handle(
        _bankCsvDateFormatMeta,
        bankCsvDateFormat.isAcceptableOrUnknown(
          data['bank_csv_date_format']!,
          _bankCsvDateFormatMeta,
        ),
      );
    }
    if (data.containsKey('bank_csv_decimal_separator')) {
      context.handle(
        _bankCsvDecimalSeparatorMeta,
        bankCsvDecimalSeparator.isAcceptableOrUnknown(
          data['bank_csv_decimal_separator']!,
          _bankCsvDecimalSeparatorMeta,
        ),
      );
    }
    if (data.containsKey('datev_berater_nummer')) {
      context.handle(
        _datevBeraterNummerMeta,
        datevBeraterNummer.isAcceptableOrUnknown(
          data['datev_berater_nummer']!,
          _datevBeraterNummerMeta,
        ),
      );
    }
    if (data.containsKey('datev_mandant_nummer')) {
      context.handle(
        _datevMandantNummerMeta,
        datevMandantNummer.isAcceptableOrUnknown(
          data['datev_mandant_nummer']!,
          _datevMandantNummerMeta,
        ),
      );
    }
    if (data.containsKey('datev_bank_gegenkonto')) {
      context.handle(
        _datevBankGegenkontoMeta,
        datevBankGegenkonto.isAcceptableOrUnknown(
          data['datev_bank_gegenkonto']!,
          _datevBankGegenkontoMeta,
        ),
      );
    }
    if (data.containsKey('datev_sachkontenlaenge')) {
      context.handle(
        _datevSachkontenlaengeMeta,
        datevSachkontenlaenge.isAcceptableOrUnknown(
          data['datev_sachkontenlaenge']!,
          _datevSachkontenlaengeMeta,
        ),
      );
    }
    if (data.containsKey('credit_notes_enabled')) {
      context.handle(
        _creditNotesEnabledMeta,
        creditNotesEnabled.isAcceptableOrUnknown(
          data['credit_notes_enabled']!,
          _creditNotesEnabledMeta,
        ),
      );
    }
    if (data.containsKey('pdf_intro_text_credit_note')) {
      context.handle(
        _pdfIntroTextCreditNoteMeta,
        pdfIntroTextCreditNote.isAcceptableOrUnknown(
          data['pdf_intro_text_credit_note']!,
          _pdfIntroTextCreditNoteMeta,
        ),
      );
    }
    if (data.containsKey('pdf_closing_text_credit_note')) {
      context.handle(
        _pdfClosingTextCreditNoteMeta,
        pdfClosingTextCreditNote.isAcceptableOrUnknown(
          data['pdf_closing_text_credit_note']!,
          _pdfClosingTextCreditNoteMeta,
        ),
      );
    }
    if (data.containsKey('is_small_business_exempt')) {
      context.handle(
        _isSmallBusinessExemptMeta,
        isSmallBusinessExempt.isAcceptableOrUnknown(
          data['is_small_business_exempt']!,
          _isSmallBusinessExemptMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Company map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Company(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      taxNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tax_number'],
      ),
      vatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vat_id'],
      ),
      iban: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}iban'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      quotesEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}quotes_enabled'],
      )!,
      ordersEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}orders_enabled'],
      )!,
      deliveryNotesEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}delivery_notes_enabled'],
      )!,
      proformaEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}proforma_enabled'],
      )!,
      projectsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}projects_enabled'],
      )!,
      fleetEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}fleet_enabled'],
      )!,
      recurringInvoicesEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}recurring_invoices_enabled'],
      )!,
      advancePaymentInvoicesEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}advance_payment_invoices_enabled'],
      )!,
      dunningEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dunning_enabled'],
      )!,
      dunningReminder2AfterDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dunning_reminder2_after_days'],
      )!,
      dunningReminder3AfterDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dunning_reminder3_after_days'],
      )!,
      dunningFeeLevel1Cents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dunning_fee_level1_cents'],
      )!,
      dunningFeeLevel2Cents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dunning_fee_level2_cents'],
      )!,
      dunningFeeLevel3Cents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dunning_fee_level3_cents'],
      )!,
      dunningInterestRatePercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}dunning_interest_rate_percent'],
      )!,
      pdfIntroTextDunning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_intro_text_dunning'],
      ),
      pdfClosingTextDunning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_closing_text_dunning'],
      ),
      pdfIntroText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_intro_text'],
      ),
      pdfClosingText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_closing_text'],
      ),
      pdfIntroTextQuote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_intro_text_quote'],
      ),
      pdfClosingTextQuote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_closing_text_quote'],
      ),
      pdfIntroTextOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_intro_text_order'],
      ),
      pdfClosingTextOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_closing_text_order'],
      ),
      pdfIntroTextDeliveryNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_intro_text_delivery_note'],
      ),
      pdfClosingTextDeliveryNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_closing_text_delivery_note'],
      ),
      pdfIntroTextProforma: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_intro_text_proforma'],
      ),
      pdfClosingTextProforma: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_closing_text_proforma'],
      ),
      pdfFooterText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_footer_text'],
      ),
      smtpEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}smtp_enabled'],
      )!,
      smtpHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}smtp_host'],
      ),
      smtpPort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}smtp_port'],
      )!,
      smtpUsername: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}smtp_username'],
      ),
      smtpFromAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}smtp_from_address'],
      ),
      smtpFromName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}smtp_from_name'],
      ),
      smtpUseTls: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}smtp_use_tls'],
      )!,
      smtpInvoiceSubjectTemplate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}smtp_invoice_subject_template'],
      ),
      smtpInvoiceBodyTemplate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}smtp_invoice_body_template'],
      ),
      smtpDunningSubjectTemplate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}smtp_dunning_subject_template'],
      ),
      smtpDunningBodyTemplate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}smtp_dunning_body_template'],
      ),
      buchhaltungEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}buchhaltung_enabled'],
      )!,
      bankCsvDelimiter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_csv_delimiter'],
      )!,
      bankCsvHasHeaderRow: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}bank_csv_has_header_row'],
      )!,
      bankCsvDateColumn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_csv_date_column'],
      ),
      bankCsvAmountColumn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_csv_amount_column'],
      ),
      bankCsvPurposeColumn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_csv_purpose_column'],
      ),
      bankCsvCounterpartyColumn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_csv_counterparty_column'],
      ),
      bankCsvDateFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_csv_date_format'],
      )!,
      bankCsvDecimalSeparator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank_csv_decimal_separator'],
      )!,
      datevBeraterNummer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}datev_berater_nummer'],
      ),
      datevMandantNummer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}datev_mandant_nummer'],
      ),
      datevBankGegenkonto: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}datev_bank_gegenkonto'],
      ),
      datevSachkontenlaenge: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}datev_sachkontenlaenge'],
      )!,
      creditNotesEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}credit_notes_enabled'],
      )!,
      pdfIntroTextCreditNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_intro_text_credit_note'],
      ),
      pdfClosingTextCreditNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_closing_text_credit_note'],
      ),
      isSmallBusinessExempt: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_small_business_exempt'],
      )!,
    );
  }

  @override
  $CompaniesTable createAlias(String alias) {
    return $CompaniesTable(attachedDatabase, alias);
  }
}

class Company extends DataClass implements Insertable<Company> {
  final String id;
  final String name;
  final String? address;
  final String? taxNumber;
  final String? vatId;
  final String? iban;
  final String? email;
  final String? phone;
  final DateTime createdAt;

  /// A5: Angebot/Auftrag sind pro Firma ein-/ausblendbare Module (nicht
  /// pro Nutzer — WerkkernERP hat bewusst kein Nutzerkonto/Login, Firma
  /// ist die einzige vorhandene Mandantengrenze). Default aus: Rechnung
  /// bleibt ohne Zusatzschritt direkt nutzbar (A0-Prinzip).
  final bool quotesEnabled;
  final bool ordersEnabled;
  final bool deliveryNotesEnabled;

  /// C10 Proforma-Rechnungen (Kay-Priorisierungsentscheidung 2026-10-17,
  /// Lücke aus dem RechnungsFee-Funktionsabgleich): wie Angebot/Auftrag/
  /// Lieferschein ein pro Firma ein-/ausblendbares Modul, Default aus.
  final bool proformaEnabled;

  /// C1 Projekte (Kay-Priorisierungsentscheidung 2026-10-17): ebenfalls
  /// ein pro Firma ein-/ausblendbares Modul, Default aus — siehe
  /// [Projects].
  final bool projectsEnabled;

  /// C6 Fuhrpark/Auswärtsmontage (Kay-Priorisierungsentscheidung
  /// 2026-10-17): ebenfalls ein pro Firma ein-/ausblendbares Modul,
  /// Default aus — siehe [Vehicles].
  final bool fleetEnabled;

  /// C11 Wiederkehrende Rechnungen (Kay-Priorisierungsentscheidung
  /// 2026-10-17): ebenfalls ein pro Firma ein-/ausblendbares Modul,
  /// Default aus — siehe [RecurringInvoiceTemplates].
  final bool recurringInvoicesEnabled;

  /// C13 Abschlagsrechnungen (Kay-Priorisierungsentscheidung 2026-10-17):
  /// schaltet nur den "Ist eine Abschlagsrechnung"-Schalter im
  /// Rechnungseditor und die Abschlags-Abrechnung in der Schlussrechnung
  /// frei — keine eigene Tabelle/Liste, siehe `Invoices.isAdvancePayment`.
  final bool advancePaymentInvoicesEnabled;

  /// C12 Mahnwesen (Kay-Priorisierungsentscheidung 2026-10-17): schaltet
  /// Fälligkeitsdatum, Zahlungsstatus und die berechnete Mahnstufen-
  /// Anzeige im Rechnungseditor/-liste frei — keine eigene Tabelle.
  final bool dunningEnabled;

  /// C12 Mahnwesen — Nachbesserung (Kay-Feedback 2026-10-17: "Wo stelle
  /// ich die Gebühren und die Fristen ein?"). **Kays eigene Werte**,
  /// keine von dieser App vorgegebenen oder rechtlich geprüften Fristen/
  /// Beträge — siehe ausführlichen Doc-Kommentar bei `DunningConfig` in
  /// `domain/services/dunning_service.dart`. Default-Fristen (14/28
  /// Tage) entsprechen den bisherigen festverdrahteten Werten, Default-
  /// Gebühren/Zins sind 0 (kein Automatismus ohne explizite Eingabe).
  final int dunningReminder2AfterDays;
  final int dunningReminder3AfterDays;
  final int dunningFeeLevel1Cents;
  final int dunningFeeLevel2Cents;
  final int dunningFeeLevel3Cents;
  final double dunningInterestRatePercent;

  /// Einleitungs-/Schlusstext für ein erzeugtes Mahnschreiben — gleiches
  /// Muster wie die Dokumentart-Texte oben, aber nicht an einen
  /// [DocumentKind] gebunden (ein Mahnschreiben ist kein eigenständiges
  /// Dokument mit eigenem Nummernkreis, sondern ein Zusatzschreiben zu
  /// einer bereits finalisierten Rechnung).
  final String? pdfIntroTextDunning;
  final String? pdfClosingTextDunning;

  /// Anpassbare PDF-Texte (Kay-Nachtrag 2026-10-16: "Rechtstexte,
  /// Fußzeile und Kopfzeile in Dokumenten anpassbar machen"). Ursprünglich
  /// EIN gemeinsamer Satz für alle Dokumentarten — zweiter Nachtrag
  /// (2026-10-16): "Einleitungstext und Schlußtext müssen pro Dokument
  /// abweichend sein!" (Beispiele: Angebot braucht eine Bindefrist,
  /// Rechnung ein Zahlungsziel). `pdfIntroText`/`pdfClosingText` bleiben
  /// als Rechnungs-Text erhalten (keine Datenmigration/-verlust nötig,
  /// analog zu RechnungsFees unpräfigiertem `einleitungstext`/
  /// `schlusstext` für die Rechnung), die drei neuen Paare kommen für
  /// Angebot/Auftrag/Lieferschein dazu — exakt RechnungsFees Muster
  /// (`einleitungstext_angebot` usw., nur fachlich angeschaut, keine
  /// Code-/Text-Übernahme). Fußzeile bleibt bewusst gemeinsam (enthält
  /// typischerweise Firma/Anschrift, nicht dokumentartspezifisch).
  final String? pdfIntroText;
  final String? pdfClosingText;
  final String? pdfIntroTextQuote;
  final String? pdfClosingTextQuote;
  final String? pdfIntroTextOrder;
  final String? pdfClosingTextOrder;
  final String? pdfIntroTextDeliveryNote;
  final String? pdfClosingTextDeliveryNote;

  /// C10 Proforma-Rechnungen — eigenes Textpaar wie die übrigen drei
  /// optionalen Dokumentarten (gleiches Muster, siehe oben).
  final String? pdfIntroTextProforma;
  final String? pdfClosingTextProforma;
  final String? pdfFooterText;

  /// C7a SMTP-Versand (Kay-Nachfrage 2026-10-17: "Gibt es schon den SMTP
  /// Versand? Wo konfiguriere ich den Betreff und den Body der Mail?").
  /// Modul-Schalter wie bei den übrigen optionalen Bereichen, Default
  /// aus. Das SMTP-**Passwort** steht bewusst NICHT hier — die lokale
  /// SQLite-Datei ist (noch) unverschlüsselt (siehe F4-Hinweis in
  /// `connection.dart`) und wird 1:1 ins Backup-Zip gepackt; das Passwort
  /// liegt stattdessen in `flutter_secure_storage`
  /// (`domain/services/smtp_credential_store.dart`), referenziert über
  /// die Firmen-ID, nie über eine Spalte in dieser Tabelle.
  final bool smtpEnabled;
  final String? smtpHost;
  final int smtpPort;
  final String? smtpUsername;
  final String? smtpFromAddress;
  final String? smtpFromName;
  final bool smtpUseTls;

  /// Betreff/Text je Versandanlass — Kays ausdrückliche Nachfrage, wo das
  /// konfigurierbar ist. Freitext mit einfachen Platzhaltern
  /// (`{{kunde}}`, `{{nummer}}`, `{{firma}}`), ersetzt beim Öffnen des
  /// Versanddialogs (siehe `EmailSendDialog`) — danach im Dialog noch
  /// frei editierbar, nie stillschweigend unverändert versendet.
  final String? smtpInvoiceSubjectTemplate;
  final String? smtpInvoiceBodyTemplate;
  final String? smtpDunningSubjectTemplate;
  final String? smtpDunningBodyTemplate;

  /// C14 Buchhaltung (Kay-Priorisierungsentscheidung 2026-10-18, voller
  /// Umfang: Offene Posten + Belege/Ausgaben + Bankabgleich + DATEV-
  /// Export). EIN Modul-Schalter für den gesamten Buchhaltungsbereich
  /// (nicht pro Unterschritt) — die einzelnen Bausteine (C14.1–C14.5)
  /// kommen schrittweise dazu, teilen sich aber dasselbe Flag, weil Kay
  /// sie als ein zusammenhängendes Modul angefragt hat, nicht als
  /// unabhängige Funktionen.
  final bool buchhaltungEnabled;

  /// C14.4 Bankabgleich per CSV (Kay-Priorisierungsentscheidung
  /// 2026-10-18: CSV statt MT940, trotz des höheren Aufwands bewusst so
  /// gewählt — jede Bank hat ein eigenes CSV-Spaltenschema, deshalb
  /// konfigurierbare Spaltenzuordnung statt eines bankspezifischen
  /// Parsers). `bankCsvDateColumn`/`bankCsvAmountColumn`/... sind je
  /// nach `bankCsvHasHeaderRow` entweder Spaltenüberschriften (Text)
  /// oder nullbasierte Spaltenindizes (als Text gespeichert, z. B.
  /// "2") — beides Freitext, damit kein zweites Spaltenpaar für die
  /// beiden Fälle nötig ist.
  final String bankCsvDelimiter;
  final bool bankCsvHasHeaderRow;
  final String? bankCsvDateColumn;
  final String? bankCsvAmountColumn;
  final String? bankCsvPurposeColumn;
  final String? bankCsvCounterpartyColumn;

  /// `intl`-Musterformat, z. B. `dd.MM.yyyy` oder `yyyy-MM-dd`.
  final String bankCsvDateFormat;

  /// `,` (deutsch, Standard) oder `.` (englisch/US) als Dezimaltrenner
  /// im Betragsfeld der CSV-Datei.
  final String bankCsvDecimalSeparator;

  /// C14.5 DATEV-Export (Kay-Priorisierungsentscheidung 2026-10-18,
  /// letzter Baustein der vollen Buchhaltung, Kontenrahmen SKR03).
  /// Berater-/Mandantennummer sind Kays eigene Angaben von seinem
  /// Steuerberater/seiner DATEV-Kanzlei — diese App erfindet oder rät
  /// hier nichts. `datevBankGegenkonto` ist das Konto, gegen das Belege
  /// gebucht werden (typischerweise das Bank-/Kassenkonto, z. B. 1200
  /// in SKR03) — ebenfalls Kays eigene Angabe.
  final String? datevBeraterNummer;
  final String? datevMandantNummer;
  final String? datevBankGegenkonto;
  final int datevSachkontenlaenge;

  /// Gutschriften (Kay-Entscheidung 2026-10-19) — pro Firma ein-/
  /// ausblendbares Modul wie alle übrigen optionalen Dokumentarten,
  /// Default aus. Eigenes Einleitungs-/Schlusstext-Paar wie bei den
  /// übrigen Dokumentarten (siehe `document_text_resolver.dart`).
  final bool creditNotesEnabled;
  final String? pdfIntroTextCreditNote;
  final String? pdfClosingTextCreditNote;

  /// Nachtrag 2026-10-18: "Kleingewerbe nach §?? darf Umsatzsteuer
  /// NICHT ausweisen." Arbeitsvorgabe wie bei allen anderen
  /// steuerlichen Punkten dieser App (F1: keine Rechtsprüfung) — Kay
  /// bestätigt mit seinem Steuerberater, dass § 19 Abs. 1 UStG
  /// (Kleinunternehmerregelung) tatsächlich zutrifft, diese App prüft
  /// das nicht. Ist der Schalter aktiv, erzwingt der Positions-Dialog
  /// 0 % auf jede neue Position (siehe `invoice_item_dialog.dart`) und
  /// das PDF zeigt automatisch den gesetzlich vorgeschriebenen Hinweis
  /// (siehe `invoice_pdf_builder.dart`) — bewusst NICHT im frei
  /// editierbaren `pdfClosingText`, damit der Hinweis nicht versehentlich
  /// beim Bearbeiten des Schlusstexts verschwindet.
  final bool isSmallBusinessExempt;
  const Company({
    required this.id,
    required this.name,
    this.address,
    this.taxNumber,
    this.vatId,
    this.iban,
    this.email,
    this.phone,
    required this.createdAt,
    required this.quotesEnabled,
    required this.ordersEnabled,
    required this.deliveryNotesEnabled,
    required this.proformaEnabled,
    required this.projectsEnabled,
    required this.fleetEnabled,
    required this.recurringInvoicesEnabled,
    required this.advancePaymentInvoicesEnabled,
    required this.dunningEnabled,
    required this.dunningReminder2AfterDays,
    required this.dunningReminder3AfterDays,
    required this.dunningFeeLevel1Cents,
    required this.dunningFeeLevel2Cents,
    required this.dunningFeeLevel3Cents,
    required this.dunningInterestRatePercent,
    this.pdfIntroTextDunning,
    this.pdfClosingTextDunning,
    this.pdfIntroText,
    this.pdfClosingText,
    this.pdfIntroTextQuote,
    this.pdfClosingTextQuote,
    this.pdfIntroTextOrder,
    this.pdfClosingTextOrder,
    this.pdfIntroTextDeliveryNote,
    this.pdfClosingTextDeliveryNote,
    this.pdfIntroTextProforma,
    this.pdfClosingTextProforma,
    this.pdfFooterText,
    required this.smtpEnabled,
    this.smtpHost,
    required this.smtpPort,
    this.smtpUsername,
    this.smtpFromAddress,
    this.smtpFromName,
    required this.smtpUseTls,
    this.smtpInvoiceSubjectTemplate,
    this.smtpInvoiceBodyTemplate,
    this.smtpDunningSubjectTemplate,
    this.smtpDunningBodyTemplate,
    required this.buchhaltungEnabled,
    required this.bankCsvDelimiter,
    required this.bankCsvHasHeaderRow,
    this.bankCsvDateColumn,
    this.bankCsvAmountColumn,
    this.bankCsvPurposeColumn,
    this.bankCsvCounterpartyColumn,
    required this.bankCsvDateFormat,
    required this.bankCsvDecimalSeparator,
    this.datevBeraterNummer,
    this.datevMandantNummer,
    this.datevBankGegenkonto,
    required this.datevSachkontenlaenge,
    required this.creditNotesEnabled,
    this.pdfIntroTextCreditNote,
    this.pdfClosingTextCreditNote,
    required this.isSmallBusinessExempt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || taxNumber != null) {
      map['tax_number'] = Variable<String>(taxNumber);
    }
    if (!nullToAbsent || vatId != null) {
      map['vat_id'] = Variable<String>(vatId);
    }
    if (!nullToAbsent || iban != null) {
      map['iban'] = Variable<String>(iban);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['quotes_enabled'] = Variable<bool>(quotesEnabled);
    map['orders_enabled'] = Variable<bool>(ordersEnabled);
    map['delivery_notes_enabled'] = Variable<bool>(deliveryNotesEnabled);
    map['proforma_enabled'] = Variable<bool>(proformaEnabled);
    map['projects_enabled'] = Variable<bool>(projectsEnabled);
    map['fleet_enabled'] = Variable<bool>(fleetEnabled);
    map['recurring_invoices_enabled'] = Variable<bool>(
      recurringInvoicesEnabled,
    );
    map['advance_payment_invoices_enabled'] = Variable<bool>(
      advancePaymentInvoicesEnabled,
    );
    map['dunning_enabled'] = Variable<bool>(dunningEnabled);
    map['dunning_reminder2_after_days'] = Variable<int>(
      dunningReminder2AfterDays,
    );
    map['dunning_reminder3_after_days'] = Variable<int>(
      dunningReminder3AfterDays,
    );
    map['dunning_fee_level1_cents'] = Variable<int>(dunningFeeLevel1Cents);
    map['dunning_fee_level2_cents'] = Variable<int>(dunningFeeLevel2Cents);
    map['dunning_fee_level3_cents'] = Variable<int>(dunningFeeLevel3Cents);
    map['dunning_interest_rate_percent'] = Variable<double>(
      dunningInterestRatePercent,
    );
    if (!nullToAbsent || pdfIntroTextDunning != null) {
      map['pdf_intro_text_dunning'] = Variable<String>(pdfIntroTextDunning);
    }
    if (!nullToAbsent || pdfClosingTextDunning != null) {
      map['pdf_closing_text_dunning'] = Variable<String>(pdfClosingTextDunning);
    }
    if (!nullToAbsent || pdfIntroText != null) {
      map['pdf_intro_text'] = Variable<String>(pdfIntroText);
    }
    if (!nullToAbsent || pdfClosingText != null) {
      map['pdf_closing_text'] = Variable<String>(pdfClosingText);
    }
    if (!nullToAbsent || pdfIntroTextQuote != null) {
      map['pdf_intro_text_quote'] = Variable<String>(pdfIntroTextQuote);
    }
    if (!nullToAbsent || pdfClosingTextQuote != null) {
      map['pdf_closing_text_quote'] = Variable<String>(pdfClosingTextQuote);
    }
    if (!nullToAbsent || pdfIntroTextOrder != null) {
      map['pdf_intro_text_order'] = Variable<String>(pdfIntroTextOrder);
    }
    if (!nullToAbsent || pdfClosingTextOrder != null) {
      map['pdf_closing_text_order'] = Variable<String>(pdfClosingTextOrder);
    }
    if (!nullToAbsent || pdfIntroTextDeliveryNote != null) {
      map['pdf_intro_text_delivery_note'] = Variable<String>(
        pdfIntroTextDeliveryNote,
      );
    }
    if (!nullToAbsent || pdfClosingTextDeliveryNote != null) {
      map['pdf_closing_text_delivery_note'] = Variable<String>(
        pdfClosingTextDeliveryNote,
      );
    }
    if (!nullToAbsent || pdfIntroTextProforma != null) {
      map['pdf_intro_text_proforma'] = Variable<String>(pdfIntroTextProforma);
    }
    if (!nullToAbsent || pdfClosingTextProforma != null) {
      map['pdf_closing_text_proforma'] = Variable<String>(
        pdfClosingTextProforma,
      );
    }
    if (!nullToAbsent || pdfFooterText != null) {
      map['pdf_footer_text'] = Variable<String>(pdfFooterText);
    }
    map['smtp_enabled'] = Variable<bool>(smtpEnabled);
    if (!nullToAbsent || smtpHost != null) {
      map['smtp_host'] = Variable<String>(smtpHost);
    }
    map['smtp_port'] = Variable<int>(smtpPort);
    if (!nullToAbsent || smtpUsername != null) {
      map['smtp_username'] = Variable<String>(smtpUsername);
    }
    if (!nullToAbsent || smtpFromAddress != null) {
      map['smtp_from_address'] = Variable<String>(smtpFromAddress);
    }
    if (!nullToAbsent || smtpFromName != null) {
      map['smtp_from_name'] = Variable<String>(smtpFromName);
    }
    map['smtp_use_tls'] = Variable<bool>(smtpUseTls);
    if (!nullToAbsent || smtpInvoiceSubjectTemplate != null) {
      map['smtp_invoice_subject_template'] = Variable<String>(
        smtpInvoiceSubjectTemplate,
      );
    }
    if (!nullToAbsent || smtpInvoiceBodyTemplate != null) {
      map['smtp_invoice_body_template'] = Variable<String>(
        smtpInvoiceBodyTemplate,
      );
    }
    if (!nullToAbsent || smtpDunningSubjectTemplate != null) {
      map['smtp_dunning_subject_template'] = Variable<String>(
        smtpDunningSubjectTemplate,
      );
    }
    if (!nullToAbsent || smtpDunningBodyTemplate != null) {
      map['smtp_dunning_body_template'] = Variable<String>(
        smtpDunningBodyTemplate,
      );
    }
    map['buchhaltung_enabled'] = Variable<bool>(buchhaltungEnabled);
    map['bank_csv_delimiter'] = Variable<String>(bankCsvDelimiter);
    map['bank_csv_has_header_row'] = Variable<bool>(bankCsvHasHeaderRow);
    if (!nullToAbsent || bankCsvDateColumn != null) {
      map['bank_csv_date_column'] = Variable<String>(bankCsvDateColumn);
    }
    if (!nullToAbsent || bankCsvAmountColumn != null) {
      map['bank_csv_amount_column'] = Variable<String>(bankCsvAmountColumn);
    }
    if (!nullToAbsent || bankCsvPurposeColumn != null) {
      map['bank_csv_purpose_column'] = Variable<String>(bankCsvPurposeColumn);
    }
    if (!nullToAbsent || bankCsvCounterpartyColumn != null) {
      map['bank_csv_counterparty_column'] = Variable<String>(
        bankCsvCounterpartyColumn,
      );
    }
    map['bank_csv_date_format'] = Variable<String>(bankCsvDateFormat);
    map['bank_csv_decimal_separator'] = Variable<String>(
      bankCsvDecimalSeparator,
    );
    if (!nullToAbsent || datevBeraterNummer != null) {
      map['datev_berater_nummer'] = Variable<String>(datevBeraterNummer);
    }
    if (!nullToAbsent || datevMandantNummer != null) {
      map['datev_mandant_nummer'] = Variable<String>(datevMandantNummer);
    }
    if (!nullToAbsent || datevBankGegenkonto != null) {
      map['datev_bank_gegenkonto'] = Variable<String>(datevBankGegenkonto);
    }
    map['datev_sachkontenlaenge'] = Variable<int>(datevSachkontenlaenge);
    map['credit_notes_enabled'] = Variable<bool>(creditNotesEnabled);
    if (!nullToAbsent || pdfIntroTextCreditNote != null) {
      map['pdf_intro_text_credit_note'] = Variable<String>(
        pdfIntroTextCreditNote,
      );
    }
    if (!nullToAbsent || pdfClosingTextCreditNote != null) {
      map['pdf_closing_text_credit_note'] = Variable<String>(
        pdfClosingTextCreditNote,
      );
    }
    map['is_small_business_exempt'] = Variable<bool>(isSmallBusinessExempt);
    return map;
  }

  CompaniesCompanion toCompanion(bool nullToAbsent) {
    return CompaniesCompanion(
      id: Value(id),
      name: Value(name),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      taxNumber: taxNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(taxNumber),
      vatId: vatId == null && nullToAbsent
          ? const Value.absent()
          : Value(vatId),
      iban: iban == null && nullToAbsent ? const Value.absent() : Value(iban),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      createdAt: Value(createdAt),
      quotesEnabled: Value(quotesEnabled),
      ordersEnabled: Value(ordersEnabled),
      deliveryNotesEnabled: Value(deliveryNotesEnabled),
      proformaEnabled: Value(proformaEnabled),
      projectsEnabled: Value(projectsEnabled),
      fleetEnabled: Value(fleetEnabled),
      recurringInvoicesEnabled: Value(recurringInvoicesEnabled),
      advancePaymentInvoicesEnabled: Value(advancePaymentInvoicesEnabled),
      dunningEnabled: Value(dunningEnabled),
      dunningReminder2AfterDays: Value(dunningReminder2AfterDays),
      dunningReminder3AfterDays: Value(dunningReminder3AfterDays),
      dunningFeeLevel1Cents: Value(dunningFeeLevel1Cents),
      dunningFeeLevel2Cents: Value(dunningFeeLevel2Cents),
      dunningFeeLevel3Cents: Value(dunningFeeLevel3Cents),
      dunningInterestRatePercent: Value(dunningInterestRatePercent),
      pdfIntroTextDunning: pdfIntroTextDunning == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfIntroTextDunning),
      pdfClosingTextDunning: pdfClosingTextDunning == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfClosingTextDunning),
      pdfIntroText: pdfIntroText == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfIntroText),
      pdfClosingText: pdfClosingText == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfClosingText),
      pdfIntroTextQuote: pdfIntroTextQuote == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfIntroTextQuote),
      pdfClosingTextQuote: pdfClosingTextQuote == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfClosingTextQuote),
      pdfIntroTextOrder: pdfIntroTextOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfIntroTextOrder),
      pdfClosingTextOrder: pdfClosingTextOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfClosingTextOrder),
      pdfIntroTextDeliveryNote: pdfIntroTextDeliveryNote == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfIntroTextDeliveryNote),
      pdfClosingTextDeliveryNote:
          pdfClosingTextDeliveryNote == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfClosingTextDeliveryNote),
      pdfIntroTextProforma: pdfIntroTextProforma == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfIntroTextProforma),
      pdfClosingTextProforma: pdfClosingTextProforma == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfClosingTextProforma),
      pdfFooterText: pdfFooterText == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfFooterText),
      smtpEnabled: Value(smtpEnabled),
      smtpHost: smtpHost == null && nullToAbsent
          ? const Value.absent()
          : Value(smtpHost),
      smtpPort: Value(smtpPort),
      smtpUsername: smtpUsername == null && nullToAbsent
          ? const Value.absent()
          : Value(smtpUsername),
      smtpFromAddress: smtpFromAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(smtpFromAddress),
      smtpFromName: smtpFromName == null && nullToAbsent
          ? const Value.absent()
          : Value(smtpFromName),
      smtpUseTls: Value(smtpUseTls),
      smtpInvoiceSubjectTemplate:
          smtpInvoiceSubjectTemplate == null && nullToAbsent
          ? const Value.absent()
          : Value(smtpInvoiceSubjectTemplate),
      smtpInvoiceBodyTemplate: smtpInvoiceBodyTemplate == null && nullToAbsent
          ? const Value.absent()
          : Value(smtpInvoiceBodyTemplate),
      smtpDunningSubjectTemplate:
          smtpDunningSubjectTemplate == null && nullToAbsent
          ? const Value.absent()
          : Value(smtpDunningSubjectTemplate),
      smtpDunningBodyTemplate: smtpDunningBodyTemplate == null && nullToAbsent
          ? const Value.absent()
          : Value(smtpDunningBodyTemplate),
      buchhaltungEnabled: Value(buchhaltungEnabled),
      bankCsvDelimiter: Value(bankCsvDelimiter),
      bankCsvHasHeaderRow: Value(bankCsvHasHeaderRow),
      bankCsvDateColumn: bankCsvDateColumn == null && nullToAbsent
          ? const Value.absent()
          : Value(bankCsvDateColumn),
      bankCsvAmountColumn: bankCsvAmountColumn == null && nullToAbsent
          ? const Value.absent()
          : Value(bankCsvAmountColumn),
      bankCsvPurposeColumn: bankCsvPurposeColumn == null && nullToAbsent
          ? const Value.absent()
          : Value(bankCsvPurposeColumn),
      bankCsvCounterpartyColumn:
          bankCsvCounterpartyColumn == null && nullToAbsent
          ? const Value.absent()
          : Value(bankCsvCounterpartyColumn),
      bankCsvDateFormat: Value(bankCsvDateFormat),
      bankCsvDecimalSeparator: Value(bankCsvDecimalSeparator),
      datevBeraterNummer: datevBeraterNummer == null && nullToAbsent
          ? const Value.absent()
          : Value(datevBeraterNummer),
      datevMandantNummer: datevMandantNummer == null && nullToAbsent
          ? const Value.absent()
          : Value(datevMandantNummer),
      datevBankGegenkonto: datevBankGegenkonto == null && nullToAbsent
          ? const Value.absent()
          : Value(datevBankGegenkonto),
      datevSachkontenlaenge: Value(datevSachkontenlaenge),
      creditNotesEnabled: Value(creditNotesEnabled),
      pdfIntroTextCreditNote: pdfIntroTextCreditNote == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfIntroTextCreditNote),
      pdfClosingTextCreditNote: pdfClosingTextCreditNote == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfClosingTextCreditNote),
      isSmallBusinessExempt: Value(isSmallBusinessExempt),
    );
  }

  factory Company.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Company(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      address: serializer.fromJson<String?>(json['address']),
      taxNumber: serializer.fromJson<String?>(json['taxNumber']),
      vatId: serializer.fromJson<String?>(json['vatId']),
      iban: serializer.fromJson<String?>(json['iban']),
      email: serializer.fromJson<String?>(json['email']),
      phone: serializer.fromJson<String?>(json['phone']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      quotesEnabled: serializer.fromJson<bool>(json['quotesEnabled']),
      ordersEnabled: serializer.fromJson<bool>(json['ordersEnabled']),
      deliveryNotesEnabled: serializer.fromJson<bool>(
        json['deliveryNotesEnabled'],
      ),
      proformaEnabled: serializer.fromJson<bool>(json['proformaEnabled']),
      projectsEnabled: serializer.fromJson<bool>(json['projectsEnabled']),
      fleetEnabled: serializer.fromJson<bool>(json['fleetEnabled']),
      recurringInvoicesEnabled: serializer.fromJson<bool>(
        json['recurringInvoicesEnabled'],
      ),
      advancePaymentInvoicesEnabled: serializer.fromJson<bool>(
        json['advancePaymentInvoicesEnabled'],
      ),
      dunningEnabled: serializer.fromJson<bool>(json['dunningEnabled']),
      dunningReminder2AfterDays: serializer.fromJson<int>(
        json['dunningReminder2AfterDays'],
      ),
      dunningReminder3AfterDays: serializer.fromJson<int>(
        json['dunningReminder3AfterDays'],
      ),
      dunningFeeLevel1Cents: serializer.fromJson<int>(
        json['dunningFeeLevel1Cents'],
      ),
      dunningFeeLevel2Cents: serializer.fromJson<int>(
        json['dunningFeeLevel2Cents'],
      ),
      dunningFeeLevel3Cents: serializer.fromJson<int>(
        json['dunningFeeLevel3Cents'],
      ),
      dunningInterestRatePercent: serializer.fromJson<double>(
        json['dunningInterestRatePercent'],
      ),
      pdfIntroTextDunning: serializer.fromJson<String?>(
        json['pdfIntroTextDunning'],
      ),
      pdfClosingTextDunning: serializer.fromJson<String?>(
        json['pdfClosingTextDunning'],
      ),
      pdfIntroText: serializer.fromJson<String?>(json['pdfIntroText']),
      pdfClosingText: serializer.fromJson<String?>(json['pdfClosingText']),
      pdfIntroTextQuote: serializer.fromJson<String?>(
        json['pdfIntroTextQuote'],
      ),
      pdfClosingTextQuote: serializer.fromJson<String?>(
        json['pdfClosingTextQuote'],
      ),
      pdfIntroTextOrder: serializer.fromJson<String?>(
        json['pdfIntroTextOrder'],
      ),
      pdfClosingTextOrder: serializer.fromJson<String?>(
        json['pdfClosingTextOrder'],
      ),
      pdfIntroTextDeliveryNote: serializer.fromJson<String?>(
        json['pdfIntroTextDeliveryNote'],
      ),
      pdfClosingTextDeliveryNote: serializer.fromJson<String?>(
        json['pdfClosingTextDeliveryNote'],
      ),
      pdfIntroTextProforma: serializer.fromJson<String?>(
        json['pdfIntroTextProforma'],
      ),
      pdfClosingTextProforma: serializer.fromJson<String?>(
        json['pdfClosingTextProforma'],
      ),
      pdfFooterText: serializer.fromJson<String?>(json['pdfFooterText']),
      smtpEnabled: serializer.fromJson<bool>(json['smtpEnabled']),
      smtpHost: serializer.fromJson<String?>(json['smtpHost']),
      smtpPort: serializer.fromJson<int>(json['smtpPort']),
      smtpUsername: serializer.fromJson<String?>(json['smtpUsername']),
      smtpFromAddress: serializer.fromJson<String?>(json['smtpFromAddress']),
      smtpFromName: serializer.fromJson<String?>(json['smtpFromName']),
      smtpUseTls: serializer.fromJson<bool>(json['smtpUseTls']),
      smtpInvoiceSubjectTemplate: serializer.fromJson<String?>(
        json['smtpInvoiceSubjectTemplate'],
      ),
      smtpInvoiceBodyTemplate: serializer.fromJson<String?>(
        json['smtpInvoiceBodyTemplate'],
      ),
      smtpDunningSubjectTemplate: serializer.fromJson<String?>(
        json['smtpDunningSubjectTemplate'],
      ),
      smtpDunningBodyTemplate: serializer.fromJson<String?>(
        json['smtpDunningBodyTemplate'],
      ),
      buchhaltungEnabled: serializer.fromJson<bool>(json['buchhaltungEnabled']),
      bankCsvDelimiter: serializer.fromJson<String>(json['bankCsvDelimiter']),
      bankCsvHasHeaderRow: serializer.fromJson<bool>(
        json['bankCsvHasHeaderRow'],
      ),
      bankCsvDateColumn: serializer.fromJson<String?>(
        json['bankCsvDateColumn'],
      ),
      bankCsvAmountColumn: serializer.fromJson<String?>(
        json['bankCsvAmountColumn'],
      ),
      bankCsvPurposeColumn: serializer.fromJson<String?>(
        json['bankCsvPurposeColumn'],
      ),
      bankCsvCounterpartyColumn: serializer.fromJson<String?>(
        json['bankCsvCounterpartyColumn'],
      ),
      bankCsvDateFormat: serializer.fromJson<String>(json['bankCsvDateFormat']),
      bankCsvDecimalSeparator: serializer.fromJson<String>(
        json['bankCsvDecimalSeparator'],
      ),
      datevBeraterNummer: serializer.fromJson<String?>(
        json['datevBeraterNummer'],
      ),
      datevMandantNummer: serializer.fromJson<String?>(
        json['datevMandantNummer'],
      ),
      datevBankGegenkonto: serializer.fromJson<String?>(
        json['datevBankGegenkonto'],
      ),
      datevSachkontenlaenge: serializer.fromJson<int>(
        json['datevSachkontenlaenge'],
      ),
      creditNotesEnabled: serializer.fromJson<bool>(json['creditNotesEnabled']),
      pdfIntroTextCreditNote: serializer.fromJson<String?>(
        json['pdfIntroTextCreditNote'],
      ),
      pdfClosingTextCreditNote: serializer.fromJson<String?>(
        json['pdfClosingTextCreditNote'],
      ),
      isSmallBusinessExempt: serializer.fromJson<bool>(
        json['isSmallBusinessExempt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'address': serializer.toJson<String?>(address),
      'taxNumber': serializer.toJson<String?>(taxNumber),
      'vatId': serializer.toJson<String?>(vatId),
      'iban': serializer.toJson<String?>(iban),
      'email': serializer.toJson<String?>(email),
      'phone': serializer.toJson<String?>(phone),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'quotesEnabled': serializer.toJson<bool>(quotesEnabled),
      'ordersEnabled': serializer.toJson<bool>(ordersEnabled),
      'deliveryNotesEnabled': serializer.toJson<bool>(deliveryNotesEnabled),
      'proformaEnabled': serializer.toJson<bool>(proformaEnabled),
      'projectsEnabled': serializer.toJson<bool>(projectsEnabled),
      'fleetEnabled': serializer.toJson<bool>(fleetEnabled),
      'recurringInvoicesEnabled': serializer.toJson<bool>(
        recurringInvoicesEnabled,
      ),
      'advancePaymentInvoicesEnabled': serializer.toJson<bool>(
        advancePaymentInvoicesEnabled,
      ),
      'dunningEnabled': serializer.toJson<bool>(dunningEnabled),
      'dunningReminder2AfterDays': serializer.toJson<int>(
        dunningReminder2AfterDays,
      ),
      'dunningReminder3AfterDays': serializer.toJson<int>(
        dunningReminder3AfterDays,
      ),
      'dunningFeeLevel1Cents': serializer.toJson<int>(dunningFeeLevel1Cents),
      'dunningFeeLevel2Cents': serializer.toJson<int>(dunningFeeLevel2Cents),
      'dunningFeeLevel3Cents': serializer.toJson<int>(dunningFeeLevel3Cents),
      'dunningInterestRatePercent': serializer.toJson<double>(
        dunningInterestRatePercent,
      ),
      'pdfIntroTextDunning': serializer.toJson<String?>(pdfIntroTextDunning),
      'pdfClosingTextDunning': serializer.toJson<String?>(
        pdfClosingTextDunning,
      ),
      'pdfIntroText': serializer.toJson<String?>(pdfIntroText),
      'pdfClosingText': serializer.toJson<String?>(pdfClosingText),
      'pdfIntroTextQuote': serializer.toJson<String?>(pdfIntroTextQuote),
      'pdfClosingTextQuote': serializer.toJson<String?>(pdfClosingTextQuote),
      'pdfIntroTextOrder': serializer.toJson<String?>(pdfIntroTextOrder),
      'pdfClosingTextOrder': serializer.toJson<String?>(pdfClosingTextOrder),
      'pdfIntroTextDeliveryNote': serializer.toJson<String?>(
        pdfIntroTextDeliveryNote,
      ),
      'pdfClosingTextDeliveryNote': serializer.toJson<String?>(
        pdfClosingTextDeliveryNote,
      ),
      'pdfIntroTextProforma': serializer.toJson<String?>(pdfIntroTextProforma),
      'pdfClosingTextProforma': serializer.toJson<String?>(
        pdfClosingTextProforma,
      ),
      'pdfFooterText': serializer.toJson<String?>(pdfFooterText),
      'smtpEnabled': serializer.toJson<bool>(smtpEnabled),
      'smtpHost': serializer.toJson<String?>(smtpHost),
      'smtpPort': serializer.toJson<int>(smtpPort),
      'smtpUsername': serializer.toJson<String?>(smtpUsername),
      'smtpFromAddress': serializer.toJson<String?>(smtpFromAddress),
      'smtpFromName': serializer.toJson<String?>(smtpFromName),
      'smtpUseTls': serializer.toJson<bool>(smtpUseTls),
      'smtpInvoiceSubjectTemplate': serializer.toJson<String?>(
        smtpInvoiceSubjectTemplate,
      ),
      'smtpInvoiceBodyTemplate': serializer.toJson<String?>(
        smtpInvoiceBodyTemplate,
      ),
      'smtpDunningSubjectTemplate': serializer.toJson<String?>(
        smtpDunningSubjectTemplate,
      ),
      'smtpDunningBodyTemplate': serializer.toJson<String?>(
        smtpDunningBodyTemplate,
      ),
      'buchhaltungEnabled': serializer.toJson<bool>(buchhaltungEnabled),
      'bankCsvDelimiter': serializer.toJson<String>(bankCsvDelimiter),
      'bankCsvHasHeaderRow': serializer.toJson<bool>(bankCsvHasHeaderRow),
      'bankCsvDateColumn': serializer.toJson<String?>(bankCsvDateColumn),
      'bankCsvAmountColumn': serializer.toJson<String?>(bankCsvAmountColumn),
      'bankCsvPurposeColumn': serializer.toJson<String?>(bankCsvPurposeColumn),
      'bankCsvCounterpartyColumn': serializer.toJson<String?>(
        bankCsvCounterpartyColumn,
      ),
      'bankCsvDateFormat': serializer.toJson<String>(bankCsvDateFormat),
      'bankCsvDecimalSeparator': serializer.toJson<String>(
        bankCsvDecimalSeparator,
      ),
      'datevBeraterNummer': serializer.toJson<String?>(datevBeraterNummer),
      'datevMandantNummer': serializer.toJson<String?>(datevMandantNummer),
      'datevBankGegenkonto': serializer.toJson<String?>(datevBankGegenkonto),
      'datevSachkontenlaenge': serializer.toJson<int>(datevSachkontenlaenge),
      'creditNotesEnabled': serializer.toJson<bool>(creditNotesEnabled),
      'pdfIntroTextCreditNote': serializer.toJson<String?>(
        pdfIntroTextCreditNote,
      ),
      'pdfClosingTextCreditNote': serializer.toJson<String?>(
        pdfClosingTextCreditNote,
      ),
      'isSmallBusinessExempt': serializer.toJson<bool>(isSmallBusinessExempt),
    };
  }

  Company copyWith({
    String? id,
    String? name,
    Value<String?> address = const Value.absent(),
    Value<String?> taxNumber = const Value.absent(),
    Value<String?> vatId = const Value.absent(),
    Value<String?> iban = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    DateTime? createdAt,
    bool? quotesEnabled,
    bool? ordersEnabled,
    bool? deliveryNotesEnabled,
    bool? proformaEnabled,
    bool? projectsEnabled,
    bool? fleetEnabled,
    bool? recurringInvoicesEnabled,
    bool? advancePaymentInvoicesEnabled,
    bool? dunningEnabled,
    int? dunningReminder2AfterDays,
    int? dunningReminder3AfterDays,
    int? dunningFeeLevel1Cents,
    int? dunningFeeLevel2Cents,
    int? dunningFeeLevel3Cents,
    double? dunningInterestRatePercent,
    Value<String?> pdfIntroTextDunning = const Value.absent(),
    Value<String?> pdfClosingTextDunning = const Value.absent(),
    Value<String?> pdfIntroText = const Value.absent(),
    Value<String?> pdfClosingText = const Value.absent(),
    Value<String?> pdfIntroTextQuote = const Value.absent(),
    Value<String?> pdfClosingTextQuote = const Value.absent(),
    Value<String?> pdfIntroTextOrder = const Value.absent(),
    Value<String?> pdfClosingTextOrder = const Value.absent(),
    Value<String?> pdfIntroTextDeliveryNote = const Value.absent(),
    Value<String?> pdfClosingTextDeliveryNote = const Value.absent(),
    Value<String?> pdfIntroTextProforma = const Value.absent(),
    Value<String?> pdfClosingTextProforma = const Value.absent(),
    Value<String?> pdfFooterText = const Value.absent(),
    bool? smtpEnabled,
    Value<String?> smtpHost = const Value.absent(),
    int? smtpPort,
    Value<String?> smtpUsername = const Value.absent(),
    Value<String?> smtpFromAddress = const Value.absent(),
    Value<String?> smtpFromName = const Value.absent(),
    bool? smtpUseTls,
    Value<String?> smtpInvoiceSubjectTemplate = const Value.absent(),
    Value<String?> smtpInvoiceBodyTemplate = const Value.absent(),
    Value<String?> smtpDunningSubjectTemplate = const Value.absent(),
    Value<String?> smtpDunningBodyTemplate = const Value.absent(),
    bool? buchhaltungEnabled,
    String? bankCsvDelimiter,
    bool? bankCsvHasHeaderRow,
    Value<String?> bankCsvDateColumn = const Value.absent(),
    Value<String?> bankCsvAmountColumn = const Value.absent(),
    Value<String?> bankCsvPurposeColumn = const Value.absent(),
    Value<String?> bankCsvCounterpartyColumn = const Value.absent(),
    String? bankCsvDateFormat,
    String? bankCsvDecimalSeparator,
    Value<String?> datevBeraterNummer = const Value.absent(),
    Value<String?> datevMandantNummer = const Value.absent(),
    Value<String?> datevBankGegenkonto = const Value.absent(),
    int? datevSachkontenlaenge,
    bool? creditNotesEnabled,
    Value<String?> pdfIntroTextCreditNote = const Value.absent(),
    Value<String?> pdfClosingTextCreditNote = const Value.absent(),
    bool? isSmallBusinessExempt,
  }) => Company(
    id: id ?? this.id,
    name: name ?? this.name,
    address: address.present ? address.value : this.address,
    taxNumber: taxNumber.present ? taxNumber.value : this.taxNumber,
    vatId: vatId.present ? vatId.value : this.vatId,
    iban: iban.present ? iban.value : this.iban,
    email: email.present ? email.value : this.email,
    phone: phone.present ? phone.value : this.phone,
    createdAt: createdAt ?? this.createdAt,
    quotesEnabled: quotesEnabled ?? this.quotesEnabled,
    ordersEnabled: ordersEnabled ?? this.ordersEnabled,
    deliveryNotesEnabled: deliveryNotesEnabled ?? this.deliveryNotesEnabled,
    proformaEnabled: proformaEnabled ?? this.proformaEnabled,
    projectsEnabled: projectsEnabled ?? this.projectsEnabled,
    fleetEnabled: fleetEnabled ?? this.fleetEnabled,
    recurringInvoicesEnabled:
        recurringInvoicesEnabled ?? this.recurringInvoicesEnabled,
    advancePaymentInvoicesEnabled:
        advancePaymentInvoicesEnabled ?? this.advancePaymentInvoicesEnabled,
    dunningEnabled: dunningEnabled ?? this.dunningEnabled,
    dunningReminder2AfterDays:
        dunningReminder2AfterDays ?? this.dunningReminder2AfterDays,
    dunningReminder3AfterDays:
        dunningReminder3AfterDays ?? this.dunningReminder3AfterDays,
    dunningFeeLevel1Cents: dunningFeeLevel1Cents ?? this.dunningFeeLevel1Cents,
    dunningFeeLevel2Cents: dunningFeeLevel2Cents ?? this.dunningFeeLevel2Cents,
    dunningFeeLevel3Cents: dunningFeeLevel3Cents ?? this.dunningFeeLevel3Cents,
    dunningInterestRatePercent:
        dunningInterestRatePercent ?? this.dunningInterestRatePercent,
    pdfIntroTextDunning: pdfIntroTextDunning.present
        ? pdfIntroTextDunning.value
        : this.pdfIntroTextDunning,
    pdfClosingTextDunning: pdfClosingTextDunning.present
        ? pdfClosingTextDunning.value
        : this.pdfClosingTextDunning,
    pdfIntroText: pdfIntroText.present ? pdfIntroText.value : this.pdfIntroText,
    pdfClosingText: pdfClosingText.present
        ? pdfClosingText.value
        : this.pdfClosingText,
    pdfIntroTextQuote: pdfIntroTextQuote.present
        ? pdfIntroTextQuote.value
        : this.pdfIntroTextQuote,
    pdfClosingTextQuote: pdfClosingTextQuote.present
        ? pdfClosingTextQuote.value
        : this.pdfClosingTextQuote,
    pdfIntroTextOrder: pdfIntroTextOrder.present
        ? pdfIntroTextOrder.value
        : this.pdfIntroTextOrder,
    pdfClosingTextOrder: pdfClosingTextOrder.present
        ? pdfClosingTextOrder.value
        : this.pdfClosingTextOrder,
    pdfIntroTextDeliveryNote: pdfIntroTextDeliveryNote.present
        ? pdfIntroTextDeliveryNote.value
        : this.pdfIntroTextDeliveryNote,
    pdfClosingTextDeliveryNote: pdfClosingTextDeliveryNote.present
        ? pdfClosingTextDeliveryNote.value
        : this.pdfClosingTextDeliveryNote,
    pdfIntroTextProforma: pdfIntroTextProforma.present
        ? pdfIntroTextProforma.value
        : this.pdfIntroTextProforma,
    pdfClosingTextProforma: pdfClosingTextProforma.present
        ? pdfClosingTextProforma.value
        : this.pdfClosingTextProforma,
    pdfFooterText: pdfFooterText.present
        ? pdfFooterText.value
        : this.pdfFooterText,
    smtpEnabled: smtpEnabled ?? this.smtpEnabled,
    smtpHost: smtpHost.present ? smtpHost.value : this.smtpHost,
    smtpPort: smtpPort ?? this.smtpPort,
    smtpUsername: smtpUsername.present ? smtpUsername.value : this.smtpUsername,
    smtpFromAddress: smtpFromAddress.present
        ? smtpFromAddress.value
        : this.smtpFromAddress,
    smtpFromName: smtpFromName.present ? smtpFromName.value : this.smtpFromName,
    smtpUseTls: smtpUseTls ?? this.smtpUseTls,
    smtpInvoiceSubjectTemplate: smtpInvoiceSubjectTemplate.present
        ? smtpInvoiceSubjectTemplate.value
        : this.smtpInvoiceSubjectTemplate,
    smtpInvoiceBodyTemplate: smtpInvoiceBodyTemplate.present
        ? smtpInvoiceBodyTemplate.value
        : this.smtpInvoiceBodyTemplate,
    smtpDunningSubjectTemplate: smtpDunningSubjectTemplate.present
        ? smtpDunningSubjectTemplate.value
        : this.smtpDunningSubjectTemplate,
    smtpDunningBodyTemplate: smtpDunningBodyTemplate.present
        ? smtpDunningBodyTemplate.value
        : this.smtpDunningBodyTemplate,
    buchhaltungEnabled: buchhaltungEnabled ?? this.buchhaltungEnabled,
    bankCsvDelimiter: bankCsvDelimiter ?? this.bankCsvDelimiter,
    bankCsvHasHeaderRow: bankCsvHasHeaderRow ?? this.bankCsvHasHeaderRow,
    bankCsvDateColumn: bankCsvDateColumn.present
        ? bankCsvDateColumn.value
        : this.bankCsvDateColumn,
    bankCsvAmountColumn: bankCsvAmountColumn.present
        ? bankCsvAmountColumn.value
        : this.bankCsvAmountColumn,
    bankCsvPurposeColumn: bankCsvPurposeColumn.present
        ? bankCsvPurposeColumn.value
        : this.bankCsvPurposeColumn,
    bankCsvCounterpartyColumn: bankCsvCounterpartyColumn.present
        ? bankCsvCounterpartyColumn.value
        : this.bankCsvCounterpartyColumn,
    bankCsvDateFormat: bankCsvDateFormat ?? this.bankCsvDateFormat,
    bankCsvDecimalSeparator:
        bankCsvDecimalSeparator ?? this.bankCsvDecimalSeparator,
    datevBeraterNummer: datevBeraterNummer.present
        ? datevBeraterNummer.value
        : this.datevBeraterNummer,
    datevMandantNummer: datevMandantNummer.present
        ? datevMandantNummer.value
        : this.datevMandantNummer,
    datevBankGegenkonto: datevBankGegenkonto.present
        ? datevBankGegenkonto.value
        : this.datevBankGegenkonto,
    datevSachkontenlaenge: datevSachkontenlaenge ?? this.datevSachkontenlaenge,
    creditNotesEnabled: creditNotesEnabled ?? this.creditNotesEnabled,
    pdfIntroTextCreditNote: pdfIntroTextCreditNote.present
        ? pdfIntroTextCreditNote.value
        : this.pdfIntroTextCreditNote,
    pdfClosingTextCreditNote: pdfClosingTextCreditNote.present
        ? pdfClosingTextCreditNote.value
        : this.pdfClosingTextCreditNote,
    isSmallBusinessExempt: isSmallBusinessExempt ?? this.isSmallBusinessExempt,
  );
  Company copyWithCompanion(CompaniesCompanion data) {
    return Company(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      address: data.address.present ? data.address.value : this.address,
      taxNumber: data.taxNumber.present ? data.taxNumber.value : this.taxNumber,
      vatId: data.vatId.present ? data.vatId.value : this.vatId,
      iban: data.iban.present ? data.iban.value : this.iban,
      email: data.email.present ? data.email.value : this.email,
      phone: data.phone.present ? data.phone.value : this.phone,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      quotesEnabled: data.quotesEnabled.present
          ? data.quotesEnabled.value
          : this.quotesEnabled,
      ordersEnabled: data.ordersEnabled.present
          ? data.ordersEnabled.value
          : this.ordersEnabled,
      deliveryNotesEnabled: data.deliveryNotesEnabled.present
          ? data.deliveryNotesEnabled.value
          : this.deliveryNotesEnabled,
      proformaEnabled: data.proformaEnabled.present
          ? data.proformaEnabled.value
          : this.proformaEnabled,
      projectsEnabled: data.projectsEnabled.present
          ? data.projectsEnabled.value
          : this.projectsEnabled,
      fleetEnabled: data.fleetEnabled.present
          ? data.fleetEnabled.value
          : this.fleetEnabled,
      recurringInvoicesEnabled: data.recurringInvoicesEnabled.present
          ? data.recurringInvoicesEnabled.value
          : this.recurringInvoicesEnabled,
      advancePaymentInvoicesEnabled: data.advancePaymentInvoicesEnabled.present
          ? data.advancePaymentInvoicesEnabled.value
          : this.advancePaymentInvoicesEnabled,
      dunningEnabled: data.dunningEnabled.present
          ? data.dunningEnabled.value
          : this.dunningEnabled,
      dunningReminder2AfterDays: data.dunningReminder2AfterDays.present
          ? data.dunningReminder2AfterDays.value
          : this.dunningReminder2AfterDays,
      dunningReminder3AfterDays: data.dunningReminder3AfterDays.present
          ? data.dunningReminder3AfterDays.value
          : this.dunningReminder3AfterDays,
      dunningFeeLevel1Cents: data.dunningFeeLevel1Cents.present
          ? data.dunningFeeLevel1Cents.value
          : this.dunningFeeLevel1Cents,
      dunningFeeLevel2Cents: data.dunningFeeLevel2Cents.present
          ? data.dunningFeeLevel2Cents.value
          : this.dunningFeeLevel2Cents,
      dunningFeeLevel3Cents: data.dunningFeeLevel3Cents.present
          ? data.dunningFeeLevel3Cents.value
          : this.dunningFeeLevel3Cents,
      dunningInterestRatePercent: data.dunningInterestRatePercent.present
          ? data.dunningInterestRatePercent.value
          : this.dunningInterestRatePercent,
      pdfIntroTextDunning: data.pdfIntroTextDunning.present
          ? data.pdfIntroTextDunning.value
          : this.pdfIntroTextDunning,
      pdfClosingTextDunning: data.pdfClosingTextDunning.present
          ? data.pdfClosingTextDunning.value
          : this.pdfClosingTextDunning,
      pdfIntroText: data.pdfIntroText.present
          ? data.pdfIntroText.value
          : this.pdfIntroText,
      pdfClosingText: data.pdfClosingText.present
          ? data.pdfClosingText.value
          : this.pdfClosingText,
      pdfIntroTextQuote: data.pdfIntroTextQuote.present
          ? data.pdfIntroTextQuote.value
          : this.pdfIntroTextQuote,
      pdfClosingTextQuote: data.pdfClosingTextQuote.present
          ? data.pdfClosingTextQuote.value
          : this.pdfClosingTextQuote,
      pdfIntroTextOrder: data.pdfIntroTextOrder.present
          ? data.pdfIntroTextOrder.value
          : this.pdfIntroTextOrder,
      pdfClosingTextOrder: data.pdfClosingTextOrder.present
          ? data.pdfClosingTextOrder.value
          : this.pdfClosingTextOrder,
      pdfIntroTextDeliveryNote: data.pdfIntroTextDeliveryNote.present
          ? data.pdfIntroTextDeliveryNote.value
          : this.pdfIntroTextDeliveryNote,
      pdfClosingTextDeliveryNote: data.pdfClosingTextDeliveryNote.present
          ? data.pdfClosingTextDeliveryNote.value
          : this.pdfClosingTextDeliveryNote,
      pdfIntroTextProforma: data.pdfIntroTextProforma.present
          ? data.pdfIntroTextProforma.value
          : this.pdfIntroTextProforma,
      pdfClosingTextProforma: data.pdfClosingTextProforma.present
          ? data.pdfClosingTextProforma.value
          : this.pdfClosingTextProforma,
      pdfFooterText: data.pdfFooterText.present
          ? data.pdfFooterText.value
          : this.pdfFooterText,
      smtpEnabled: data.smtpEnabled.present
          ? data.smtpEnabled.value
          : this.smtpEnabled,
      smtpHost: data.smtpHost.present ? data.smtpHost.value : this.smtpHost,
      smtpPort: data.smtpPort.present ? data.smtpPort.value : this.smtpPort,
      smtpUsername: data.smtpUsername.present
          ? data.smtpUsername.value
          : this.smtpUsername,
      smtpFromAddress: data.smtpFromAddress.present
          ? data.smtpFromAddress.value
          : this.smtpFromAddress,
      smtpFromName: data.smtpFromName.present
          ? data.smtpFromName.value
          : this.smtpFromName,
      smtpUseTls: data.smtpUseTls.present
          ? data.smtpUseTls.value
          : this.smtpUseTls,
      smtpInvoiceSubjectTemplate: data.smtpInvoiceSubjectTemplate.present
          ? data.smtpInvoiceSubjectTemplate.value
          : this.smtpInvoiceSubjectTemplate,
      smtpInvoiceBodyTemplate: data.smtpInvoiceBodyTemplate.present
          ? data.smtpInvoiceBodyTemplate.value
          : this.smtpInvoiceBodyTemplate,
      smtpDunningSubjectTemplate: data.smtpDunningSubjectTemplate.present
          ? data.smtpDunningSubjectTemplate.value
          : this.smtpDunningSubjectTemplate,
      smtpDunningBodyTemplate: data.smtpDunningBodyTemplate.present
          ? data.smtpDunningBodyTemplate.value
          : this.smtpDunningBodyTemplate,
      buchhaltungEnabled: data.buchhaltungEnabled.present
          ? data.buchhaltungEnabled.value
          : this.buchhaltungEnabled,
      bankCsvDelimiter: data.bankCsvDelimiter.present
          ? data.bankCsvDelimiter.value
          : this.bankCsvDelimiter,
      bankCsvHasHeaderRow: data.bankCsvHasHeaderRow.present
          ? data.bankCsvHasHeaderRow.value
          : this.bankCsvHasHeaderRow,
      bankCsvDateColumn: data.bankCsvDateColumn.present
          ? data.bankCsvDateColumn.value
          : this.bankCsvDateColumn,
      bankCsvAmountColumn: data.bankCsvAmountColumn.present
          ? data.bankCsvAmountColumn.value
          : this.bankCsvAmountColumn,
      bankCsvPurposeColumn: data.bankCsvPurposeColumn.present
          ? data.bankCsvPurposeColumn.value
          : this.bankCsvPurposeColumn,
      bankCsvCounterpartyColumn: data.bankCsvCounterpartyColumn.present
          ? data.bankCsvCounterpartyColumn.value
          : this.bankCsvCounterpartyColumn,
      bankCsvDateFormat: data.bankCsvDateFormat.present
          ? data.bankCsvDateFormat.value
          : this.bankCsvDateFormat,
      bankCsvDecimalSeparator: data.bankCsvDecimalSeparator.present
          ? data.bankCsvDecimalSeparator.value
          : this.bankCsvDecimalSeparator,
      datevBeraterNummer: data.datevBeraterNummer.present
          ? data.datevBeraterNummer.value
          : this.datevBeraterNummer,
      datevMandantNummer: data.datevMandantNummer.present
          ? data.datevMandantNummer.value
          : this.datevMandantNummer,
      datevBankGegenkonto: data.datevBankGegenkonto.present
          ? data.datevBankGegenkonto.value
          : this.datevBankGegenkonto,
      datevSachkontenlaenge: data.datevSachkontenlaenge.present
          ? data.datevSachkontenlaenge.value
          : this.datevSachkontenlaenge,
      creditNotesEnabled: data.creditNotesEnabled.present
          ? data.creditNotesEnabled.value
          : this.creditNotesEnabled,
      pdfIntroTextCreditNote: data.pdfIntroTextCreditNote.present
          ? data.pdfIntroTextCreditNote.value
          : this.pdfIntroTextCreditNote,
      pdfClosingTextCreditNote: data.pdfClosingTextCreditNote.present
          ? data.pdfClosingTextCreditNote.value
          : this.pdfClosingTextCreditNote,
      isSmallBusinessExempt: data.isSmallBusinessExempt.present
          ? data.isSmallBusinessExempt.value
          : this.isSmallBusinessExempt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Company(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('taxNumber: $taxNumber, ')
          ..write('vatId: $vatId, ')
          ..write('iban: $iban, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('createdAt: $createdAt, ')
          ..write('quotesEnabled: $quotesEnabled, ')
          ..write('ordersEnabled: $ordersEnabled, ')
          ..write('deliveryNotesEnabled: $deliveryNotesEnabled, ')
          ..write('proformaEnabled: $proformaEnabled, ')
          ..write('projectsEnabled: $projectsEnabled, ')
          ..write('fleetEnabled: $fleetEnabled, ')
          ..write('recurringInvoicesEnabled: $recurringInvoicesEnabled, ')
          ..write(
            'advancePaymentInvoicesEnabled: $advancePaymentInvoicesEnabled, ',
          )
          ..write('dunningEnabled: $dunningEnabled, ')
          ..write('dunningReminder2AfterDays: $dunningReminder2AfterDays, ')
          ..write('dunningReminder3AfterDays: $dunningReminder3AfterDays, ')
          ..write('dunningFeeLevel1Cents: $dunningFeeLevel1Cents, ')
          ..write('dunningFeeLevel2Cents: $dunningFeeLevel2Cents, ')
          ..write('dunningFeeLevel3Cents: $dunningFeeLevel3Cents, ')
          ..write('dunningInterestRatePercent: $dunningInterestRatePercent, ')
          ..write('pdfIntroTextDunning: $pdfIntroTextDunning, ')
          ..write('pdfClosingTextDunning: $pdfClosingTextDunning, ')
          ..write('pdfIntroText: $pdfIntroText, ')
          ..write('pdfClosingText: $pdfClosingText, ')
          ..write('pdfIntroTextQuote: $pdfIntroTextQuote, ')
          ..write('pdfClosingTextQuote: $pdfClosingTextQuote, ')
          ..write('pdfIntroTextOrder: $pdfIntroTextOrder, ')
          ..write('pdfClosingTextOrder: $pdfClosingTextOrder, ')
          ..write('pdfIntroTextDeliveryNote: $pdfIntroTextDeliveryNote, ')
          ..write('pdfClosingTextDeliveryNote: $pdfClosingTextDeliveryNote, ')
          ..write('pdfIntroTextProforma: $pdfIntroTextProforma, ')
          ..write('pdfClosingTextProforma: $pdfClosingTextProforma, ')
          ..write('pdfFooterText: $pdfFooterText, ')
          ..write('smtpEnabled: $smtpEnabled, ')
          ..write('smtpHost: $smtpHost, ')
          ..write('smtpPort: $smtpPort, ')
          ..write('smtpUsername: $smtpUsername, ')
          ..write('smtpFromAddress: $smtpFromAddress, ')
          ..write('smtpFromName: $smtpFromName, ')
          ..write('smtpUseTls: $smtpUseTls, ')
          ..write('smtpInvoiceSubjectTemplate: $smtpInvoiceSubjectTemplate, ')
          ..write('smtpInvoiceBodyTemplate: $smtpInvoiceBodyTemplate, ')
          ..write('smtpDunningSubjectTemplate: $smtpDunningSubjectTemplate, ')
          ..write('smtpDunningBodyTemplate: $smtpDunningBodyTemplate, ')
          ..write('buchhaltungEnabled: $buchhaltungEnabled, ')
          ..write('bankCsvDelimiter: $bankCsvDelimiter, ')
          ..write('bankCsvHasHeaderRow: $bankCsvHasHeaderRow, ')
          ..write('bankCsvDateColumn: $bankCsvDateColumn, ')
          ..write('bankCsvAmountColumn: $bankCsvAmountColumn, ')
          ..write('bankCsvPurposeColumn: $bankCsvPurposeColumn, ')
          ..write('bankCsvCounterpartyColumn: $bankCsvCounterpartyColumn, ')
          ..write('bankCsvDateFormat: $bankCsvDateFormat, ')
          ..write('bankCsvDecimalSeparator: $bankCsvDecimalSeparator, ')
          ..write('datevBeraterNummer: $datevBeraterNummer, ')
          ..write('datevMandantNummer: $datevMandantNummer, ')
          ..write('datevBankGegenkonto: $datevBankGegenkonto, ')
          ..write('datevSachkontenlaenge: $datevSachkontenlaenge, ')
          ..write('creditNotesEnabled: $creditNotesEnabled, ')
          ..write('pdfIntroTextCreditNote: $pdfIntroTextCreditNote, ')
          ..write('pdfClosingTextCreditNote: $pdfClosingTextCreditNote, ')
          ..write('isSmallBusinessExempt: $isSmallBusinessExempt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    address,
    taxNumber,
    vatId,
    iban,
    email,
    phone,
    createdAt,
    quotesEnabled,
    ordersEnabled,
    deliveryNotesEnabled,
    proformaEnabled,
    projectsEnabled,
    fleetEnabled,
    recurringInvoicesEnabled,
    advancePaymentInvoicesEnabled,
    dunningEnabled,
    dunningReminder2AfterDays,
    dunningReminder3AfterDays,
    dunningFeeLevel1Cents,
    dunningFeeLevel2Cents,
    dunningFeeLevel3Cents,
    dunningInterestRatePercent,
    pdfIntroTextDunning,
    pdfClosingTextDunning,
    pdfIntroText,
    pdfClosingText,
    pdfIntroTextQuote,
    pdfClosingTextQuote,
    pdfIntroTextOrder,
    pdfClosingTextOrder,
    pdfIntroTextDeliveryNote,
    pdfClosingTextDeliveryNote,
    pdfIntroTextProforma,
    pdfClosingTextProforma,
    pdfFooterText,
    smtpEnabled,
    smtpHost,
    smtpPort,
    smtpUsername,
    smtpFromAddress,
    smtpFromName,
    smtpUseTls,
    smtpInvoiceSubjectTemplate,
    smtpInvoiceBodyTemplate,
    smtpDunningSubjectTemplate,
    smtpDunningBodyTemplate,
    buchhaltungEnabled,
    bankCsvDelimiter,
    bankCsvHasHeaderRow,
    bankCsvDateColumn,
    bankCsvAmountColumn,
    bankCsvPurposeColumn,
    bankCsvCounterpartyColumn,
    bankCsvDateFormat,
    bankCsvDecimalSeparator,
    datevBeraterNummer,
    datevMandantNummer,
    datevBankGegenkonto,
    datevSachkontenlaenge,
    creditNotesEnabled,
    pdfIntroTextCreditNote,
    pdfClosingTextCreditNote,
    isSmallBusinessExempt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Company &&
          other.id == this.id &&
          other.name == this.name &&
          other.address == this.address &&
          other.taxNumber == this.taxNumber &&
          other.vatId == this.vatId &&
          other.iban == this.iban &&
          other.email == this.email &&
          other.phone == this.phone &&
          other.createdAt == this.createdAt &&
          other.quotesEnabled == this.quotesEnabled &&
          other.ordersEnabled == this.ordersEnabled &&
          other.deliveryNotesEnabled == this.deliveryNotesEnabled &&
          other.proformaEnabled == this.proformaEnabled &&
          other.projectsEnabled == this.projectsEnabled &&
          other.fleetEnabled == this.fleetEnabled &&
          other.recurringInvoicesEnabled == this.recurringInvoicesEnabled &&
          other.advancePaymentInvoicesEnabled ==
              this.advancePaymentInvoicesEnabled &&
          other.dunningEnabled == this.dunningEnabled &&
          other.dunningReminder2AfterDays == this.dunningReminder2AfterDays &&
          other.dunningReminder3AfterDays == this.dunningReminder3AfterDays &&
          other.dunningFeeLevel1Cents == this.dunningFeeLevel1Cents &&
          other.dunningFeeLevel2Cents == this.dunningFeeLevel2Cents &&
          other.dunningFeeLevel3Cents == this.dunningFeeLevel3Cents &&
          other.dunningInterestRatePercent == this.dunningInterestRatePercent &&
          other.pdfIntroTextDunning == this.pdfIntroTextDunning &&
          other.pdfClosingTextDunning == this.pdfClosingTextDunning &&
          other.pdfIntroText == this.pdfIntroText &&
          other.pdfClosingText == this.pdfClosingText &&
          other.pdfIntroTextQuote == this.pdfIntroTextQuote &&
          other.pdfClosingTextQuote == this.pdfClosingTextQuote &&
          other.pdfIntroTextOrder == this.pdfIntroTextOrder &&
          other.pdfClosingTextOrder == this.pdfClosingTextOrder &&
          other.pdfIntroTextDeliveryNote == this.pdfIntroTextDeliveryNote &&
          other.pdfClosingTextDeliveryNote == this.pdfClosingTextDeliveryNote &&
          other.pdfIntroTextProforma == this.pdfIntroTextProforma &&
          other.pdfClosingTextProforma == this.pdfClosingTextProforma &&
          other.pdfFooterText == this.pdfFooterText &&
          other.smtpEnabled == this.smtpEnabled &&
          other.smtpHost == this.smtpHost &&
          other.smtpPort == this.smtpPort &&
          other.smtpUsername == this.smtpUsername &&
          other.smtpFromAddress == this.smtpFromAddress &&
          other.smtpFromName == this.smtpFromName &&
          other.smtpUseTls == this.smtpUseTls &&
          other.smtpInvoiceSubjectTemplate == this.smtpInvoiceSubjectTemplate &&
          other.smtpInvoiceBodyTemplate == this.smtpInvoiceBodyTemplate &&
          other.smtpDunningSubjectTemplate == this.smtpDunningSubjectTemplate &&
          other.smtpDunningBodyTemplate == this.smtpDunningBodyTemplate &&
          other.buchhaltungEnabled == this.buchhaltungEnabled &&
          other.bankCsvDelimiter == this.bankCsvDelimiter &&
          other.bankCsvHasHeaderRow == this.bankCsvHasHeaderRow &&
          other.bankCsvDateColumn == this.bankCsvDateColumn &&
          other.bankCsvAmountColumn == this.bankCsvAmountColumn &&
          other.bankCsvPurposeColumn == this.bankCsvPurposeColumn &&
          other.bankCsvCounterpartyColumn == this.bankCsvCounterpartyColumn &&
          other.bankCsvDateFormat == this.bankCsvDateFormat &&
          other.bankCsvDecimalSeparator == this.bankCsvDecimalSeparator &&
          other.datevBeraterNummer == this.datevBeraterNummer &&
          other.datevMandantNummer == this.datevMandantNummer &&
          other.datevBankGegenkonto == this.datevBankGegenkonto &&
          other.datevSachkontenlaenge == this.datevSachkontenlaenge &&
          other.creditNotesEnabled == this.creditNotesEnabled &&
          other.pdfIntroTextCreditNote == this.pdfIntroTextCreditNote &&
          other.pdfClosingTextCreditNote == this.pdfClosingTextCreditNote &&
          other.isSmallBusinessExempt == this.isSmallBusinessExempt);
}

class CompaniesCompanion extends UpdateCompanion<Company> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> address;
  final Value<String?> taxNumber;
  final Value<String?> vatId;
  final Value<String?> iban;
  final Value<String?> email;
  final Value<String?> phone;
  final Value<DateTime> createdAt;
  final Value<bool> quotesEnabled;
  final Value<bool> ordersEnabled;
  final Value<bool> deliveryNotesEnabled;
  final Value<bool> proformaEnabled;
  final Value<bool> projectsEnabled;
  final Value<bool> fleetEnabled;
  final Value<bool> recurringInvoicesEnabled;
  final Value<bool> advancePaymentInvoicesEnabled;
  final Value<bool> dunningEnabled;
  final Value<int> dunningReminder2AfterDays;
  final Value<int> dunningReminder3AfterDays;
  final Value<int> dunningFeeLevel1Cents;
  final Value<int> dunningFeeLevel2Cents;
  final Value<int> dunningFeeLevel3Cents;
  final Value<double> dunningInterestRatePercent;
  final Value<String?> pdfIntroTextDunning;
  final Value<String?> pdfClosingTextDunning;
  final Value<String?> pdfIntroText;
  final Value<String?> pdfClosingText;
  final Value<String?> pdfIntroTextQuote;
  final Value<String?> pdfClosingTextQuote;
  final Value<String?> pdfIntroTextOrder;
  final Value<String?> pdfClosingTextOrder;
  final Value<String?> pdfIntroTextDeliveryNote;
  final Value<String?> pdfClosingTextDeliveryNote;
  final Value<String?> pdfIntroTextProforma;
  final Value<String?> pdfClosingTextProforma;
  final Value<String?> pdfFooterText;
  final Value<bool> smtpEnabled;
  final Value<String?> smtpHost;
  final Value<int> smtpPort;
  final Value<String?> smtpUsername;
  final Value<String?> smtpFromAddress;
  final Value<String?> smtpFromName;
  final Value<bool> smtpUseTls;
  final Value<String?> smtpInvoiceSubjectTemplate;
  final Value<String?> smtpInvoiceBodyTemplate;
  final Value<String?> smtpDunningSubjectTemplate;
  final Value<String?> smtpDunningBodyTemplate;
  final Value<bool> buchhaltungEnabled;
  final Value<String> bankCsvDelimiter;
  final Value<bool> bankCsvHasHeaderRow;
  final Value<String?> bankCsvDateColumn;
  final Value<String?> bankCsvAmountColumn;
  final Value<String?> bankCsvPurposeColumn;
  final Value<String?> bankCsvCounterpartyColumn;
  final Value<String> bankCsvDateFormat;
  final Value<String> bankCsvDecimalSeparator;
  final Value<String?> datevBeraterNummer;
  final Value<String?> datevMandantNummer;
  final Value<String?> datevBankGegenkonto;
  final Value<int> datevSachkontenlaenge;
  final Value<bool> creditNotesEnabled;
  final Value<String?> pdfIntroTextCreditNote;
  final Value<String?> pdfClosingTextCreditNote;
  final Value<bool> isSmallBusinessExempt;
  final Value<int> rowid;
  const CompaniesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.taxNumber = const Value.absent(),
    this.vatId = const Value.absent(),
    this.iban = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.quotesEnabled = const Value.absent(),
    this.ordersEnabled = const Value.absent(),
    this.deliveryNotesEnabled = const Value.absent(),
    this.proformaEnabled = const Value.absent(),
    this.projectsEnabled = const Value.absent(),
    this.fleetEnabled = const Value.absent(),
    this.recurringInvoicesEnabled = const Value.absent(),
    this.advancePaymentInvoicesEnabled = const Value.absent(),
    this.dunningEnabled = const Value.absent(),
    this.dunningReminder2AfterDays = const Value.absent(),
    this.dunningReminder3AfterDays = const Value.absent(),
    this.dunningFeeLevel1Cents = const Value.absent(),
    this.dunningFeeLevel2Cents = const Value.absent(),
    this.dunningFeeLevel3Cents = const Value.absent(),
    this.dunningInterestRatePercent = const Value.absent(),
    this.pdfIntroTextDunning = const Value.absent(),
    this.pdfClosingTextDunning = const Value.absent(),
    this.pdfIntroText = const Value.absent(),
    this.pdfClosingText = const Value.absent(),
    this.pdfIntroTextQuote = const Value.absent(),
    this.pdfClosingTextQuote = const Value.absent(),
    this.pdfIntroTextOrder = const Value.absent(),
    this.pdfClosingTextOrder = const Value.absent(),
    this.pdfIntroTextDeliveryNote = const Value.absent(),
    this.pdfClosingTextDeliveryNote = const Value.absent(),
    this.pdfIntroTextProforma = const Value.absent(),
    this.pdfClosingTextProforma = const Value.absent(),
    this.pdfFooterText = const Value.absent(),
    this.smtpEnabled = const Value.absent(),
    this.smtpHost = const Value.absent(),
    this.smtpPort = const Value.absent(),
    this.smtpUsername = const Value.absent(),
    this.smtpFromAddress = const Value.absent(),
    this.smtpFromName = const Value.absent(),
    this.smtpUseTls = const Value.absent(),
    this.smtpInvoiceSubjectTemplate = const Value.absent(),
    this.smtpInvoiceBodyTemplate = const Value.absent(),
    this.smtpDunningSubjectTemplate = const Value.absent(),
    this.smtpDunningBodyTemplate = const Value.absent(),
    this.buchhaltungEnabled = const Value.absent(),
    this.bankCsvDelimiter = const Value.absent(),
    this.bankCsvHasHeaderRow = const Value.absent(),
    this.bankCsvDateColumn = const Value.absent(),
    this.bankCsvAmountColumn = const Value.absent(),
    this.bankCsvPurposeColumn = const Value.absent(),
    this.bankCsvCounterpartyColumn = const Value.absent(),
    this.bankCsvDateFormat = const Value.absent(),
    this.bankCsvDecimalSeparator = const Value.absent(),
    this.datevBeraterNummer = const Value.absent(),
    this.datevMandantNummer = const Value.absent(),
    this.datevBankGegenkonto = const Value.absent(),
    this.datevSachkontenlaenge = const Value.absent(),
    this.creditNotesEnabled = const Value.absent(),
    this.pdfIntroTextCreditNote = const Value.absent(),
    this.pdfClosingTextCreditNote = const Value.absent(),
    this.isSmallBusinessExempt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompaniesCompanion.insert({
    required String id,
    required String name,
    this.address = const Value.absent(),
    this.taxNumber = const Value.absent(),
    this.vatId = const Value.absent(),
    this.iban = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    required DateTime createdAt,
    this.quotesEnabled = const Value.absent(),
    this.ordersEnabled = const Value.absent(),
    this.deliveryNotesEnabled = const Value.absent(),
    this.proformaEnabled = const Value.absent(),
    this.projectsEnabled = const Value.absent(),
    this.fleetEnabled = const Value.absent(),
    this.recurringInvoicesEnabled = const Value.absent(),
    this.advancePaymentInvoicesEnabled = const Value.absent(),
    this.dunningEnabled = const Value.absent(),
    this.dunningReminder2AfterDays = const Value.absent(),
    this.dunningReminder3AfterDays = const Value.absent(),
    this.dunningFeeLevel1Cents = const Value.absent(),
    this.dunningFeeLevel2Cents = const Value.absent(),
    this.dunningFeeLevel3Cents = const Value.absent(),
    this.dunningInterestRatePercent = const Value.absent(),
    this.pdfIntroTextDunning = const Value.absent(),
    this.pdfClosingTextDunning = const Value.absent(),
    this.pdfIntroText = const Value.absent(),
    this.pdfClosingText = const Value.absent(),
    this.pdfIntroTextQuote = const Value.absent(),
    this.pdfClosingTextQuote = const Value.absent(),
    this.pdfIntroTextOrder = const Value.absent(),
    this.pdfClosingTextOrder = const Value.absent(),
    this.pdfIntroTextDeliveryNote = const Value.absent(),
    this.pdfClosingTextDeliveryNote = const Value.absent(),
    this.pdfIntroTextProforma = const Value.absent(),
    this.pdfClosingTextProforma = const Value.absent(),
    this.pdfFooterText = const Value.absent(),
    this.smtpEnabled = const Value.absent(),
    this.smtpHost = const Value.absent(),
    this.smtpPort = const Value.absent(),
    this.smtpUsername = const Value.absent(),
    this.smtpFromAddress = const Value.absent(),
    this.smtpFromName = const Value.absent(),
    this.smtpUseTls = const Value.absent(),
    this.smtpInvoiceSubjectTemplate = const Value.absent(),
    this.smtpInvoiceBodyTemplate = const Value.absent(),
    this.smtpDunningSubjectTemplate = const Value.absent(),
    this.smtpDunningBodyTemplate = const Value.absent(),
    this.buchhaltungEnabled = const Value.absent(),
    this.bankCsvDelimiter = const Value.absent(),
    this.bankCsvHasHeaderRow = const Value.absent(),
    this.bankCsvDateColumn = const Value.absent(),
    this.bankCsvAmountColumn = const Value.absent(),
    this.bankCsvPurposeColumn = const Value.absent(),
    this.bankCsvCounterpartyColumn = const Value.absent(),
    this.bankCsvDateFormat = const Value.absent(),
    this.bankCsvDecimalSeparator = const Value.absent(),
    this.datevBeraterNummer = const Value.absent(),
    this.datevMandantNummer = const Value.absent(),
    this.datevBankGegenkonto = const Value.absent(),
    this.datevSachkontenlaenge = const Value.absent(),
    this.creditNotesEnabled = const Value.absent(),
    this.pdfIntroTextCreditNote = const Value.absent(),
    this.pdfClosingTextCreditNote = const Value.absent(),
    this.isSmallBusinessExempt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Company> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? address,
    Expression<String>? taxNumber,
    Expression<String>? vatId,
    Expression<String>? iban,
    Expression<String>? email,
    Expression<String>? phone,
    Expression<DateTime>? createdAt,
    Expression<bool>? quotesEnabled,
    Expression<bool>? ordersEnabled,
    Expression<bool>? deliveryNotesEnabled,
    Expression<bool>? proformaEnabled,
    Expression<bool>? projectsEnabled,
    Expression<bool>? fleetEnabled,
    Expression<bool>? recurringInvoicesEnabled,
    Expression<bool>? advancePaymentInvoicesEnabled,
    Expression<bool>? dunningEnabled,
    Expression<int>? dunningReminder2AfterDays,
    Expression<int>? dunningReminder3AfterDays,
    Expression<int>? dunningFeeLevel1Cents,
    Expression<int>? dunningFeeLevel2Cents,
    Expression<int>? dunningFeeLevel3Cents,
    Expression<double>? dunningInterestRatePercent,
    Expression<String>? pdfIntroTextDunning,
    Expression<String>? pdfClosingTextDunning,
    Expression<String>? pdfIntroText,
    Expression<String>? pdfClosingText,
    Expression<String>? pdfIntroTextQuote,
    Expression<String>? pdfClosingTextQuote,
    Expression<String>? pdfIntroTextOrder,
    Expression<String>? pdfClosingTextOrder,
    Expression<String>? pdfIntroTextDeliveryNote,
    Expression<String>? pdfClosingTextDeliveryNote,
    Expression<String>? pdfIntroTextProforma,
    Expression<String>? pdfClosingTextProforma,
    Expression<String>? pdfFooterText,
    Expression<bool>? smtpEnabled,
    Expression<String>? smtpHost,
    Expression<int>? smtpPort,
    Expression<String>? smtpUsername,
    Expression<String>? smtpFromAddress,
    Expression<String>? smtpFromName,
    Expression<bool>? smtpUseTls,
    Expression<String>? smtpInvoiceSubjectTemplate,
    Expression<String>? smtpInvoiceBodyTemplate,
    Expression<String>? smtpDunningSubjectTemplate,
    Expression<String>? smtpDunningBodyTemplate,
    Expression<bool>? buchhaltungEnabled,
    Expression<String>? bankCsvDelimiter,
    Expression<bool>? bankCsvHasHeaderRow,
    Expression<String>? bankCsvDateColumn,
    Expression<String>? bankCsvAmountColumn,
    Expression<String>? bankCsvPurposeColumn,
    Expression<String>? bankCsvCounterpartyColumn,
    Expression<String>? bankCsvDateFormat,
    Expression<String>? bankCsvDecimalSeparator,
    Expression<String>? datevBeraterNummer,
    Expression<String>? datevMandantNummer,
    Expression<String>? datevBankGegenkonto,
    Expression<int>? datevSachkontenlaenge,
    Expression<bool>? creditNotesEnabled,
    Expression<String>? pdfIntroTextCreditNote,
    Expression<String>? pdfClosingTextCreditNote,
    Expression<bool>? isSmallBusinessExempt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (taxNumber != null) 'tax_number': taxNumber,
      if (vatId != null) 'vat_id': vatId,
      if (iban != null) 'iban': iban,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (createdAt != null) 'created_at': createdAt,
      if (quotesEnabled != null) 'quotes_enabled': quotesEnabled,
      if (ordersEnabled != null) 'orders_enabled': ordersEnabled,
      if (deliveryNotesEnabled != null)
        'delivery_notes_enabled': deliveryNotesEnabled,
      if (proformaEnabled != null) 'proforma_enabled': proformaEnabled,
      if (projectsEnabled != null) 'projects_enabled': projectsEnabled,
      if (fleetEnabled != null) 'fleet_enabled': fleetEnabled,
      if (recurringInvoicesEnabled != null)
        'recurring_invoices_enabled': recurringInvoicesEnabled,
      if (advancePaymentInvoicesEnabled != null)
        'advance_payment_invoices_enabled': advancePaymentInvoicesEnabled,
      if (dunningEnabled != null) 'dunning_enabled': dunningEnabled,
      if (dunningReminder2AfterDays != null)
        'dunning_reminder2_after_days': dunningReminder2AfterDays,
      if (dunningReminder3AfterDays != null)
        'dunning_reminder3_after_days': dunningReminder3AfterDays,
      if (dunningFeeLevel1Cents != null)
        'dunning_fee_level1_cents': dunningFeeLevel1Cents,
      if (dunningFeeLevel2Cents != null)
        'dunning_fee_level2_cents': dunningFeeLevel2Cents,
      if (dunningFeeLevel3Cents != null)
        'dunning_fee_level3_cents': dunningFeeLevel3Cents,
      if (dunningInterestRatePercent != null)
        'dunning_interest_rate_percent': dunningInterestRatePercent,
      if (pdfIntroTextDunning != null)
        'pdf_intro_text_dunning': pdfIntroTextDunning,
      if (pdfClosingTextDunning != null)
        'pdf_closing_text_dunning': pdfClosingTextDunning,
      if (pdfIntroText != null) 'pdf_intro_text': pdfIntroText,
      if (pdfClosingText != null) 'pdf_closing_text': pdfClosingText,
      if (pdfIntroTextQuote != null) 'pdf_intro_text_quote': pdfIntroTextQuote,
      if (pdfClosingTextQuote != null)
        'pdf_closing_text_quote': pdfClosingTextQuote,
      if (pdfIntroTextOrder != null) 'pdf_intro_text_order': pdfIntroTextOrder,
      if (pdfClosingTextOrder != null)
        'pdf_closing_text_order': pdfClosingTextOrder,
      if (pdfIntroTextDeliveryNote != null)
        'pdf_intro_text_delivery_note': pdfIntroTextDeliveryNote,
      if (pdfClosingTextDeliveryNote != null)
        'pdf_closing_text_delivery_note': pdfClosingTextDeliveryNote,
      if (pdfIntroTextProforma != null)
        'pdf_intro_text_proforma': pdfIntroTextProforma,
      if (pdfClosingTextProforma != null)
        'pdf_closing_text_proforma': pdfClosingTextProforma,
      if (pdfFooterText != null) 'pdf_footer_text': pdfFooterText,
      if (smtpEnabled != null) 'smtp_enabled': smtpEnabled,
      if (smtpHost != null) 'smtp_host': smtpHost,
      if (smtpPort != null) 'smtp_port': smtpPort,
      if (smtpUsername != null) 'smtp_username': smtpUsername,
      if (smtpFromAddress != null) 'smtp_from_address': smtpFromAddress,
      if (smtpFromName != null) 'smtp_from_name': smtpFromName,
      if (smtpUseTls != null) 'smtp_use_tls': smtpUseTls,
      if (smtpInvoiceSubjectTemplate != null)
        'smtp_invoice_subject_template': smtpInvoiceSubjectTemplate,
      if (smtpInvoiceBodyTemplate != null)
        'smtp_invoice_body_template': smtpInvoiceBodyTemplate,
      if (smtpDunningSubjectTemplate != null)
        'smtp_dunning_subject_template': smtpDunningSubjectTemplate,
      if (smtpDunningBodyTemplate != null)
        'smtp_dunning_body_template': smtpDunningBodyTemplate,
      if (buchhaltungEnabled != null) 'buchhaltung_enabled': buchhaltungEnabled,
      if (bankCsvDelimiter != null) 'bank_csv_delimiter': bankCsvDelimiter,
      if (bankCsvHasHeaderRow != null)
        'bank_csv_has_header_row': bankCsvHasHeaderRow,
      if (bankCsvDateColumn != null) 'bank_csv_date_column': bankCsvDateColumn,
      if (bankCsvAmountColumn != null)
        'bank_csv_amount_column': bankCsvAmountColumn,
      if (bankCsvPurposeColumn != null)
        'bank_csv_purpose_column': bankCsvPurposeColumn,
      if (bankCsvCounterpartyColumn != null)
        'bank_csv_counterparty_column': bankCsvCounterpartyColumn,
      if (bankCsvDateFormat != null) 'bank_csv_date_format': bankCsvDateFormat,
      if (bankCsvDecimalSeparator != null)
        'bank_csv_decimal_separator': bankCsvDecimalSeparator,
      if (datevBeraterNummer != null)
        'datev_berater_nummer': datevBeraterNummer,
      if (datevMandantNummer != null)
        'datev_mandant_nummer': datevMandantNummer,
      if (datevBankGegenkonto != null)
        'datev_bank_gegenkonto': datevBankGegenkonto,
      if (datevSachkontenlaenge != null)
        'datev_sachkontenlaenge': datevSachkontenlaenge,
      if (creditNotesEnabled != null)
        'credit_notes_enabled': creditNotesEnabled,
      if (pdfIntroTextCreditNote != null)
        'pdf_intro_text_credit_note': pdfIntroTextCreditNote,
      if (pdfClosingTextCreditNote != null)
        'pdf_closing_text_credit_note': pdfClosingTextCreditNote,
      if (isSmallBusinessExempt != null)
        'is_small_business_exempt': isSmallBusinessExempt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompaniesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? address,
    Value<String?>? taxNumber,
    Value<String?>? vatId,
    Value<String?>? iban,
    Value<String?>? email,
    Value<String?>? phone,
    Value<DateTime>? createdAt,
    Value<bool>? quotesEnabled,
    Value<bool>? ordersEnabled,
    Value<bool>? deliveryNotesEnabled,
    Value<bool>? proformaEnabled,
    Value<bool>? projectsEnabled,
    Value<bool>? fleetEnabled,
    Value<bool>? recurringInvoicesEnabled,
    Value<bool>? advancePaymentInvoicesEnabled,
    Value<bool>? dunningEnabled,
    Value<int>? dunningReminder2AfterDays,
    Value<int>? dunningReminder3AfterDays,
    Value<int>? dunningFeeLevel1Cents,
    Value<int>? dunningFeeLevel2Cents,
    Value<int>? dunningFeeLevel3Cents,
    Value<double>? dunningInterestRatePercent,
    Value<String?>? pdfIntroTextDunning,
    Value<String?>? pdfClosingTextDunning,
    Value<String?>? pdfIntroText,
    Value<String?>? pdfClosingText,
    Value<String?>? pdfIntroTextQuote,
    Value<String?>? pdfClosingTextQuote,
    Value<String?>? pdfIntroTextOrder,
    Value<String?>? pdfClosingTextOrder,
    Value<String?>? pdfIntroTextDeliveryNote,
    Value<String?>? pdfClosingTextDeliveryNote,
    Value<String?>? pdfIntroTextProforma,
    Value<String?>? pdfClosingTextProforma,
    Value<String?>? pdfFooterText,
    Value<bool>? smtpEnabled,
    Value<String?>? smtpHost,
    Value<int>? smtpPort,
    Value<String?>? smtpUsername,
    Value<String?>? smtpFromAddress,
    Value<String?>? smtpFromName,
    Value<bool>? smtpUseTls,
    Value<String?>? smtpInvoiceSubjectTemplate,
    Value<String?>? smtpInvoiceBodyTemplate,
    Value<String?>? smtpDunningSubjectTemplate,
    Value<String?>? smtpDunningBodyTemplate,
    Value<bool>? buchhaltungEnabled,
    Value<String>? bankCsvDelimiter,
    Value<bool>? bankCsvHasHeaderRow,
    Value<String?>? bankCsvDateColumn,
    Value<String?>? bankCsvAmountColumn,
    Value<String?>? bankCsvPurposeColumn,
    Value<String?>? bankCsvCounterpartyColumn,
    Value<String>? bankCsvDateFormat,
    Value<String>? bankCsvDecimalSeparator,
    Value<String?>? datevBeraterNummer,
    Value<String?>? datevMandantNummer,
    Value<String?>? datevBankGegenkonto,
    Value<int>? datevSachkontenlaenge,
    Value<bool>? creditNotesEnabled,
    Value<String?>? pdfIntroTextCreditNote,
    Value<String?>? pdfClosingTextCreditNote,
    Value<bool>? isSmallBusinessExempt,
    Value<int>? rowid,
  }) {
    return CompaniesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      taxNumber: taxNumber ?? this.taxNumber,
      vatId: vatId ?? this.vatId,
      iban: iban ?? this.iban,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      quotesEnabled: quotesEnabled ?? this.quotesEnabled,
      ordersEnabled: ordersEnabled ?? this.ordersEnabled,
      deliveryNotesEnabled: deliveryNotesEnabled ?? this.deliveryNotesEnabled,
      proformaEnabled: proformaEnabled ?? this.proformaEnabled,
      projectsEnabled: projectsEnabled ?? this.projectsEnabled,
      fleetEnabled: fleetEnabled ?? this.fleetEnabled,
      recurringInvoicesEnabled:
          recurringInvoicesEnabled ?? this.recurringInvoicesEnabled,
      advancePaymentInvoicesEnabled:
          advancePaymentInvoicesEnabled ?? this.advancePaymentInvoicesEnabled,
      dunningEnabled: dunningEnabled ?? this.dunningEnabled,
      dunningReminder2AfterDays:
          dunningReminder2AfterDays ?? this.dunningReminder2AfterDays,
      dunningReminder3AfterDays:
          dunningReminder3AfterDays ?? this.dunningReminder3AfterDays,
      dunningFeeLevel1Cents:
          dunningFeeLevel1Cents ?? this.dunningFeeLevel1Cents,
      dunningFeeLevel2Cents:
          dunningFeeLevel2Cents ?? this.dunningFeeLevel2Cents,
      dunningFeeLevel3Cents:
          dunningFeeLevel3Cents ?? this.dunningFeeLevel3Cents,
      dunningInterestRatePercent:
          dunningInterestRatePercent ?? this.dunningInterestRatePercent,
      pdfIntroTextDunning: pdfIntroTextDunning ?? this.pdfIntroTextDunning,
      pdfClosingTextDunning:
          pdfClosingTextDunning ?? this.pdfClosingTextDunning,
      pdfIntroText: pdfIntroText ?? this.pdfIntroText,
      pdfClosingText: pdfClosingText ?? this.pdfClosingText,
      pdfIntroTextQuote: pdfIntroTextQuote ?? this.pdfIntroTextQuote,
      pdfClosingTextQuote: pdfClosingTextQuote ?? this.pdfClosingTextQuote,
      pdfIntroTextOrder: pdfIntroTextOrder ?? this.pdfIntroTextOrder,
      pdfClosingTextOrder: pdfClosingTextOrder ?? this.pdfClosingTextOrder,
      pdfIntroTextDeliveryNote:
          pdfIntroTextDeliveryNote ?? this.pdfIntroTextDeliveryNote,
      pdfClosingTextDeliveryNote:
          pdfClosingTextDeliveryNote ?? this.pdfClosingTextDeliveryNote,
      pdfIntroTextProforma: pdfIntroTextProforma ?? this.pdfIntroTextProforma,
      pdfClosingTextProforma:
          pdfClosingTextProforma ?? this.pdfClosingTextProforma,
      pdfFooterText: pdfFooterText ?? this.pdfFooterText,
      smtpEnabled: smtpEnabled ?? this.smtpEnabled,
      smtpHost: smtpHost ?? this.smtpHost,
      smtpPort: smtpPort ?? this.smtpPort,
      smtpUsername: smtpUsername ?? this.smtpUsername,
      smtpFromAddress: smtpFromAddress ?? this.smtpFromAddress,
      smtpFromName: smtpFromName ?? this.smtpFromName,
      smtpUseTls: smtpUseTls ?? this.smtpUseTls,
      smtpInvoiceSubjectTemplate:
          smtpInvoiceSubjectTemplate ?? this.smtpInvoiceSubjectTemplate,
      smtpInvoiceBodyTemplate:
          smtpInvoiceBodyTemplate ?? this.smtpInvoiceBodyTemplate,
      smtpDunningSubjectTemplate:
          smtpDunningSubjectTemplate ?? this.smtpDunningSubjectTemplate,
      smtpDunningBodyTemplate:
          smtpDunningBodyTemplate ?? this.smtpDunningBodyTemplate,
      buchhaltungEnabled: buchhaltungEnabled ?? this.buchhaltungEnabled,
      bankCsvDelimiter: bankCsvDelimiter ?? this.bankCsvDelimiter,
      bankCsvHasHeaderRow: bankCsvHasHeaderRow ?? this.bankCsvHasHeaderRow,
      bankCsvDateColumn: bankCsvDateColumn ?? this.bankCsvDateColumn,
      bankCsvAmountColumn: bankCsvAmountColumn ?? this.bankCsvAmountColumn,
      bankCsvPurposeColumn: bankCsvPurposeColumn ?? this.bankCsvPurposeColumn,
      bankCsvCounterpartyColumn:
          bankCsvCounterpartyColumn ?? this.bankCsvCounterpartyColumn,
      bankCsvDateFormat: bankCsvDateFormat ?? this.bankCsvDateFormat,
      bankCsvDecimalSeparator:
          bankCsvDecimalSeparator ?? this.bankCsvDecimalSeparator,
      datevBeraterNummer: datevBeraterNummer ?? this.datevBeraterNummer,
      datevMandantNummer: datevMandantNummer ?? this.datevMandantNummer,
      datevBankGegenkonto: datevBankGegenkonto ?? this.datevBankGegenkonto,
      datevSachkontenlaenge:
          datevSachkontenlaenge ?? this.datevSachkontenlaenge,
      creditNotesEnabled: creditNotesEnabled ?? this.creditNotesEnabled,
      pdfIntroTextCreditNote:
          pdfIntroTextCreditNote ?? this.pdfIntroTextCreditNote,
      pdfClosingTextCreditNote:
          pdfClosingTextCreditNote ?? this.pdfClosingTextCreditNote,
      isSmallBusinessExempt:
          isSmallBusinessExempt ?? this.isSmallBusinessExempt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (taxNumber.present) {
      map['tax_number'] = Variable<String>(taxNumber.value);
    }
    if (vatId.present) {
      map['vat_id'] = Variable<String>(vatId.value);
    }
    if (iban.present) {
      map['iban'] = Variable<String>(iban.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (quotesEnabled.present) {
      map['quotes_enabled'] = Variable<bool>(quotesEnabled.value);
    }
    if (ordersEnabled.present) {
      map['orders_enabled'] = Variable<bool>(ordersEnabled.value);
    }
    if (deliveryNotesEnabled.present) {
      map['delivery_notes_enabled'] = Variable<bool>(
        deliveryNotesEnabled.value,
      );
    }
    if (proformaEnabled.present) {
      map['proforma_enabled'] = Variable<bool>(proformaEnabled.value);
    }
    if (projectsEnabled.present) {
      map['projects_enabled'] = Variable<bool>(projectsEnabled.value);
    }
    if (fleetEnabled.present) {
      map['fleet_enabled'] = Variable<bool>(fleetEnabled.value);
    }
    if (recurringInvoicesEnabled.present) {
      map['recurring_invoices_enabled'] = Variable<bool>(
        recurringInvoicesEnabled.value,
      );
    }
    if (advancePaymentInvoicesEnabled.present) {
      map['advance_payment_invoices_enabled'] = Variable<bool>(
        advancePaymentInvoicesEnabled.value,
      );
    }
    if (dunningEnabled.present) {
      map['dunning_enabled'] = Variable<bool>(dunningEnabled.value);
    }
    if (dunningReminder2AfterDays.present) {
      map['dunning_reminder2_after_days'] = Variable<int>(
        dunningReminder2AfterDays.value,
      );
    }
    if (dunningReminder3AfterDays.present) {
      map['dunning_reminder3_after_days'] = Variable<int>(
        dunningReminder3AfterDays.value,
      );
    }
    if (dunningFeeLevel1Cents.present) {
      map['dunning_fee_level1_cents'] = Variable<int>(
        dunningFeeLevel1Cents.value,
      );
    }
    if (dunningFeeLevel2Cents.present) {
      map['dunning_fee_level2_cents'] = Variable<int>(
        dunningFeeLevel2Cents.value,
      );
    }
    if (dunningFeeLevel3Cents.present) {
      map['dunning_fee_level3_cents'] = Variable<int>(
        dunningFeeLevel3Cents.value,
      );
    }
    if (dunningInterestRatePercent.present) {
      map['dunning_interest_rate_percent'] = Variable<double>(
        dunningInterestRatePercent.value,
      );
    }
    if (pdfIntroTextDunning.present) {
      map['pdf_intro_text_dunning'] = Variable<String>(
        pdfIntroTextDunning.value,
      );
    }
    if (pdfClosingTextDunning.present) {
      map['pdf_closing_text_dunning'] = Variable<String>(
        pdfClosingTextDunning.value,
      );
    }
    if (pdfIntroText.present) {
      map['pdf_intro_text'] = Variable<String>(pdfIntroText.value);
    }
    if (pdfClosingText.present) {
      map['pdf_closing_text'] = Variable<String>(pdfClosingText.value);
    }
    if (pdfIntroTextQuote.present) {
      map['pdf_intro_text_quote'] = Variable<String>(pdfIntroTextQuote.value);
    }
    if (pdfClosingTextQuote.present) {
      map['pdf_closing_text_quote'] = Variable<String>(
        pdfClosingTextQuote.value,
      );
    }
    if (pdfIntroTextOrder.present) {
      map['pdf_intro_text_order'] = Variable<String>(pdfIntroTextOrder.value);
    }
    if (pdfClosingTextOrder.present) {
      map['pdf_closing_text_order'] = Variable<String>(
        pdfClosingTextOrder.value,
      );
    }
    if (pdfIntroTextDeliveryNote.present) {
      map['pdf_intro_text_delivery_note'] = Variable<String>(
        pdfIntroTextDeliveryNote.value,
      );
    }
    if (pdfClosingTextDeliveryNote.present) {
      map['pdf_closing_text_delivery_note'] = Variable<String>(
        pdfClosingTextDeliveryNote.value,
      );
    }
    if (pdfIntroTextProforma.present) {
      map['pdf_intro_text_proforma'] = Variable<String>(
        pdfIntroTextProforma.value,
      );
    }
    if (pdfClosingTextProforma.present) {
      map['pdf_closing_text_proforma'] = Variable<String>(
        pdfClosingTextProforma.value,
      );
    }
    if (pdfFooterText.present) {
      map['pdf_footer_text'] = Variable<String>(pdfFooterText.value);
    }
    if (smtpEnabled.present) {
      map['smtp_enabled'] = Variable<bool>(smtpEnabled.value);
    }
    if (smtpHost.present) {
      map['smtp_host'] = Variable<String>(smtpHost.value);
    }
    if (smtpPort.present) {
      map['smtp_port'] = Variable<int>(smtpPort.value);
    }
    if (smtpUsername.present) {
      map['smtp_username'] = Variable<String>(smtpUsername.value);
    }
    if (smtpFromAddress.present) {
      map['smtp_from_address'] = Variable<String>(smtpFromAddress.value);
    }
    if (smtpFromName.present) {
      map['smtp_from_name'] = Variable<String>(smtpFromName.value);
    }
    if (smtpUseTls.present) {
      map['smtp_use_tls'] = Variable<bool>(smtpUseTls.value);
    }
    if (smtpInvoiceSubjectTemplate.present) {
      map['smtp_invoice_subject_template'] = Variable<String>(
        smtpInvoiceSubjectTemplate.value,
      );
    }
    if (smtpInvoiceBodyTemplate.present) {
      map['smtp_invoice_body_template'] = Variable<String>(
        smtpInvoiceBodyTemplate.value,
      );
    }
    if (smtpDunningSubjectTemplate.present) {
      map['smtp_dunning_subject_template'] = Variable<String>(
        smtpDunningSubjectTemplate.value,
      );
    }
    if (smtpDunningBodyTemplate.present) {
      map['smtp_dunning_body_template'] = Variable<String>(
        smtpDunningBodyTemplate.value,
      );
    }
    if (buchhaltungEnabled.present) {
      map['buchhaltung_enabled'] = Variable<bool>(buchhaltungEnabled.value);
    }
    if (bankCsvDelimiter.present) {
      map['bank_csv_delimiter'] = Variable<String>(bankCsvDelimiter.value);
    }
    if (bankCsvHasHeaderRow.present) {
      map['bank_csv_has_header_row'] = Variable<bool>(
        bankCsvHasHeaderRow.value,
      );
    }
    if (bankCsvDateColumn.present) {
      map['bank_csv_date_column'] = Variable<String>(bankCsvDateColumn.value);
    }
    if (bankCsvAmountColumn.present) {
      map['bank_csv_amount_column'] = Variable<String>(
        bankCsvAmountColumn.value,
      );
    }
    if (bankCsvPurposeColumn.present) {
      map['bank_csv_purpose_column'] = Variable<String>(
        bankCsvPurposeColumn.value,
      );
    }
    if (bankCsvCounterpartyColumn.present) {
      map['bank_csv_counterparty_column'] = Variable<String>(
        bankCsvCounterpartyColumn.value,
      );
    }
    if (bankCsvDateFormat.present) {
      map['bank_csv_date_format'] = Variable<String>(bankCsvDateFormat.value);
    }
    if (bankCsvDecimalSeparator.present) {
      map['bank_csv_decimal_separator'] = Variable<String>(
        bankCsvDecimalSeparator.value,
      );
    }
    if (datevBeraterNummer.present) {
      map['datev_berater_nummer'] = Variable<String>(datevBeraterNummer.value);
    }
    if (datevMandantNummer.present) {
      map['datev_mandant_nummer'] = Variable<String>(datevMandantNummer.value);
    }
    if (datevBankGegenkonto.present) {
      map['datev_bank_gegenkonto'] = Variable<String>(
        datevBankGegenkonto.value,
      );
    }
    if (datevSachkontenlaenge.present) {
      map['datev_sachkontenlaenge'] = Variable<int>(
        datevSachkontenlaenge.value,
      );
    }
    if (creditNotesEnabled.present) {
      map['credit_notes_enabled'] = Variable<bool>(creditNotesEnabled.value);
    }
    if (pdfIntroTextCreditNote.present) {
      map['pdf_intro_text_credit_note'] = Variable<String>(
        pdfIntroTextCreditNote.value,
      );
    }
    if (pdfClosingTextCreditNote.present) {
      map['pdf_closing_text_credit_note'] = Variable<String>(
        pdfClosingTextCreditNote.value,
      );
    }
    if (isSmallBusinessExempt.present) {
      map['is_small_business_exempt'] = Variable<bool>(
        isSmallBusinessExempt.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompaniesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('taxNumber: $taxNumber, ')
          ..write('vatId: $vatId, ')
          ..write('iban: $iban, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('createdAt: $createdAt, ')
          ..write('quotesEnabled: $quotesEnabled, ')
          ..write('ordersEnabled: $ordersEnabled, ')
          ..write('deliveryNotesEnabled: $deliveryNotesEnabled, ')
          ..write('proformaEnabled: $proformaEnabled, ')
          ..write('projectsEnabled: $projectsEnabled, ')
          ..write('fleetEnabled: $fleetEnabled, ')
          ..write('recurringInvoicesEnabled: $recurringInvoicesEnabled, ')
          ..write(
            'advancePaymentInvoicesEnabled: $advancePaymentInvoicesEnabled, ',
          )
          ..write('dunningEnabled: $dunningEnabled, ')
          ..write('dunningReminder2AfterDays: $dunningReminder2AfterDays, ')
          ..write('dunningReminder3AfterDays: $dunningReminder3AfterDays, ')
          ..write('dunningFeeLevel1Cents: $dunningFeeLevel1Cents, ')
          ..write('dunningFeeLevel2Cents: $dunningFeeLevel2Cents, ')
          ..write('dunningFeeLevel3Cents: $dunningFeeLevel3Cents, ')
          ..write('dunningInterestRatePercent: $dunningInterestRatePercent, ')
          ..write('pdfIntroTextDunning: $pdfIntroTextDunning, ')
          ..write('pdfClosingTextDunning: $pdfClosingTextDunning, ')
          ..write('pdfIntroText: $pdfIntroText, ')
          ..write('pdfClosingText: $pdfClosingText, ')
          ..write('pdfIntroTextQuote: $pdfIntroTextQuote, ')
          ..write('pdfClosingTextQuote: $pdfClosingTextQuote, ')
          ..write('pdfIntroTextOrder: $pdfIntroTextOrder, ')
          ..write('pdfClosingTextOrder: $pdfClosingTextOrder, ')
          ..write('pdfIntroTextDeliveryNote: $pdfIntroTextDeliveryNote, ')
          ..write('pdfClosingTextDeliveryNote: $pdfClosingTextDeliveryNote, ')
          ..write('pdfIntroTextProforma: $pdfIntroTextProforma, ')
          ..write('pdfClosingTextProforma: $pdfClosingTextProforma, ')
          ..write('pdfFooterText: $pdfFooterText, ')
          ..write('smtpEnabled: $smtpEnabled, ')
          ..write('smtpHost: $smtpHost, ')
          ..write('smtpPort: $smtpPort, ')
          ..write('smtpUsername: $smtpUsername, ')
          ..write('smtpFromAddress: $smtpFromAddress, ')
          ..write('smtpFromName: $smtpFromName, ')
          ..write('smtpUseTls: $smtpUseTls, ')
          ..write('smtpInvoiceSubjectTemplate: $smtpInvoiceSubjectTemplate, ')
          ..write('smtpInvoiceBodyTemplate: $smtpInvoiceBodyTemplate, ')
          ..write('smtpDunningSubjectTemplate: $smtpDunningSubjectTemplate, ')
          ..write('smtpDunningBodyTemplate: $smtpDunningBodyTemplate, ')
          ..write('buchhaltungEnabled: $buchhaltungEnabled, ')
          ..write('bankCsvDelimiter: $bankCsvDelimiter, ')
          ..write('bankCsvHasHeaderRow: $bankCsvHasHeaderRow, ')
          ..write('bankCsvDateColumn: $bankCsvDateColumn, ')
          ..write('bankCsvAmountColumn: $bankCsvAmountColumn, ')
          ..write('bankCsvPurposeColumn: $bankCsvPurposeColumn, ')
          ..write('bankCsvCounterpartyColumn: $bankCsvCounterpartyColumn, ')
          ..write('bankCsvDateFormat: $bankCsvDateFormat, ')
          ..write('bankCsvDecimalSeparator: $bankCsvDecimalSeparator, ')
          ..write('datevBeraterNummer: $datevBeraterNummer, ')
          ..write('datevMandantNummer: $datevMandantNummer, ')
          ..write('datevBankGegenkonto: $datevBankGegenkonto, ')
          ..write('datevSachkontenlaenge: $datevSachkontenlaenge, ')
          ..write('creditNotesEnabled: $creditNotesEnabled, ')
          ..write('pdfIntroTextCreditNote: $pdfIntroTextCreditNote, ')
          ..write('pdfClosingTextCreditNote: $pdfClosingTextCreditNote, ')
          ..write('isSmallBusinessExempt: $isSmallBusinessExempt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomersTable extends Customers
    with TableInfo<$CustomersTable, Customer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES companies (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vatIdMeta = const VerificationMeta('vatId');
  @override
  late final GeneratedColumn<String> vatId = GeneratedColumn<String>(
    'vat_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contactPersonMeta = const VerificationMeta(
    'contactPerson',
  );
  @override
  late final GeneratedColumn<String> contactPerson = GeneratedColumn<String>(
    'contact_person',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    name,
    address,
    email,
    phone,
    vatId,
    contactPerson,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'customers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Customer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('vat_id')) {
      context.handle(
        _vatIdMeta,
        vatId.isAcceptableOrUnknown(data['vat_id']!, _vatIdMeta),
      );
    }
    if (data.containsKey('contact_person')) {
      context.handle(
        _contactPersonMeta,
        contactPerson.isAcceptableOrUnknown(
          data['contact_person']!,
          _contactPersonMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Customer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Customer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      vatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vat_id'],
      ),
      contactPerson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_person'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CustomersTable createAlias(String alias) {
    return $CustomersTable(attachedDatabase, alias);
  }
}

class Customer extends DataClass implements Insertable<Customer> {
  final String id;
  final String companyId;
  final String name;
  final String? address;
  final String? email;
  final String? phone;

  /// USt-IdNr. des Kunden (B2B/Reverse-Charge-Fälle) — eigenständig als
  /// Feld ergänzt (Kay-Nachtrag 2026-10-16: "es fehlen viele Datenfelder",
  /// RechnungsFee nur als fachliche Anregung angeschaut, keine Übernahme
  /// von Code/Feldnamen/Texten).
  final String? vatId;
  final String? contactPerson;
  final String? notes;
  final DateTime createdAt;
  const Customer({
    required this.id,
    required this.companyId,
    required this.name,
    this.address,
    this.email,
    this.phone,
    this.vatId,
    this.contactPerson,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || vatId != null) {
      map['vat_id'] = Variable<String>(vatId);
    }
    if (!nullToAbsent || contactPerson != null) {
      map['contact_person'] = Variable<String>(contactPerson);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CustomersCompanion toCompanion(bool nullToAbsent) {
    return CustomersCompanion(
      id: Value(id),
      companyId: Value(companyId),
      name: Value(name),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      vatId: vatId == null && nullToAbsent
          ? const Value.absent()
          : Value(vatId),
      contactPerson: contactPerson == null && nullToAbsent
          ? const Value.absent()
          : Value(contactPerson),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory Customer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Customer(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      name: serializer.fromJson<String>(json['name']),
      address: serializer.fromJson<String?>(json['address']),
      email: serializer.fromJson<String?>(json['email']),
      phone: serializer.fromJson<String?>(json['phone']),
      vatId: serializer.fromJson<String?>(json['vatId']),
      contactPerson: serializer.fromJson<String?>(json['contactPerson']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'name': serializer.toJson<String>(name),
      'address': serializer.toJson<String?>(address),
      'email': serializer.toJson<String?>(email),
      'phone': serializer.toJson<String?>(phone),
      'vatId': serializer.toJson<String?>(vatId),
      'contactPerson': serializer.toJson<String?>(contactPerson),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Customer copyWith({
    String? id,
    String? companyId,
    String? name,
    Value<String?> address = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> vatId = const Value.absent(),
    Value<String?> contactPerson = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
  }) => Customer(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    name: name ?? this.name,
    address: address.present ? address.value : this.address,
    email: email.present ? email.value : this.email,
    phone: phone.present ? phone.value : this.phone,
    vatId: vatId.present ? vatId.value : this.vatId,
    contactPerson: contactPerson.present
        ? contactPerson.value
        : this.contactPerson,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  Customer copyWithCompanion(CustomersCompanion data) {
    return Customer(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      name: data.name.present ? data.name.value : this.name,
      address: data.address.present ? data.address.value : this.address,
      email: data.email.present ? data.email.value : this.email,
      phone: data.phone.present ? data.phone.value : this.phone,
      vatId: data.vatId.present ? data.vatId.value : this.vatId,
      contactPerson: data.contactPerson.present
          ? data.contactPerson.value
          : this.contactPerson,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Customer(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('vatId: $vatId, ')
          ..write('contactPerson: $contactPerson, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    name,
    address,
    email,
    phone,
    vatId,
    contactPerson,
    notes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Customer &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.name == this.name &&
          other.address == this.address &&
          other.email == this.email &&
          other.phone == this.phone &&
          other.vatId == this.vatId &&
          other.contactPerson == this.contactPerson &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class CustomersCompanion extends UpdateCompanion<Customer> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> name;
  final Value<String?> address;
  final Value<String?> email;
  final Value<String?> phone;
  final Value<String?> vatId;
  final Value<String?> contactPerson;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CustomersCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.vatId = const Value.absent(),
    this.contactPerson = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomersCompanion.insert({
    required String id,
    required String companyId,
    required String name,
    this.address = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.vatId = const Value.absent(),
    this.contactPerson = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Customer> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? name,
    Expression<String>? address,
    Expression<String>? email,
    Expression<String>? phone,
    Expression<String>? vatId,
    Expression<String>? contactPerson,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (vatId != null) 'vat_id': vatId,
      if (contactPerson != null) 'contact_person': contactPerson,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomersCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? name,
    Value<String?>? address,
    Value<String?>? email,
    Value<String?>? phone,
    Value<String?>? vatId,
    Value<String?>? contactPerson,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CustomersCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      address: address ?? this.address,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      vatId: vatId ?? this.vatId,
      contactPerson: contactPerson ?? this.contactPerson,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (vatId.present) {
      map['vat_id'] = Variable<String>(vatId.value);
    }
    if (contactPerson.present) {
      map['contact_person'] = Variable<String>(contactPerson.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomersCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('vatId: $vatId, ')
          ..write('contactPerson: $contactPerson, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SuppliersTable extends Suppliers
    with TableInfo<$SuppliersTable, Supplier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SuppliersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES companies (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vatIdMeta = const VerificationMeta('vatId');
  @override
  late final GeneratedColumn<String> vatId = GeneratedColumn<String>(
    'vat_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contactPersonMeta = const VerificationMeta(
    'contactPerson',
  );
  @override
  late final GeneratedColumn<String> contactPerson = GeneratedColumn<String>(
    'contact_person',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    name,
    address,
    email,
    phone,
    vatId,
    contactPerson,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'suppliers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Supplier> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('vat_id')) {
      context.handle(
        _vatIdMeta,
        vatId.isAcceptableOrUnknown(data['vat_id']!, _vatIdMeta),
      );
    }
    if (data.containsKey('contact_person')) {
      context.handle(
        _contactPersonMeta,
        contactPerson.isAcceptableOrUnknown(
          data['contact_person']!,
          _contactPersonMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Supplier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Supplier(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      vatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vat_id'],
      ),
      contactPerson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_person'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SuppliersTable createAlias(String alias) {
    return $SuppliersTable(attachedDatabase, alias);
  }
}

class Supplier extends DataClass implements Insertable<Supplier> {
  final String id;
  final String companyId;
  final String name;
  final String? address;
  final String? email;
  final String? phone;
  final String? vatId;
  final String? contactPerson;
  final String? notes;
  final DateTime createdAt;
  const Supplier({
    required this.id,
    required this.companyId,
    required this.name,
    this.address,
    this.email,
    this.phone,
    this.vatId,
    this.contactPerson,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || vatId != null) {
      map['vat_id'] = Variable<String>(vatId);
    }
    if (!nullToAbsent || contactPerson != null) {
      map['contact_person'] = Variable<String>(contactPerson);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SuppliersCompanion toCompanion(bool nullToAbsent) {
    return SuppliersCompanion(
      id: Value(id),
      companyId: Value(companyId),
      name: Value(name),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      vatId: vatId == null && nullToAbsent
          ? const Value.absent()
          : Value(vatId),
      contactPerson: contactPerson == null && nullToAbsent
          ? const Value.absent()
          : Value(contactPerson),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory Supplier.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Supplier(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      name: serializer.fromJson<String>(json['name']),
      address: serializer.fromJson<String?>(json['address']),
      email: serializer.fromJson<String?>(json['email']),
      phone: serializer.fromJson<String?>(json['phone']),
      vatId: serializer.fromJson<String?>(json['vatId']),
      contactPerson: serializer.fromJson<String?>(json['contactPerson']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'name': serializer.toJson<String>(name),
      'address': serializer.toJson<String?>(address),
      'email': serializer.toJson<String?>(email),
      'phone': serializer.toJson<String?>(phone),
      'vatId': serializer.toJson<String?>(vatId),
      'contactPerson': serializer.toJson<String?>(contactPerson),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Supplier copyWith({
    String? id,
    String? companyId,
    String? name,
    Value<String?> address = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> vatId = const Value.absent(),
    Value<String?> contactPerson = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
  }) => Supplier(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    name: name ?? this.name,
    address: address.present ? address.value : this.address,
    email: email.present ? email.value : this.email,
    phone: phone.present ? phone.value : this.phone,
    vatId: vatId.present ? vatId.value : this.vatId,
    contactPerson: contactPerson.present
        ? contactPerson.value
        : this.contactPerson,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  Supplier copyWithCompanion(SuppliersCompanion data) {
    return Supplier(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      name: data.name.present ? data.name.value : this.name,
      address: data.address.present ? data.address.value : this.address,
      email: data.email.present ? data.email.value : this.email,
      phone: data.phone.present ? data.phone.value : this.phone,
      vatId: data.vatId.present ? data.vatId.value : this.vatId,
      contactPerson: data.contactPerson.present
          ? data.contactPerson.value
          : this.contactPerson,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Supplier(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('vatId: $vatId, ')
          ..write('contactPerson: $contactPerson, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    name,
    address,
    email,
    phone,
    vatId,
    contactPerson,
    notes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Supplier &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.name == this.name &&
          other.address == this.address &&
          other.email == this.email &&
          other.phone == this.phone &&
          other.vatId == this.vatId &&
          other.contactPerson == this.contactPerson &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class SuppliersCompanion extends UpdateCompanion<Supplier> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> name;
  final Value<String?> address;
  final Value<String?> email;
  final Value<String?> phone;
  final Value<String?> vatId;
  final Value<String?> contactPerson;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SuppliersCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.vatId = const Value.absent(),
    this.contactPerson = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SuppliersCompanion.insert({
    required String id,
    required String companyId,
    required String name,
    this.address = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.vatId = const Value.absent(),
    this.contactPerson = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Supplier> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? name,
    Expression<String>? address,
    Expression<String>? email,
    Expression<String>? phone,
    Expression<String>? vatId,
    Expression<String>? contactPerson,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (vatId != null) 'vat_id': vatId,
      if (contactPerson != null) 'contact_person': contactPerson,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SuppliersCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? name,
    Value<String?>? address,
    Value<String?>? email,
    Value<String?>? phone,
    Value<String?>? vatId,
    Value<String?>? contactPerson,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SuppliersCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      address: address ?? this.address,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      vatId: vatId ?? this.vatId,
      contactPerson: contactPerson ?? this.contactPerson,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (vatId.present) {
      map['vat_id'] = Variable<String>(vatId.value);
    }
    if (contactPerson.present) {
      map['contact_person'] = Variable<String>(contactPerson.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SuppliersCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('vatId: $vatId, ')
          ..write('contactPerson: $contactPerson, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArticleGroupsTable extends ArticleGroups
    with TableInfo<$ArticleGroupsTable, ArticleGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArticleGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES companies (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _markupPercentMeta = const VerificationMeta(
    'markupPercent',
  );
  @override
  late final GeneratedColumn<double> markupPercent = GeneratedColumn<double>(
    'markup_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    name,
    markupPercent,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'article_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArticleGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('markup_percent')) {
      context.handle(
        _markupPercentMeta,
        markupPercent.isAcceptableOrUnknown(
          data['markup_percent']!,
          _markupPercentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_markupPercentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ArticleGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArticleGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      markupPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}markup_percent'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ArticleGroupsTable createAlias(String alias) {
    return $ArticleGroupsTable(attachedDatabase, alias);
  }
}

class ArticleGroup extends DataClass implements Insertable<ArticleGroup> {
  final String id;
  final String companyId;
  final String name;

  /// Aufschlag in Prozent, z. B. 30.0 für 30 %.
  final double markupPercent;
  final DateTime createdAt;
  const ArticleGroup({
    required this.id,
    required this.companyId,
    required this.name,
    required this.markupPercent,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['name'] = Variable<String>(name);
    map['markup_percent'] = Variable<double>(markupPercent);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ArticleGroupsCompanion toCompanion(bool nullToAbsent) {
    return ArticleGroupsCompanion(
      id: Value(id),
      companyId: Value(companyId),
      name: Value(name),
      markupPercent: Value(markupPercent),
      createdAt: Value(createdAt),
    );
  }

  factory ArticleGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArticleGroup(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      name: serializer.fromJson<String>(json['name']),
      markupPercent: serializer.fromJson<double>(json['markupPercent']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'name': serializer.toJson<String>(name),
      'markupPercent': serializer.toJson<double>(markupPercent),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ArticleGroup copyWith({
    String? id,
    String? companyId,
    String? name,
    double? markupPercent,
    DateTime? createdAt,
  }) => ArticleGroup(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    name: name ?? this.name,
    markupPercent: markupPercent ?? this.markupPercent,
    createdAt: createdAt ?? this.createdAt,
  );
  ArticleGroup copyWithCompanion(ArticleGroupsCompanion data) {
    return ArticleGroup(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      name: data.name.present ? data.name.value : this.name,
      markupPercent: data.markupPercent.present
          ? data.markupPercent.value
          : this.markupPercent,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArticleGroup(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('markupPercent: $markupPercent, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, companyId, name, markupPercent, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArticleGroup &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.name == this.name &&
          other.markupPercent == this.markupPercent &&
          other.createdAt == this.createdAt);
}

class ArticleGroupsCompanion extends UpdateCompanion<ArticleGroup> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> name;
  final Value<double> markupPercent;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ArticleGroupsCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.name = const Value.absent(),
    this.markupPercent = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArticleGroupsCompanion.insert({
    required String id,
    required String companyId,
    required String name,
    required double markupPercent,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       name = Value(name),
       markupPercent = Value(markupPercent),
       createdAt = Value(createdAt);
  static Insertable<ArticleGroup> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? name,
    Expression<double>? markupPercent,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (name != null) 'name': name,
      if (markupPercent != null) 'markup_percent': markupPercent,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArticleGroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? name,
    Value<double>? markupPercent,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ArticleGroupsCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      markupPercent: markupPercent ?? this.markupPercent,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (markupPercent.present) {
      map['markup_percent'] = Variable<double>(markupPercent.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArticleGroupsCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('markupPercent: $markupPercent, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArticlesTable extends Articles with TableInfo<$ArticlesTable, Article> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArticlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES companies (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _articleGroupIdMeta = const VerificationMeta(
    'articleGroupId',
  );
  @override
  late final GeneratedColumn<String> articleGroupId = GeneratedColumn<String>(
    'article_group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES article_groups (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _defaultSupplierIdMeta = const VerificationMeta(
    'defaultSupplierId',
  );
  @override
  late final GeneratedColumn<String> defaultSupplierId =
      GeneratedColumn<String>(
        'default_supplier_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES suppliers (id) ON DELETE SET NULL',
        ),
      );
  static const VerificationMeta _manualSalePriceCentsMeta =
      const VerificationMeta('manualSalePriceCents');
  @override
  late final GeneratedColumn<int> manualSalePriceCents = GeneratedColumn<int>(
    'manual_sale_price_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    name,
    unit,
    articleGroupId,
    defaultSupplierId,
    manualSalePriceCents,
    active,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'articles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Article> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('article_group_id')) {
      context.handle(
        _articleGroupIdMeta,
        articleGroupId.isAcceptableOrUnknown(
          data['article_group_id']!,
          _articleGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('default_supplier_id')) {
      context.handle(
        _defaultSupplierIdMeta,
        defaultSupplierId.isAcceptableOrUnknown(
          data['default_supplier_id']!,
          _defaultSupplierIdMeta,
        ),
      );
    }
    if (data.containsKey('manual_sale_price_cents')) {
      context.handle(
        _manualSalePriceCentsMeta,
        manualSalePriceCents.isAcceptableOrUnknown(
          data['manual_sale_price_cents']!,
          _manualSalePriceCentsMeta,
        ),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Article map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Article(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
      articleGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article_group_id'],
      ),
      defaultSupplierId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_supplier_id'],
      ),
      manualSalePriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manual_sale_price_cents'],
      ),
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ArticlesTable createAlias(String alias) {
    return $ArticlesTable(attachedDatabase, alias);
  }
}

class Article extends DataClass implements Insertable<Article> {
  final String id;
  final String companyId;
  final String name;
  final String? unit;
  final String? articleGroupId;

  /// Bevorzugter Kalkulations-Preisgeber (Brainstorming: "Standardlieferant
  /// gibt den bevorzugten Einkaufspreis für die Kalkulation vor"). `null`,
  /// solange kein Lieferant gesetzt ist — dann ist nur ein manueller
  /// Verkaufspreis möglich (siehe [manualSalePriceCents]).
  final String? defaultSupplierId;

  /// Manuell abweichender Verkaufspreis (Minor Units/Cent). Überschreibt
  /// die Kalkulation aus Standardlieferant + Artikelgruppen-Aufschlag,
  /// falls gesetzt.
  final int? manualSalePriceCents;

  /// Deaktivieren statt löschen (Nachtrag 2026-10-18: "Artikel müssen
  /// deaktiviert werden können, wenn der Hersteller sie abkündigt") —
  /// gleiches Prinzip wie Projekte/Fahrzeuge/Modul-Schalter. Ein
  /// deaktivierter Artikel bleibt in bereits erfassten Positionen
  /// unverändert sichtbar, verschwindet nur aus Auswahllisten für neue
  /// Positionen.
  final bool active;
  final DateTime createdAt;
  const Article({
    required this.id,
    required this.companyId,
    required this.name,
    this.unit,
    this.articleGroupId,
    this.defaultSupplierId,
    this.manualSalePriceCents,
    required this.active,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    if (!nullToAbsent || articleGroupId != null) {
      map['article_group_id'] = Variable<String>(articleGroupId);
    }
    if (!nullToAbsent || defaultSupplierId != null) {
      map['default_supplier_id'] = Variable<String>(defaultSupplierId);
    }
    if (!nullToAbsent || manualSalePriceCents != null) {
      map['manual_sale_price_cents'] = Variable<int>(manualSalePriceCents);
    }
    map['active'] = Variable<bool>(active);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ArticlesCompanion toCompanion(bool nullToAbsent) {
    return ArticlesCompanion(
      id: Value(id),
      companyId: Value(companyId),
      name: Value(name),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      articleGroupId: articleGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(articleGroupId),
      defaultSupplierId: defaultSupplierId == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultSupplierId),
      manualSalePriceCents: manualSalePriceCents == null && nullToAbsent
          ? const Value.absent()
          : Value(manualSalePriceCents),
      active: Value(active),
      createdAt: Value(createdAt),
    );
  }

  factory Article.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Article(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      name: serializer.fromJson<String>(json['name']),
      unit: serializer.fromJson<String?>(json['unit']),
      articleGroupId: serializer.fromJson<String?>(json['articleGroupId']),
      defaultSupplierId: serializer.fromJson<String?>(
        json['defaultSupplierId'],
      ),
      manualSalePriceCents: serializer.fromJson<int?>(
        json['manualSalePriceCents'],
      ),
      active: serializer.fromJson<bool>(json['active']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'name': serializer.toJson<String>(name),
      'unit': serializer.toJson<String?>(unit),
      'articleGroupId': serializer.toJson<String?>(articleGroupId),
      'defaultSupplierId': serializer.toJson<String?>(defaultSupplierId),
      'manualSalePriceCents': serializer.toJson<int?>(manualSalePriceCents),
      'active': serializer.toJson<bool>(active),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Article copyWith({
    String? id,
    String? companyId,
    String? name,
    Value<String?> unit = const Value.absent(),
    Value<String?> articleGroupId = const Value.absent(),
    Value<String?> defaultSupplierId = const Value.absent(),
    Value<int?> manualSalePriceCents = const Value.absent(),
    bool? active,
    DateTime? createdAt,
  }) => Article(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    name: name ?? this.name,
    unit: unit.present ? unit.value : this.unit,
    articleGroupId: articleGroupId.present
        ? articleGroupId.value
        : this.articleGroupId,
    defaultSupplierId: defaultSupplierId.present
        ? defaultSupplierId.value
        : this.defaultSupplierId,
    manualSalePriceCents: manualSalePriceCents.present
        ? manualSalePriceCents.value
        : this.manualSalePriceCents,
    active: active ?? this.active,
    createdAt: createdAt ?? this.createdAt,
  );
  Article copyWithCompanion(ArticlesCompanion data) {
    return Article(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      name: data.name.present ? data.name.value : this.name,
      unit: data.unit.present ? data.unit.value : this.unit,
      articleGroupId: data.articleGroupId.present
          ? data.articleGroupId.value
          : this.articleGroupId,
      defaultSupplierId: data.defaultSupplierId.present
          ? data.defaultSupplierId.value
          : this.defaultSupplierId,
      manualSalePriceCents: data.manualSalePriceCents.present
          ? data.manualSalePriceCents.value
          : this.manualSalePriceCents,
      active: data.active.present ? data.active.value : this.active,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Article(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('unit: $unit, ')
          ..write('articleGroupId: $articleGroupId, ')
          ..write('defaultSupplierId: $defaultSupplierId, ')
          ..write('manualSalePriceCents: $manualSalePriceCents, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    name,
    unit,
    articleGroupId,
    defaultSupplierId,
    manualSalePriceCents,
    active,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Article &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.name == this.name &&
          other.unit == this.unit &&
          other.articleGroupId == this.articleGroupId &&
          other.defaultSupplierId == this.defaultSupplierId &&
          other.manualSalePriceCents == this.manualSalePriceCents &&
          other.active == this.active &&
          other.createdAt == this.createdAt);
}

class ArticlesCompanion extends UpdateCompanion<Article> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> name;
  final Value<String?> unit;
  final Value<String?> articleGroupId;
  final Value<String?> defaultSupplierId;
  final Value<int?> manualSalePriceCents;
  final Value<bool> active;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ArticlesCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.name = const Value.absent(),
    this.unit = const Value.absent(),
    this.articleGroupId = const Value.absent(),
    this.defaultSupplierId = const Value.absent(),
    this.manualSalePriceCents = const Value.absent(),
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArticlesCompanion.insert({
    required String id,
    required String companyId,
    required String name,
    this.unit = const Value.absent(),
    this.articleGroupId = const Value.absent(),
    this.defaultSupplierId = const Value.absent(),
    this.manualSalePriceCents = const Value.absent(),
    this.active = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Article> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? name,
    Expression<String>? unit,
    Expression<String>? articleGroupId,
    Expression<String>? defaultSupplierId,
    Expression<int>? manualSalePriceCents,
    Expression<bool>? active,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (name != null) 'name': name,
      if (unit != null) 'unit': unit,
      if (articleGroupId != null) 'article_group_id': articleGroupId,
      if (defaultSupplierId != null) 'default_supplier_id': defaultSupplierId,
      if (manualSalePriceCents != null)
        'manual_sale_price_cents': manualSalePriceCents,
      if (active != null) 'active': active,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArticlesCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? name,
    Value<String?>? unit,
    Value<String?>? articleGroupId,
    Value<String?>? defaultSupplierId,
    Value<int?>? manualSalePriceCents,
    Value<bool>? active,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ArticlesCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      articleGroupId: articleGroupId ?? this.articleGroupId,
      defaultSupplierId: defaultSupplierId ?? this.defaultSupplierId,
      manualSalePriceCents: manualSalePriceCents ?? this.manualSalePriceCents,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (articleGroupId.present) {
      map['article_group_id'] = Variable<String>(articleGroupId.value);
    }
    if (defaultSupplierId.present) {
      map['default_supplier_id'] = Variable<String>(defaultSupplierId.value);
    }
    if (manualSalePriceCents.present) {
      map['manual_sale_price_cents'] = Variable<int>(
        manualSalePriceCents.value,
      );
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArticlesCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('unit: $unit, ')
          ..write('articleGroupId: $articleGroupId, ')
          ..write('defaultSupplierId: $defaultSupplierId, ')
          ..write('manualSalePriceCents: $manualSalePriceCents, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArticleSupplierPricesTable extends ArticleSupplierPrices
    with TableInfo<$ArticleSupplierPricesTable, ArticleSupplierPrice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArticleSupplierPricesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _articleIdMeta = const VerificationMeta(
    'articleId',
  );
  @override
  late final GeneratedColumn<String> articleId = GeneratedColumn<String>(
    'article_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES articles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _supplierIdMeta = const VerificationMeta(
    'supplierId',
  );
  @override
  late final GeneratedColumn<String> supplierId = GeneratedColumn<String>(
    'supplier_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES suppliers (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _purchasePriceCentsMeta =
      const VerificationMeta('purchasePriceCents');
  @override
  late final GeneratedColumn<int> purchasePriceCents = GeneratedColumn<int>(
    'purchase_price_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    articleId,
    supplierId,
    purchasePriceCents,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'article_supplier_prices';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArticleSupplierPrice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('article_id')) {
      context.handle(
        _articleIdMeta,
        articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_articleIdMeta);
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
        _supplierIdMeta,
        supplierId.isAcceptableOrUnknown(data['supplier_id']!, _supplierIdMeta),
      );
    } else if (isInserting) {
      context.missing(_supplierIdMeta);
    }
    if (data.containsKey('purchase_price_cents')) {
      context.handle(
        _purchasePriceCentsMeta,
        purchasePriceCents.isAcceptableOrUnknown(
          data['purchase_price_cents']!,
          _purchasePriceCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_purchasePriceCentsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {articleId, supplierId},
  ];
  @override
  ArticleSupplierPrice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArticleSupplierPrice(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      articleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article_id'],
      )!,
      supplierId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supplier_id'],
      )!,
      purchasePriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}purchase_price_cents'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ArticleSupplierPricesTable createAlias(String alias) {
    return $ArticleSupplierPricesTable(attachedDatabase, alias);
  }
}

class ArticleSupplierPrice extends DataClass
    implements Insertable<ArticleSupplierPrice> {
  final String id;
  final String articleId;
  final String supplierId;
  final int purchasePriceCents;
  final DateTime createdAt;
  const ArticleSupplierPrice({
    required this.id,
    required this.articleId,
    required this.supplierId,
    required this.purchasePriceCents,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['article_id'] = Variable<String>(articleId);
    map['supplier_id'] = Variable<String>(supplierId);
    map['purchase_price_cents'] = Variable<int>(purchasePriceCents);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ArticleSupplierPricesCompanion toCompanion(bool nullToAbsent) {
    return ArticleSupplierPricesCompanion(
      id: Value(id),
      articleId: Value(articleId),
      supplierId: Value(supplierId),
      purchasePriceCents: Value(purchasePriceCents),
      createdAt: Value(createdAt),
    );
  }

  factory ArticleSupplierPrice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArticleSupplierPrice(
      id: serializer.fromJson<String>(json['id']),
      articleId: serializer.fromJson<String>(json['articleId']),
      supplierId: serializer.fromJson<String>(json['supplierId']),
      purchasePriceCents: serializer.fromJson<int>(json['purchasePriceCents']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'articleId': serializer.toJson<String>(articleId),
      'supplierId': serializer.toJson<String>(supplierId),
      'purchasePriceCents': serializer.toJson<int>(purchasePriceCents),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ArticleSupplierPrice copyWith({
    String? id,
    String? articleId,
    String? supplierId,
    int? purchasePriceCents,
    DateTime? createdAt,
  }) => ArticleSupplierPrice(
    id: id ?? this.id,
    articleId: articleId ?? this.articleId,
    supplierId: supplierId ?? this.supplierId,
    purchasePriceCents: purchasePriceCents ?? this.purchasePriceCents,
    createdAt: createdAt ?? this.createdAt,
  );
  ArticleSupplierPrice copyWithCompanion(ArticleSupplierPricesCompanion data) {
    return ArticleSupplierPrice(
      id: data.id.present ? data.id.value : this.id,
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      supplierId: data.supplierId.present
          ? data.supplierId.value
          : this.supplierId,
      purchasePriceCents: data.purchasePriceCents.present
          ? data.purchasePriceCents.value
          : this.purchasePriceCents,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArticleSupplierPrice(')
          ..write('id: $id, ')
          ..write('articleId: $articleId, ')
          ..write('supplierId: $supplierId, ')
          ..write('purchasePriceCents: $purchasePriceCents, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, articleId, supplierId, purchasePriceCents, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArticleSupplierPrice &&
          other.id == this.id &&
          other.articleId == this.articleId &&
          other.supplierId == this.supplierId &&
          other.purchasePriceCents == this.purchasePriceCents &&
          other.createdAt == this.createdAt);
}

class ArticleSupplierPricesCompanion
    extends UpdateCompanion<ArticleSupplierPrice> {
  final Value<String> id;
  final Value<String> articleId;
  final Value<String> supplierId;
  final Value<int> purchasePriceCents;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ArticleSupplierPricesCompanion({
    this.id = const Value.absent(),
    this.articleId = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.purchasePriceCents = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArticleSupplierPricesCompanion.insert({
    required String id,
    required String articleId,
    required String supplierId,
    required int purchasePriceCents,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       articleId = Value(articleId),
       supplierId = Value(supplierId),
       purchasePriceCents = Value(purchasePriceCents),
       createdAt = Value(createdAt);
  static Insertable<ArticleSupplierPrice> custom({
    Expression<String>? id,
    Expression<String>? articleId,
    Expression<String>? supplierId,
    Expression<int>? purchasePriceCents,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (articleId != null) 'article_id': articleId,
      if (supplierId != null) 'supplier_id': supplierId,
      if (purchasePriceCents != null)
        'purchase_price_cents': purchasePriceCents,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArticleSupplierPricesCompanion copyWith({
    Value<String>? id,
    Value<String>? articleId,
    Value<String>? supplierId,
    Value<int>? purchasePriceCents,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ArticleSupplierPricesCompanion(
      id: id ?? this.id,
      articleId: articleId ?? this.articleId,
      supplierId: supplierId ?? this.supplierId,
      purchasePriceCents: purchasePriceCents ?? this.purchasePriceCents,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (articleId.present) {
      map['article_id'] = Variable<String>(articleId.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<String>(supplierId.value);
    }
    if (purchasePriceCents.present) {
      map['purchase_price_cents'] = Variable<int>(purchasePriceCents.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArticleSupplierPricesCompanion(')
          ..write('id: $id, ')
          ..write('articleId: $articleId, ')
          ..write('supplierId: $supplierId, ')
          ..write('purchasePriceCents: $purchasePriceCents, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES companies (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES customers (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ProjectStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(ProjectStatus.active.name),
      ).withConverter<ProjectStatus>($ProjectsTable.$converterstatus);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    name,
    customerId,
    notes,
    status,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Project> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      status: $ProjectsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ProjectStatus, String, String> $converterstatus =
      const EnumNameConverter<ProjectStatus>(ProjectStatus.values);
}

class Project extends DataClass implements Insertable<Project> {
  final String id;
  final String companyId;
  final String name;

  /// Optionaler Kundenbezug — ein Projekt kann, muss aber nicht genau
  /// einem Kunden zugeordnet sein (Brainstorming lässt das offen).
  final String? customerId;
  final String? notes;
  final ProjectStatus status;
  final DateTime createdAt;
  const Project({
    required this.id,
    required this.companyId,
    required this.name,
    this.customerId,
    this.notes,
    required this.status,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || customerId != null) {
      map['customer_id'] = Variable<String>(customerId);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    {
      map['status'] = Variable<String>(
        $ProjectsTable.$converterstatus.toSql(status),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      companyId: Value(companyId),
      name: Value(name),
      customerId: customerId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerId),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory Project.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      name: serializer.fromJson<String>(json['name']),
      customerId: serializer.fromJson<String?>(json['customerId']),
      notes: serializer.fromJson<String?>(json['notes']),
      status: $ProjectsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'name': serializer.toJson<String>(name),
      'customerId': serializer.toJson<String?>(customerId),
      'notes': serializer.toJson<String?>(notes),
      'status': serializer.toJson<String>(
        $ProjectsTable.$converterstatus.toJson(status),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Project copyWith({
    String? id,
    String? companyId,
    String? name,
    Value<String?> customerId = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    ProjectStatus? status,
    DateTime? createdAt,
  }) => Project(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    name: name ?? this.name,
    customerId: customerId.present ? customerId.value : this.customerId,
    notes: notes.present ? notes.value : this.notes,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      name: data.name.present ? data.name.value : this.name,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      notes: data.notes.present ? data.notes.value : this.notes,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('customerId: $customerId, ')
          ..write('notes: $notes, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, companyId, name, customerId, notes, status, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.name == this.name &&
          other.customerId == this.customerId &&
          other.notes == this.notes &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> name;
  final Value<String?> customerId;
  final Value<String?> notes;
  final Value<ProjectStatus> status;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.name = const Value.absent(),
    this.customerId = const Value.absent(),
    this.notes = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String companyId,
    required String name,
    this.customerId = const Value.absent(),
    this.notes = const Value.absent(),
    this.status = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Project> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? name,
    Expression<String>? customerId,
    Expression<String>? notes,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (name != null) 'name': name,
      if (customerId != null) 'customer_id': customerId,
      if (notes != null) 'notes': notes,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? name,
    Value<String?>? customerId,
    Value<String?>? notes,
    Value<ProjectStatus>? status,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      customerId: customerId ?? this.customerId,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $ProjectsTable.$converterstatus.toSql(status.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('customerId: $customerId, ')
          ..write('notes: $notes, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InvoicesTable extends Invoices with TableInfo<$InvoicesTable, Invoice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvoicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES companies (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES customers (id) ON DELETE RESTRICT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DocumentKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(DocumentKind.invoice.name),
      ).withConverter<DocumentKind>($InvoicesTable.$converterkind);
  @override
  late final GeneratedColumnWithTypeConverter<InvoiceStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<InvoiceStatus>($InvoicesTable.$converterstatus);
  static const VerificationMeta _invoiceNumberMeta = const VerificationMeta(
    'invoiceNumber',
  );
  @override
  late final GeneratedColumn<String> invoiceNumber = GeneratedColumn<String>(
    'invoice_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _numberYearMeta = const VerificationMeta(
    'numberYear',
  );
  @override
  late final GeneratedColumn<int> numberYear = GeneratedColumn<int>(
    'number_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _issueDateMeta = const VerificationMeta(
    'issueDate',
  );
  @override
  late final GeneratedColumn<DateTime> issueDate = GeneratedColumn<DateTime>(
    'issue_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serviceDateMeta = const VerificationMeta(
    'serviceDate',
  );
  @override
  late final GeneratedColumn<DateTime> serviceDate = GeneratedColumn<DateTime>(
    'service_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paymentTermsMeta = const VerificationMeta(
    'paymentTerms',
  );
  @override
  late final GeneratedColumn<String> paymentTerms = GeneratedColumn<String>(
    'payment_terms',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customerSnapshotNameMeta =
      const VerificationMeta('customerSnapshotName');
  @override
  late final GeneratedColumn<String> customerSnapshotName =
      GeneratedColumn<String>(
        'customer_snapshot_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _customerSnapshotAddressMeta =
      const VerificationMeta('customerSnapshotAddress');
  @override
  late final GeneratedColumn<String> customerSnapshotAddress =
      GeneratedColumn<String>(
        'customer_snapshot_address',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _customerSnapshotVatIdMeta =
      const VerificationMeta('customerSnapshotVatId');
  @override
  late final GeneratedColumn<String> customerSnapshotVatId =
      GeneratedColumn<String>(
        'customer_snapshot_vat_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _companySnapshotNameMeta =
      const VerificationMeta('companySnapshotName');
  @override
  late final GeneratedColumn<String> companySnapshotName =
      GeneratedColumn<String>(
        'company_snapshot_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _companySnapshotAddressMeta =
      const VerificationMeta('companySnapshotAddress');
  @override
  late final GeneratedColumn<String> companySnapshotAddress =
      GeneratedColumn<String>(
        'company_snapshot_address',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _companySnapshotTaxNumberMeta =
      const VerificationMeta('companySnapshotTaxNumber');
  @override
  late final GeneratedColumn<String> companySnapshotTaxNumber =
      GeneratedColumn<String>(
        'company_snapshot_tax_number',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _companySnapshotVatIdMeta =
      const VerificationMeta('companySnapshotVatId');
  @override
  late final GeneratedColumn<String> companySnapshotVatId =
      GeneratedColumn<String>(
        'company_snapshot_vat_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _companySnapshotIbanMeta =
      const VerificationMeta('companySnapshotIban');
  @override
  late final GeneratedColumn<String> companySnapshotIban =
      GeneratedColumn<String>(
        'company_snapshot_iban',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pdfIntroTextSnapshotMeta =
      const VerificationMeta('pdfIntroTextSnapshot');
  @override
  late final GeneratedColumn<String> pdfIntroTextSnapshot =
      GeneratedColumn<String>(
        'pdf_intro_text_snapshot',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pdfClosingTextSnapshotMeta =
      const VerificationMeta('pdfClosingTextSnapshot');
  @override
  late final GeneratedColumn<String> pdfClosingTextSnapshot =
      GeneratedColumn<String>(
        'pdf_closing_text_snapshot',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pdfFooterTextSnapshotMeta =
      const VerificationMeta('pdfFooterTextSnapshot');
  @override
  late final GeneratedColumn<String> pdfFooterTextSnapshot =
      GeneratedColumn<String>(
        'pdf_footer_text_snapshot',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _finalizedAtMeta = const VerificationMeta(
    'finalizedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finalizedAt = GeneratedColumn<DateTime>(
    'finalized_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _convertedFromIdMeta = const VerificationMeta(
    'convertedFromId',
  );
  @override
  late final GeneratedColumn<String> convertedFromId = GeneratedColumn<String>(
    'converted_from_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES invoices (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _isAdvancePaymentMeta = const VerificationMeta(
    'isAdvancePayment',
  );
  @override
  late final GeneratedColumn<bool> isAdvancePayment = GeneratedColumn<bool>(
    'is_advance_payment',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_advance_payment" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PaymentStatus, String>
  paymentStatus = GeneratedColumn<String>(
    'payment_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(PaymentStatus.open.name),
  ).withConverter<PaymentStatus>($InvoicesTable.$converterpaymentStatus);
  static const VerificationMeta _paidAtMeta = const VerificationMeta('paidAt');
  @override
  late final GeneratedColumn<DateTime> paidAt = GeneratedColumn<DateTime>(
    'paid_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    customerId,
    kind,
    status,
    invoiceNumber,
    numberYear,
    issueDate,
    serviceDate,
    paymentTerms,
    notes,
    customerSnapshotName,
    customerSnapshotAddress,
    customerSnapshotVatId,
    companySnapshotName,
    companySnapshotAddress,
    companySnapshotTaxNumber,
    companySnapshotVatId,
    companySnapshotIban,
    pdfIntroTextSnapshot,
    pdfClosingTextSnapshot,
    pdfFooterTextSnapshot,
    finalizedAt,
    createdAt,
    updatedAt,
    convertedFromId,
    projectId,
    isAdvancePayment,
    dueDate,
    paymentStatus,
    paidAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'invoices';
  @override
  VerificationContext validateIntegrity(
    Insertable<Invoice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('invoice_number')) {
      context.handle(
        _invoiceNumberMeta,
        invoiceNumber.isAcceptableOrUnknown(
          data['invoice_number']!,
          _invoiceNumberMeta,
        ),
      );
    }
    if (data.containsKey('number_year')) {
      context.handle(
        _numberYearMeta,
        numberYear.isAcceptableOrUnknown(data['number_year']!, _numberYearMeta),
      );
    }
    if (data.containsKey('issue_date')) {
      context.handle(
        _issueDateMeta,
        issueDate.isAcceptableOrUnknown(data['issue_date']!, _issueDateMeta),
      );
    } else if (isInserting) {
      context.missing(_issueDateMeta);
    }
    if (data.containsKey('service_date')) {
      context.handle(
        _serviceDateMeta,
        serviceDate.isAcceptableOrUnknown(
          data['service_date']!,
          _serviceDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serviceDateMeta);
    }
    if (data.containsKey('payment_terms')) {
      context.handle(
        _paymentTermsMeta,
        paymentTerms.isAcceptableOrUnknown(
          data['payment_terms']!,
          _paymentTermsMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('customer_snapshot_name')) {
      context.handle(
        _customerSnapshotNameMeta,
        customerSnapshotName.isAcceptableOrUnknown(
          data['customer_snapshot_name']!,
          _customerSnapshotNameMeta,
        ),
      );
    }
    if (data.containsKey('customer_snapshot_address')) {
      context.handle(
        _customerSnapshotAddressMeta,
        customerSnapshotAddress.isAcceptableOrUnknown(
          data['customer_snapshot_address']!,
          _customerSnapshotAddressMeta,
        ),
      );
    }
    if (data.containsKey('customer_snapshot_vat_id')) {
      context.handle(
        _customerSnapshotVatIdMeta,
        customerSnapshotVatId.isAcceptableOrUnknown(
          data['customer_snapshot_vat_id']!,
          _customerSnapshotVatIdMeta,
        ),
      );
    }
    if (data.containsKey('company_snapshot_name')) {
      context.handle(
        _companySnapshotNameMeta,
        companySnapshotName.isAcceptableOrUnknown(
          data['company_snapshot_name']!,
          _companySnapshotNameMeta,
        ),
      );
    }
    if (data.containsKey('company_snapshot_address')) {
      context.handle(
        _companySnapshotAddressMeta,
        companySnapshotAddress.isAcceptableOrUnknown(
          data['company_snapshot_address']!,
          _companySnapshotAddressMeta,
        ),
      );
    }
    if (data.containsKey('company_snapshot_tax_number')) {
      context.handle(
        _companySnapshotTaxNumberMeta,
        companySnapshotTaxNumber.isAcceptableOrUnknown(
          data['company_snapshot_tax_number']!,
          _companySnapshotTaxNumberMeta,
        ),
      );
    }
    if (data.containsKey('company_snapshot_vat_id')) {
      context.handle(
        _companySnapshotVatIdMeta,
        companySnapshotVatId.isAcceptableOrUnknown(
          data['company_snapshot_vat_id']!,
          _companySnapshotVatIdMeta,
        ),
      );
    }
    if (data.containsKey('company_snapshot_iban')) {
      context.handle(
        _companySnapshotIbanMeta,
        companySnapshotIban.isAcceptableOrUnknown(
          data['company_snapshot_iban']!,
          _companySnapshotIbanMeta,
        ),
      );
    }
    if (data.containsKey('pdf_intro_text_snapshot')) {
      context.handle(
        _pdfIntroTextSnapshotMeta,
        pdfIntroTextSnapshot.isAcceptableOrUnknown(
          data['pdf_intro_text_snapshot']!,
          _pdfIntroTextSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('pdf_closing_text_snapshot')) {
      context.handle(
        _pdfClosingTextSnapshotMeta,
        pdfClosingTextSnapshot.isAcceptableOrUnknown(
          data['pdf_closing_text_snapshot']!,
          _pdfClosingTextSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('pdf_footer_text_snapshot')) {
      context.handle(
        _pdfFooterTextSnapshotMeta,
        pdfFooterTextSnapshot.isAcceptableOrUnknown(
          data['pdf_footer_text_snapshot']!,
          _pdfFooterTextSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('finalized_at')) {
      context.handle(
        _finalizedAtMeta,
        finalizedAt.isAcceptableOrUnknown(
          data['finalized_at']!,
          _finalizedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('converted_from_id')) {
      context.handle(
        _convertedFromIdMeta,
        convertedFromId.isAcceptableOrUnknown(
          data['converted_from_id']!,
          _convertedFromIdMeta,
        ),
      );
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    }
    if (data.containsKey('is_advance_payment')) {
      context.handle(
        _isAdvancePaymentMeta,
        isAdvancePayment.isAcceptableOrUnknown(
          data['is_advance_payment']!,
          _isAdvancePaymentMeta,
        ),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('paid_at')) {
      context.handle(
        _paidAtMeta,
        paidAt.isAcceptableOrUnknown(data['paid_at']!, _paidAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Invoice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Invoice(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      )!,
      kind: $InvoicesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      status: $InvoicesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      invoiceNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice_number'],
      ),
      numberYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number_year'],
      ),
      issueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}issue_date'],
      )!,
      serviceDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}service_date'],
      )!,
      paymentTerms: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_terms'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      customerSnapshotName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_snapshot_name'],
      ),
      customerSnapshotAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_snapshot_address'],
      ),
      customerSnapshotVatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_snapshot_vat_id'],
      ),
      companySnapshotName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_snapshot_name'],
      ),
      companySnapshotAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_snapshot_address'],
      ),
      companySnapshotTaxNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_snapshot_tax_number'],
      ),
      companySnapshotVatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_snapshot_vat_id'],
      ),
      companySnapshotIban: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_snapshot_iban'],
      ),
      pdfIntroTextSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_intro_text_snapshot'],
      ),
      pdfClosingTextSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_closing_text_snapshot'],
      ),
      pdfFooterTextSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pdf_footer_text_snapshot'],
      ),
      finalizedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finalized_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      convertedFromId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}converted_from_id'],
      ),
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      ),
      isAdvancePayment: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_advance_payment'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      paymentStatus: $InvoicesTable.$converterpaymentStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}payment_status'],
        )!,
      ),
      paidAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}paid_at'],
      ),
    );
  }

  @override
  $InvoicesTable createAlias(String alias) {
    return $InvoicesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DocumentKind, String, String> $converterkind =
      const EnumNameConverter<DocumentKind>(DocumentKind.values);
  static JsonTypeConverter2<InvoiceStatus, String, String> $converterstatus =
      const EnumNameConverter<InvoiceStatus>(InvoiceStatus.values);
  static JsonTypeConverter2<PaymentStatus, String, String>
  $converterpaymentStatus = const EnumNameConverter<PaymentStatus>(
    PaymentStatus.values,
  );
}

class Invoice extends DataClass implements Insertable<Invoice> {
  final String id;
  final String companyId;
  final String customerId;

  /// Default `invoice` für Bestandsdaten vor A5 (Migration, siehe
  /// `database.dart`).
  final DocumentKind kind;
  final InvoiceStatus status;

  /// Vollständige Dokumentnummer, z. B. "R-26054". `null`, solange die
  /// Rechnung ein Entwurf ist.
  final String? invoiceNumber;

  /// Jahr des Nummernkreises (Finalisierungszeitpunkt, siehe F3). `null`
  /// im Entwurf.
  final int? numberYear;
  final DateTime issueDate;

  /// Leistungsdatum/-zeitraum-Beginn (F1-Pflichtangabe).
  final DateTime serviceDate;
  final String? paymentTerms;
  final String? notes;

  /// Kundendaten-Schnappschuss zum Finalisierungszeitpunkt (Roadmap A1:
  /// spätere Stammdatenänderungen dürfen finalisierte PDFs nicht
  /// verändern). `null` im Entwurf — dort wird live aus [Customers]
  /// gelesen.
  final String? customerSnapshotName;
  final String? customerSnapshotAddress;
  final String? customerSnapshotVatId;

  /// Firmendaten-Schnappschuss zum Finalisierungszeitpunkt, aus demselben
  /// Grund wie der Kunden-Schnappschuss.
  final String? companySnapshotName;
  final String? companySnapshotAddress;
  final String? companySnapshotTaxNumber;
  final String? companySnapshotVatId;
  final String? companySnapshotIban;

  /// PDF-Text-Schnappschuss zum Finalisierungszeitpunkt (Audit-Befund
  /// 2026-10-17, `Abweichungen.md` Abschnitt 2.1: "Ein später geänderter
  /// Text kann bei erneutem Teilen eine andere PDF-Fassung derselben
  /// finalisierten Rechnung erzeugen"). `buildInvoicePdf()` liest für
  /// finalisierte Dokumente **ausschließlich** diese drei Felder statt
  /// der aktuellen, möglicherweise seither geänderten Firmeneinstellungen
  /// — das PDF einer finalisierten Rechnung bleibt dadurch über die Zeit
  /// byte-identisch reproduzierbar, ohne die Texte selbst als Datei/BLOB
  /// archivieren zu müssen. `null` im Entwurf — dort gilt weiterhin live
  /// aus [Companies] gelesen (siehe `buildDraftPreviewPdf`).
  final String? pdfIntroTextSnapshot;
  final String? pdfClosingTextSnapshot;
  final String? pdfFooterTextSnapshot;
  final DateTime? finalizedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Zeigt auf das **Quelldokument**, aus dem diese Zeile per
  /// `InvoiceRepository.convertTo()` erzeugt wurde (Kay-Nachtrag
  /// 2026-10-16: "Finalisierte Dokumente muss man wandeln können —
  /// Angebot in Auftrag, Lieferschein oder Rechnung"). `null` für
  /// eigenständig angelegte Dokumente. Bewusst ein einziges rückwärts
  /// zeigendes Feld statt eines eigenen Fremdschlüssels je möglicher
  /// Zielart (wie bei RechnungsFee) — ein Angebot kann so sowohl in
  /// einen Auftrag **als auch** separat in einen Lieferschein
  /// umgewandelt werden, beide neuen Zeilen zeigen einfach auf
  /// dasselbe Quelldokument zurück; `onDelete: setNull` ist nur
  /// defensiv, finalisierte Dokumente werden in der UI nie gelöscht.
  final String? convertedFromId;

  /// C1 Projekte — optionale Zuordnung zu einem Projekt, über alle
  /// [DocumentKind]s hinweg nutzbar. `onDelete: setNull` statt cascade:
  /// ein gelöschtes Projekt darf keine bereits finalisierten Dokumente
  /// mitlöschen, nur die Zuordnung entfällt.
  final String? projectId;

  /// C13 Abschlagsrechnungen (Kay-Priorisierungsentscheidung 2026-10-17):
  /// markiert eine Rechnung als Abschlags-/Anzahlungsrechnung statt einer
  /// regulären (Schluss-)Rechnung. **Arbeitsvorgabe, keine Rechtsprüfung**
  /// (analog zu F1/F2 — siehe Roadmap C13): nach gängiger deutscher
  /// Rechnungspraxis weist eine Abschlagsrechnung ihre eigene USt
  /// vollständig aus (keine aufgeschobene Steuer bis zur Schlussrechnung);
  /// die Schlussrechnung rechnet den Gesamtwert ab und zieht bereits
  /// gestellte, finalisierte Abschläge **inklusive** ihrer USt wieder ab
  /// (siehe `InvoiceRepository.sumAdvancePaymentsForOrder()`). Nur bei
  /// `kind == invoice` sinnvoll — Angebot/Auftrag/Lieferschein/Proforma
  /// kennen dieses Feld, setzen es aber nie.
  final bool isAdvancePayment;

  /// C12 Mahnwesen (Kay-Priorisierungsentscheidung 2026-10-17): optionales
  /// Fälligkeitsdatum, vom Nutzer im Entwurf gesetzt. `null` = keine
  /// Fälligkeitsüberwachung für dieses Dokument. Nur bei `kind ==
  /// invoice` sinnvoll — siehe `domain/services/dunning_service.dart`
  /// für die reine Anzeige-Berechnung der Mahnstufe daraus (keine
  /// Mahngebühr/Verzugszins-Berechnung, das braucht eine eigene
  /// rechtliche Prüfung nach §286/288 BGB, siehe Roadmap C12).
  final DateTime? dueDate;

  /// C12 Mahnwesen: reiner, **manuell** gesetzter Zahlungsstatus — kein
  /// Bankabgleich/automatische Zahlungserfassung (das ist C7, eigenes
  /// Entscheidungstor). Bewusst binär (offen/bezahlt), keine
  /// Teilzahlungen.
  final PaymentStatus paymentStatus;
  final DateTime? paidAt;
  const Invoice({
    required this.id,
    required this.companyId,
    required this.customerId,
    required this.kind,
    required this.status,
    this.invoiceNumber,
    this.numberYear,
    required this.issueDate,
    required this.serviceDate,
    this.paymentTerms,
    this.notes,
    this.customerSnapshotName,
    this.customerSnapshotAddress,
    this.customerSnapshotVatId,
    this.companySnapshotName,
    this.companySnapshotAddress,
    this.companySnapshotTaxNumber,
    this.companySnapshotVatId,
    this.companySnapshotIban,
    this.pdfIntroTextSnapshot,
    this.pdfClosingTextSnapshot,
    this.pdfFooterTextSnapshot,
    this.finalizedAt,
    required this.createdAt,
    required this.updatedAt,
    this.convertedFromId,
    this.projectId,
    required this.isAdvancePayment,
    this.dueDate,
    required this.paymentStatus,
    this.paidAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['customer_id'] = Variable<String>(customerId);
    {
      map['kind'] = Variable<String>($InvoicesTable.$converterkind.toSql(kind));
    }
    {
      map['status'] = Variable<String>(
        $InvoicesTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || invoiceNumber != null) {
      map['invoice_number'] = Variable<String>(invoiceNumber);
    }
    if (!nullToAbsent || numberYear != null) {
      map['number_year'] = Variable<int>(numberYear);
    }
    map['issue_date'] = Variable<DateTime>(issueDate);
    map['service_date'] = Variable<DateTime>(serviceDate);
    if (!nullToAbsent || paymentTerms != null) {
      map['payment_terms'] = Variable<String>(paymentTerms);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || customerSnapshotName != null) {
      map['customer_snapshot_name'] = Variable<String>(customerSnapshotName);
    }
    if (!nullToAbsent || customerSnapshotAddress != null) {
      map['customer_snapshot_address'] = Variable<String>(
        customerSnapshotAddress,
      );
    }
    if (!nullToAbsent || customerSnapshotVatId != null) {
      map['customer_snapshot_vat_id'] = Variable<String>(customerSnapshotVatId);
    }
    if (!nullToAbsent || companySnapshotName != null) {
      map['company_snapshot_name'] = Variable<String>(companySnapshotName);
    }
    if (!nullToAbsent || companySnapshotAddress != null) {
      map['company_snapshot_address'] = Variable<String>(
        companySnapshotAddress,
      );
    }
    if (!nullToAbsent || companySnapshotTaxNumber != null) {
      map['company_snapshot_tax_number'] = Variable<String>(
        companySnapshotTaxNumber,
      );
    }
    if (!nullToAbsent || companySnapshotVatId != null) {
      map['company_snapshot_vat_id'] = Variable<String>(companySnapshotVatId);
    }
    if (!nullToAbsent || companySnapshotIban != null) {
      map['company_snapshot_iban'] = Variable<String>(companySnapshotIban);
    }
    if (!nullToAbsent || pdfIntroTextSnapshot != null) {
      map['pdf_intro_text_snapshot'] = Variable<String>(pdfIntroTextSnapshot);
    }
    if (!nullToAbsent || pdfClosingTextSnapshot != null) {
      map['pdf_closing_text_snapshot'] = Variable<String>(
        pdfClosingTextSnapshot,
      );
    }
    if (!nullToAbsent || pdfFooterTextSnapshot != null) {
      map['pdf_footer_text_snapshot'] = Variable<String>(pdfFooterTextSnapshot);
    }
    if (!nullToAbsent || finalizedAt != null) {
      map['finalized_at'] = Variable<DateTime>(finalizedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || convertedFromId != null) {
      map['converted_from_id'] = Variable<String>(convertedFromId);
    }
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    map['is_advance_payment'] = Variable<bool>(isAdvancePayment);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    {
      map['payment_status'] = Variable<String>(
        $InvoicesTable.$converterpaymentStatus.toSql(paymentStatus),
      );
    }
    if (!nullToAbsent || paidAt != null) {
      map['paid_at'] = Variable<DateTime>(paidAt);
    }
    return map;
  }

  InvoicesCompanion toCompanion(bool nullToAbsent) {
    return InvoicesCompanion(
      id: Value(id),
      companyId: Value(companyId),
      customerId: Value(customerId),
      kind: Value(kind),
      status: Value(status),
      invoiceNumber: invoiceNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(invoiceNumber),
      numberYear: numberYear == null && nullToAbsent
          ? const Value.absent()
          : Value(numberYear),
      issueDate: Value(issueDate),
      serviceDate: Value(serviceDate),
      paymentTerms: paymentTerms == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentTerms),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      customerSnapshotName: customerSnapshotName == null && nullToAbsent
          ? const Value.absent()
          : Value(customerSnapshotName),
      customerSnapshotAddress: customerSnapshotAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(customerSnapshotAddress),
      customerSnapshotVatId: customerSnapshotVatId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerSnapshotVatId),
      companySnapshotName: companySnapshotName == null && nullToAbsent
          ? const Value.absent()
          : Value(companySnapshotName),
      companySnapshotAddress: companySnapshotAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(companySnapshotAddress),
      companySnapshotTaxNumber: companySnapshotTaxNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(companySnapshotTaxNumber),
      companySnapshotVatId: companySnapshotVatId == null && nullToAbsent
          ? const Value.absent()
          : Value(companySnapshotVatId),
      companySnapshotIban: companySnapshotIban == null && nullToAbsent
          ? const Value.absent()
          : Value(companySnapshotIban),
      pdfIntroTextSnapshot: pdfIntroTextSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfIntroTextSnapshot),
      pdfClosingTextSnapshot: pdfClosingTextSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfClosingTextSnapshot),
      pdfFooterTextSnapshot: pdfFooterTextSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfFooterTextSnapshot),
      finalizedAt: finalizedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finalizedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      convertedFromId: convertedFromId == null && nullToAbsent
          ? const Value.absent()
          : Value(convertedFromId),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      isAdvancePayment: Value(isAdvancePayment),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      paymentStatus: Value(paymentStatus),
      paidAt: paidAt == null && nullToAbsent
          ? const Value.absent()
          : Value(paidAt),
    );
  }

  factory Invoice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Invoice(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      customerId: serializer.fromJson<String>(json['customerId']),
      kind: $InvoicesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      status: $InvoicesTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      invoiceNumber: serializer.fromJson<String?>(json['invoiceNumber']),
      numberYear: serializer.fromJson<int?>(json['numberYear']),
      issueDate: serializer.fromJson<DateTime>(json['issueDate']),
      serviceDate: serializer.fromJson<DateTime>(json['serviceDate']),
      paymentTerms: serializer.fromJson<String?>(json['paymentTerms']),
      notes: serializer.fromJson<String?>(json['notes']),
      customerSnapshotName: serializer.fromJson<String?>(
        json['customerSnapshotName'],
      ),
      customerSnapshotAddress: serializer.fromJson<String?>(
        json['customerSnapshotAddress'],
      ),
      customerSnapshotVatId: serializer.fromJson<String?>(
        json['customerSnapshotVatId'],
      ),
      companySnapshotName: serializer.fromJson<String?>(
        json['companySnapshotName'],
      ),
      companySnapshotAddress: serializer.fromJson<String?>(
        json['companySnapshotAddress'],
      ),
      companySnapshotTaxNumber: serializer.fromJson<String?>(
        json['companySnapshotTaxNumber'],
      ),
      companySnapshotVatId: serializer.fromJson<String?>(
        json['companySnapshotVatId'],
      ),
      companySnapshotIban: serializer.fromJson<String?>(
        json['companySnapshotIban'],
      ),
      pdfIntroTextSnapshot: serializer.fromJson<String?>(
        json['pdfIntroTextSnapshot'],
      ),
      pdfClosingTextSnapshot: serializer.fromJson<String?>(
        json['pdfClosingTextSnapshot'],
      ),
      pdfFooterTextSnapshot: serializer.fromJson<String?>(
        json['pdfFooterTextSnapshot'],
      ),
      finalizedAt: serializer.fromJson<DateTime?>(json['finalizedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      convertedFromId: serializer.fromJson<String?>(json['convertedFromId']),
      projectId: serializer.fromJson<String?>(json['projectId']),
      isAdvancePayment: serializer.fromJson<bool>(json['isAdvancePayment']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      paymentStatus: $InvoicesTable.$converterpaymentStatus.fromJson(
        serializer.fromJson<String>(json['paymentStatus']),
      ),
      paidAt: serializer.fromJson<DateTime?>(json['paidAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'customerId': serializer.toJson<String>(customerId),
      'kind': serializer.toJson<String>(
        $InvoicesTable.$converterkind.toJson(kind),
      ),
      'status': serializer.toJson<String>(
        $InvoicesTable.$converterstatus.toJson(status),
      ),
      'invoiceNumber': serializer.toJson<String?>(invoiceNumber),
      'numberYear': serializer.toJson<int?>(numberYear),
      'issueDate': serializer.toJson<DateTime>(issueDate),
      'serviceDate': serializer.toJson<DateTime>(serviceDate),
      'paymentTerms': serializer.toJson<String?>(paymentTerms),
      'notes': serializer.toJson<String?>(notes),
      'customerSnapshotName': serializer.toJson<String?>(customerSnapshotName),
      'customerSnapshotAddress': serializer.toJson<String?>(
        customerSnapshotAddress,
      ),
      'customerSnapshotVatId': serializer.toJson<String?>(
        customerSnapshotVatId,
      ),
      'companySnapshotName': serializer.toJson<String?>(companySnapshotName),
      'companySnapshotAddress': serializer.toJson<String?>(
        companySnapshotAddress,
      ),
      'companySnapshotTaxNumber': serializer.toJson<String?>(
        companySnapshotTaxNumber,
      ),
      'companySnapshotVatId': serializer.toJson<String?>(companySnapshotVatId),
      'companySnapshotIban': serializer.toJson<String?>(companySnapshotIban),
      'pdfIntroTextSnapshot': serializer.toJson<String?>(pdfIntroTextSnapshot),
      'pdfClosingTextSnapshot': serializer.toJson<String?>(
        pdfClosingTextSnapshot,
      ),
      'pdfFooterTextSnapshot': serializer.toJson<String?>(
        pdfFooterTextSnapshot,
      ),
      'finalizedAt': serializer.toJson<DateTime?>(finalizedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'convertedFromId': serializer.toJson<String?>(convertedFromId),
      'projectId': serializer.toJson<String?>(projectId),
      'isAdvancePayment': serializer.toJson<bool>(isAdvancePayment),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'paymentStatus': serializer.toJson<String>(
        $InvoicesTable.$converterpaymentStatus.toJson(paymentStatus),
      ),
      'paidAt': serializer.toJson<DateTime?>(paidAt),
    };
  }

  Invoice copyWith({
    String? id,
    String? companyId,
    String? customerId,
    DocumentKind? kind,
    InvoiceStatus? status,
    Value<String?> invoiceNumber = const Value.absent(),
    Value<int?> numberYear = const Value.absent(),
    DateTime? issueDate,
    DateTime? serviceDate,
    Value<String?> paymentTerms = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> customerSnapshotName = const Value.absent(),
    Value<String?> customerSnapshotAddress = const Value.absent(),
    Value<String?> customerSnapshotVatId = const Value.absent(),
    Value<String?> companySnapshotName = const Value.absent(),
    Value<String?> companySnapshotAddress = const Value.absent(),
    Value<String?> companySnapshotTaxNumber = const Value.absent(),
    Value<String?> companySnapshotVatId = const Value.absent(),
    Value<String?> companySnapshotIban = const Value.absent(),
    Value<String?> pdfIntroTextSnapshot = const Value.absent(),
    Value<String?> pdfClosingTextSnapshot = const Value.absent(),
    Value<String?> pdfFooterTextSnapshot = const Value.absent(),
    Value<DateTime?> finalizedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> convertedFromId = const Value.absent(),
    Value<String?> projectId = const Value.absent(),
    bool? isAdvancePayment,
    Value<DateTime?> dueDate = const Value.absent(),
    PaymentStatus? paymentStatus,
    Value<DateTime?> paidAt = const Value.absent(),
  }) => Invoice(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    customerId: customerId ?? this.customerId,
    kind: kind ?? this.kind,
    status: status ?? this.status,
    invoiceNumber: invoiceNumber.present
        ? invoiceNumber.value
        : this.invoiceNumber,
    numberYear: numberYear.present ? numberYear.value : this.numberYear,
    issueDate: issueDate ?? this.issueDate,
    serviceDate: serviceDate ?? this.serviceDate,
    paymentTerms: paymentTerms.present ? paymentTerms.value : this.paymentTerms,
    notes: notes.present ? notes.value : this.notes,
    customerSnapshotName: customerSnapshotName.present
        ? customerSnapshotName.value
        : this.customerSnapshotName,
    customerSnapshotAddress: customerSnapshotAddress.present
        ? customerSnapshotAddress.value
        : this.customerSnapshotAddress,
    customerSnapshotVatId: customerSnapshotVatId.present
        ? customerSnapshotVatId.value
        : this.customerSnapshotVatId,
    companySnapshotName: companySnapshotName.present
        ? companySnapshotName.value
        : this.companySnapshotName,
    companySnapshotAddress: companySnapshotAddress.present
        ? companySnapshotAddress.value
        : this.companySnapshotAddress,
    companySnapshotTaxNumber: companySnapshotTaxNumber.present
        ? companySnapshotTaxNumber.value
        : this.companySnapshotTaxNumber,
    companySnapshotVatId: companySnapshotVatId.present
        ? companySnapshotVatId.value
        : this.companySnapshotVatId,
    companySnapshotIban: companySnapshotIban.present
        ? companySnapshotIban.value
        : this.companySnapshotIban,
    pdfIntroTextSnapshot: pdfIntroTextSnapshot.present
        ? pdfIntroTextSnapshot.value
        : this.pdfIntroTextSnapshot,
    pdfClosingTextSnapshot: pdfClosingTextSnapshot.present
        ? pdfClosingTextSnapshot.value
        : this.pdfClosingTextSnapshot,
    pdfFooterTextSnapshot: pdfFooterTextSnapshot.present
        ? pdfFooterTextSnapshot.value
        : this.pdfFooterTextSnapshot,
    finalizedAt: finalizedAt.present ? finalizedAt.value : this.finalizedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    convertedFromId: convertedFromId.present
        ? convertedFromId.value
        : this.convertedFromId,
    projectId: projectId.present ? projectId.value : this.projectId,
    isAdvancePayment: isAdvancePayment ?? this.isAdvancePayment,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    paidAt: paidAt.present ? paidAt.value : this.paidAt,
  );
  Invoice copyWithCompanion(InvoicesCompanion data) {
    return Invoice(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      kind: data.kind.present ? data.kind.value : this.kind,
      status: data.status.present ? data.status.value : this.status,
      invoiceNumber: data.invoiceNumber.present
          ? data.invoiceNumber.value
          : this.invoiceNumber,
      numberYear: data.numberYear.present
          ? data.numberYear.value
          : this.numberYear,
      issueDate: data.issueDate.present ? data.issueDate.value : this.issueDate,
      serviceDate: data.serviceDate.present
          ? data.serviceDate.value
          : this.serviceDate,
      paymentTerms: data.paymentTerms.present
          ? data.paymentTerms.value
          : this.paymentTerms,
      notes: data.notes.present ? data.notes.value : this.notes,
      customerSnapshotName: data.customerSnapshotName.present
          ? data.customerSnapshotName.value
          : this.customerSnapshotName,
      customerSnapshotAddress: data.customerSnapshotAddress.present
          ? data.customerSnapshotAddress.value
          : this.customerSnapshotAddress,
      customerSnapshotVatId: data.customerSnapshotVatId.present
          ? data.customerSnapshotVatId.value
          : this.customerSnapshotVatId,
      companySnapshotName: data.companySnapshotName.present
          ? data.companySnapshotName.value
          : this.companySnapshotName,
      companySnapshotAddress: data.companySnapshotAddress.present
          ? data.companySnapshotAddress.value
          : this.companySnapshotAddress,
      companySnapshotTaxNumber: data.companySnapshotTaxNumber.present
          ? data.companySnapshotTaxNumber.value
          : this.companySnapshotTaxNumber,
      companySnapshotVatId: data.companySnapshotVatId.present
          ? data.companySnapshotVatId.value
          : this.companySnapshotVatId,
      companySnapshotIban: data.companySnapshotIban.present
          ? data.companySnapshotIban.value
          : this.companySnapshotIban,
      pdfIntroTextSnapshot: data.pdfIntroTextSnapshot.present
          ? data.pdfIntroTextSnapshot.value
          : this.pdfIntroTextSnapshot,
      pdfClosingTextSnapshot: data.pdfClosingTextSnapshot.present
          ? data.pdfClosingTextSnapshot.value
          : this.pdfClosingTextSnapshot,
      pdfFooterTextSnapshot: data.pdfFooterTextSnapshot.present
          ? data.pdfFooterTextSnapshot.value
          : this.pdfFooterTextSnapshot,
      finalizedAt: data.finalizedAt.present
          ? data.finalizedAt.value
          : this.finalizedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      convertedFromId: data.convertedFromId.present
          ? data.convertedFromId.value
          : this.convertedFromId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      isAdvancePayment: data.isAdvancePayment.present
          ? data.isAdvancePayment.value
          : this.isAdvancePayment,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      paymentStatus: data.paymentStatus.present
          ? data.paymentStatus.value
          : this.paymentStatus,
      paidAt: data.paidAt.present ? data.paidAt.value : this.paidAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Invoice(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('customerId: $customerId, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('invoiceNumber: $invoiceNumber, ')
          ..write('numberYear: $numberYear, ')
          ..write('issueDate: $issueDate, ')
          ..write('serviceDate: $serviceDate, ')
          ..write('paymentTerms: $paymentTerms, ')
          ..write('notes: $notes, ')
          ..write('customerSnapshotName: $customerSnapshotName, ')
          ..write('customerSnapshotAddress: $customerSnapshotAddress, ')
          ..write('customerSnapshotVatId: $customerSnapshotVatId, ')
          ..write('companySnapshotName: $companySnapshotName, ')
          ..write('companySnapshotAddress: $companySnapshotAddress, ')
          ..write('companySnapshotTaxNumber: $companySnapshotTaxNumber, ')
          ..write('companySnapshotVatId: $companySnapshotVatId, ')
          ..write('companySnapshotIban: $companySnapshotIban, ')
          ..write('pdfIntroTextSnapshot: $pdfIntroTextSnapshot, ')
          ..write('pdfClosingTextSnapshot: $pdfClosingTextSnapshot, ')
          ..write('pdfFooterTextSnapshot: $pdfFooterTextSnapshot, ')
          ..write('finalizedAt: $finalizedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('convertedFromId: $convertedFromId, ')
          ..write('projectId: $projectId, ')
          ..write('isAdvancePayment: $isAdvancePayment, ')
          ..write('dueDate: $dueDate, ')
          ..write('paymentStatus: $paymentStatus, ')
          ..write('paidAt: $paidAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    companyId,
    customerId,
    kind,
    status,
    invoiceNumber,
    numberYear,
    issueDate,
    serviceDate,
    paymentTerms,
    notes,
    customerSnapshotName,
    customerSnapshotAddress,
    customerSnapshotVatId,
    companySnapshotName,
    companySnapshotAddress,
    companySnapshotTaxNumber,
    companySnapshotVatId,
    companySnapshotIban,
    pdfIntroTextSnapshot,
    pdfClosingTextSnapshot,
    pdfFooterTextSnapshot,
    finalizedAt,
    createdAt,
    updatedAt,
    convertedFromId,
    projectId,
    isAdvancePayment,
    dueDate,
    paymentStatus,
    paidAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Invoice &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.customerId == this.customerId &&
          other.kind == this.kind &&
          other.status == this.status &&
          other.invoiceNumber == this.invoiceNumber &&
          other.numberYear == this.numberYear &&
          other.issueDate == this.issueDate &&
          other.serviceDate == this.serviceDate &&
          other.paymentTerms == this.paymentTerms &&
          other.notes == this.notes &&
          other.customerSnapshotName == this.customerSnapshotName &&
          other.customerSnapshotAddress == this.customerSnapshotAddress &&
          other.customerSnapshotVatId == this.customerSnapshotVatId &&
          other.companySnapshotName == this.companySnapshotName &&
          other.companySnapshotAddress == this.companySnapshotAddress &&
          other.companySnapshotTaxNumber == this.companySnapshotTaxNumber &&
          other.companySnapshotVatId == this.companySnapshotVatId &&
          other.companySnapshotIban == this.companySnapshotIban &&
          other.pdfIntroTextSnapshot == this.pdfIntroTextSnapshot &&
          other.pdfClosingTextSnapshot == this.pdfClosingTextSnapshot &&
          other.pdfFooterTextSnapshot == this.pdfFooterTextSnapshot &&
          other.finalizedAt == this.finalizedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.convertedFromId == this.convertedFromId &&
          other.projectId == this.projectId &&
          other.isAdvancePayment == this.isAdvancePayment &&
          other.dueDate == this.dueDate &&
          other.paymentStatus == this.paymentStatus &&
          other.paidAt == this.paidAt);
}

class InvoicesCompanion extends UpdateCompanion<Invoice> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> customerId;
  final Value<DocumentKind> kind;
  final Value<InvoiceStatus> status;
  final Value<String?> invoiceNumber;
  final Value<int?> numberYear;
  final Value<DateTime> issueDate;
  final Value<DateTime> serviceDate;
  final Value<String?> paymentTerms;
  final Value<String?> notes;
  final Value<String?> customerSnapshotName;
  final Value<String?> customerSnapshotAddress;
  final Value<String?> customerSnapshotVatId;
  final Value<String?> companySnapshotName;
  final Value<String?> companySnapshotAddress;
  final Value<String?> companySnapshotTaxNumber;
  final Value<String?> companySnapshotVatId;
  final Value<String?> companySnapshotIban;
  final Value<String?> pdfIntroTextSnapshot;
  final Value<String?> pdfClosingTextSnapshot;
  final Value<String?> pdfFooterTextSnapshot;
  final Value<DateTime?> finalizedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> convertedFromId;
  final Value<String?> projectId;
  final Value<bool> isAdvancePayment;
  final Value<DateTime?> dueDate;
  final Value<PaymentStatus> paymentStatus;
  final Value<DateTime?> paidAt;
  final Value<int> rowid;
  const InvoicesCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.customerId = const Value.absent(),
    this.kind = const Value.absent(),
    this.status = const Value.absent(),
    this.invoiceNumber = const Value.absent(),
    this.numberYear = const Value.absent(),
    this.issueDate = const Value.absent(),
    this.serviceDate = const Value.absent(),
    this.paymentTerms = const Value.absent(),
    this.notes = const Value.absent(),
    this.customerSnapshotName = const Value.absent(),
    this.customerSnapshotAddress = const Value.absent(),
    this.customerSnapshotVatId = const Value.absent(),
    this.companySnapshotName = const Value.absent(),
    this.companySnapshotAddress = const Value.absent(),
    this.companySnapshotTaxNumber = const Value.absent(),
    this.companySnapshotVatId = const Value.absent(),
    this.companySnapshotIban = const Value.absent(),
    this.pdfIntroTextSnapshot = const Value.absent(),
    this.pdfClosingTextSnapshot = const Value.absent(),
    this.pdfFooterTextSnapshot = const Value.absent(),
    this.finalizedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.convertedFromId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.isAdvancePayment = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.paymentStatus = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InvoicesCompanion.insert({
    required String id,
    required String companyId,
    required String customerId,
    this.kind = const Value.absent(),
    required InvoiceStatus status,
    this.invoiceNumber = const Value.absent(),
    this.numberYear = const Value.absent(),
    required DateTime issueDate,
    required DateTime serviceDate,
    this.paymentTerms = const Value.absent(),
    this.notes = const Value.absent(),
    this.customerSnapshotName = const Value.absent(),
    this.customerSnapshotAddress = const Value.absent(),
    this.customerSnapshotVatId = const Value.absent(),
    this.companySnapshotName = const Value.absent(),
    this.companySnapshotAddress = const Value.absent(),
    this.companySnapshotTaxNumber = const Value.absent(),
    this.companySnapshotVatId = const Value.absent(),
    this.companySnapshotIban = const Value.absent(),
    this.pdfIntroTextSnapshot = const Value.absent(),
    this.pdfClosingTextSnapshot = const Value.absent(),
    this.pdfFooterTextSnapshot = const Value.absent(),
    this.finalizedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.convertedFromId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.isAdvancePayment = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.paymentStatus = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       customerId = Value(customerId),
       status = Value(status),
       issueDate = Value(issueDate),
       serviceDate = Value(serviceDate),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Invoice> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? customerId,
    Expression<String>? kind,
    Expression<String>? status,
    Expression<String>? invoiceNumber,
    Expression<int>? numberYear,
    Expression<DateTime>? issueDate,
    Expression<DateTime>? serviceDate,
    Expression<String>? paymentTerms,
    Expression<String>? notes,
    Expression<String>? customerSnapshotName,
    Expression<String>? customerSnapshotAddress,
    Expression<String>? customerSnapshotVatId,
    Expression<String>? companySnapshotName,
    Expression<String>? companySnapshotAddress,
    Expression<String>? companySnapshotTaxNumber,
    Expression<String>? companySnapshotVatId,
    Expression<String>? companySnapshotIban,
    Expression<String>? pdfIntroTextSnapshot,
    Expression<String>? pdfClosingTextSnapshot,
    Expression<String>? pdfFooterTextSnapshot,
    Expression<DateTime>? finalizedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? convertedFromId,
    Expression<String>? projectId,
    Expression<bool>? isAdvancePayment,
    Expression<DateTime>? dueDate,
    Expression<String>? paymentStatus,
    Expression<DateTime>? paidAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (customerId != null) 'customer_id': customerId,
      if (kind != null) 'kind': kind,
      if (status != null) 'status': status,
      if (invoiceNumber != null) 'invoice_number': invoiceNumber,
      if (numberYear != null) 'number_year': numberYear,
      if (issueDate != null) 'issue_date': issueDate,
      if (serviceDate != null) 'service_date': serviceDate,
      if (paymentTerms != null) 'payment_terms': paymentTerms,
      if (notes != null) 'notes': notes,
      if (customerSnapshotName != null)
        'customer_snapshot_name': customerSnapshotName,
      if (customerSnapshotAddress != null)
        'customer_snapshot_address': customerSnapshotAddress,
      if (customerSnapshotVatId != null)
        'customer_snapshot_vat_id': customerSnapshotVatId,
      if (companySnapshotName != null)
        'company_snapshot_name': companySnapshotName,
      if (companySnapshotAddress != null)
        'company_snapshot_address': companySnapshotAddress,
      if (companySnapshotTaxNumber != null)
        'company_snapshot_tax_number': companySnapshotTaxNumber,
      if (companySnapshotVatId != null)
        'company_snapshot_vat_id': companySnapshotVatId,
      if (companySnapshotIban != null)
        'company_snapshot_iban': companySnapshotIban,
      if (pdfIntroTextSnapshot != null)
        'pdf_intro_text_snapshot': pdfIntroTextSnapshot,
      if (pdfClosingTextSnapshot != null)
        'pdf_closing_text_snapshot': pdfClosingTextSnapshot,
      if (pdfFooterTextSnapshot != null)
        'pdf_footer_text_snapshot': pdfFooterTextSnapshot,
      if (finalizedAt != null) 'finalized_at': finalizedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (convertedFromId != null) 'converted_from_id': convertedFromId,
      if (projectId != null) 'project_id': projectId,
      if (isAdvancePayment != null) 'is_advance_payment': isAdvancePayment,
      if (dueDate != null) 'due_date': dueDate,
      if (paymentStatus != null) 'payment_status': paymentStatus,
      if (paidAt != null) 'paid_at': paidAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InvoicesCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? customerId,
    Value<DocumentKind>? kind,
    Value<InvoiceStatus>? status,
    Value<String?>? invoiceNumber,
    Value<int?>? numberYear,
    Value<DateTime>? issueDate,
    Value<DateTime>? serviceDate,
    Value<String?>? paymentTerms,
    Value<String?>? notes,
    Value<String?>? customerSnapshotName,
    Value<String?>? customerSnapshotAddress,
    Value<String?>? customerSnapshotVatId,
    Value<String?>? companySnapshotName,
    Value<String?>? companySnapshotAddress,
    Value<String?>? companySnapshotTaxNumber,
    Value<String?>? companySnapshotVatId,
    Value<String?>? companySnapshotIban,
    Value<String?>? pdfIntroTextSnapshot,
    Value<String?>? pdfClosingTextSnapshot,
    Value<String?>? pdfFooterTextSnapshot,
    Value<DateTime?>? finalizedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? convertedFromId,
    Value<String?>? projectId,
    Value<bool>? isAdvancePayment,
    Value<DateTime?>? dueDate,
    Value<PaymentStatus>? paymentStatus,
    Value<DateTime?>? paidAt,
    Value<int>? rowid,
  }) {
    return InvoicesCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      customerId: customerId ?? this.customerId,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      numberYear: numberYear ?? this.numberYear,
      issueDate: issueDate ?? this.issueDate,
      serviceDate: serviceDate ?? this.serviceDate,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      notes: notes ?? this.notes,
      customerSnapshotName: customerSnapshotName ?? this.customerSnapshotName,
      customerSnapshotAddress:
          customerSnapshotAddress ?? this.customerSnapshotAddress,
      customerSnapshotVatId:
          customerSnapshotVatId ?? this.customerSnapshotVatId,
      companySnapshotName: companySnapshotName ?? this.companySnapshotName,
      companySnapshotAddress:
          companySnapshotAddress ?? this.companySnapshotAddress,
      companySnapshotTaxNumber:
          companySnapshotTaxNumber ?? this.companySnapshotTaxNumber,
      companySnapshotVatId: companySnapshotVatId ?? this.companySnapshotVatId,
      companySnapshotIban: companySnapshotIban ?? this.companySnapshotIban,
      pdfIntroTextSnapshot: pdfIntroTextSnapshot ?? this.pdfIntroTextSnapshot,
      pdfClosingTextSnapshot:
          pdfClosingTextSnapshot ?? this.pdfClosingTextSnapshot,
      pdfFooterTextSnapshot:
          pdfFooterTextSnapshot ?? this.pdfFooterTextSnapshot,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      convertedFromId: convertedFromId ?? this.convertedFromId,
      projectId: projectId ?? this.projectId,
      isAdvancePayment: isAdvancePayment ?? this.isAdvancePayment,
      dueDate: dueDate ?? this.dueDate,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paidAt: paidAt ?? this.paidAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $InvoicesTable.$converterkind.toSql(kind.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $InvoicesTable.$converterstatus.toSql(status.value),
      );
    }
    if (invoiceNumber.present) {
      map['invoice_number'] = Variable<String>(invoiceNumber.value);
    }
    if (numberYear.present) {
      map['number_year'] = Variable<int>(numberYear.value);
    }
    if (issueDate.present) {
      map['issue_date'] = Variable<DateTime>(issueDate.value);
    }
    if (serviceDate.present) {
      map['service_date'] = Variable<DateTime>(serviceDate.value);
    }
    if (paymentTerms.present) {
      map['payment_terms'] = Variable<String>(paymentTerms.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (customerSnapshotName.present) {
      map['customer_snapshot_name'] = Variable<String>(
        customerSnapshotName.value,
      );
    }
    if (customerSnapshotAddress.present) {
      map['customer_snapshot_address'] = Variable<String>(
        customerSnapshotAddress.value,
      );
    }
    if (customerSnapshotVatId.present) {
      map['customer_snapshot_vat_id'] = Variable<String>(
        customerSnapshotVatId.value,
      );
    }
    if (companySnapshotName.present) {
      map['company_snapshot_name'] = Variable<String>(
        companySnapshotName.value,
      );
    }
    if (companySnapshotAddress.present) {
      map['company_snapshot_address'] = Variable<String>(
        companySnapshotAddress.value,
      );
    }
    if (companySnapshotTaxNumber.present) {
      map['company_snapshot_tax_number'] = Variable<String>(
        companySnapshotTaxNumber.value,
      );
    }
    if (companySnapshotVatId.present) {
      map['company_snapshot_vat_id'] = Variable<String>(
        companySnapshotVatId.value,
      );
    }
    if (companySnapshotIban.present) {
      map['company_snapshot_iban'] = Variable<String>(
        companySnapshotIban.value,
      );
    }
    if (pdfIntroTextSnapshot.present) {
      map['pdf_intro_text_snapshot'] = Variable<String>(
        pdfIntroTextSnapshot.value,
      );
    }
    if (pdfClosingTextSnapshot.present) {
      map['pdf_closing_text_snapshot'] = Variable<String>(
        pdfClosingTextSnapshot.value,
      );
    }
    if (pdfFooterTextSnapshot.present) {
      map['pdf_footer_text_snapshot'] = Variable<String>(
        pdfFooterTextSnapshot.value,
      );
    }
    if (finalizedAt.present) {
      map['finalized_at'] = Variable<DateTime>(finalizedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (convertedFromId.present) {
      map['converted_from_id'] = Variable<String>(convertedFromId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (isAdvancePayment.present) {
      map['is_advance_payment'] = Variable<bool>(isAdvancePayment.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (paymentStatus.present) {
      map['payment_status'] = Variable<String>(
        $InvoicesTable.$converterpaymentStatus.toSql(paymentStatus.value),
      );
    }
    if (paidAt.present) {
      map['paid_at'] = Variable<DateTime>(paidAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InvoicesCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('customerId: $customerId, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('invoiceNumber: $invoiceNumber, ')
          ..write('numberYear: $numberYear, ')
          ..write('issueDate: $issueDate, ')
          ..write('serviceDate: $serviceDate, ')
          ..write('paymentTerms: $paymentTerms, ')
          ..write('notes: $notes, ')
          ..write('customerSnapshotName: $customerSnapshotName, ')
          ..write('customerSnapshotAddress: $customerSnapshotAddress, ')
          ..write('customerSnapshotVatId: $customerSnapshotVatId, ')
          ..write('companySnapshotName: $companySnapshotName, ')
          ..write('companySnapshotAddress: $companySnapshotAddress, ')
          ..write('companySnapshotTaxNumber: $companySnapshotTaxNumber, ')
          ..write('companySnapshotVatId: $companySnapshotVatId, ')
          ..write('companySnapshotIban: $companySnapshotIban, ')
          ..write('pdfIntroTextSnapshot: $pdfIntroTextSnapshot, ')
          ..write('pdfClosingTextSnapshot: $pdfClosingTextSnapshot, ')
          ..write('pdfFooterTextSnapshot: $pdfFooterTextSnapshot, ')
          ..write('finalizedAt: $finalizedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('convertedFromId: $convertedFromId, ')
          ..write('projectId: $projectId, ')
          ..write('isAdvancePayment: $isAdvancePayment, ')
          ..write('dueDate: $dueDate, ')
          ..write('paymentStatus: $paymentStatus, ')
          ..write('paidAt: $paidAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InvoiceItemsTable extends InvoiceItems
    with TableInfo<$InvoiceItemsTable, InvoiceItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvoiceItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _invoiceIdMeta = const VerificationMeta(
    'invoiceId',
  );
  @override
  late final GeneratedColumn<String> invoiceId = GeneratedColumn<String>(
    'invoice_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES invoices (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<InvoiceItemKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<InvoiceItemKind>($InvoiceItemsTable.$converterkind);
  static const VerificationMeta _articleIdMeta = const VerificationMeta(
    'articleId',
  );
  @override
  late final GeneratedColumn<String> articleId = GeneratedColumn<String>(
    'article_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES articles (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<String> quantity = GeneratedColumn<String>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitPriceCentsMeta = const VerificationMeta(
    'unitPriceCents',
  );
  @override
  late final GeneratedColumn<int> unitPriceCents = GeneratedColumn<int>(
    'unit_price_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vatRatePercentMeta = const VerificationMeta(
    'vatRatePercent',
  );
  @override
  late final GeneratedColumn<double> vatRatePercent = GeneratedColumn<double>(
    'vat_rate_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discountPercentMeta = const VerificationMeta(
    'discountPercent',
  );
  @override
  late final GeneratedColumn<double> discountPercent = GeneratedColumn<double>(
    'discount_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _groupLabelMeta = const VerificationMeta(
    'groupLabel',
  );
  @override
  late final GeneratedColumn<String> groupLabel = GeneratedColumn<String>(
    'group_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    invoiceId,
    kind,
    articleId,
    description,
    quantity,
    unitPriceCents,
    vatRatePercent,
    unit,
    discountPercent,
    groupLabel,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'invoice_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<InvoiceItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('invoice_id')) {
      context.handle(
        _invoiceIdMeta,
        invoiceId.isAcceptableOrUnknown(data['invoice_id']!, _invoiceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_invoiceIdMeta);
    }
    if (data.containsKey('article_id')) {
      context.handle(
        _articleIdMeta,
        articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit_price_cents')) {
      context.handle(
        _unitPriceCentsMeta,
        unitPriceCents.isAcceptableOrUnknown(
          data['unit_price_cents']!,
          _unitPriceCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unitPriceCentsMeta);
    }
    if (data.containsKey('vat_rate_percent')) {
      context.handle(
        _vatRatePercentMeta,
        vatRatePercent.isAcceptableOrUnknown(
          data['vat_rate_percent']!,
          _vatRatePercentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_vatRatePercentMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('discount_percent')) {
      context.handle(
        _discountPercentMeta,
        discountPercent.isAcceptableOrUnknown(
          data['discount_percent']!,
          _discountPercentMeta,
        ),
      );
    }
    if (data.containsKey('group_label')) {
      context.handle(
        _groupLabelMeta,
        groupLabel.isAcceptableOrUnknown(data['group_label']!, _groupLabelMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InvoiceItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InvoiceItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      invoiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice_id'],
      )!,
      kind: $InvoiceItemsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      articleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article_id'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quantity'],
      )!,
      unitPriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_price_cents'],
      )!,
      vatRatePercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}vat_rate_percent'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
      discountPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}discount_percent'],
      )!,
      groupLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_label'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $InvoiceItemsTable createAlias(String alias) {
    return $InvoiceItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<InvoiceItemKind, String, String> $converterkind =
      const EnumNameConverter<InvoiceItemKind>(InvoiceItemKind.values);
}

class InvoiceItem extends DataClass implements Insertable<InvoiceItem> {
  final String id;
  final String invoiceId;
  final InvoiceItemKind kind;
  final String? articleId;
  final String description;

  /// Menge — Dezimalwert als Text gespeichert (siehe [Money]/Decimal-
  /// Nutzung, F2: keine Binär-Floats für Geld-/Mengenwerte).
  final String quantity;
  final int unitPriceCents;
  final double vatRatePercent;

  /// Einheit (z. B. "Stk", "h", "m", "pauschal") — Kay-Nachtrag
  /// 2026-10-16: "Es fehlen Details" beim Vergleich mit RechnungsFee.
  /// `null` = keine Einheit angegeben (z. B. Freitext-Pauschalposten).
  final String? unit;

  /// Rabatt in Prozent auf diese Position (Kay-Nachtrag 2026-10-16,
  /// analog zu RechnungsFees `rabatt_prozent` — nur als fachliche
  /// Anregung angeschaut, keine Code-/Text-Übernahme). Wird auf den
  /// Netto-Betrag **vor** Steuerberechnung angewendet, siehe
  /// `InvoiceLineInput.lineNet`.
  final double discountPercent;

  /// Positionsgruppe (z. B. "Elektroinstallation EG") — ungleich der
  /// Artikelgruppe im Stamm. `null` = ungruppierte Position.
  final String? groupLabel;
  final int sortOrder;
  const InvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.kind,
    this.articleId,
    required this.description,
    required this.quantity,
    required this.unitPriceCents,
    required this.vatRatePercent,
    this.unit,
    required this.discountPercent,
    this.groupLabel,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['invoice_id'] = Variable<String>(invoiceId);
    {
      map['kind'] = Variable<String>(
        $InvoiceItemsTable.$converterkind.toSql(kind),
      );
    }
    if (!nullToAbsent || articleId != null) {
      map['article_id'] = Variable<String>(articleId);
    }
    map['description'] = Variable<String>(description);
    map['quantity'] = Variable<String>(quantity);
    map['unit_price_cents'] = Variable<int>(unitPriceCents);
    map['vat_rate_percent'] = Variable<double>(vatRatePercent);
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    map['discount_percent'] = Variable<double>(discountPercent);
    if (!nullToAbsent || groupLabel != null) {
      map['group_label'] = Variable<String>(groupLabel);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  InvoiceItemsCompanion toCompanion(bool nullToAbsent) {
    return InvoiceItemsCompanion(
      id: Value(id),
      invoiceId: Value(invoiceId),
      kind: Value(kind),
      articleId: articleId == null && nullToAbsent
          ? const Value.absent()
          : Value(articleId),
      description: Value(description),
      quantity: Value(quantity),
      unitPriceCents: Value(unitPriceCents),
      vatRatePercent: Value(vatRatePercent),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      discountPercent: Value(discountPercent),
      groupLabel: groupLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(groupLabel),
      sortOrder: Value(sortOrder),
    );
  }

  factory InvoiceItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InvoiceItem(
      id: serializer.fromJson<String>(json['id']),
      invoiceId: serializer.fromJson<String>(json['invoiceId']),
      kind: $InvoiceItemsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      articleId: serializer.fromJson<String?>(json['articleId']),
      description: serializer.fromJson<String>(json['description']),
      quantity: serializer.fromJson<String>(json['quantity']),
      unitPriceCents: serializer.fromJson<int>(json['unitPriceCents']),
      vatRatePercent: serializer.fromJson<double>(json['vatRatePercent']),
      unit: serializer.fromJson<String?>(json['unit']),
      discountPercent: serializer.fromJson<double>(json['discountPercent']),
      groupLabel: serializer.fromJson<String?>(json['groupLabel']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'invoiceId': serializer.toJson<String>(invoiceId),
      'kind': serializer.toJson<String>(
        $InvoiceItemsTable.$converterkind.toJson(kind),
      ),
      'articleId': serializer.toJson<String?>(articleId),
      'description': serializer.toJson<String>(description),
      'quantity': serializer.toJson<String>(quantity),
      'unitPriceCents': serializer.toJson<int>(unitPriceCents),
      'vatRatePercent': serializer.toJson<double>(vatRatePercent),
      'unit': serializer.toJson<String?>(unit),
      'discountPercent': serializer.toJson<double>(discountPercent),
      'groupLabel': serializer.toJson<String?>(groupLabel),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  InvoiceItem copyWith({
    String? id,
    String? invoiceId,
    InvoiceItemKind? kind,
    Value<String?> articleId = const Value.absent(),
    String? description,
    String? quantity,
    int? unitPriceCents,
    double? vatRatePercent,
    Value<String?> unit = const Value.absent(),
    double? discountPercent,
    Value<String?> groupLabel = const Value.absent(),
    int? sortOrder,
  }) => InvoiceItem(
    id: id ?? this.id,
    invoiceId: invoiceId ?? this.invoiceId,
    kind: kind ?? this.kind,
    articleId: articleId.present ? articleId.value : this.articleId,
    description: description ?? this.description,
    quantity: quantity ?? this.quantity,
    unitPriceCents: unitPriceCents ?? this.unitPriceCents,
    vatRatePercent: vatRatePercent ?? this.vatRatePercent,
    unit: unit.present ? unit.value : this.unit,
    discountPercent: discountPercent ?? this.discountPercent,
    groupLabel: groupLabel.present ? groupLabel.value : this.groupLabel,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  InvoiceItem copyWithCompanion(InvoiceItemsCompanion data) {
    return InvoiceItem(
      id: data.id.present ? data.id.value : this.id,
      invoiceId: data.invoiceId.present ? data.invoiceId.value : this.invoiceId,
      kind: data.kind.present ? data.kind.value : this.kind,
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      description: data.description.present
          ? data.description.value
          : this.description,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitPriceCents: data.unitPriceCents.present
          ? data.unitPriceCents.value
          : this.unitPriceCents,
      vatRatePercent: data.vatRatePercent.present
          ? data.vatRatePercent.value
          : this.vatRatePercent,
      unit: data.unit.present ? data.unit.value : this.unit,
      discountPercent: data.discountPercent.present
          ? data.discountPercent.value
          : this.discountPercent,
      groupLabel: data.groupLabel.present
          ? data.groupLabel.value
          : this.groupLabel,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InvoiceItem(')
          ..write('id: $id, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('kind: $kind, ')
          ..write('articleId: $articleId, ')
          ..write('description: $description, ')
          ..write('quantity: $quantity, ')
          ..write('unitPriceCents: $unitPriceCents, ')
          ..write('vatRatePercent: $vatRatePercent, ')
          ..write('unit: $unit, ')
          ..write('discountPercent: $discountPercent, ')
          ..write('groupLabel: $groupLabel, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    invoiceId,
    kind,
    articleId,
    description,
    quantity,
    unitPriceCents,
    vatRatePercent,
    unit,
    discountPercent,
    groupLabel,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvoiceItem &&
          other.id == this.id &&
          other.invoiceId == this.invoiceId &&
          other.kind == this.kind &&
          other.articleId == this.articleId &&
          other.description == this.description &&
          other.quantity == this.quantity &&
          other.unitPriceCents == this.unitPriceCents &&
          other.vatRatePercent == this.vatRatePercent &&
          other.unit == this.unit &&
          other.discountPercent == this.discountPercent &&
          other.groupLabel == this.groupLabel &&
          other.sortOrder == this.sortOrder);
}

class InvoiceItemsCompanion extends UpdateCompanion<InvoiceItem> {
  final Value<String> id;
  final Value<String> invoiceId;
  final Value<InvoiceItemKind> kind;
  final Value<String?> articleId;
  final Value<String> description;
  final Value<String> quantity;
  final Value<int> unitPriceCents;
  final Value<double> vatRatePercent;
  final Value<String?> unit;
  final Value<double> discountPercent;
  final Value<String?> groupLabel;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const InvoiceItemsCompanion({
    this.id = const Value.absent(),
    this.invoiceId = const Value.absent(),
    this.kind = const Value.absent(),
    this.articleId = const Value.absent(),
    this.description = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitPriceCents = const Value.absent(),
    this.vatRatePercent = const Value.absent(),
    this.unit = const Value.absent(),
    this.discountPercent = const Value.absent(),
    this.groupLabel = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InvoiceItemsCompanion.insert({
    required String id,
    required String invoiceId,
    required InvoiceItemKind kind,
    this.articleId = const Value.absent(),
    required String description,
    required String quantity,
    required int unitPriceCents,
    required double vatRatePercent,
    this.unit = const Value.absent(),
    this.discountPercent = const Value.absent(),
    this.groupLabel = const Value.absent(),
    required int sortOrder,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       invoiceId = Value(invoiceId),
       kind = Value(kind),
       description = Value(description),
       quantity = Value(quantity),
       unitPriceCents = Value(unitPriceCents),
       vatRatePercent = Value(vatRatePercent),
       sortOrder = Value(sortOrder);
  static Insertable<InvoiceItem> custom({
    Expression<String>? id,
    Expression<String>? invoiceId,
    Expression<String>? kind,
    Expression<String>? articleId,
    Expression<String>? description,
    Expression<String>? quantity,
    Expression<int>? unitPriceCents,
    Expression<double>? vatRatePercent,
    Expression<String>? unit,
    Expression<double>? discountPercent,
    Expression<String>? groupLabel,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (invoiceId != null) 'invoice_id': invoiceId,
      if (kind != null) 'kind': kind,
      if (articleId != null) 'article_id': articleId,
      if (description != null) 'description': description,
      if (quantity != null) 'quantity': quantity,
      if (unitPriceCents != null) 'unit_price_cents': unitPriceCents,
      if (vatRatePercent != null) 'vat_rate_percent': vatRatePercent,
      if (unit != null) 'unit': unit,
      if (discountPercent != null) 'discount_percent': discountPercent,
      if (groupLabel != null) 'group_label': groupLabel,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InvoiceItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? invoiceId,
    Value<InvoiceItemKind>? kind,
    Value<String?>? articleId,
    Value<String>? description,
    Value<String>? quantity,
    Value<int>? unitPriceCents,
    Value<double>? vatRatePercent,
    Value<String?>? unit,
    Value<double>? discountPercent,
    Value<String?>? groupLabel,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return InvoiceItemsCompanion(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      kind: kind ?? this.kind,
      articleId: articleId ?? this.articleId,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPriceCents: unitPriceCents ?? this.unitPriceCents,
      vatRatePercent: vatRatePercent ?? this.vatRatePercent,
      unit: unit ?? this.unit,
      discountPercent: discountPercent ?? this.discountPercent,
      groupLabel: groupLabel ?? this.groupLabel,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (invoiceId.present) {
      map['invoice_id'] = Variable<String>(invoiceId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $InvoiceItemsTable.$converterkind.toSql(kind.value),
      );
    }
    if (articleId.present) {
      map['article_id'] = Variable<String>(articleId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<String>(quantity.value);
    }
    if (unitPriceCents.present) {
      map['unit_price_cents'] = Variable<int>(unitPriceCents.value);
    }
    if (vatRatePercent.present) {
      map['vat_rate_percent'] = Variable<double>(vatRatePercent.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (discountPercent.present) {
      map['discount_percent'] = Variable<double>(discountPercent.value);
    }
    if (groupLabel.present) {
      map['group_label'] = Variable<String>(groupLabel.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InvoiceItemsCompanion(')
          ..write('id: $id, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('kind: $kind, ')
          ..write('articleId: $articleId, ')
          ..write('description: $description, ')
          ..write('quantity: $quantity, ')
          ..write('unitPriceCents: $unitPriceCents, ')
          ..write('vatRatePercent: $vatRatePercent, ')
          ..write('unit: $unit, ')
          ..write('discountPercent: $discountPercent, ')
          ..write('groupLabel: $groupLabel, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NumberSequencesTable extends NumberSequences
    with TableInfo<$NumberSequencesTable, NumberSequence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NumberSequencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES companies (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _documentTypeMeta = const VerificationMeta(
    'documentType',
  );
  @override
  late final GeneratedColumn<String> documentType = GeneratedColumn<String>(
    'document_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastNumberMeta = const VerificationMeta(
    'lastNumber',
  );
  @override
  late final GeneratedColumn<int> lastNumber = GeneratedColumn<int>(
    'last_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    companyId,
    documentType,
    year,
    lastNumber,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'number_sequences';
  @override
  VerificationContext validateIntegrity(
    Insertable<NumberSequence> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('document_type')) {
      context.handle(
        _documentTypeMeta,
        documentType.isAcceptableOrUnknown(
          data['document_type']!,
          _documentTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_documentTypeMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('last_number')) {
      context.handle(
        _lastNumberMeta,
        lastNumber.isAcceptableOrUnknown(data['last_number']!, _lastNumberMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {companyId, documentType, year};
  @override
  NumberSequence map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NumberSequence(
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      documentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_type'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      lastNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_number'],
      )!,
    );
  }

  @override
  $NumberSequencesTable createAlias(String alias) {
    return $NumberSequencesTable(attachedDatabase, alias);
  }
}

class NumberSequence extends DataClass implements Insertable<NumberSequence> {
  final String companyId;

  /// `DocumentKind.name`, also "invoice"/"quote"/"order"/"deliveryNote"
  /// (Präfixe "R"/"An"/"A"/"LS"). Gutschrift ("G") kommt erst mit Phase C.
  final String documentType;
  final int year;
  final int lastNumber;
  const NumberSequence({
    required this.companyId,
    required this.documentType,
    required this.year,
    required this.lastNumber,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['company_id'] = Variable<String>(companyId);
    map['document_type'] = Variable<String>(documentType);
    map['year'] = Variable<int>(year);
    map['last_number'] = Variable<int>(lastNumber);
    return map;
  }

  NumberSequencesCompanion toCompanion(bool nullToAbsent) {
    return NumberSequencesCompanion(
      companyId: Value(companyId),
      documentType: Value(documentType),
      year: Value(year),
      lastNumber: Value(lastNumber),
    );
  }

  factory NumberSequence.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NumberSequence(
      companyId: serializer.fromJson<String>(json['companyId']),
      documentType: serializer.fromJson<String>(json['documentType']),
      year: serializer.fromJson<int>(json['year']),
      lastNumber: serializer.fromJson<int>(json['lastNumber']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'companyId': serializer.toJson<String>(companyId),
      'documentType': serializer.toJson<String>(documentType),
      'year': serializer.toJson<int>(year),
      'lastNumber': serializer.toJson<int>(lastNumber),
    };
  }

  NumberSequence copyWith({
    String? companyId,
    String? documentType,
    int? year,
    int? lastNumber,
  }) => NumberSequence(
    companyId: companyId ?? this.companyId,
    documentType: documentType ?? this.documentType,
    year: year ?? this.year,
    lastNumber: lastNumber ?? this.lastNumber,
  );
  NumberSequence copyWithCompanion(NumberSequencesCompanion data) {
    return NumberSequence(
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      documentType: data.documentType.present
          ? data.documentType.value
          : this.documentType,
      year: data.year.present ? data.year.value : this.year,
      lastNumber: data.lastNumber.present
          ? data.lastNumber.value
          : this.lastNumber,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NumberSequence(')
          ..write('companyId: $companyId, ')
          ..write('documentType: $documentType, ')
          ..write('year: $year, ')
          ..write('lastNumber: $lastNumber')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(companyId, documentType, year, lastNumber);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NumberSequence &&
          other.companyId == this.companyId &&
          other.documentType == this.documentType &&
          other.year == this.year &&
          other.lastNumber == this.lastNumber);
}

class NumberSequencesCompanion extends UpdateCompanion<NumberSequence> {
  final Value<String> companyId;
  final Value<String> documentType;
  final Value<int> year;
  final Value<int> lastNumber;
  final Value<int> rowid;
  const NumberSequencesCompanion({
    this.companyId = const Value.absent(),
    this.documentType = const Value.absent(),
    this.year = const Value.absent(),
    this.lastNumber = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NumberSequencesCompanion.insert({
    required String companyId,
    required String documentType,
    required int year,
    this.lastNumber = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : companyId = Value(companyId),
       documentType = Value(documentType),
       year = Value(year);
  static Insertable<NumberSequence> custom({
    Expression<String>? companyId,
    Expression<String>? documentType,
    Expression<int>? year,
    Expression<int>? lastNumber,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (companyId != null) 'company_id': companyId,
      if (documentType != null) 'document_type': documentType,
      if (year != null) 'year': year,
      if (lastNumber != null) 'last_number': lastNumber,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NumberSequencesCompanion copyWith({
    Value<String>? companyId,
    Value<String>? documentType,
    Value<int>? year,
    Value<int>? lastNumber,
    Value<int>? rowid,
  }) {
    return NumberSequencesCompanion(
      companyId: companyId ?? this.companyId,
      documentType: documentType ?? this.documentType,
      year: year ?? this.year,
      lastNumber: lastNumber ?? this.lastNumber,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (documentType.present) {
      map['document_type'] = Variable<String>(documentType.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (lastNumber.present) {
      map['last_number'] = Variable<int>(lastNumber.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NumberSequencesCompanion(')
          ..write('companyId: $companyId, ')
          ..write('documentType: $documentType, ')
          ..write('year: $year, ')
          ..write('lastNumber: $lastNumber, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VehiclesTable extends Vehicles with TableInfo<$VehiclesTable, Vehicle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VehiclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES companies (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _licensePlateMeta = const VerificationMeta(
    'licensePlate',
  );
  @override
  late final GeneratedColumn<String> licensePlate = GeneratedColumn<String>(
    'license_plate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextInspectionDateMeta =
      const VerificationMeta('nextInspectionDate');
  @override
  late final GeneratedColumn<DateTime> nextInspectionDate =
      GeneratedColumn<DateTime>(
        'next_inspection_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    name,
    licensePlate,
    notes,
    nextInspectionDate,
    active,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vehicles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Vehicle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('license_plate')) {
      context.handle(
        _licensePlateMeta,
        licensePlate.isAcceptableOrUnknown(
          data['license_plate']!,
          _licensePlateMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('next_inspection_date')) {
      context.handle(
        _nextInspectionDateMeta,
        nextInspectionDate.isAcceptableOrUnknown(
          data['next_inspection_date']!,
          _nextInspectionDateMeta,
        ),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Vehicle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Vehicle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      licensePlate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}license_plate'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      nextInspectionDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_inspection_date'],
      ),
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $VehiclesTable createAlias(String alias) {
    return $VehiclesTable(attachedDatabase, alias);
  }
}

class Vehicle extends DataClass implements Insertable<Vehicle> {
  final String id;
  final String companyId;
  final String name;
  final String? licensePlate;
  final String? notes;

  /// Nächster TÜV-/Hauptuntersuchungstermin (Brainstorming: "TÜV-Termine
  /// ... Fälligkeiten"). `null` = nicht erfasst.
  final DateTime? nextInspectionDate;
  final bool active;
  final DateTime createdAt;
  const Vehicle({
    required this.id,
    required this.companyId,
    required this.name,
    this.licensePlate,
    this.notes,
    this.nextInspectionDate,
    required this.active,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || licensePlate != null) {
      map['license_plate'] = Variable<String>(licensePlate);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || nextInspectionDate != null) {
      map['next_inspection_date'] = Variable<DateTime>(nextInspectionDate);
    }
    map['active'] = Variable<bool>(active);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  VehiclesCompanion toCompanion(bool nullToAbsent) {
    return VehiclesCompanion(
      id: Value(id),
      companyId: Value(companyId),
      name: Value(name),
      licensePlate: licensePlate == null && nullToAbsent
          ? const Value.absent()
          : Value(licensePlate),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      nextInspectionDate: nextInspectionDate == null && nullToAbsent
          ? const Value.absent()
          : Value(nextInspectionDate),
      active: Value(active),
      createdAt: Value(createdAt),
    );
  }

  factory Vehicle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Vehicle(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      name: serializer.fromJson<String>(json['name']),
      licensePlate: serializer.fromJson<String?>(json['licensePlate']),
      notes: serializer.fromJson<String?>(json['notes']),
      nextInspectionDate: serializer.fromJson<DateTime?>(
        json['nextInspectionDate'],
      ),
      active: serializer.fromJson<bool>(json['active']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'name': serializer.toJson<String>(name),
      'licensePlate': serializer.toJson<String?>(licensePlate),
      'notes': serializer.toJson<String?>(notes),
      'nextInspectionDate': serializer.toJson<DateTime?>(nextInspectionDate),
      'active': serializer.toJson<bool>(active),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Vehicle copyWith({
    String? id,
    String? companyId,
    String? name,
    Value<String?> licensePlate = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> nextInspectionDate = const Value.absent(),
    bool? active,
    DateTime? createdAt,
  }) => Vehicle(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    name: name ?? this.name,
    licensePlate: licensePlate.present ? licensePlate.value : this.licensePlate,
    notes: notes.present ? notes.value : this.notes,
    nextInspectionDate: nextInspectionDate.present
        ? nextInspectionDate.value
        : this.nextInspectionDate,
    active: active ?? this.active,
    createdAt: createdAt ?? this.createdAt,
  );
  Vehicle copyWithCompanion(VehiclesCompanion data) {
    return Vehicle(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      name: data.name.present ? data.name.value : this.name,
      licensePlate: data.licensePlate.present
          ? data.licensePlate.value
          : this.licensePlate,
      notes: data.notes.present ? data.notes.value : this.notes,
      nextInspectionDate: data.nextInspectionDate.present
          ? data.nextInspectionDate.value
          : this.nextInspectionDate,
      active: data.active.present ? data.active.value : this.active,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Vehicle(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('licensePlate: $licensePlate, ')
          ..write('notes: $notes, ')
          ..write('nextInspectionDate: $nextInspectionDate, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    name,
    licensePlate,
    notes,
    nextInspectionDate,
    active,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Vehicle &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.name == this.name &&
          other.licensePlate == this.licensePlate &&
          other.notes == this.notes &&
          other.nextInspectionDate == this.nextInspectionDate &&
          other.active == this.active &&
          other.createdAt == this.createdAt);
}

class VehiclesCompanion extends UpdateCompanion<Vehicle> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> name;
  final Value<String?> licensePlate;
  final Value<String?> notes;
  final Value<DateTime?> nextInspectionDate;
  final Value<bool> active;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const VehiclesCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.name = const Value.absent(),
    this.licensePlate = const Value.absent(),
    this.notes = const Value.absent(),
    this.nextInspectionDate = const Value.absent(),
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VehiclesCompanion.insert({
    required String id,
    required String companyId,
    required String name,
    this.licensePlate = const Value.absent(),
    this.notes = const Value.absent(),
    this.nextInspectionDate = const Value.absent(),
    this.active = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Vehicle> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? name,
    Expression<String>? licensePlate,
    Expression<String>? notes,
    Expression<DateTime>? nextInspectionDate,
    Expression<bool>? active,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (name != null) 'name': name,
      if (licensePlate != null) 'license_plate': licensePlate,
      if (notes != null) 'notes': notes,
      if (nextInspectionDate != null)
        'next_inspection_date': nextInspectionDate,
      if (active != null) 'active': active,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VehiclesCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? name,
    Value<String?>? licensePlate,
    Value<String?>? notes,
    Value<DateTime?>? nextInspectionDate,
    Value<bool>? active,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return VehiclesCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      licensePlate: licensePlate ?? this.licensePlate,
      notes: notes ?? this.notes,
      nextInspectionDate: nextInspectionDate ?? this.nextInspectionDate,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (licensePlate.present) {
      map['license_plate'] = Variable<String>(licensePlate.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (nextInspectionDate.present) {
      map['next_inspection_date'] = Variable<DateTime>(
        nextInspectionDate.value,
      );
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VehiclesCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('name: $name, ')
          ..write('licensePlate: $licensePlate, ')
          ..write('notes: $notes, ')
          ..write('nextInspectionDate: $nextInspectionDate, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VehicleCostEntriesTable extends VehicleCostEntries
    with TableInfo<$VehicleCostEntriesTable, VehicleCostEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VehicleCostEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES companies (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<VehicleCostCategory, String>
  category =
      GeneratedColumn<String>(
        'category',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<VehicleCostCategory>(
        $VehicleCostEntriesTable.$convertercategory,
      );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    vehicleId,
    date,
    amountCents,
    category,
    description,
    projectId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vehicle_cost_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<VehicleCostEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VehicleCostEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VehicleCostEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      category: $VehicleCostEntriesTable.$convertercategory.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}category'],
        )!,
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $VehicleCostEntriesTable createAlias(String alias) {
    return $VehicleCostEntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<VehicleCostCategory, String, String>
  $convertercategory = const EnumNameConverter<VehicleCostCategory>(
    VehicleCostCategory.values,
  );
}

class VehicleCostEntry extends DataClass
    implements Insertable<VehicleCostEntry> {
  final String id;

  /// Direkt auf der Buchung statt nur über [vehicleId] ableitbar — ein
  /// bewusst durchgehaltenes Muster in diesem Schema (siehe z. B.
  /// [Invoices].companyId trotz customerId), hält jede Abfrage
  /// unmittelbar companyId-filterbar statt über einen Join.
  final String companyId;
  final String vehicleId;
  final DateTime date;
  final int amountCents;
  final VehicleCostCategory category;
  final String? description;

  /// Reine Markierung für eine spätere, noch zu entscheidende
  /// Projektumlage (siehe Klassendoc) — `onDelete: setNull`, ein
  /// gelöschtes Projekt darf keine Kostenbuchung mitreißen.
  final String? projectId;
  final DateTime createdAt;
  const VehicleCostEntry({
    required this.id,
    required this.companyId,
    required this.vehicleId,
    required this.date,
    required this.amountCents,
    required this.category,
    this.description,
    this.projectId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['date'] = Variable<DateTime>(date);
    map['amount_cents'] = Variable<int>(amountCents);
    {
      map['category'] = Variable<String>(
        $VehicleCostEntriesTable.$convertercategory.toSql(category),
      );
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  VehicleCostEntriesCompanion toCompanion(bool nullToAbsent) {
    return VehicleCostEntriesCompanion(
      id: Value(id),
      companyId: Value(companyId),
      vehicleId: Value(vehicleId),
      date: Value(date),
      amountCents: Value(amountCents),
      category: Value(category),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      createdAt: Value(createdAt),
    );
  }

  factory VehicleCostEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VehicleCostEntry(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      date: serializer.fromJson<DateTime>(json['date']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      category: $VehicleCostEntriesTable.$convertercategory.fromJson(
        serializer.fromJson<String>(json['category']),
      ),
      description: serializer.fromJson<String?>(json['description']),
      projectId: serializer.fromJson<String?>(json['projectId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'date': serializer.toJson<DateTime>(date),
      'amountCents': serializer.toJson<int>(amountCents),
      'category': serializer.toJson<String>(
        $VehicleCostEntriesTable.$convertercategory.toJson(category),
      ),
      'description': serializer.toJson<String?>(description),
      'projectId': serializer.toJson<String?>(projectId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  VehicleCostEntry copyWith({
    String? id,
    String? companyId,
    String? vehicleId,
    DateTime? date,
    int? amountCents,
    VehicleCostCategory? category,
    Value<String?> description = const Value.absent(),
    Value<String?> projectId = const Value.absent(),
    DateTime? createdAt,
  }) => VehicleCostEntry(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    vehicleId: vehicleId ?? this.vehicleId,
    date: date ?? this.date,
    amountCents: amountCents ?? this.amountCents,
    category: category ?? this.category,
    description: description.present ? description.value : this.description,
    projectId: projectId.present ? projectId.value : this.projectId,
    createdAt: createdAt ?? this.createdAt,
  );
  VehicleCostEntry copyWithCompanion(VehicleCostEntriesCompanion data) {
    return VehicleCostEntry(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      date: data.date.present ? data.date.value : this.date,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      category: data.category.present ? data.category.value : this.category,
      description: data.description.present
          ? data.description.value
          : this.description,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VehicleCostEntry(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('date: $date, ')
          ..write('amountCents: $amountCents, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('projectId: $projectId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    vehicleId,
    date,
    amountCents,
    category,
    description,
    projectId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VehicleCostEntry &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.vehicleId == this.vehicleId &&
          other.date == this.date &&
          other.amountCents == this.amountCents &&
          other.category == this.category &&
          other.description == this.description &&
          other.projectId == this.projectId &&
          other.createdAt == this.createdAt);
}

class VehicleCostEntriesCompanion extends UpdateCompanion<VehicleCostEntry> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> vehicleId;
  final Value<DateTime> date;
  final Value<int> amountCents;
  final Value<VehicleCostCategory> category;
  final Value<String?> description;
  final Value<String?> projectId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const VehicleCostEntriesCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.date = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.category = const Value.absent(),
    this.description = const Value.absent(),
    this.projectId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VehicleCostEntriesCompanion.insert({
    required String id,
    required String companyId,
    required String vehicleId,
    required DateTime date,
    required int amountCents,
    required VehicleCostCategory category,
    this.description = const Value.absent(),
    this.projectId = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       vehicleId = Value(vehicleId),
       date = Value(date),
       amountCents = Value(amountCents),
       category = Value(category),
       createdAt = Value(createdAt);
  static Insertable<VehicleCostEntry> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? vehicleId,
    Expression<DateTime>? date,
    Expression<int>? amountCents,
    Expression<String>? category,
    Expression<String>? description,
    Expression<String>? projectId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (date != null) 'date': date,
      if (amountCents != null) 'amount_cents': amountCents,
      if (category != null) 'category': category,
      if (description != null) 'description': description,
      if (projectId != null) 'project_id': projectId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VehicleCostEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? vehicleId,
    Value<DateTime>? date,
    Value<int>? amountCents,
    Value<VehicleCostCategory>? category,
    Value<String?>? description,
    Value<String?>? projectId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return VehicleCostEntriesCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      amountCents: amountCents ?? this.amountCents,
      category: category ?? this.category,
      description: description ?? this.description,
      projectId: projectId ?? this.projectId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(
        $VehicleCostEntriesTable.$convertercategory.toSql(category.value),
      );
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VehicleCostEntriesCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('date: $date, ')
          ..write('amountCents: $amountCents, ')
          ..write('category: $category, ')
          ..write('description: $description, ')
          ..write('projectId: $projectId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecurringInvoiceTemplatesTable extends RecurringInvoiceTemplates
    with TableInfo<$RecurringInvoiceTemplatesTable, RecurringInvoiceTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurringInvoiceTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES companies (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES customers (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RecurrenceInterval, String>
  interval =
      GeneratedColumn<String>(
        'interval',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RecurrenceInterval>(
        $RecurringInvoiceTemplatesTable.$converterinterval,
      );
  static const VerificationMeta _nextDueDateMeta = const VerificationMeta(
    'nextDueDate',
  );
  @override
  late final GeneratedColumn<DateTime> nextDueDate = GeneratedColumn<DateTime>(
    'next_due_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paymentTermsMeta = const VerificationMeta(
    'paymentTerms',
  );
  @override
  late final GeneratedColumn<String> paymentTerms = GeneratedColumn<String>(
    'payment_terms',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    customerId,
    label,
    interval,
    nextDueDate,
    paymentTerms,
    notes,
    active,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurring_invoice_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecurringInvoiceTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('next_due_date')) {
      context.handle(
        _nextDueDateMeta,
        nextDueDate.isAcceptableOrUnknown(
          data['next_due_date']!,
          _nextDueDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextDueDateMeta);
    }
    if (data.containsKey('payment_terms')) {
      context.handle(
        _paymentTermsMeta,
        paymentTerms.isAcceptableOrUnknown(
          data['payment_terms']!,
          _paymentTermsMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecurringInvoiceTemplate map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecurringInvoiceTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      interval: $RecurringInvoiceTemplatesTable.$converterinterval.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}interval'],
        )!,
      ),
      nextDueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_due_date'],
      )!,
      paymentTerms: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_terms'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RecurringInvoiceTemplatesTable createAlias(String alias) {
    return $RecurringInvoiceTemplatesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RecurrenceInterval, String, String>
  $converterinterval = const EnumNameConverter<RecurrenceInterval>(
    RecurrenceInterval.values,
  );
}

class RecurringInvoiceTemplate extends DataClass
    implements Insertable<RecurringInvoiceTemplate> {
  final String id;
  final String companyId;
  final String customerId;

  /// Freitext zur Wiedererkennung der Vorlage (z. B. "Hosting Kunde X
  /// monatlich") — keine der üblichen Rechnungsfelder, nur für die
  /// Vorlagenliste selbst.
  final String label;
  final RecurrenceInterval interval;

  /// Nächstes Fälligkeitsdatum — wird nach jeder Generierung um
  /// [interval] weitergeschoben (siehe Klassendoc).
  final DateTime nextDueDate;
  final String? paymentTerms;
  final String? notes;

  /// Pausiert statt gelöscht — gleiches "Deaktivieren löscht keine
  /// Daten"-Prinzip wie die Modul-Schalter und Projekte/Fahrzeuge.
  final bool active;
  final DateTime createdAt;
  const RecurringInvoiceTemplate({
    required this.id,
    required this.companyId,
    required this.customerId,
    required this.label,
    required this.interval,
    required this.nextDueDate,
    this.paymentTerms,
    this.notes,
    required this.active,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['customer_id'] = Variable<String>(customerId);
    map['label'] = Variable<String>(label);
    {
      map['interval'] = Variable<String>(
        $RecurringInvoiceTemplatesTable.$converterinterval.toSql(interval),
      );
    }
    map['next_due_date'] = Variable<DateTime>(nextDueDate);
    if (!nullToAbsent || paymentTerms != null) {
      map['payment_terms'] = Variable<String>(paymentTerms);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['active'] = Variable<bool>(active);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RecurringInvoiceTemplatesCompanion toCompanion(bool nullToAbsent) {
    return RecurringInvoiceTemplatesCompanion(
      id: Value(id),
      companyId: Value(companyId),
      customerId: Value(customerId),
      label: Value(label),
      interval: Value(interval),
      nextDueDate: Value(nextDueDate),
      paymentTerms: paymentTerms == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentTerms),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      active: Value(active),
      createdAt: Value(createdAt),
    );
  }

  factory RecurringInvoiceTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecurringInvoiceTemplate(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      customerId: serializer.fromJson<String>(json['customerId']),
      label: serializer.fromJson<String>(json['label']),
      interval: $RecurringInvoiceTemplatesTable.$converterinterval.fromJson(
        serializer.fromJson<String>(json['interval']),
      ),
      nextDueDate: serializer.fromJson<DateTime>(json['nextDueDate']),
      paymentTerms: serializer.fromJson<String?>(json['paymentTerms']),
      notes: serializer.fromJson<String?>(json['notes']),
      active: serializer.fromJson<bool>(json['active']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'customerId': serializer.toJson<String>(customerId),
      'label': serializer.toJson<String>(label),
      'interval': serializer.toJson<String>(
        $RecurringInvoiceTemplatesTable.$converterinterval.toJson(interval),
      ),
      'nextDueDate': serializer.toJson<DateTime>(nextDueDate),
      'paymentTerms': serializer.toJson<String?>(paymentTerms),
      'notes': serializer.toJson<String?>(notes),
      'active': serializer.toJson<bool>(active),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RecurringInvoiceTemplate copyWith({
    String? id,
    String? companyId,
    String? customerId,
    String? label,
    RecurrenceInterval? interval,
    DateTime? nextDueDate,
    Value<String?> paymentTerms = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    bool? active,
    DateTime? createdAt,
  }) => RecurringInvoiceTemplate(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    customerId: customerId ?? this.customerId,
    label: label ?? this.label,
    interval: interval ?? this.interval,
    nextDueDate: nextDueDate ?? this.nextDueDate,
    paymentTerms: paymentTerms.present ? paymentTerms.value : this.paymentTerms,
    notes: notes.present ? notes.value : this.notes,
    active: active ?? this.active,
    createdAt: createdAt ?? this.createdAt,
  );
  RecurringInvoiceTemplate copyWithCompanion(
    RecurringInvoiceTemplatesCompanion data,
  ) {
    return RecurringInvoiceTemplate(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      label: data.label.present ? data.label.value : this.label,
      interval: data.interval.present ? data.interval.value : this.interval,
      nextDueDate: data.nextDueDate.present
          ? data.nextDueDate.value
          : this.nextDueDate,
      paymentTerms: data.paymentTerms.present
          ? data.paymentTerms.value
          : this.paymentTerms,
      notes: data.notes.present ? data.notes.value : this.notes,
      active: data.active.present ? data.active.value : this.active,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecurringInvoiceTemplate(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('customerId: $customerId, ')
          ..write('label: $label, ')
          ..write('interval: $interval, ')
          ..write('nextDueDate: $nextDueDate, ')
          ..write('paymentTerms: $paymentTerms, ')
          ..write('notes: $notes, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    customerId,
    label,
    interval,
    nextDueDate,
    paymentTerms,
    notes,
    active,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurringInvoiceTemplate &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.customerId == this.customerId &&
          other.label == this.label &&
          other.interval == this.interval &&
          other.nextDueDate == this.nextDueDate &&
          other.paymentTerms == this.paymentTerms &&
          other.notes == this.notes &&
          other.active == this.active &&
          other.createdAt == this.createdAt);
}

class RecurringInvoiceTemplatesCompanion
    extends UpdateCompanion<RecurringInvoiceTemplate> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> customerId;
  final Value<String> label;
  final Value<RecurrenceInterval> interval;
  final Value<DateTime> nextDueDate;
  final Value<String?> paymentTerms;
  final Value<String?> notes;
  final Value<bool> active;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RecurringInvoiceTemplatesCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.customerId = const Value.absent(),
    this.label = const Value.absent(),
    this.interval = const Value.absent(),
    this.nextDueDate = const Value.absent(),
    this.paymentTerms = const Value.absent(),
    this.notes = const Value.absent(),
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecurringInvoiceTemplatesCompanion.insert({
    required String id,
    required String companyId,
    required String customerId,
    required String label,
    required RecurrenceInterval interval,
    required DateTime nextDueDate,
    this.paymentTerms = const Value.absent(),
    this.notes = const Value.absent(),
    this.active = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       customerId = Value(customerId),
       label = Value(label),
       interval = Value(interval),
       nextDueDate = Value(nextDueDate),
       createdAt = Value(createdAt);
  static Insertable<RecurringInvoiceTemplate> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? customerId,
    Expression<String>? label,
    Expression<String>? interval,
    Expression<DateTime>? nextDueDate,
    Expression<String>? paymentTerms,
    Expression<String>? notes,
    Expression<bool>? active,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (customerId != null) 'customer_id': customerId,
      if (label != null) 'label': label,
      if (interval != null) 'interval': interval,
      if (nextDueDate != null) 'next_due_date': nextDueDate,
      if (paymentTerms != null) 'payment_terms': paymentTerms,
      if (notes != null) 'notes': notes,
      if (active != null) 'active': active,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecurringInvoiceTemplatesCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? customerId,
    Value<String>? label,
    Value<RecurrenceInterval>? interval,
    Value<DateTime>? nextDueDate,
    Value<String?>? paymentTerms,
    Value<String?>? notes,
    Value<bool>? active,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return RecurringInvoiceTemplatesCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      customerId: customerId ?? this.customerId,
      label: label ?? this.label,
      interval: interval ?? this.interval,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      notes: notes ?? this.notes,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (interval.present) {
      map['interval'] = Variable<String>(
        $RecurringInvoiceTemplatesTable.$converterinterval.toSql(
          interval.value,
        ),
      );
    }
    if (nextDueDate.present) {
      map['next_due_date'] = Variable<DateTime>(nextDueDate.value);
    }
    if (paymentTerms.present) {
      map['payment_terms'] = Variable<String>(paymentTerms.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurringInvoiceTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('customerId: $customerId, ')
          ..write('label: $label, ')
          ..write('interval: $interval, ')
          ..write('nextDueDate: $nextDueDate, ')
          ..write('paymentTerms: $paymentTerms, ')
          ..write('notes: $notes, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecurringInvoiceTemplateItemsTable extends RecurringInvoiceTemplateItems
    with
        TableInfo<
          $RecurringInvoiceTemplateItemsTable,
          RecurringInvoiceTemplateItem
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurringInvoiceTemplateItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recurring_invoice_templates (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<InvoiceItemKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<InvoiceItemKind>(
        $RecurringInvoiceTemplateItemsTable.$converterkind,
      );
  static const VerificationMeta _articleIdMeta = const VerificationMeta(
    'articleId',
  );
  @override
  late final GeneratedColumn<String> articleId = GeneratedColumn<String>(
    'article_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES articles (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<String> quantity = GeneratedColumn<String>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitPriceCentsMeta = const VerificationMeta(
    'unitPriceCents',
  );
  @override
  late final GeneratedColumn<int> unitPriceCents = GeneratedColumn<int>(
    'unit_price_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vatRatePercentMeta = const VerificationMeta(
    'vatRatePercent',
  );
  @override
  late final GeneratedColumn<double> vatRatePercent = GeneratedColumn<double>(
    'vat_rate_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discountPercentMeta = const VerificationMeta(
    'discountPercent',
  );
  @override
  late final GeneratedColumn<double> discountPercent = GeneratedColumn<double>(
    'discount_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _groupLabelMeta = const VerificationMeta(
    'groupLabel',
  );
  @override
  late final GeneratedColumn<String> groupLabel = GeneratedColumn<String>(
    'group_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    templateId,
    kind,
    articleId,
    description,
    quantity,
    unitPriceCents,
    vatRatePercent,
    unit,
    discountPercent,
    groupLabel,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurring_invoice_template_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecurringInvoiceTemplateItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    } else if (isInserting) {
      context.missing(_templateIdMeta);
    }
    if (data.containsKey('article_id')) {
      context.handle(
        _articleIdMeta,
        articleId.isAcceptableOrUnknown(data['article_id']!, _articleIdMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit_price_cents')) {
      context.handle(
        _unitPriceCentsMeta,
        unitPriceCents.isAcceptableOrUnknown(
          data['unit_price_cents']!,
          _unitPriceCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unitPriceCentsMeta);
    }
    if (data.containsKey('vat_rate_percent')) {
      context.handle(
        _vatRatePercentMeta,
        vatRatePercent.isAcceptableOrUnknown(
          data['vat_rate_percent']!,
          _vatRatePercentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_vatRatePercentMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('discount_percent')) {
      context.handle(
        _discountPercentMeta,
        discountPercent.isAcceptableOrUnknown(
          data['discount_percent']!,
          _discountPercentMeta,
        ),
      );
    }
    if (data.containsKey('group_label')) {
      context.handle(
        _groupLabelMeta,
        groupLabel.isAcceptableOrUnknown(data['group_label']!, _groupLabelMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecurringInvoiceTemplateItem map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecurringInvoiceTemplateItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      )!,
      kind: $RecurringInvoiceTemplateItemsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      articleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}article_id'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quantity'],
      )!,
      unitPriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_price_cents'],
      )!,
      vatRatePercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}vat_rate_percent'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
      discountPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}discount_percent'],
      )!,
      groupLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_label'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $RecurringInvoiceTemplateItemsTable createAlias(String alias) {
    return $RecurringInvoiceTemplateItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<InvoiceItemKind, String, String> $converterkind =
      const EnumNameConverter<InvoiceItemKind>(InvoiceItemKind.values);
}

class RecurringInvoiceTemplateItem extends DataClass
    implements Insertable<RecurringInvoiceTemplateItem> {
  final String id;
  final String templateId;
  final InvoiceItemKind kind;
  final String? articleId;
  final String description;
  final String quantity;
  final int unitPriceCents;
  final double vatRatePercent;
  final String? unit;
  final double discountPercent;
  final String? groupLabel;
  final int sortOrder;
  const RecurringInvoiceTemplateItem({
    required this.id,
    required this.templateId,
    required this.kind,
    this.articleId,
    required this.description,
    required this.quantity,
    required this.unitPriceCents,
    required this.vatRatePercent,
    this.unit,
    required this.discountPercent,
    this.groupLabel,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['template_id'] = Variable<String>(templateId);
    {
      map['kind'] = Variable<String>(
        $RecurringInvoiceTemplateItemsTable.$converterkind.toSql(kind),
      );
    }
    if (!nullToAbsent || articleId != null) {
      map['article_id'] = Variable<String>(articleId);
    }
    map['description'] = Variable<String>(description);
    map['quantity'] = Variable<String>(quantity);
    map['unit_price_cents'] = Variable<int>(unitPriceCents);
    map['vat_rate_percent'] = Variable<double>(vatRatePercent);
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    map['discount_percent'] = Variable<double>(discountPercent);
    if (!nullToAbsent || groupLabel != null) {
      map['group_label'] = Variable<String>(groupLabel);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  RecurringInvoiceTemplateItemsCompanion toCompanion(bool nullToAbsent) {
    return RecurringInvoiceTemplateItemsCompanion(
      id: Value(id),
      templateId: Value(templateId),
      kind: Value(kind),
      articleId: articleId == null && nullToAbsent
          ? const Value.absent()
          : Value(articleId),
      description: Value(description),
      quantity: Value(quantity),
      unitPriceCents: Value(unitPriceCents),
      vatRatePercent: Value(vatRatePercent),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      discountPercent: Value(discountPercent),
      groupLabel: groupLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(groupLabel),
      sortOrder: Value(sortOrder),
    );
  }

  factory RecurringInvoiceTemplateItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecurringInvoiceTemplateItem(
      id: serializer.fromJson<String>(json['id']),
      templateId: serializer.fromJson<String>(json['templateId']),
      kind: $RecurringInvoiceTemplateItemsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      articleId: serializer.fromJson<String?>(json['articleId']),
      description: serializer.fromJson<String>(json['description']),
      quantity: serializer.fromJson<String>(json['quantity']),
      unitPriceCents: serializer.fromJson<int>(json['unitPriceCents']),
      vatRatePercent: serializer.fromJson<double>(json['vatRatePercent']),
      unit: serializer.fromJson<String?>(json['unit']),
      discountPercent: serializer.fromJson<double>(json['discountPercent']),
      groupLabel: serializer.fromJson<String?>(json['groupLabel']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'templateId': serializer.toJson<String>(templateId),
      'kind': serializer.toJson<String>(
        $RecurringInvoiceTemplateItemsTable.$converterkind.toJson(kind),
      ),
      'articleId': serializer.toJson<String?>(articleId),
      'description': serializer.toJson<String>(description),
      'quantity': serializer.toJson<String>(quantity),
      'unitPriceCents': serializer.toJson<int>(unitPriceCents),
      'vatRatePercent': serializer.toJson<double>(vatRatePercent),
      'unit': serializer.toJson<String?>(unit),
      'discountPercent': serializer.toJson<double>(discountPercent),
      'groupLabel': serializer.toJson<String?>(groupLabel),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  RecurringInvoiceTemplateItem copyWith({
    String? id,
    String? templateId,
    InvoiceItemKind? kind,
    Value<String?> articleId = const Value.absent(),
    String? description,
    String? quantity,
    int? unitPriceCents,
    double? vatRatePercent,
    Value<String?> unit = const Value.absent(),
    double? discountPercent,
    Value<String?> groupLabel = const Value.absent(),
    int? sortOrder,
  }) => RecurringInvoiceTemplateItem(
    id: id ?? this.id,
    templateId: templateId ?? this.templateId,
    kind: kind ?? this.kind,
    articleId: articleId.present ? articleId.value : this.articleId,
    description: description ?? this.description,
    quantity: quantity ?? this.quantity,
    unitPriceCents: unitPriceCents ?? this.unitPriceCents,
    vatRatePercent: vatRatePercent ?? this.vatRatePercent,
    unit: unit.present ? unit.value : this.unit,
    discountPercent: discountPercent ?? this.discountPercent,
    groupLabel: groupLabel.present ? groupLabel.value : this.groupLabel,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  RecurringInvoiceTemplateItem copyWithCompanion(
    RecurringInvoiceTemplateItemsCompanion data,
  ) {
    return RecurringInvoiceTemplateItem(
      id: data.id.present ? data.id.value : this.id,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      kind: data.kind.present ? data.kind.value : this.kind,
      articleId: data.articleId.present ? data.articleId.value : this.articleId,
      description: data.description.present
          ? data.description.value
          : this.description,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitPriceCents: data.unitPriceCents.present
          ? data.unitPriceCents.value
          : this.unitPriceCents,
      vatRatePercent: data.vatRatePercent.present
          ? data.vatRatePercent.value
          : this.vatRatePercent,
      unit: data.unit.present ? data.unit.value : this.unit,
      discountPercent: data.discountPercent.present
          ? data.discountPercent.value
          : this.discountPercent,
      groupLabel: data.groupLabel.present
          ? data.groupLabel.value
          : this.groupLabel,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecurringInvoiceTemplateItem(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('kind: $kind, ')
          ..write('articleId: $articleId, ')
          ..write('description: $description, ')
          ..write('quantity: $quantity, ')
          ..write('unitPriceCents: $unitPriceCents, ')
          ..write('vatRatePercent: $vatRatePercent, ')
          ..write('unit: $unit, ')
          ..write('discountPercent: $discountPercent, ')
          ..write('groupLabel: $groupLabel, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    templateId,
    kind,
    articleId,
    description,
    quantity,
    unitPriceCents,
    vatRatePercent,
    unit,
    discountPercent,
    groupLabel,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurringInvoiceTemplateItem &&
          other.id == this.id &&
          other.templateId == this.templateId &&
          other.kind == this.kind &&
          other.articleId == this.articleId &&
          other.description == this.description &&
          other.quantity == this.quantity &&
          other.unitPriceCents == this.unitPriceCents &&
          other.vatRatePercent == this.vatRatePercent &&
          other.unit == this.unit &&
          other.discountPercent == this.discountPercent &&
          other.groupLabel == this.groupLabel &&
          other.sortOrder == this.sortOrder);
}

class RecurringInvoiceTemplateItemsCompanion
    extends UpdateCompanion<RecurringInvoiceTemplateItem> {
  final Value<String> id;
  final Value<String> templateId;
  final Value<InvoiceItemKind> kind;
  final Value<String?> articleId;
  final Value<String> description;
  final Value<String> quantity;
  final Value<int> unitPriceCents;
  final Value<double> vatRatePercent;
  final Value<String?> unit;
  final Value<double> discountPercent;
  final Value<String?> groupLabel;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const RecurringInvoiceTemplateItemsCompanion({
    this.id = const Value.absent(),
    this.templateId = const Value.absent(),
    this.kind = const Value.absent(),
    this.articleId = const Value.absent(),
    this.description = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitPriceCents = const Value.absent(),
    this.vatRatePercent = const Value.absent(),
    this.unit = const Value.absent(),
    this.discountPercent = const Value.absent(),
    this.groupLabel = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecurringInvoiceTemplateItemsCompanion.insert({
    required String id,
    required String templateId,
    required InvoiceItemKind kind,
    this.articleId = const Value.absent(),
    required String description,
    required String quantity,
    required int unitPriceCents,
    required double vatRatePercent,
    this.unit = const Value.absent(),
    this.discountPercent = const Value.absent(),
    this.groupLabel = const Value.absent(),
    required int sortOrder,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       templateId = Value(templateId),
       kind = Value(kind),
       description = Value(description),
       quantity = Value(quantity),
       unitPriceCents = Value(unitPriceCents),
       vatRatePercent = Value(vatRatePercent),
       sortOrder = Value(sortOrder);
  static Insertable<RecurringInvoiceTemplateItem> custom({
    Expression<String>? id,
    Expression<String>? templateId,
    Expression<String>? kind,
    Expression<String>? articleId,
    Expression<String>? description,
    Expression<String>? quantity,
    Expression<int>? unitPriceCents,
    Expression<double>? vatRatePercent,
    Expression<String>? unit,
    Expression<double>? discountPercent,
    Expression<String>? groupLabel,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (templateId != null) 'template_id': templateId,
      if (kind != null) 'kind': kind,
      if (articleId != null) 'article_id': articleId,
      if (description != null) 'description': description,
      if (quantity != null) 'quantity': quantity,
      if (unitPriceCents != null) 'unit_price_cents': unitPriceCents,
      if (vatRatePercent != null) 'vat_rate_percent': vatRatePercent,
      if (unit != null) 'unit': unit,
      if (discountPercent != null) 'discount_percent': discountPercent,
      if (groupLabel != null) 'group_label': groupLabel,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecurringInvoiceTemplateItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? templateId,
    Value<InvoiceItemKind>? kind,
    Value<String?>? articleId,
    Value<String>? description,
    Value<String>? quantity,
    Value<int>? unitPriceCents,
    Value<double>? vatRatePercent,
    Value<String?>? unit,
    Value<double>? discountPercent,
    Value<String?>? groupLabel,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return RecurringInvoiceTemplateItemsCompanion(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      kind: kind ?? this.kind,
      articleId: articleId ?? this.articleId,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPriceCents: unitPriceCents ?? this.unitPriceCents,
      vatRatePercent: vatRatePercent ?? this.vatRatePercent,
      unit: unit ?? this.unit,
      discountPercent: discountPercent ?? this.discountPercent,
      groupLabel: groupLabel ?? this.groupLabel,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $RecurringInvoiceTemplateItemsTable.$converterkind.toSql(kind.value),
      );
    }
    if (articleId.present) {
      map['article_id'] = Variable<String>(articleId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<String>(quantity.value);
    }
    if (unitPriceCents.present) {
      map['unit_price_cents'] = Variable<int>(unitPriceCents.value);
    }
    if (vatRatePercent.present) {
      map['vat_rate_percent'] = Variable<double>(vatRatePercent.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (discountPercent.present) {
      map['discount_percent'] = Variable<double>(discountPercent.value);
    }
    if (groupLabel.present) {
      map['group_label'] = Variable<String>(groupLabel.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurringInvoiceTemplateItemsCompanion(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('kind: $kind, ')
          ..write('articleId: $articleId, ')
          ..write('description: $description, ')
          ..write('quantity: $quantity, ')
          ..write('unitPriceCents: $unitPriceCents, ')
          ..write('vatRatePercent: $vatRatePercent, ')
          ..write('unit: $unit, ')
          ..write('discountPercent: $discountPercent, ')
          ..write('groupLabel: $groupLabel, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExpenseCategoriesTable extends ExpenseCategories
    with TableInfo<$ExpenseCategoriesTable, ExpenseCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpenseCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES companies (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skr03AccountMeta = const VerificationMeta(
    'skr03Account',
  );
  @override
  late final GeneratedColumn<String> skr03Account = GeneratedColumn<String>(
    'skr03_account',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    label,
    skr03Account,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expense_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExpenseCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('skr03_account')) {
      context.handle(
        _skr03AccountMeta,
        skr03Account.isAcceptableOrUnknown(
          data['skr03_account']!,
          _skr03AccountMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExpenseCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExpenseCategory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      skr03Account: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skr03_account'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ExpenseCategoriesTable createAlias(String alias) {
    return $ExpenseCategoriesTable(attachedDatabase, alias);
  }
}

class ExpenseCategory extends DataClass implements Insertable<ExpenseCategory> {
  final String id;
  final String companyId;
  final String label;

  /// SKR03-Kontonummer als Freitext (nicht als Integer — manche Konten-
  /// bezeichnungen haben führende Nullen oder Unterkonten-Suffixe).
  /// `null`, bis Kay sie selbst einträgt.
  final String? skr03Account;
  final DateTime createdAt;
  const ExpenseCategory({
    required this.id,
    required this.companyId,
    required this.label,
    this.skr03Account,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || skr03Account != null) {
      map['skr03_account'] = Variable<String>(skr03Account);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ExpenseCategoriesCompanion toCompanion(bool nullToAbsent) {
    return ExpenseCategoriesCompanion(
      id: Value(id),
      companyId: Value(companyId),
      label: Value(label),
      skr03Account: skr03Account == null && nullToAbsent
          ? const Value.absent()
          : Value(skr03Account),
      createdAt: Value(createdAt),
    );
  }

  factory ExpenseCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExpenseCategory(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      label: serializer.fromJson<String>(json['label']),
      skr03Account: serializer.fromJson<String?>(json['skr03Account']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'label': serializer.toJson<String>(label),
      'skr03Account': serializer.toJson<String?>(skr03Account),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ExpenseCategory copyWith({
    String? id,
    String? companyId,
    String? label,
    Value<String?> skr03Account = const Value.absent(),
    DateTime? createdAt,
  }) => ExpenseCategory(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    label: label ?? this.label,
    skr03Account: skr03Account.present ? skr03Account.value : this.skr03Account,
    createdAt: createdAt ?? this.createdAt,
  );
  ExpenseCategory copyWithCompanion(ExpenseCategoriesCompanion data) {
    return ExpenseCategory(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      label: data.label.present ? data.label.value : this.label,
      skr03Account: data.skr03Account.present
          ? data.skr03Account.value
          : this.skr03Account,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseCategory(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('label: $label, ')
          ..write('skr03Account: $skr03Account, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, companyId, label, skr03Account, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExpenseCategory &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.label == this.label &&
          other.skr03Account == this.skr03Account &&
          other.createdAt == this.createdAt);
}

class ExpenseCategoriesCompanion extends UpdateCompanion<ExpenseCategory> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<String> label;
  final Value<String?> skr03Account;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ExpenseCategoriesCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.label = const Value.absent(),
    this.skr03Account = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpenseCategoriesCompanion.insert({
    required String id,
    required String companyId,
    required String label,
    this.skr03Account = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       label = Value(label),
       createdAt = Value(createdAt);
  static Insertable<ExpenseCategory> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<String>? label,
    Expression<String>? skr03Account,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (label != null) 'label': label,
      if (skr03Account != null) 'skr03_account': skr03Account,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpenseCategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<String>? label,
    Value<String?>? skr03Account,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ExpenseCategoriesCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      label: label ?? this.label,
      skr03Account: skr03Account ?? this.skr03Account,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (skr03Account.present) {
      map['skr03_account'] = Variable<String>(skr03Account.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('label: $label, ')
          ..write('skr03Account: $skr03Account, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExpensesTable extends Expenses with TableInfo<$ExpensesTable, Expense> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES companies (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountGrossCentsMeta = const VerificationMeta(
    'amountGrossCents',
  );
  @override
  late final GeneratedColumn<int> amountGrossCents = GeneratedColumn<int>(
    'amount_gross_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vatRatePercentMeta = const VerificationMeta(
    'vatRatePercent',
  );
  @override
  late final GeneratedColumn<double> vatRatePercent = GeneratedColumn<double>(
    'vat_rate_percent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES expense_categories (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _supplierReferenceMeta = const VerificationMeta(
    'supplierReference',
  );
  @override
  late final GeneratedColumn<String> supplierReference =
      GeneratedColumn<String>(
        'supplier_reference',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    date,
    description,
    amountGrossCents,
    vatRatePercent,
    categoryId,
    supplierReference,
    projectId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<Expense> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('amount_gross_cents')) {
      context.handle(
        _amountGrossCentsMeta,
        amountGrossCents.isAcceptableOrUnknown(
          data['amount_gross_cents']!,
          _amountGrossCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountGrossCentsMeta);
    }
    if (data.containsKey('vat_rate_percent')) {
      context.handle(
        _vatRatePercentMeta,
        vatRatePercent.isAcceptableOrUnknown(
          data['vat_rate_percent']!,
          _vatRatePercentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_vatRatePercentMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('supplier_reference')) {
      context.handle(
        _supplierReferenceMeta,
        supplierReference.isAcceptableOrUnknown(
          data['supplier_reference']!,
          _supplierReferenceMeta,
        ),
      );
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Expense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Expense(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      amountGrossCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_gross_cents'],
      )!,
      vatRatePercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}vat_rate_percent'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      supplierReference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supplier_reference'],
      ),
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ExpensesTable createAlias(String alias) {
    return $ExpensesTable(attachedDatabase, alias);
  }
}

class Expense extends DataClass implements Insertable<Expense> {
  final String id;
  final String companyId;
  final DateTime date;
  final String description;
  final int amountGrossCents;
  final double vatRatePercent;

  /// `onDelete: setNull` — eine gelöschte/umbenannte Kategorie darf
  /// keinen bereits erfassten Beleg mitreißen (gleiches Prinzip wie bei
  /// `VehicleCostEntries.projectId`).
  final String? categoryId;

  /// Freitext für Lieferant/Belegnummer — kein eigener Lieferanten-
  /// Stammdatenbezug, das wäre für diesen Zweck Überkonstruktion.
  final String? supplierReference;

  /// Projekt-Direktkosten (Kay-Anfrage 2026-10-19: "Was brauchst du für
  /// die Projekt-Ergebnisrechnung?"). Anders als die inzwischen bewusst
  /// NICHT mehr projektbezogen gerechneten Fuhrpark-Kosten (Kay-
  /// Entscheidung: "Fuhrpark wird auf Gemeinkosten gerechnet") zählen
  /// Belege mit Projektzuordnung ECHT in die Projekt-Ergebnisrechnung
  /// (Erlöse − direkte Belege-Kosten), siehe `project_result_service.dart`.
  /// `onDelete: setNull` — ein gelöschtes Projekt reißt keinen bereits
  /// erfassten Beleg mit (gleiches Prinzip wie überall in diesem Schema).
  final String? projectId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Expense({
    required this.id,
    required this.companyId,
    required this.date,
    required this.description,
    required this.amountGrossCents,
    required this.vatRatePercent,
    this.categoryId,
    this.supplierReference,
    this.projectId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['date'] = Variable<DateTime>(date);
    map['description'] = Variable<String>(description);
    map['amount_gross_cents'] = Variable<int>(amountGrossCents);
    map['vat_rate_percent'] = Variable<double>(vatRatePercent);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || supplierReference != null) {
      map['supplier_reference'] = Variable<String>(supplierReference);
    }
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ExpensesCompanion toCompanion(bool nullToAbsent) {
    return ExpensesCompanion(
      id: Value(id),
      companyId: Value(companyId),
      date: Value(date),
      description: Value(description),
      amountGrossCents: Value(amountGrossCents),
      vatRatePercent: Value(vatRatePercent),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      supplierReference: supplierReference == null && nullToAbsent
          ? const Value.absent()
          : Value(supplierReference),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Expense.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Expense(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      date: serializer.fromJson<DateTime>(json['date']),
      description: serializer.fromJson<String>(json['description']),
      amountGrossCents: serializer.fromJson<int>(json['amountGrossCents']),
      vatRatePercent: serializer.fromJson<double>(json['vatRatePercent']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      supplierReference: serializer.fromJson<String?>(
        json['supplierReference'],
      ),
      projectId: serializer.fromJson<String?>(json['projectId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'date': serializer.toJson<DateTime>(date),
      'description': serializer.toJson<String>(description),
      'amountGrossCents': serializer.toJson<int>(amountGrossCents),
      'vatRatePercent': serializer.toJson<double>(vatRatePercent),
      'categoryId': serializer.toJson<String?>(categoryId),
      'supplierReference': serializer.toJson<String?>(supplierReference),
      'projectId': serializer.toJson<String?>(projectId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Expense copyWith({
    String? id,
    String? companyId,
    DateTime? date,
    String? description,
    int? amountGrossCents,
    double? vatRatePercent,
    Value<String?> categoryId = const Value.absent(),
    Value<String?> supplierReference = const Value.absent(),
    Value<String?> projectId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Expense(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    date: date ?? this.date,
    description: description ?? this.description,
    amountGrossCents: amountGrossCents ?? this.amountGrossCents,
    vatRatePercent: vatRatePercent ?? this.vatRatePercent,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    supplierReference: supplierReference.present
        ? supplierReference.value
        : this.supplierReference,
    projectId: projectId.present ? projectId.value : this.projectId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Expense copyWithCompanion(ExpensesCompanion data) {
    return Expense(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      date: data.date.present ? data.date.value : this.date,
      description: data.description.present
          ? data.description.value
          : this.description,
      amountGrossCents: data.amountGrossCents.present
          ? data.amountGrossCents.value
          : this.amountGrossCents,
      vatRatePercent: data.vatRatePercent.present
          ? data.vatRatePercent.value
          : this.vatRatePercent,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      supplierReference: data.supplierReference.present
          ? data.supplierReference.value
          : this.supplierReference,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Expense(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('date: $date, ')
          ..write('description: $description, ')
          ..write('amountGrossCents: $amountGrossCents, ')
          ..write('vatRatePercent: $vatRatePercent, ')
          ..write('categoryId: $categoryId, ')
          ..write('supplierReference: $supplierReference, ')
          ..write('projectId: $projectId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    date,
    description,
    amountGrossCents,
    vatRatePercent,
    categoryId,
    supplierReference,
    projectId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Expense &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.date == this.date &&
          other.description == this.description &&
          other.amountGrossCents == this.amountGrossCents &&
          other.vatRatePercent == this.vatRatePercent &&
          other.categoryId == this.categoryId &&
          other.supplierReference == this.supplierReference &&
          other.projectId == this.projectId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ExpensesCompanion extends UpdateCompanion<Expense> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<DateTime> date;
  final Value<String> description;
  final Value<int> amountGrossCents;
  final Value<double> vatRatePercent;
  final Value<String?> categoryId;
  final Value<String?> supplierReference;
  final Value<String?> projectId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ExpensesCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.date = const Value.absent(),
    this.description = const Value.absent(),
    this.amountGrossCents = const Value.absent(),
    this.vatRatePercent = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.supplierReference = const Value.absent(),
    this.projectId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpensesCompanion.insert({
    required String id,
    required String companyId,
    required DateTime date,
    required String description,
    required int amountGrossCents,
    required double vatRatePercent,
    this.categoryId = const Value.absent(),
    this.supplierReference = const Value.absent(),
    this.projectId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       date = Value(date),
       description = Value(description),
       amountGrossCents = Value(amountGrossCents),
       vatRatePercent = Value(vatRatePercent),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Expense> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<DateTime>? date,
    Expression<String>? description,
    Expression<int>? amountGrossCents,
    Expression<double>? vatRatePercent,
    Expression<String>? categoryId,
    Expression<String>? supplierReference,
    Expression<String>? projectId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (date != null) 'date': date,
      if (description != null) 'description': description,
      if (amountGrossCents != null) 'amount_gross_cents': amountGrossCents,
      if (vatRatePercent != null) 'vat_rate_percent': vatRatePercent,
      if (categoryId != null) 'category_id': categoryId,
      if (supplierReference != null) 'supplier_reference': supplierReference,
      if (projectId != null) 'project_id': projectId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpensesCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<DateTime>? date,
    Value<String>? description,
    Value<int>? amountGrossCents,
    Value<double>? vatRatePercent,
    Value<String?>? categoryId,
    Value<String?>? supplierReference,
    Value<String?>? projectId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ExpensesCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      date: date ?? this.date,
      description: description ?? this.description,
      amountGrossCents: amountGrossCents ?? this.amountGrossCents,
      vatRatePercent: vatRatePercent ?? this.vatRatePercent,
      categoryId: categoryId ?? this.categoryId,
      supplierReference: supplierReference ?? this.supplierReference,
      projectId: projectId ?? this.projectId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (amountGrossCents.present) {
      map['amount_gross_cents'] = Variable<int>(amountGrossCents.value);
    }
    if (vatRatePercent.present) {
      map['vat_rate_percent'] = Variable<double>(vatRatePercent.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (supplierReference.present) {
      map['supplier_reference'] = Variable<String>(supplierReference.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpensesCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('date: $date, ')
          ..write('description: $description, ')
          ..write('amountGrossCents: $amountGrossCents, ')
          ..write('vatRatePercent: $vatRatePercent, ')
          ..write('categoryId: $categoryId, ')
          ..write('supplierReference: $supplierReference, ')
          ..write('projectId: $projectId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BankTransactionsTable extends BankTransactions
    with TableInfo<$BankTransactionsTable, BankTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BankTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES companies (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _purposeMeta = const VerificationMeta(
    'purpose',
  );
  @override
  late final GeneratedColumn<String> purpose = GeneratedColumn<String>(
    'purpose',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _counterpartyMeta = const VerificationMeta(
    'counterparty',
  );
  @override
  late final GeneratedColumn<String> counterparty = GeneratedColumn<String>(
    'counterparty',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _matchedInvoiceIdMeta = const VerificationMeta(
    'matchedInvoiceId',
  );
  @override
  late final GeneratedColumn<String> matchedInvoiceId = GeneratedColumn<String>(
    'matched_invoice_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES invoices (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _importHashMeta = const VerificationMeta(
    'importHash',
  );
  @override
  late final GeneratedColumn<String> importHash = GeneratedColumn<String>(
    'import_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyId,
    date,
    amountCents,
    purpose,
    counterparty,
    matchedInvoiceId,
    importHash,
    importedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bank_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<BankTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('purpose')) {
      context.handle(
        _purposeMeta,
        purpose.isAcceptableOrUnknown(data['purpose']!, _purposeMeta),
      );
    }
    if (data.containsKey('counterparty')) {
      context.handle(
        _counterpartyMeta,
        counterparty.isAcceptableOrUnknown(
          data['counterparty']!,
          _counterpartyMeta,
        ),
      );
    }
    if (data.containsKey('matched_invoice_id')) {
      context.handle(
        _matchedInvoiceIdMeta,
        matchedInvoiceId.isAcceptableOrUnknown(
          data['matched_invoice_id']!,
          _matchedInvoiceIdMeta,
        ),
      );
    }
    if (data.containsKey('import_hash')) {
      context.handle(
        _importHashMeta,
        importHash.isAcceptableOrUnknown(data['import_hash']!, _importHashMeta),
      );
    } else if (isInserting) {
      context.missing(_importHashMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BankTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BankTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      purpose: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}purpose'],
      ),
      counterparty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counterparty'],
      ),
      matchedInvoiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}matched_invoice_id'],
      ),
      importHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_hash'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
    );
  }

  @override
  $BankTransactionsTable createAlias(String alias) {
    return $BankTransactionsTable(attachedDatabase, alias);
  }
}

class BankTransaction extends DataClass implements Insertable<BankTransaction> {
  final String id;
  final String companyId;
  final DateTime date;
  final int amountCents;
  final String? purpose;
  final String? counterparty;

  /// `onDelete: setNull` — eine gelöschte Rechnung darf keine bereits
  /// importierte Bank-Zeile mitreißen (gleiches Prinzip wie überall in
  /// diesem Schema).
  final String? matchedInvoiceId;

  /// Hash aus Datum+Betrag+Verwendungszweck+Auftraggeber — verhindert,
  /// dass ein erneuter Import derselben Export-Datei (z. B. mit
  /// überlappendem Zeitraum) doppelte Zeilen anlegt.
  final String importHash;
  final DateTime importedAt;
  const BankTransaction({
    required this.id,
    required this.companyId,
    required this.date,
    required this.amountCents,
    this.purpose,
    this.counterparty,
    this.matchedInvoiceId,
    required this.importHash,
    required this.importedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['company_id'] = Variable<String>(companyId);
    map['date'] = Variable<DateTime>(date);
    map['amount_cents'] = Variable<int>(amountCents);
    if (!nullToAbsent || purpose != null) {
      map['purpose'] = Variable<String>(purpose);
    }
    if (!nullToAbsent || counterparty != null) {
      map['counterparty'] = Variable<String>(counterparty);
    }
    if (!nullToAbsent || matchedInvoiceId != null) {
      map['matched_invoice_id'] = Variable<String>(matchedInvoiceId);
    }
    map['import_hash'] = Variable<String>(importHash);
    map['imported_at'] = Variable<DateTime>(importedAt);
    return map;
  }

  BankTransactionsCompanion toCompanion(bool nullToAbsent) {
    return BankTransactionsCompanion(
      id: Value(id),
      companyId: Value(companyId),
      date: Value(date),
      amountCents: Value(amountCents),
      purpose: purpose == null && nullToAbsent
          ? const Value.absent()
          : Value(purpose),
      counterparty: counterparty == null && nullToAbsent
          ? const Value.absent()
          : Value(counterparty),
      matchedInvoiceId: matchedInvoiceId == null && nullToAbsent
          ? const Value.absent()
          : Value(matchedInvoiceId),
      importHash: Value(importHash),
      importedAt: Value(importedAt),
    );
  }

  factory BankTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BankTransaction(
      id: serializer.fromJson<String>(json['id']),
      companyId: serializer.fromJson<String>(json['companyId']),
      date: serializer.fromJson<DateTime>(json['date']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      purpose: serializer.fromJson<String?>(json['purpose']),
      counterparty: serializer.fromJson<String?>(json['counterparty']),
      matchedInvoiceId: serializer.fromJson<String?>(json['matchedInvoiceId']),
      importHash: serializer.fromJson<String>(json['importHash']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'companyId': serializer.toJson<String>(companyId),
      'date': serializer.toJson<DateTime>(date),
      'amountCents': serializer.toJson<int>(amountCents),
      'purpose': serializer.toJson<String?>(purpose),
      'counterparty': serializer.toJson<String?>(counterparty),
      'matchedInvoiceId': serializer.toJson<String?>(matchedInvoiceId),
      'importHash': serializer.toJson<String>(importHash),
      'importedAt': serializer.toJson<DateTime>(importedAt),
    };
  }

  BankTransaction copyWith({
    String? id,
    String? companyId,
    DateTime? date,
    int? amountCents,
    Value<String?> purpose = const Value.absent(),
    Value<String?> counterparty = const Value.absent(),
    Value<String?> matchedInvoiceId = const Value.absent(),
    String? importHash,
    DateTime? importedAt,
  }) => BankTransaction(
    id: id ?? this.id,
    companyId: companyId ?? this.companyId,
    date: date ?? this.date,
    amountCents: amountCents ?? this.amountCents,
    purpose: purpose.present ? purpose.value : this.purpose,
    counterparty: counterparty.present ? counterparty.value : this.counterparty,
    matchedInvoiceId: matchedInvoiceId.present
        ? matchedInvoiceId.value
        : this.matchedInvoiceId,
    importHash: importHash ?? this.importHash,
    importedAt: importedAt ?? this.importedAt,
  );
  BankTransaction copyWithCompanion(BankTransactionsCompanion data) {
    return BankTransaction(
      id: data.id.present ? data.id.value : this.id,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      date: data.date.present ? data.date.value : this.date,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      purpose: data.purpose.present ? data.purpose.value : this.purpose,
      counterparty: data.counterparty.present
          ? data.counterparty.value
          : this.counterparty,
      matchedInvoiceId: data.matchedInvoiceId.present
          ? data.matchedInvoiceId.value
          : this.matchedInvoiceId,
      importHash: data.importHash.present
          ? data.importHash.value
          : this.importHash,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BankTransaction(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('date: $date, ')
          ..write('amountCents: $amountCents, ')
          ..write('purpose: $purpose, ')
          ..write('counterparty: $counterparty, ')
          ..write('matchedInvoiceId: $matchedInvoiceId, ')
          ..write('importHash: $importHash, ')
          ..write('importedAt: $importedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    companyId,
    date,
    amountCents,
    purpose,
    counterparty,
    matchedInvoiceId,
    importHash,
    importedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BankTransaction &&
          other.id == this.id &&
          other.companyId == this.companyId &&
          other.date == this.date &&
          other.amountCents == this.amountCents &&
          other.purpose == this.purpose &&
          other.counterparty == this.counterparty &&
          other.matchedInvoiceId == this.matchedInvoiceId &&
          other.importHash == this.importHash &&
          other.importedAt == this.importedAt);
}

class BankTransactionsCompanion extends UpdateCompanion<BankTransaction> {
  final Value<String> id;
  final Value<String> companyId;
  final Value<DateTime> date;
  final Value<int> amountCents;
  final Value<String?> purpose;
  final Value<String?> counterparty;
  final Value<String?> matchedInvoiceId;
  final Value<String> importHash;
  final Value<DateTime> importedAt;
  final Value<int> rowid;
  const BankTransactionsCompanion({
    this.id = const Value.absent(),
    this.companyId = const Value.absent(),
    this.date = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.purpose = const Value.absent(),
    this.counterparty = const Value.absent(),
    this.matchedInvoiceId = const Value.absent(),
    this.importHash = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BankTransactionsCompanion.insert({
    required String id,
    required String companyId,
    required DateTime date,
    required int amountCents,
    this.purpose = const Value.absent(),
    this.counterparty = const Value.absent(),
    this.matchedInvoiceId = const Value.absent(),
    required String importHash,
    required DateTime importedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       companyId = Value(companyId),
       date = Value(date),
       amountCents = Value(amountCents),
       importHash = Value(importHash),
       importedAt = Value(importedAt);
  static Insertable<BankTransaction> custom({
    Expression<String>? id,
    Expression<String>? companyId,
    Expression<DateTime>? date,
    Expression<int>? amountCents,
    Expression<String>? purpose,
    Expression<String>? counterparty,
    Expression<String>? matchedInvoiceId,
    Expression<String>? importHash,
    Expression<DateTime>? importedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyId != null) 'company_id': companyId,
      if (date != null) 'date': date,
      if (amountCents != null) 'amount_cents': amountCents,
      if (purpose != null) 'purpose': purpose,
      if (counterparty != null) 'counterparty': counterparty,
      if (matchedInvoiceId != null) 'matched_invoice_id': matchedInvoiceId,
      if (importHash != null) 'import_hash': importHash,
      if (importedAt != null) 'imported_at': importedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BankTransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? companyId,
    Value<DateTime>? date,
    Value<int>? amountCents,
    Value<String?>? purpose,
    Value<String?>? counterparty,
    Value<String?>? matchedInvoiceId,
    Value<String>? importHash,
    Value<DateTime>? importedAt,
    Value<int>? rowid,
  }) {
    return BankTransactionsCompanion(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      date: date ?? this.date,
      amountCents: amountCents ?? this.amountCents,
      purpose: purpose ?? this.purpose,
      counterparty: counterparty ?? this.counterparty,
      matchedInvoiceId: matchedInvoiceId ?? this.matchedInvoiceId,
      importHash: importHash ?? this.importHash,
      importedAt: importedAt ?? this.importedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (purpose.present) {
      map['purpose'] = Variable<String>(purpose.value);
    }
    if (counterparty.present) {
      map['counterparty'] = Variable<String>(counterparty.value);
    }
    if (matchedInvoiceId.present) {
      map['matched_invoice_id'] = Variable<String>(matchedInvoiceId.value);
    }
    if (importHash.present) {
      map['import_hash'] = Variable<String>(importHash.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BankTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('companyId: $companyId, ')
          ..write('date: $date, ')
          ..write('amountCents: $amountCents, ')
          ..write('purpose: $purpose, ')
          ..write('counterparty: $counterparty, ')
          ..write('matchedInvoiceId: $matchedInvoiceId, ')
          ..write('importHash: $importHash, ')
          ..write('importedAt: $importedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CompaniesTable companies = $CompaniesTable(this);
  late final $CustomersTable customers = $CustomersTable(this);
  late final $SuppliersTable suppliers = $SuppliersTable(this);
  late final $ArticleGroupsTable articleGroups = $ArticleGroupsTable(this);
  late final $ArticlesTable articles = $ArticlesTable(this);
  late final $ArticleSupplierPricesTable articleSupplierPrices =
      $ArticleSupplierPricesTable(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $InvoicesTable invoices = $InvoicesTable(this);
  late final $InvoiceItemsTable invoiceItems = $InvoiceItemsTable(this);
  late final $NumberSequencesTable numberSequences = $NumberSequencesTable(
    this,
  );
  late final $VehiclesTable vehicles = $VehiclesTable(this);
  late final $VehicleCostEntriesTable vehicleCostEntries =
      $VehicleCostEntriesTable(this);
  late final $RecurringInvoiceTemplatesTable recurringInvoiceTemplates =
      $RecurringInvoiceTemplatesTable(this);
  late final $RecurringInvoiceTemplateItemsTable recurringInvoiceTemplateItems =
      $RecurringInvoiceTemplateItemsTable(this);
  late final $ExpenseCategoriesTable expenseCategories =
      $ExpenseCategoriesTable(this);
  late final $ExpensesTable expenses = $ExpensesTable(this);
  late final $BankTransactionsTable bankTransactions = $BankTransactionsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    companies,
    customers,
    suppliers,
    articleGroups,
    articles,
    articleSupplierPrices,
    projects,
    invoices,
    invoiceItems,
    numberSequences,
    vehicles,
    vehicleCostEntries,
    recurringInvoiceTemplates,
    recurringInvoiceTemplateItems,
    expenseCategories,
    expenses,
    bankTransactions,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'companies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('customers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'companies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('suppliers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'companies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('article_groups', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'companies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('articles', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'article_groups',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('articles', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'suppliers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('articles', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'articles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('article_supplier_prices', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'suppliers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('article_supplier_prices', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'companies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('projects', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'customers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('projects', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'companies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('invoices', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'invoices',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('invoices', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('invoices', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'invoices',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('invoice_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'articles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('invoice_items', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'companies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('number_sequences', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'companies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('vehicles', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'companies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('vehicle_cost_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vehicles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('vehicle_cost_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('vehicle_cost_entries', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'companies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('recurring_invoice_templates', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recurring_invoice_templates',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate(
          'recurring_invoice_template_items',
          kind: UpdateKind.delete,
        ),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'articles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate(
          'recurring_invoice_template_items',
          kind: UpdateKind.update,
        ),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'companies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('expense_categories', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'companies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('expenses', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'expense_categories',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('expenses', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('expenses', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'companies',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('bank_transactions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'invoices',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('bank_transactions', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$CompaniesTableCreateCompanionBuilder =
    CompaniesCompanion Function({
      required String id,
      required String name,
      Value<String?> address,
      Value<String?> taxNumber,
      Value<String?> vatId,
      Value<String?> iban,
      Value<String?> email,
      Value<String?> phone,
      required DateTime createdAt,
      Value<bool> quotesEnabled,
      Value<bool> ordersEnabled,
      Value<bool> deliveryNotesEnabled,
      Value<bool> proformaEnabled,
      Value<bool> projectsEnabled,
      Value<bool> fleetEnabled,
      Value<bool> recurringInvoicesEnabled,
      Value<bool> advancePaymentInvoicesEnabled,
      Value<bool> dunningEnabled,
      Value<int> dunningReminder2AfterDays,
      Value<int> dunningReminder3AfterDays,
      Value<int> dunningFeeLevel1Cents,
      Value<int> dunningFeeLevel2Cents,
      Value<int> dunningFeeLevel3Cents,
      Value<double> dunningInterestRatePercent,
      Value<String?> pdfIntroTextDunning,
      Value<String?> pdfClosingTextDunning,
      Value<String?> pdfIntroText,
      Value<String?> pdfClosingText,
      Value<String?> pdfIntroTextQuote,
      Value<String?> pdfClosingTextQuote,
      Value<String?> pdfIntroTextOrder,
      Value<String?> pdfClosingTextOrder,
      Value<String?> pdfIntroTextDeliveryNote,
      Value<String?> pdfClosingTextDeliveryNote,
      Value<String?> pdfIntroTextProforma,
      Value<String?> pdfClosingTextProforma,
      Value<String?> pdfFooterText,
      Value<bool> smtpEnabled,
      Value<String?> smtpHost,
      Value<int> smtpPort,
      Value<String?> smtpUsername,
      Value<String?> smtpFromAddress,
      Value<String?> smtpFromName,
      Value<bool> smtpUseTls,
      Value<String?> smtpInvoiceSubjectTemplate,
      Value<String?> smtpInvoiceBodyTemplate,
      Value<String?> smtpDunningSubjectTemplate,
      Value<String?> smtpDunningBodyTemplate,
      Value<bool> buchhaltungEnabled,
      Value<String> bankCsvDelimiter,
      Value<bool> bankCsvHasHeaderRow,
      Value<String?> bankCsvDateColumn,
      Value<String?> bankCsvAmountColumn,
      Value<String?> bankCsvPurposeColumn,
      Value<String?> bankCsvCounterpartyColumn,
      Value<String> bankCsvDateFormat,
      Value<String> bankCsvDecimalSeparator,
      Value<String?> datevBeraterNummer,
      Value<String?> datevMandantNummer,
      Value<String?> datevBankGegenkonto,
      Value<int> datevSachkontenlaenge,
      Value<bool> creditNotesEnabled,
      Value<String?> pdfIntroTextCreditNote,
      Value<String?> pdfClosingTextCreditNote,
      Value<bool> isSmallBusinessExempt,
      Value<int> rowid,
    });
typedef $$CompaniesTableUpdateCompanionBuilder =
    CompaniesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> address,
      Value<String?> taxNumber,
      Value<String?> vatId,
      Value<String?> iban,
      Value<String?> email,
      Value<String?> phone,
      Value<DateTime> createdAt,
      Value<bool> quotesEnabled,
      Value<bool> ordersEnabled,
      Value<bool> deliveryNotesEnabled,
      Value<bool> proformaEnabled,
      Value<bool> projectsEnabled,
      Value<bool> fleetEnabled,
      Value<bool> recurringInvoicesEnabled,
      Value<bool> advancePaymentInvoicesEnabled,
      Value<bool> dunningEnabled,
      Value<int> dunningReminder2AfterDays,
      Value<int> dunningReminder3AfterDays,
      Value<int> dunningFeeLevel1Cents,
      Value<int> dunningFeeLevel2Cents,
      Value<int> dunningFeeLevel3Cents,
      Value<double> dunningInterestRatePercent,
      Value<String?> pdfIntroTextDunning,
      Value<String?> pdfClosingTextDunning,
      Value<String?> pdfIntroText,
      Value<String?> pdfClosingText,
      Value<String?> pdfIntroTextQuote,
      Value<String?> pdfClosingTextQuote,
      Value<String?> pdfIntroTextOrder,
      Value<String?> pdfClosingTextOrder,
      Value<String?> pdfIntroTextDeliveryNote,
      Value<String?> pdfClosingTextDeliveryNote,
      Value<String?> pdfIntroTextProforma,
      Value<String?> pdfClosingTextProforma,
      Value<String?> pdfFooterText,
      Value<bool> smtpEnabled,
      Value<String?> smtpHost,
      Value<int> smtpPort,
      Value<String?> smtpUsername,
      Value<String?> smtpFromAddress,
      Value<String?> smtpFromName,
      Value<bool> smtpUseTls,
      Value<String?> smtpInvoiceSubjectTemplate,
      Value<String?> smtpInvoiceBodyTemplate,
      Value<String?> smtpDunningSubjectTemplate,
      Value<String?> smtpDunningBodyTemplate,
      Value<bool> buchhaltungEnabled,
      Value<String> bankCsvDelimiter,
      Value<bool> bankCsvHasHeaderRow,
      Value<String?> bankCsvDateColumn,
      Value<String?> bankCsvAmountColumn,
      Value<String?> bankCsvPurposeColumn,
      Value<String?> bankCsvCounterpartyColumn,
      Value<String> bankCsvDateFormat,
      Value<String> bankCsvDecimalSeparator,
      Value<String?> datevBeraterNummer,
      Value<String?> datevMandantNummer,
      Value<String?> datevBankGegenkonto,
      Value<int> datevSachkontenlaenge,
      Value<bool> creditNotesEnabled,
      Value<String?> pdfIntroTextCreditNote,
      Value<String?> pdfClosingTextCreditNote,
      Value<bool> isSmallBusinessExempt,
      Value<int> rowid,
    });

final class $$CompaniesTableReferences
    extends BaseReferences<_$AppDatabase, $CompaniesTable, Company> {
  $$CompaniesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CustomersTable, List<Customer>>
  _customersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.customers,
    aliasName: 'companies__id__customers__company_id',
  );

  $$CustomersTableProcessedTableManager get customersRefs {
    final manager = $$CustomersTableTableManager(
      $_db,
      $_db.customers,
    ).filter((f) => f.companyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_customersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SuppliersTable, List<Supplier>>
  _suppliersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.suppliers,
    aliasName: 'companies__id__suppliers__company_id',
  );

  $$SuppliersTableProcessedTableManager get suppliersRefs {
    final manager = $$SuppliersTableTableManager(
      $_db,
      $_db.suppliers,
    ).filter((f) => f.companyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_suppliersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ArticleGroupsTable, List<ArticleGroup>>
  _articleGroupsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.articleGroups,
    aliasName: 'companies__id__article_groups__company_id',
  );

  $$ArticleGroupsTableProcessedTableManager get articleGroupsRefs {
    final manager = $$ArticleGroupsTableTableManager(
      $_db,
      $_db.articleGroups,
    ).filter((f) => f.companyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_articleGroupsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ArticlesTable, List<Article>> _articlesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.articles,
    aliasName: 'companies__id__articles__company_id',
  );

  $$ArticlesTableProcessedTableManager get articlesRefs {
    final manager = $$ArticlesTableTableManager(
      $_db,
      $_db.articles,
    ).filter((f) => f.companyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_articlesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProjectsTable, List<Project>> _projectsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.projects,
    aliasName: 'companies__id__projects__company_id',
  );

  $$ProjectsTableProcessedTableManager get projectsRefs {
    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.companyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_projectsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$InvoicesTable, List<Invoice>> _invoicesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.invoices,
    aliasName: 'companies__id__invoices__company_id',
  );

  $$InvoicesTableProcessedTableManager get invoicesRefs {
    final manager = $$InvoicesTableTableManager(
      $_db,
      $_db.invoices,
    ).filter((f) => f.companyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_invoicesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NumberSequencesTable, List<NumberSequence>>
  _numberSequencesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.numberSequences,
    aliasName: 'companies__id__number_sequences__company_id',
  );

  $$NumberSequencesTableProcessedTableManager get numberSequencesRefs {
    final manager = $$NumberSequencesTableTableManager(
      $_db,
      $_db.numberSequences,
    ).filter((f) => f.companyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _numberSequencesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$VehiclesTable, List<Vehicle>> _vehiclesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.vehicles,
    aliasName: 'companies__id__vehicles__company_id',
  );

  $$VehiclesTableProcessedTableManager get vehiclesRefs {
    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.companyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_vehiclesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$VehicleCostEntriesTable, List<VehicleCostEntry>>
  _vehicleCostEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.vehicleCostEntries,
        aliasName: 'companies__id__vehicle_cost_entries__company_id',
      );

  $$VehicleCostEntriesTableProcessedTableManager get vehicleCostEntriesRefs {
    final manager = $$VehicleCostEntriesTableTableManager(
      $_db,
      $_db.vehicleCostEntries,
    ).filter((f) => f.companyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _vehicleCostEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $RecurringInvoiceTemplatesTable,
    List<RecurringInvoiceTemplate>
  >
  _recurringInvoiceTemplatesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.recurringInvoiceTemplates,
        aliasName: 'companies__id__recurring_invoice_templates__company_id',
      );

  $$RecurringInvoiceTemplatesTableProcessedTableManager
  get recurringInvoiceTemplatesRefs {
    final manager = $$RecurringInvoiceTemplatesTableTableManager(
      $_db,
      $_db.recurringInvoiceTemplates,
    ).filter((f) => f.companyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _recurringInvoiceTemplatesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ExpenseCategoriesTable, List<ExpenseCategory>>
  _expenseCategoriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.expenseCategories,
        aliasName: 'companies__id__expense_categories__company_id',
      );

  $$ExpenseCategoriesTableProcessedTableManager get expenseCategoriesRefs {
    final manager = $$ExpenseCategoriesTableTableManager(
      $_db,
      $_db.expenseCategories,
    ).filter((f) => f.companyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _expenseCategoriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ExpensesTable, List<Expense>> _expensesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.expenses,
    aliasName: 'companies__id__expenses__company_id',
  );

  $$ExpensesTableProcessedTableManager get expensesRefs {
    final manager = $$ExpensesTableTableManager(
      $_db,
      $_db.expenses,
    ).filter((f) => f.companyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_expensesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BankTransactionsTable, List<BankTransaction>>
  _bankTransactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bankTransactions,
    aliasName: 'companies__id__bank_transactions__company_id',
  );

  $$BankTransactionsTableProcessedTableManager get bankTransactionsRefs {
    final manager = $$BankTransactionsTableTableManager(
      $_db,
      $_db.bankTransactions,
    ).filter((f) => f.companyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _bankTransactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CompaniesTableFilterComposer
    extends Composer<_$AppDatabase, $CompaniesTable> {
  $$CompaniesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taxNumber => $composableBuilder(
    column: $table.taxNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vatId => $composableBuilder(
    column: $table.vatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iban => $composableBuilder(
    column: $table.iban,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get quotesEnabled => $composableBuilder(
    column: $table.quotesEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ordersEnabled => $composableBuilder(
    column: $table.ordersEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deliveryNotesEnabled => $composableBuilder(
    column: $table.deliveryNotesEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get proformaEnabled => $composableBuilder(
    column: $table.proformaEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get projectsEnabled => $composableBuilder(
    column: $table.projectsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fleetEnabled => $composableBuilder(
    column: $table.fleetEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get recurringInvoicesEnabled => $composableBuilder(
    column: $table.recurringInvoicesEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get advancePaymentInvoicesEnabled => $composableBuilder(
    column: $table.advancePaymentInvoicesEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dunningEnabled => $composableBuilder(
    column: $table.dunningEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dunningReminder2AfterDays => $composableBuilder(
    column: $table.dunningReminder2AfterDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dunningReminder3AfterDays => $composableBuilder(
    column: $table.dunningReminder3AfterDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dunningFeeLevel1Cents => $composableBuilder(
    column: $table.dunningFeeLevel1Cents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dunningFeeLevel2Cents => $composableBuilder(
    column: $table.dunningFeeLevel2Cents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dunningFeeLevel3Cents => $composableBuilder(
    column: $table.dunningFeeLevel3Cents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dunningInterestRatePercent => $composableBuilder(
    column: $table.dunningInterestRatePercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfIntroTextDunning => $composableBuilder(
    column: $table.pdfIntroTextDunning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfClosingTextDunning => $composableBuilder(
    column: $table.pdfClosingTextDunning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfIntroText => $composableBuilder(
    column: $table.pdfIntroText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfClosingText => $composableBuilder(
    column: $table.pdfClosingText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfIntroTextQuote => $composableBuilder(
    column: $table.pdfIntroTextQuote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfClosingTextQuote => $composableBuilder(
    column: $table.pdfClosingTextQuote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfIntroTextOrder => $composableBuilder(
    column: $table.pdfIntroTextOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfClosingTextOrder => $composableBuilder(
    column: $table.pdfClosingTextOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfIntroTextDeliveryNote => $composableBuilder(
    column: $table.pdfIntroTextDeliveryNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfClosingTextDeliveryNote => $composableBuilder(
    column: $table.pdfClosingTextDeliveryNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfIntroTextProforma => $composableBuilder(
    column: $table.pdfIntroTextProforma,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfClosingTextProforma => $composableBuilder(
    column: $table.pdfClosingTextProforma,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfFooterText => $composableBuilder(
    column: $table.pdfFooterText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get smtpEnabled => $composableBuilder(
    column: $table.smtpEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get smtpHost => $composableBuilder(
    column: $table.smtpHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get smtpPort => $composableBuilder(
    column: $table.smtpPort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get smtpUsername => $composableBuilder(
    column: $table.smtpUsername,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get smtpFromAddress => $composableBuilder(
    column: $table.smtpFromAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get smtpFromName => $composableBuilder(
    column: $table.smtpFromName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get smtpUseTls => $composableBuilder(
    column: $table.smtpUseTls,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get smtpInvoiceSubjectTemplate => $composableBuilder(
    column: $table.smtpInvoiceSubjectTemplate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get smtpInvoiceBodyTemplate => $composableBuilder(
    column: $table.smtpInvoiceBodyTemplate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get smtpDunningSubjectTemplate => $composableBuilder(
    column: $table.smtpDunningSubjectTemplate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get smtpDunningBodyTemplate => $composableBuilder(
    column: $table.smtpDunningBodyTemplate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get buchhaltungEnabled => $composableBuilder(
    column: $table.buchhaltungEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bankCsvDelimiter => $composableBuilder(
    column: $table.bankCsvDelimiter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get bankCsvHasHeaderRow => $composableBuilder(
    column: $table.bankCsvHasHeaderRow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bankCsvDateColumn => $composableBuilder(
    column: $table.bankCsvDateColumn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bankCsvAmountColumn => $composableBuilder(
    column: $table.bankCsvAmountColumn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bankCsvPurposeColumn => $composableBuilder(
    column: $table.bankCsvPurposeColumn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bankCsvCounterpartyColumn => $composableBuilder(
    column: $table.bankCsvCounterpartyColumn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bankCsvDateFormat => $composableBuilder(
    column: $table.bankCsvDateFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bankCsvDecimalSeparator => $composableBuilder(
    column: $table.bankCsvDecimalSeparator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get datevBeraterNummer => $composableBuilder(
    column: $table.datevBeraterNummer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get datevMandantNummer => $composableBuilder(
    column: $table.datevMandantNummer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get datevBankGegenkonto => $composableBuilder(
    column: $table.datevBankGegenkonto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get datevSachkontenlaenge => $composableBuilder(
    column: $table.datevSachkontenlaenge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get creditNotesEnabled => $composableBuilder(
    column: $table.creditNotesEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfIntroTextCreditNote => $composableBuilder(
    column: $table.pdfIntroTextCreditNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfClosingTextCreditNote => $composableBuilder(
    column: $table.pdfClosingTextCreditNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSmallBusinessExempt => $composableBuilder(
    column: $table.isSmallBusinessExempt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> customersRefs(
    Expression<bool> Function($$CustomersTableFilterComposer f) f,
  ) {
    final $$CustomersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomersTableFilterComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> suppliersRefs(
    Expression<bool> Function($$SuppliersTableFilterComposer f) f,
  ) {
    final $$SuppliersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.suppliers,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliersTableFilterComposer(
            $db: $db,
            $table: $db.suppliers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> articleGroupsRefs(
    Expression<bool> Function($$ArticleGroupsTableFilterComposer f) f,
  ) {
    final $$ArticleGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.articleGroups,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticleGroupsTableFilterComposer(
            $db: $db,
            $table: $db.articleGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> articlesRefs(
    Expression<bool> Function($$ArticlesTableFilterComposer f) f,
  ) {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableFilterComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> projectsRefs(
    Expression<bool> Function($$ProjectsTableFilterComposer f) f,
  ) {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> invoicesRefs(
    Expression<bool> Function($$InvoicesTableFilterComposer f) f,
  ) {
    final $$InvoicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableFilterComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> numberSequencesRefs(
    Expression<bool> Function($$NumberSequencesTableFilterComposer f) f,
  ) {
    final $$NumberSequencesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.numberSequences,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NumberSequencesTableFilterComposer(
            $db: $db,
            $table: $db.numberSequences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> vehiclesRefs(
    Expression<bool> Function($$VehiclesTableFilterComposer f) f,
  ) {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> vehicleCostEntriesRefs(
    Expression<bool> Function($$VehicleCostEntriesTableFilterComposer f) f,
  ) {
    final $$VehicleCostEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.vehicleCostEntries,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehicleCostEntriesTableFilterComposer(
            $db: $db,
            $table: $db.vehicleCostEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recurringInvoiceTemplatesRefs(
    Expression<bool> Function($$RecurringInvoiceTemplatesTableFilterComposer f)
    f,
  ) {
    final $$RecurringInvoiceTemplatesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.recurringInvoiceTemplates,
          getReferencedColumn: (t) => t.companyId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecurringInvoiceTemplatesTableFilterComposer(
                $db: $db,
                $table: $db.recurringInvoiceTemplates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> expenseCategoriesRefs(
    Expression<bool> Function($$ExpenseCategoriesTableFilterComposer f) f,
  ) {
    final $$ExpenseCategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenseCategories,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpenseCategoriesTableFilterComposer(
            $db: $db,
            $table: $db.expenseCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> expensesRefs(
    Expression<bool> Function($$ExpensesTableFilterComposer f) f,
  ) {
    final $$ExpensesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenses,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpensesTableFilterComposer(
            $db: $db,
            $table: $db.expenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bankTransactionsRefs(
    Expression<bool> Function($$BankTransactionsTableFilterComposer f) f,
  ) {
    final $$BankTransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bankTransactions,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BankTransactionsTableFilterComposer(
            $db: $db,
            $table: $db.bankTransactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CompaniesTableOrderingComposer
    extends Composer<_$AppDatabase, $CompaniesTable> {
  $$CompaniesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taxNumber => $composableBuilder(
    column: $table.taxNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vatId => $composableBuilder(
    column: $table.vatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iban => $composableBuilder(
    column: $table.iban,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get quotesEnabled => $composableBuilder(
    column: $table.quotesEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ordersEnabled => $composableBuilder(
    column: $table.ordersEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deliveryNotesEnabled => $composableBuilder(
    column: $table.deliveryNotesEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get proformaEnabled => $composableBuilder(
    column: $table.proformaEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get projectsEnabled => $composableBuilder(
    column: $table.projectsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fleetEnabled => $composableBuilder(
    column: $table.fleetEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get recurringInvoicesEnabled => $composableBuilder(
    column: $table.recurringInvoicesEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get advancePaymentInvoicesEnabled => $composableBuilder(
    column: $table.advancePaymentInvoicesEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dunningEnabled => $composableBuilder(
    column: $table.dunningEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dunningReminder2AfterDays => $composableBuilder(
    column: $table.dunningReminder2AfterDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dunningReminder3AfterDays => $composableBuilder(
    column: $table.dunningReminder3AfterDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dunningFeeLevel1Cents => $composableBuilder(
    column: $table.dunningFeeLevel1Cents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dunningFeeLevel2Cents => $composableBuilder(
    column: $table.dunningFeeLevel2Cents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dunningFeeLevel3Cents => $composableBuilder(
    column: $table.dunningFeeLevel3Cents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dunningInterestRatePercent => $composableBuilder(
    column: $table.dunningInterestRatePercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfIntroTextDunning => $composableBuilder(
    column: $table.pdfIntroTextDunning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfClosingTextDunning => $composableBuilder(
    column: $table.pdfClosingTextDunning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfIntroText => $composableBuilder(
    column: $table.pdfIntroText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfClosingText => $composableBuilder(
    column: $table.pdfClosingText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfIntroTextQuote => $composableBuilder(
    column: $table.pdfIntroTextQuote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfClosingTextQuote => $composableBuilder(
    column: $table.pdfClosingTextQuote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfIntroTextOrder => $composableBuilder(
    column: $table.pdfIntroTextOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfClosingTextOrder => $composableBuilder(
    column: $table.pdfClosingTextOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfIntroTextDeliveryNote => $composableBuilder(
    column: $table.pdfIntroTextDeliveryNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfClosingTextDeliveryNote => $composableBuilder(
    column: $table.pdfClosingTextDeliveryNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfIntroTextProforma => $composableBuilder(
    column: $table.pdfIntroTextProforma,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfClosingTextProforma => $composableBuilder(
    column: $table.pdfClosingTextProforma,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfFooterText => $composableBuilder(
    column: $table.pdfFooterText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get smtpEnabled => $composableBuilder(
    column: $table.smtpEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get smtpHost => $composableBuilder(
    column: $table.smtpHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get smtpPort => $composableBuilder(
    column: $table.smtpPort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get smtpUsername => $composableBuilder(
    column: $table.smtpUsername,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get smtpFromAddress => $composableBuilder(
    column: $table.smtpFromAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get smtpFromName => $composableBuilder(
    column: $table.smtpFromName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get smtpUseTls => $composableBuilder(
    column: $table.smtpUseTls,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get smtpInvoiceSubjectTemplate => $composableBuilder(
    column: $table.smtpInvoiceSubjectTemplate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get smtpInvoiceBodyTemplate => $composableBuilder(
    column: $table.smtpInvoiceBodyTemplate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get smtpDunningSubjectTemplate => $composableBuilder(
    column: $table.smtpDunningSubjectTemplate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get smtpDunningBodyTemplate => $composableBuilder(
    column: $table.smtpDunningBodyTemplate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get buchhaltungEnabled => $composableBuilder(
    column: $table.buchhaltungEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankCsvDelimiter => $composableBuilder(
    column: $table.bankCsvDelimiter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get bankCsvHasHeaderRow => $composableBuilder(
    column: $table.bankCsvHasHeaderRow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankCsvDateColumn => $composableBuilder(
    column: $table.bankCsvDateColumn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankCsvAmountColumn => $composableBuilder(
    column: $table.bankCsvAmountColumn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankCsvPurposeColumn => $composableBuilder(
    column: $table.bankCsvPurposeColumn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankCsvCounterpartyColumn => $composableBuilder(
    column: $table.bankCsvCounterpartyColumn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankCsvDateFormat => $composableBuilder(
    column: $table.bankCsvDateFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankCsvDecimalSeparator => $composableBuilder(
    column: $table.bankCsvDecimalSeparator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get datevBeraterNummer => $composableBuilder(
    column: $table.datevBeraterNummer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get datevMandantNummer => $composableBuilder(
    column: $table.datevMandantNummer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get datevBankGegenkonto => $composableBuilder(
    column: $table.datevBankGegenkonto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get datevSachkontenlaenge => $composableBuilder(
    column: $table.datevSachkontenlaenge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get creditNotesEnabled => $composableBuilder(
    column: $table.creditNotesEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfIntroTextCreditNote => $composableBuilder(
    column: $table.pdfIntroTextCreditNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfClosingTextCreditNote => $composableBuilder(
    column: $table.pdfClosingTextCreditNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSmallBusinessExempt => $composableBuilder(
    column: $table.isSmallBusinessExempt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CompaniesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CompaniesTable> {
  $$CompaniesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get taxNumber =>
      $composableBuilder(column: $table.taxNumber, builder: (column) => column);

  GeneratedColumn<String> get vatId =>
      $composableBuilder(column: $table.vatId, builder: (column) => column);

  GeneratedColumn<String> get iban =>
      $composableBuilder(column: $table.iban, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get quotesEnabled => $composableBuilder(
    column: $table.quotesEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get ordersEnabled => $composableBuilder(
    column: $table.ordersEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deliveryNotesEnabled => $composableBuilder(
    column: $table.deliveryNotesEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get proformaEnabled => $composableBuilder(
    column: $table.proformaEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get projectsEnabled => $composableBuilder(
    column: $table.projectsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get fleetEnabled => $composableBuilder(
    column: $table.fleetEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get recurringInvoicesEnabled => $composableBuilder(
    column: $table.recurringInvoicesEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get advancePaymentInvoicesEnabled => $composableBuilder(
    column: $table.advancePaymentInvoicesEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get dunningEnabled => $composableBuilder(
    column: $table.dunningEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dunningReminder2AfterDays => $composableBuilder(
    column: $table.dunningReminder2AfterDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dunningReminder3AfterDays => $composableBuilder(
    column: $table.dunningReminder3AfterDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dunningFeeLevel1Cents => $composableBuilder(
    column: $table.dunningFeeLevel1Cents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dunningFeeLevel2Cents => $composableBuilder(
    column: $table.dunningFeeLevel2Cents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dunningFeeLevel3Cents => $composableBuilder(
    column: $table.dunningFeeLevel3Cents,
    builder: (column) => column,
  );

  GeneratedColumn<double> get dunningInterestRatePercent => $composableBuilder(
    column: $table.dunningInterestRatePercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfIntroTextDunning => $composableBuilder(
    column: $table.pdfIntroTextDunning,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfClosingTextDunning => $composableBuilder(
    column: $table.pdfClosingTextDunning,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfIntroText => $composableBuilder(
    column: $table.pdfIntroText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfClosingText => $composableBuilder(
    column: $table.pdfClosingText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfIntroTextQuote => $composableBuilder(
    column: $table.pdfIntroTextQuote,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfClosingTextQuote => $composableBuilder(
    column: $table.pdfClosingTextQuote,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfIntroTextOrder => $composableBuilder(
    column: $table.pdfIntroTextOrder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfClosingTextOrder => $composableBuilder(
    column: $table.pdfClosingTextOrder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfIntroTextDeliveryNote => $composableBuilder(
    column: $table.pdfIntroTextDeliveryNote,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfClosingTextDeliveryNote => $composableBuilder(
    column: $table.pdfClosingTextDeliveryNote,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfIntroTextProforma => $composableBuilder(
    column: $table.pdfIntroTextProforma,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfClosingTextProforma => $composableBuilder(
    column: $table.pdfClosingTextProforma,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfFooterText => $composableBuilder(
    column: $table.pdfFooterText,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get smtpEnabled => $composableBuilder(
    column: $table.smtpEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get smtpHost =>
      $composableBuilder(column: $table.smtpHost, builder: (column) => column);

  GeneratedColumn<int> get smtpPort =>
      $composableBuilder(column: $table.smtpPort, builder: (column) => column);

  GeneratedColumn<String> get smtpUsername => $composableBuilder(
    column: $table.smtpUsername,
    builder: (column) => column,
  );

  GeneratedColumn<String> get smtpFromAddress => $composableBuilder(
    column: $table.smtpFromAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get smtpFromName => $composableBuilder(
    column: $table.smtpFromName,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get smtpUseTls => $composableBuilder(
    column: $table.smtpUseTls,
    builder: (column) => column,
  );

  GeneratedColumn<String> get smtpInvoiceSubjectTemplate => $composableBuilder(
    column: $table.smtpInvoiceSubjectTemplate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get smtpInvoiceBodyTemplate => $composableBuilder(
    column: $table.smtpInvoiceBodyTemplate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get smtpDunningSubjectTemplate => $composableBuilder(
    column: $table.smtpDunningSubjectTemplate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get smtpDunningBodyTemplate => $composableBuilder(
    column: $table.smtpDunningBodyTemplate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get buchhaltungEnabled => $composableBuilder(
    column: $table.buchhaltungEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bankCsvDelimiter => $composableBuilder(
    column: $table.bankCsvDelimiter,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get bankCsvHasHeaderRow => $composableBuilder(
    column: $table.bankCsvHasHeaderRow,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bankCsvDateColumn => $composableBuilder(
    column: $table.bankCsvDateColumn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bankCsvAmountColumn => $composableBuilder(
    column: $table.bankCsvAmountColumn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bankCsvPurposeColumn => $composableBuilder(
    column: $table.bankCsvPurposeColumn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bankCsvCounterpartyColumn => $composableBuilder(
    column: $table.bankCsvCounterpartyColumn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bankCsvDateFormat => $composableBuilder(
    column: $table.bankCsvDateFormat,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bankCsvDecimalSeparator => $composableBuilder(
    column: $table.bankCsvDecimalSeparator,
    builder: (column) => column,
  );

  GeneratedColumn<String> get datevBeraterNummer => $composableBuilder(
    column: $table.datevBeraterNummer,
    builder: (column) => column,
  );

  GeneratedColumn<String> get datevMandantNummer => $composableBuilder(
    column: $table.datevMandantNummer,
    builder: (column) => column,
  );

  GeneratedColumn<String> get datevBankGegenkonto => $composableBuilder(
    column: $table.datevBankGegenkonto,
    builder: (column) => column,
  );

  GeneratedColumn<int> get datevSachkontenlaenge => $composableBuilder(
    column: $table.datevSachkontenlaenge,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get creditNotesEnabled => $composableBuilder(
    column: $table.creditNotesEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfIntroTextCreditNote => $composableBuilder(
    column: $table.pdfIntroTextCreditNote,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfClosingTextCreditNote => $composableBuilder(
    column: $table.pdfClosingTextCreditNote,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSmallBusinessExempt => $composableBuilder(
    column: $table.isSmallBusinessExempt,
    builder: (column) => column,
  );

  Expression<T> customersRefs<T extends Object>(
    Expression<T> Function($$CustomersTableAnnotationComposer a) f,
  ) {
    final $$CustomersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomersTableAnnotationComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> suppliersRefs<T extends Object>(
    Expression<T> Function($$SuppliersTableAnnotationComposer a) f,
  ) {
    final $$SuppliersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.suppliers,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliersTableAnnotationComposer(
            $db: $db,
            $table: $db.suppliers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> articleGroupsRefs<T extends Object>(
    Expression<T> Function($$ArticleGroupsTableAnnotationComposer a) f,
  ) {
    final $$ArticleGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.articleGroups,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticleGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.articleGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> articlesRefs<T extends Object>(
    Expression<T> Function($$ArticlesTableAnnotationComposer a) f,
  ) {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableAnnotationComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> projectsRefs<T extends Object>(
    Expression<T> Function($$ProjectsTableAnnotationComposer a) f,
  ) {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> invoicesRefs<T extends Object>(
    Expression<T> Function($$InvoicesTableAnnotationComposer a) f,
  ) {
    final $$InvoicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableAnnotationComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> numberSequencesRefs<T extends Object>(
    Expression<T> Function($$NumberSequencesTableAnnotationComposer a) f,
  ) {
    final $$NumberSequencesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.numberSequences,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NumberSequencesTableAnnotationComposer(
            $db: $db,
            $table: $db.numberSequences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> vehiclesRefs<T extends Object>(
    Expression<T> Function($$VehiclesTableAnnotationComposer a) f,
  ) {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> vehicleCostEntriesRefs<T extends Object>(
    Expression<T> Function($$VehicleCostEntriesTableAnnotationComposer a) f,
  ) {
    final $$VehicleCostEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.vehicleCostEntries,
          getReferencedColumn: (t) => t.companyId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$VehicleCostEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.vehicleCostEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> recurringInvoiceTemplatesRefs<T extends Object>(
    Expression<T> Function($$RecurringInvoiceTemplatesTableAnnotationComposer a)
    f,
  ) {
    final $$RecurringInvoiceTemplatesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.recurringInvoiceTemplates,
          getReferencedColumn: (t) => t.companyId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecurringInvoiceTemplatesTableAnnotationComposer(
                $db: $db,
                $table: $db.recurringInvoiceTemplates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> expenseCategoriesRefs<T extends Object>(
    Expression<T> Function($$ExpenseCategoriesTableAnnotationComposer a) f,
  ) {
    final $$ExpenseCategoriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.expenseCategories,
          getReferencedColumn: (t) => t.companyId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ExpenseCategoriesTableAnnotationComposer(
                $db: $db,
                $table: $db.expenseCategories,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> expensesRefs<T extends Object>(
    Expression<T> Function($$ExpensesTableAnnotationComposer a) f,
  ) {
    final $$ExpensesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenses,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpensesTableAnnotationComposer(
            $db: $db,
            $table: $db.expenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bankTransactionsRefs<T extends Object>(
    Expression<T> Function($$BankTransactionsTableAnnotationComposer a) f,
  ) {
    final $$BankTransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bankTransactions,
      getReferencedColumn: (t) => t.companyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BankTransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.bankTransactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CompaniesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CompaniesTable,
          Company,
          $$CompaniesTableFilterComposer,
          $$CompaniesTableOrderingComposer,
          $$CompaniesTableAnnotationComposer,
          $$CompaniesTableCreateCompanionBuilder,
          $$CompaniesTableUpdateCompanionBuilder,
          (Company, $$CompaniesTableReferences),
          Company,
          PrefetchHooks Function({
            bool customersRefs,
            bool suppliersRefs,
            bool articleGroupsRefs,
            bool articlesRefs,
            bool projectsRefs,
            bool invoicesRefs,
            bool numberSequencesRefs,
            bool vehiclesRefs,
            bool vehicleCostEntriesRefs,
            bool recurringInvoiceTemplatesRefs,
            bool expenseCategoriesRefs,
            bool expensesRefs,
            bool bankTransactionsRefs,
          })
        > {
  $$CompaniesTableTableManager(_$AppDatabase db, $CompaniesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompaniesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompaniesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompaniesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> taxNumber = const Value.absent(),
                Value<String?> vatId = const Value.absent(),
                Value<String?> iban = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> quotesEnabled = const Value.absent(),
                Value<bool> ordersEnabled = const Value.absent(),
                Value<bool> deliveryNotesEnabled = const Value.absent(),
                Value<bool> proformaEnabled = const Value.absent(),
                Value<bool> projectsEnabled = const Value.absent(),
                Value<bool> fleetEnabled = const Value.absent(),
                Value<bool> recurringInvoicesEnabled = const Value.absent(),
                Value<bool> advancePaymentInvoicesEnabled =
                    const Value.absent(),
                Value<bool> dunningEnabled = const Value.absent(),
                Value<int> dunningReminder2AfterDays = const Value.absent(),
                Value<int> dunningReminder3AfterDays = const Value.absent(),
                Value<int> dunningFeeLevel1Cents = const Value.absent(),
                Value<int> dunningFeeLevel2Cents = const Value.absent(),
                Value<int> dunningFeeLevel3Cents = const Value.absent(),
                Value<double> dunningInterestRatePercent = const Value.absent(),
                Value<String?> pdfIntroTextDunning = const Value.absent(),
                Value<String?> pdfClosingTextDunning = const Value.absent(),
                Value<String?> pdfIntroText = const Value.absent(),
                Value<String?> pdfClosingText = const Value.absent(),
                Value<String?> pdfIntroTextQuote = const Value.absent(),
                Value<String?> pdfClosingTextQuote = const Value.absent(),
                Value<String?> pdfIntroTextOrder = const Value.absent(),
                Value<String?> pdfClosingTextOrder = const Value.absent(),
                Value<String?> pdfIntroTextDeliveryNote = const Value.absent(),
                Value<String?> pdfClosingTextDeliveryNote =
                    const Value.absent(),
                Value<String?> pdfIntroTextProforma = const Value.absent(),
                Value<String?> pdfClosingTextProforma = const Value.absent(),
                Value<String?> pdfFooterText = const Value.absent(),
                Value<bool> smtpEnabled = const Value.absent(),
                Value<String?> smtpHost = const Value.absent(),
                Value<int> smtpPort = const Value.absent(),
                Value<String?> smtpUsername = const Value.absent(),
                Value<String?> smtpFromAddress = const Value.absent(),
                Value<String?> smtpFromName = const Value.absent(),
                Value<bool> smtpUseTls = const Value.absent(),
                Value<String?> smtpInvoiceSubjectTemplate =
                    const Value.absent(),
                Value<String?> smtpInvoiceBodyTemplate = const Value.absent(),
                Value<String?> smtpDunningSubjectTemplate =
                    const Value.absent(),
                Value<String?> smtpDunningBodyTemplate = const Value.absent(),
                Value<bool> buchhaltungEnabled = const Value.absent(),
                Value<String> bankCsvDelimiter = const Value.absent(),
                Value<bool> bankCsvHasHeaderRow = const Value.absent(),
                Value<String?> bankCsvDateColumn = const Value.absent(),
                Value<String?> bankCsvAmountColumn = const Value.absent(),
                Value<String?> bankCsvPurposeColumn = const Value.absent(),
                Value<String?> bankCsvCounterpartyColumn = const Value.absent(),
                Value<String> bankCsvDateFormat = const Value.absent(),
                Value<String> bankCsvDecimalSeparator = const Value.absent(),
                Value<String?> datevBeraterNummer = const Value.absent(),
                Value<String?> datevMandantNummer = const Value.absent(),
                Value<String?> datevBankGegenkonto = const Value.absent(),
                Value<int> datevSachkontenlaenge = const Value.absent(),
                Value<bool> creditNotesEnabled = const Value.absent(),
                Value<String?> pdfIntroTextCreditNote = const Value.absent(),
                Value<String?> pdfClosingTextCreditNote = const Value.absent(),
                Value<bool> isSmallBusinessExempt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompaniesCompanion(
                id: id,
                name: name,
                address: address,
                taxNumber: taxNumber,
                vatId: vatId,
                iban: iban,
                email: email,
                phone: phone,
                createdAt: createdAt,
                quotesEnabled: quotesEnabled,
                ordersEnabled: ordersEnabled,
                deliveryNotesEnabled: deliveryNotesEnabled,
                proformaEnabled: proformaEnabled,
                projectsEnabled: projectsEnabled,
                fleetEnabled: fleetEnabled,
                recurringInvoicesEnabled: recurringInvoicesEnabled,
                advancePaymentInvoicesEnabled: advancePaymentInvoicesEnabled,
                dunningEnabled: dunningEnabled,
                dunningReminder2AfterDays: dunningReminder2AfterDays,
                dunningReminder3AfterDays: dunningReminder3AfterDays,
                dunningFeeLevel1Cents: dunningFeeLevel1Cents,
                dunningFeeLevel2Cents: dunningFeeLevel2Cents,
                dunningFeeLevel3Cents: dunningFeeLevel3Cents,
                dunningInterestRatePercent: dunningInterestRatePercent,
                pdfIntroTextDunning: pdfIntroTextDunning,
                pdfClosingTextDunning: pdfClosingTextDunning,
                pdfIntroText: pdfIntroText,
                pdfClosingText: pdfClosingText,
                pdfIntroTextQuote: pdfIntroTextQuote,
                pdfClosingTextQuote: pdfClosingTextQuote,
                pdfIntroTextOrder: pdfIntroTextOrder,
                pdfClosingTextOrder: pdfClosingTextOrder,
                pdfIntroTextDeliveryNote: pdfIntroTextDeliveryNote,
                pdfClosingTextDeliveryNote: pdfClosingTextDeliveryNote,
                pdfIntroTextProforma: pdfIntroTextProforma,
                pdfClosingTextProforma: pdfClosingTextProforma,
                pdfFooterText: pdfFooterText,
                smtpEnabled: smtpEnabled,
                smtpHost: smtpHost,
                smtpPort: smtpPort,
                smtpUsername: smtpUsername,
                smtpFromAddress: smtpFromAddress,
                smtpFromName: smtpFromName,
                smtpUseTls: smtpUseTls,
                smtpInvoiceSubjectTemplate: smtpInvoiceSubjectTemplate,
                smtpInvoiceBodyTemplate: smtpInvoiceBodyTemplate,
                smtpDunningSubjectTemplate: smtpDunningSubjectTemplate,
                smtpDunningBodyTemplate: smtpDunningBodyTemplate,
                buchhaltungEnabled: buchhaltungEnabled,
                bankCsvDelimiter: bankCsvDelimiter,
                bankCsvHasHeaderRow: bankCsvHasHeaderRow,
                bankCsvDateColumn: bankCsvDateColumn,
                bankCsvAmountColumn: bankCsvAmountColumn,
                bankCsvPurposeColumn: bankCsvPurposeColumn,
                bankCsvCounterpartyColumn: bankCsvCounterpartyColumn,
                bankCsvDateFormat: bankCsvDateFormat,
                bankCsvDecimalSeparator: bankCsvDecimalSeparator,
                datevBeraterNummer: datevBeraterNummer,
                datevMandantNummer: datevMandantNummer,
                datevBankGegenkonto: datevBankGegenkonto,
                datevSachkontenlaenge: datevSachkontenlaenge,
                creditNotesEnabled: creditNotesEnabled,
                pdfIntroTextCreditNote: pdfIntroTextCreditNote,
                pdfClosingTextCreditNote: pdfClosingTextCreditNote,
                isSmallBusinessExempt: isSmallBusinessExempt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> address = const Value.absent(),
                Value<String?> taxNumber = const Value.absent(),
                Value<String?> vatId = const Value.absent(),
                Value<String?> iban = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                required DateTime createdAt,
                Value<bool> quotesEnabled = const Value.absent(),
                Value<bool> ordersEnabled = const Value.absent(),
                Value<bool> deliveryNotesEnabled = const Value.absent(),
                Value<bool> proformaEnabled = const Value.absent(),
                Value<bool> projectsEnabled = const Value.absent(),
                Value<bool> fleetEnabled = const Value.absent(),
                Value<bool> recurringInvoicesEnabled = const Value.absent(),
                Value<bool> advancePaymentInvoicesEnabled =
                    const Value.absent(),
                Value<bool> dunningEnabled = const Value.absent(),
                Value<int> dunningReminder2AfterDays = const Value.absent(),
                Value<int> dunningReminder3AfterDays = const Value.absent(),
                Value<int> dunningFeeLevel1Cents = const Value.absent(),
                Value<int> dunningFeeLevel2Cents = const Value.absent(),
                Value<int> dunningFeeLevel3Cents = const Value.absent(),
                Value<double> dunningInterestRatePercent = const Value.absent(),
                Value<String?> pdfIntroTextDunning = const Value.absent(),
                Value<String?> pdfClosingTextDunning = const Value.absent(),
                Value<String?> pdfIntroText = const Value.absent(),
                Value<String?> pdfClosingText = const Value.absent(),
                Value<String?> pdfIntroTextQuote = const Value.absent(),
                Value<String?> pdfClosingTextQuote = const Value.absent(),
                Value<String?> pdfIntroTextOrder = const Value.absent(),
                Value<String?> pdfClosingTextOrder = const Value.absent(),
                Value<String?> pdfIntroTextDeliveryNote = const Value.absent(),
                Value<String?> pdfClosingTextDeliveryNote =
                    const Value.absent(),
                Value<String?> pdfIntroTextProforma = const Value.absent(),
                Value<String?> pdfClosingTextProforma = const Value.absent(),
                Value<String?> pdfFooterText = const Value.absent(),
                Value<bool> smtpEnabled = const Value.absent(),
                Value<String?> smtpHost = const Value.absent(),
                Value<int> smtpPort = const Value.absent(),
                Value<String?> smtpUsername = const Value.absent(),
                Value<String?> smtpFromAddress = const Value.absent(),
                Value<String?> smtpFromName = const Value.absent(),
                Value<bool> smtpUseTls = const Value.absent(),
                Value<String?> smtpInvoiceSubjectTemplate =
                    const Value.absent(),
                Value<String?> smtpInvoiceBodyTemplate = const Value.absent(),
                Value<String?> smtpDunningSubjectTemplate =
                    const Value.absent(),
                Value<String?> smtpDunningBodyTemplate = const Value.absent(),
                Value<bool> buchhaltungEnabled = const Value.absent(),
                Value<String> bankCsvDelimiter = const Value.absent(),
                Value<bool> bankCsvHasHeaderRow = const Value.absent(),
                Value<String?> bankCsvDateColumn = const Value.absent(),
                Value<String?> bankCsvAmountColumn = const Value.absent(),
                Value<String?> bankCsvPurposeColumn = const Value.absent(),
                Value<String?> bankCsvCounterpartyColumn = const Value.absent(),
                Value<String> bankCsvDateFormat = const Value.absent(),
                Value<String> bankCsvDecimalSeparator = const Value.absent(),
                Value<String?> datevBeraterNummer = const Value.absent(),
                Value<String?> datevMandantNummer = const Value.absent(),
                Value<String?> datevBankGegenkonto = const Value.absent(),
                Value<int> datevSachkontenlaenge = const Value.absent(),
                Value<bool> creditNotesEnabled = const Value.absent(),
                Value<String?> pdfIntroTextCreditNote = const Value.absent(),
                Value<String?> pdfClosingTextCreditNote = const Value.absent(),
                Value<bool> isSmallBusinessExempt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompaniesCompanion.insert(
                id: id,
                name: name,
                address: address,
                taxNumber: taxNumber,
                vatId: vatId,
                iban: iban,
                email: email,
                phone: phone,
                createdAt: createdAt,
                quotesEnabled: quotesEnabled,
                ordersEnabled: ordersEnabled,
                deliveryNotesEnabled: deliveryNotesEnabled,
                proformaEnabled: proformaEnabled,
                projectsEnabled: projectsEnabled,
                fleetEnabled: fleetEnabled,
                recurringInvoicesEnabled: recurringInvoicesEnabled,
                advancePaymentInvoicesEnabled: advancePaymentInvoicesEnabled,
                dunningEnabled: dunningEnabled,
                dunningReminder2AfterDays: dunningReminder2AfterDays,
                dunningReminder3AfterDays: dunningReminder3AfterDays,
                dunningFeeLevel1Cents: dunningFeeLevel1Cents,
                dunningFeeLevel2Cents: dunningFeeLevel2Cents,
                dunningFeeLevel3Cents: dunningFeeLevel3Cents,
                dunningInterestRatePercent: dunningInterestRatePercent,
                pdfIntroTextDunning: pdfIntroTextDunning,
                pdfClosingTextDunning: pdfClosingTextDunning,
                pdfIntroText: pdfIntroText,
                pdfClosingText: pdfClosingText,
                pdfIntroTextQuote: pdfIntroTextQuote,
                pdfClosingTextQuote: pdfClosingTextQuote,
                pdfIntroTextOrder: pdfIntroTextOrder,
                pdfClosingTextOrder: pdfClosingTextOrder,
                pdfIntroTextDeliveryNote: pdfIntroTextDeliveryNote,
                pdfClosingTextDeliveryNote: pdfClosingTextDeliveryNote,
                pdfIntroTextProforma: pdfIntroTextProforma,
                pdfClosingTextProforma: pdfClosingTextProforma,
                pdfFooterText: pdfFooterText,
                smtpEnabled: smtpEnabled,
                smtpHost: smtpHost,
                smtpPort: smtpPort,
                smtpUsername: smtpUsername,
                smtpFromAddress: smtpFromAddress,
                smtpFromName: smtpFromName,
                smtpUseTls: smtpUseTls,
                smtpInvoiceSubjectTemplate: smtpInvoiceSubjectTemplate,
                smtpInvoiceBodyTemplate: smtpInvoiceBodyTemplate,
                smtpDunningSubjectTemplate: smtpDunningSubjectTemplate,
                smtpDunningBodyTemplate: smtpDunningBodyTemplate,
                buchhaltungEnabled: buchhaltungEnabled,
                bankCsvDelimiter: bankCsvDelimiter,
                bankCsvHasHeaderRow: bankCsvHasHeaderRow,
                bankCsvDateColumn: bankCsvDateColumn,
                bankCsvAmountColumn: bankCsvAmountColumn,
                bankCsvPurposeColumn: bankCsvPurposeColumn,
                bankCsvCounterpartyColumn: bankCsvCounterpartyColumn,
                bankCsvDateFormat: bankCsvDateFormat,
                bankCsvDecimalSeparator: bankCsvDecimalSeparator,
                datevBeraterNummer: datevBeraterNummer,
                datevMandantNummer: datevMandantNummer,
                datevBankGegenkonto: datevBankGegenkonto,
                datevSachkontenlaenge: datevSachkontenlaenge,
                creditNotesEnabled: creditNotesEnabled,
                pdfIntroTextCreditNote: pdfIntroTextCreditNote,
                pdfClosingTextCreditNote: pdfClosingTextCreditNote,
                isSmallBusinessExempt: isSmallBusinessExempt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CompaniesTable, Company>(table),
                  $$CompaniesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                customersRefs = false,
                suppliersRefs = false,
                articleGroupsRefs = false,
                articlesRefs = false,
                projectsRefs = false,
                invoicesRefs = false,
                numberSequencesRefs = false,
                vehiclesRefs = false,
                vehicleCostEntriesRefs = false,
                recurringInvoiceTemplatesRefs = false,
                expenseCategoriesRefs = false,
                expensesRefs = false,
                bankTransactionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (customersRefs) db.customers,
                    if (suppliersRefs) db.suppliers,
                    if (articleGroupsRefs) db.articleGroups,
                    if (articlesRefs) db.articles,
                    if (projectsRefs) db.projects,
                    if (invoicesRefs) db.invoices,
                    if (numberSequencesRefs) db.numberSequences,
                    if (vehiclesRefs) db.vehicles,
                    if (vehicleCostEntriesRefs) db.vehicleCostEntries,
                    if (recurringInvoiceTemplatesRefs)
                      db.recurringInvoiceTemplates,
                    if (expenseCategoriesRefs) db.expenseCategories,
                    if (expensesRefs) db.expenses,
                    if (bankTransactionsRefs) db.bankTransactions,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (customersRefs)
                        await $_getPrefetchedData<
                          Company,
                          $CompaniesTable,
                          Customer
                        >(
                          currentTable: table,
                          referencedTable: $$CompaniesTableReferences
                              ._customersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CompaniesTableReferences(
                                db,
                                table,
                                p0,
                              ).customersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.companyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (suppliersRefs)
                        await $_getPrefetchedData<
                          Company,
                          $CompaniesTable,
                          Supplier
                        >(
                          currentTable: table,
                          referencedTable: $$CompaniesTableReferences
                              ._suppliersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CompaniesTableReferences(
                                db,
                                table,
                                p0,
                              ).suppliersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.companyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (articleGroupsRefs)
                        await $_getPrefetchedData<
                          Company,
                          $CompaniesTable,
                          ArticleGroup
                        >(
                          currentTable: table,
                          referencedTable: $$CompaniesTableReferences
                              ._articleGroupsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CompaniesTableReferences(
                                db,
                                table,
                                p0,
                              ).articleGroupsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.companyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (articlesRefs)
                        await $_getPrefetchedData<
                          Company,
                          $CompaniesTable,
                          Article
                        >(
                          currentTable: table,
                          referencedTable: $$CompaniesTableReferences
                              ._articlesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CompaniesTableReferences(
                                db,
                                table,
                                p0,
                              ).articlesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.companyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (projectsRefs)
                        await $_getPrefetchedData<
                          Company,
                          $CompaniesTable,
                          Project
                        >(
                          currentTable: table,
                          referencedTable: $$CompaniesTableReferences
                              ._projectsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CompaniesTableReferences(
                                db,
                                table,
                                p0,
                              ).projectsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.companyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (invoicesRefs)
                        await $_getPrefetchedData<
                          Company,
                          $CompaniesTable,
                          Invoice
                        >(
                          currentTable: table,
                          referencedTable: $$CompaniesTableReferences
                              ._invoicesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CompaniesTableReferences(
                                db,
                                table,
                                p0,
                              ).invoicesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.companyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (numberSequencesRefs)
                        await $_getPrefetchedData<
                          Company,
                          $CompaniesTable,
                          NumberSequence
                        >(
                          currentTable: table,
                          referencedTable: $$CompaniesTableReferences
                              ._numberSequencesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CompaniesTableReferences(
                                db,
                                table,
                                p0,
                              ).numberSequencesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.companyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (vehiclesRefs)
                        await $_getPrefetchedData<
                          Company,
                          $CompaniesTable,
                          Vehicle
                        >(
                          currentTable: table,
                          referencedTable: $$CompaniesTableReferences
                              ._vehiclesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CompaniesTableReferences(
                                db,
                                table,
                                p0,
                              ).vehiclesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.companyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (vehicleCostEntriesRefs)
                        await $_getPrefetchedData<
                          Company,
                          $CompaniesTable,
                          VehicleCostEntry
                        >(
                          currentTable: table,
                          referencedTable: $$CompaniesTableReferences
                              ._vehicleCostEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CompaniesTableReferences(
                                db,
                                table,
                                p0,
                              ).vehicleCostEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.companyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (recurringInvoiceTemplatesRefs)
                        await $_getPrefetchedData<
                          Company,
                          $CompaniesTable,
                          RecurringInvoiceTemplate
                        >(
                          currentTable: table,
                          referencedTable: $$CompaniesTableReferences
                              ._recurringInvoiceTemplatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CompaniesTableReferences(
                                db,
                                table,
                                p0,
                              ).recurringInvoiceTemplatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.companyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (expenseCategoriesRefs)
                        await $_getPrefetchedData<
                          Company,
                          $CompaniesTable,
                          ExpenseCategory
                        >(
                          currentTable: table,
                          referencedTable: $$CompaniesTableReferences
                              ._expenseCategoriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CompaniesTableReferences(
                                db,
                                table,
                                p0,
                              ).expenseCategoriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.companyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (expensesRefs)
                        await $_getPrefetchedData<
                          Company,
                          $CompaniesTable,
                          Expense
                        >(
                          currentTable: table,
                          referencedTable: $$CompaniesTableReferences
                              ._expensesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CompaniesTableReferences(
                                db,
                                table,
                                p0,
                              ).expensesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.companyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bankTransactionsRefs)
                        await $_getPrefetchedData<
                          Company,
                          $CompaniesTable,
                          BankTransaction
                        >(
                          currentTable: table,
                          referencedTable: $$CompaniesTableReferences
                              ._bankTransactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CompaniesTableReferences(
                                db,
                                table,
                                p0,
                              ).bankTransactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.companyId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CompaniesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CompaniesTable,
      Company,
      $$CompaniesTableFilterComposer,
      $$CompaniesTableOrderingComposer,
      $$CompaniesTableAnnotationComposer,
      $$CompaniesTableCreateCompanionBuilder,
      $$CompaniesTableUpdateCompanionBuilder,
      (Company, $$CompaniesTableReferences),
      Company,
      PrefetchHooks Function({
        bool customersRefs,
        bool suppliersRefs,
        bool articleGroupsRefs,
        bool articlesRefs,
        bool projectsRefs,
        bool invoicesRefs,
        bool numberSequencesRefs,
        bool vehiclesRefs,
        bool vehicleCostEntriesRefs,
        bool recurringInvoiceTemplatesRefs,
        bool expenseCategoriesRefs,
        bool expensesRefs,
        bool bankTransactionsRefs,
      })
    >;
typedef $$CustomersTableCreateCompanionBuilder =
    CustomersCompanion Function({
      required String id,
      required String companyId,
      required String name,
      Value<String?> address,
      Value<String?> email,
      Value<String?> phone,
      Value<String?> vatId,
      Value<String?> contactPerson,
      Value<String?> notes,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$CustomersTableUpdateCompanionBuilder =
    CustomersCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> name,
      Value<String?> address,
      Value<String?> email,
      Value<String?> phone,
      Value<String?> vatId,
      Value<String?> contactPerson,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$CustomersTableReferences
    extends BaseReferences<_$AppDatabase, $CustomersTable, Customer> {
  $$CustomersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CompaniesTable _companyIdTable(_$AppDatabase db) =>
      db.companies.createAlias('customers__company_id__companies__id');

  $$CompaniesTableProcessedTableManager get companyId {
    final $_column = $_itemColumn<String>('company_id')!;

    final manager = $$CompaniesTableTableManager(
      $_db,
      $_db.companies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_companyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ProjectsTable, List<Project>> _projectsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.projects,
    aliasName: 'customers__id__projects__customer_id',
  );

  $$ProjectsTableProcessedTableManager get projectsRefs {
    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.customerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_projectsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$InvoicesTable, List<Invoice>> _invoicesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.invoices,
    aliasName: 'customers__id__invoices__customer_id',
  );

  $$InvoicesTableProcessedTableManager get invoicesRefs {
    final manager = $$InvoicesTableTableManager(
      $_db,
      $_db.invoices,
    ).filter((f) => f.customerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_invoicesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $RecurringInvoiceTemplatesTable,
    List<RecurringInvoiceTemplate>
  >
  _recurringInvoiceTemplatesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.recurringInvoiceTemplates,
        aliasName: 'customers__id__recurring_invoice_templates__customer_id',
      );

  $$RecurringInvoiceTemplatesTableProcessedTableManager
  get recurringInvoiceTemplatesRefs {
    final manager = $$RecurringInvoiceTemplatesTableTableManager(
      $_db,
      $_db.recurringInvoiceTemplates,
    ).filter((f) => f.customerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _recurringInvoiceTemplatesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CustomersTableFilterComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vatId => $composableBuilder(
    column: $table.vatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactPerson => $composableBuilder(
    column: $table.contactPerson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CompaniesTableFilterComposer get companyId {
    final $$CompaniesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableFilterComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> projectsRefs(
    Expression<bool> Function($$ProjectsTableFilterComposer f) f,
  ) {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.customerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> invoicesRefs(
    Expression<bool> Function($$InvoicesTableFilterComposer f) f,
  ) {
    final $$InvoicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.customerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableFilterComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recurringInvoiceTemplatesRefs(
    Expression<bool> Function($$RecurringInvoiceTemplatesTableFilterComposer f)
    f,
  ) {
    final $$RecurringInvoiceTemplatesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.recurringInvoiceTemplates,
          getReferencedColumn: (t) => t.customerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecurringInvoiceTemplatesTableFilterComposer(
                $db: $db,
                $table: $db.recurringInvoiceTemplates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CustomersTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vatId => $composableBuilder(
    column: $table.vatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactPerson => $composableBuilder(
    column: $table.contactPerson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompaniesTableOrderingComposer get companyId {
    final $$CompaniesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableOrderingComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CustomersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get vatId =>
      $composableBuilder(column: $table.vatId, builder: (column) => column);

  GeneratedColumn<String> get contactPerson => $composableBuilder(
    column: $table.contactPerson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CompaniesTableAnnotationComposer get companyId {
    final $$CompaniesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableAnnotationComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> projectsRefs<T extends Object>(
    Expression<T> Function($$ProjectsTableAnnotationComposer a) f,
  ) {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.customerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> invoicesRefs<T extends Object>(
    Expression<T> Function($$InvoicesTableAnnotationComposer a) f,
  ) {
    final $$InvoicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.customerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableAnnotationComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> recurringInvoiceTemplatesRefs<T extends Object>(
    Expression<T> Function($$RecurringInvoiceTemplatesTableAnnotationComposer a)
    f,
  ) {
    final $$RecurringInvoiceTemplatesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.recurringInvoiceTemplates,
          getReferencedColumn: (t) => t.customerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecurringInvoiceTemplatesTableAnnotationComposer(
                $db: $db,
                $table: $db.recurringInvoiceTemplates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CustomersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomersTable,
          Customer,
          $$CustomersTableFilterComposer,
          $$CustomersTableOrderingComposer,
          $$CustomersTableAnnotationComposer,
          $$CustomersTableCreateCompanionBuilder,
          $$CustomersTableUpdateCompanionBuilder,
          (Customer, $$CustomersTableReferences),
          Customer,
          PrefetchHooks Function({
            bool companyId,
            bool projectsRefs,
            bool invoicesRefs,
            bool recurringInvoiceTemplatesRefs,
          })
        > {
  $$CustomersTableTableManager(_$AppDatabase db, $CustomersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> vatId = const Value.absent(),
                Value<String?> contactPerson = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomersCompanion(
                id: id,
                companyId: companyId,
                name: name,
                address: address,
                email: email,
                phone: phone,
                vatId: vatId,
                contactPerson: contactPerson,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String name,
                Value<String?> address = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> vatId = const Value.absent(),
                Value<String?> contactPerson = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => CustomersCompanion.insert(
                id: id,
                companyId: companyId,
                name: name,
                address: address,
                email: email,
                phone: phone,
                vatId: vatId,
                contactPerson: contactPerson,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CustomersTable, Customer>(table),
                  $$CustomersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                companyId = false,
                projectsRefs = false,
                invoicesRefs = false,
                recurringInvoiceTemplatesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (projectsRefs) db.projects,
                    if (invoicesRefs) db.invoices,
                    if (recurringInvoiceTemplatesRefs)
                      db.recurringInvoiceTemplates,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (companyId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.companyId,
                                    referencedTable: $$CustomersTableReferences
                                        ._companyIdTable(db),
                                    referencedColumn: $$CustomersTableReferences
                                        ._companyIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (projectsRefs)
                        await $_getPrefetchedData<
                          Customer,
                          $CustomersTable,
                          Project
                        >(
                          currentTable: table,
                          referencedTable: $$CustomersTableReferences
                              ._projectsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CustomersTableReferences(
                                db,
                                table,
                                p0,
                              ).projectsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.customerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (invoicesRefs)
                        await $_getPrefetchedData<
                          Customer,
                          $CustomersTable,
                          Invoice
                        >(
                          currentTable: table,
                          referencedTable: $$CustomersTableReferences
                              ._invoicesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CustomersTableReferences(
                                db,
                                table,
                                p0,
                              ).invoicesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.customerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (recurringInvoiceTemplatesRefs)
                        await $_getPrefetchedData<
                          Customer,
                          $CustomersTable,
                          RecurringInvoiceTemplate
                        >(
                          currentTable: table,
                          referencedTable: $$CustomersTableReferences
                              ._recurringInvoiceTemplatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CustomersTableReferences(
                                db,
                                table,
                                p0,
                              ).recurringInvoiceTemplatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.customerId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CustomersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomersTable,
      Customer,
      $$CustomersTableFilterComposer,
      $$CustomersTableOrderingComposer,
      $$CustomersTableAnnotationComposer,
      $$CustomersTableCreateCompanionBuilder,
      $$CustomersTableUpdateCompanionBuilder,
      (Customer, $$CustomersTableReferences),
      Customer,
      PrefetchHooks Function({
        bool companyId,
        bool projectsRefs,
        bool invoicesRefs,
        bool recurringInvoiceTemplatesRefs,
      })
    >;
typedef $$SuppliersTableCreateCompanionBuilder =
    SuppliersCompanion Function({
      required String id,
      required String companyId,
      required String name,
      Value<String?> address,
      Value<String?> email,
      Value<String?> phone,
      Value<String?> vatId,
      Value<String?> contactPerson,
      Value<String?> notes,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SuppliersTableUpdateCompanionBuilder =
    SuppliersCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> name,
      Value<String?> address,
      Value<String?> email,
      Value<String?> phone,
      Value<String?> vatId,
      Value<String?> contactPerson,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$SuppliersTableReferences
    extends BaseReferences<_$AppDatabase, $SuppliersTable, Supplier> {
  $$SuppliersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CompaniesTable _companyIdTable(_$AppDatabase db) =>
      db.companies.createAlias('suppliers__company_id__companies__id');

  $$CompaniesTableProcessedTableManager get companyId {
    final $_column = $_itemColumn<String>('company_id')!;

    final manager = $$CompaniesTableTableManager(
      $_db,
      $_db.companies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_companyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ArticlesTable, List<Article>> _articlesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.articles,
    aliasName: 'suppliers__id__articles__default_supplier_id',
  );

  $$ArticlesTableProcessedTableManager get articlesRefs {
    final manager = $$ArticlesTableTableManager($_db, $_db.articles).filter(
      (f) => f.defaultSupplierId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_articlesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ArticleSupplierPricesTable,
    List<ArticleSupplierPrice>
  >
  _articleSupplierPricesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.articleSupplierPrices,
        aliasName: 'suppliers__id__article_supplier_prices__supplier_id',
      );

  $$ArticleSupplierPricesTableProcessedTableManager
  get articleSupplierPricesRefs {
    final manager = $$ArticleSupplierPricesTableTableManager(
      $_db,
      $_db.articleSupplierPrices,
    ).filter((f) => f.supplierId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _articleSupplierPricesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SuppliersTableFilterComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vatId => $composableBuilder(
    column: $table.vatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactPerson => $composableBuilder(
    column: $table.contactPerson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CompaniesTableFilterComposer get companyId {
    final $$CompaniesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableFilterComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> articlesRefs(
    Expression<bool> Function($$ArticlesTableFilterComposer f) f,
  ) {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.defaultSupplierId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableFilterComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> articleSupplierPricesRefs(
    Expression<bool> Function($$ArticleSupplierPricesTableFilterComposer f) f,
  ) {
    final $$ArticleSupplierPricesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.articleSupplierPrices,
          getReferencedColumn: (t) => t.supplierId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ArticleSupplierPricesTableFilterComposer(
                $db: $db,
                $table: $db.articleSupplierPrices,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$SuppliersTableOrderingComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vatId => $composableBuilder(
    column: $table.vatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactPerson => $composableBuilder(
    column: $table.contactPerson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompaniesTableOrderingComposer get companyId {
    final $$CompaniesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableOrderingComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SuppliersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get vatId =>
      $composableBuilder(column: $table.vatId, builder: (column) => column);

  GeneratedColumn<String> get contactPerson => $composableBuilder(
    column: $table.contactPerson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CompaniesTableAnnotationComposer get companyId {
    final $$CompaniesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableAnnotationComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> articlesRefs<T extends Object>(
    Expression<T> Function($$ArticlesTableAnnotationComposer a) f,
  ) {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.defaultSupplierId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableAnnotationComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> articleSupplierPricesRefs<T extends Object>(
    Expression<T> Function($$ArticleSupplierPricesTableAnnotationComposer a) f,
  ) {
    final $$ArticleSupplierPricesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.articleSupplierPrices,
          getReferencedColumn: (t) => t.supplierId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ArticleSupplierPricesTableAnnotationComposer(
                $db: $db,
                $table: $db.articleSupplierPrices,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$SuppliersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SuppliersTable,
          Supplier,
          $$SuppliersTableFilterComposer,
          $$SuppliersTableOrderingComposer,
          $$SuppliersTableAnnotationComposer,
          $$SuppliersTableCreateCompanionBuilder,
          $$SuppliersTableUpdateCompanionBuilder,
          (Supplier, $$SuppliersTableReferences),
          Supplier,
          PrefetchHooks Function({
            bool companyId,
            bool articlesRefs,
            bool articleSupplierPricesRefs,
          })
        > {
  $$SuppliersTableTableManager(_$AppDatabase db, $SuppliersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SuppliersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SuppliersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SuppliersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> vatId = const Value.absent(),
                Value<String?> contactPerson = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SuppliersCompanion(
                id: id,
                companyId: companyId,
                name: name,
                address: address,
                email: email,
                phone: phone,
                vatId: vatId,
                contactPerson: contactPerson,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String name,
                Value<String?> address = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> vatId = const Value.absent(),
                Value<String?> contactPerson = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SuppliersCompanion.insert(
                id: id,
                companyId: companyId,
                name: name,
                address: address,
                email: email,
                phone: phone,
                vatId: vatId,
                contactPerson: contactPerson,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SuppliersTable, Supplier>(table),
                  $$SuppliersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                companyId = false,
                articlesRefs = false,
                articleSupplierPricesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (articlesRefs) db.articles,
                    if (articleSupplierPricesRefs) db.articleSupplierPrices,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (companyId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.companyId,
                                    referencedTable: $$SuppliersTableReferences
                                        ._companyIdTable(db),
                                    referencedColumn: $$SuppliersTableReferences
                                        ._companyIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (articlesRefs)
                        await $_getPrefetchedData<
                          Supplier,
                          $SuppliersTable,
                          Article
                        >(
                          currentTable: table,
                          referencedTable: $$SuppliersTableReferences
                              ._articlesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SuppliersTableReferences(
                                db,
                                table,
                                p0,
                              ).articlesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.defaultSupplierId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (articleSupplierPricesRefs)
                        await $_getPrefetchedData<
                          Supplier,
                          $SuppliersTable,
                          ArticleSupplierPrice
                        >(
                          currentTable: table,
                          referencedTable: $$SuppliersTableReferences
                              ._articleSupplierPricesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SuppliersTableReferences(
                                db,
                                table,
                                p0,
                              ).articleSupplierPricesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.supplierId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SuppliersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SuppliersTable,
      Supplier,
      $$SuppliersTableFilterComposer,
      $$SuppliersTableOrderingComposer,
      $$SuppliersTableAnnotationComposer,
      $$SuppliersTableCreateCompanionBuilder,
      $$SuppliersTableUpdateCompanionBuilder,
      (Supplier, $$SuppliersTableReferences),
      Supplier,
      PrefetchHooks Function({
        bool companyId,
        bool articlesRefs,
        bool articleSupplierPricesRefs,
      })
    >;
typedef $$ArticleGroupsTableCreateCompanionBuilder =
    ArticleGroupsCompanion Function({
      required String id,
      required String companyId,
      required String name,
      required double markupPercent,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ArticleGroupsTableUpdateCompanionBuilder =
    ArticleGroupsCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> name,
      Value<double> markupPercent,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ArticleGroupsTableReferences
    extends BaseReferences<_$AppDatabase, $ArticleGroupsTable, ArticleGroup> {
  $$ArticleGroupsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CompaniesTable _companyIdTable(_$AppDatabase db) =>
      db.companies.createAlias('article_groups__company_id__companies__id');

  $$CompaniesTableProcessedTableManager get companyId {
    final $_column = $_itemColumn<String>('company_id')!;

    final manager = $$CompaniesTableTableManager(
      $_db,
      $_db.companies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_companyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ArticlesTable, List<Article>> _articlesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.articles,
    aliasName: 'article_groups__id__articles__article_group_id',
  );

  $$ArticlesTableProcessedTableManager get articlesRefs {
    final manager = $$ArticlesTableTableManager(
      $_db,
      $_db.articles,
    ).filter((f) => f.articleGroupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_articlesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ArticleGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $ArticleGroupsTable> {
  $$ArticleGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get markupPercent => $composableBuilder(
    column: $table.markupPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CompaniesTableFilterComposer get companyId {
    final $$CompaniesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableFilterComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> articlesRefs(
    Expression<bool> Function($$ArticlesTableFilterComposer f) f,
  ) {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.articleGroupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableFilterComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ArticleGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $ArticleGroupsTable> {
  $$ArticleGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get markupPercent => $composableBuilder(
    column: $table.markupPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompaniesTableOrderingComposer get companyId {
    final $$CompaniesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableOrderingComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArticleGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArticleGroupsTable> {
  $$ArticleGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get markupPercent => $composableBuilder(
    column: $table.markupPercent,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CompaniesTableAnnotationComposer get companyId {
    final $$CompaniesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableAnnotationComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> articlesRefs<T extends Object>(
    Expression<T> Function($$ArticlesTableAnnotationComposer a) f,
  ) {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.articleGroupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableAnnotationComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ArticleGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ArticleGroupsTable,
          ArticleGroup,
          $$ArticleGroupsTableFilterComposer,
          $$ArticleGroupsTableOrderingComposer,
          $$ArticleGroupsTableAnnotationComposer,
          $$ArticleGroupsTableCreateCompanionBuilder,
          $$ArticleGroupsTableUpdateCompanionBuilder,
          (ArticleGroup, $$ArticleGroupsTableReferences),
          ArticleGroup,
          PrefetchHooks Function({bool companyId, bool articlesRefs})
        > {
  $$ArticleGroupsTableTableManager(_$AppDatabase db, $ArticleGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArticleGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArticleGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArticleGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> markupPercent = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArticleGroupsCompanion(
                id: id,
                companyId: companyId,
                name: name,
                markupPercent: markupPercent,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String name,
                required double markupPercent,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ArticleGroupsCompanion.insert(
                id: id,
                companyId: companyId,
                name: name,
                markupPercent: markupPercent,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ArticleGroupsTable, ArticleGroup>(table),
                  $$ArticleGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({companyId = false, articlesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (articlesRefs) db.articles],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (companyId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.companyId,
                                referencedTable: $$ArticleGroupsTableReferences
                                    ._companyIdTable(db),
                                referencedColumn: $$ArticleGroupsTableReferences
                                    ._companyIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (articlesRefs)
                    await $_getPrefetchedData<
                      ArticleGroup,
                      $ArticleGroupsTable,
                      Article
                    >(
                      currentTable: table,
                      referencedTable: $$ArticleGroupsTableReferences
                          ._articlesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ArticleGroupsTableReferences(
                            db,
                            table,
                            p0,
                          ).articlesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.articleGroupId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ArticleGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ArticleGroupsTable,
      ArticleGroup,
      $$ArticleGroupsTableFilterComposer,
      $$ArticleGroupsTableOrderingComposer,
      $$ArticleGroupsTableAnnotationComposer,
      $$ArticleGroupsTableCreateCompanionBuilder,
      $$ArticleGroupsTableUpdateCompanionBuilder,
      (ArticleGroup, $$ArticleGroupsTableReferences),
      ArticleGroup,
      PrefetchHooks Function({bool companyId, bool articlesRefs})
    >;
typedef $$ArticlesTableCreateCompanionBuilder =
    ArticlesCompanion Function({
      required String id,
      required String companyId,
      required String name,
      Value<String?> unit,
      Value<String?> articleGroupId,
      Value<String?> defaultSupplierId,
      Value<int?> manualSalePriceCents,
      Value<bool> active,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ArticlesTableUpdateCompanionBuilder =
    ArticlesCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> name,
      Value<String?> unit,
      Value<String?> articleGroupId,
      Value<String?> defaultSupplierId,
      Value<int?> manualSalePriceCents,
      Value<bool> active,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ArticlesTableReferences
    extends BaseReferences<_$AppDatabase, $ArticlesTable, Article> {
  $$ArticlesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CompaniesTable _companyIdTable(_$AppDatabase db) =>
      db.companies.createAlias('articles__company_id__companies__id');

  $$CompaniesTableProcessedTableManager get companyId {
    final $_column = $_itemColumn<String>('company_id')!;

    final manager = $$CompaniesTableTableManager(
      $_db,
      $_db.companies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_companyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ArticleGroupsTable _articleGroupIdTable(_$AppDatabase db) => db
      .articleGroups
      .createAlias('articles__article_group_id__article_groups__id');

  $$ArticleGroupsTableProcessedTableManager? get articleGroupId {
    final $_column = $_itemColumn<String>('article_group_id');
    if ($_column == null) return null;
    final manager = $$ArticleGroupsTableTableManager(
      $_db,
      $_db.articleGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_articleGroupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SuppliersTable _defaultSupplierIdTable(_$AppDatabase db) =>
      db.suppliers.createAlias('articles__default_supplier_id__suppliers__id');

  $$SuppliersTableProcessedTableManager? get defaultSupplierId {
    final $_column = $_itemColumn<String>('default_supplier_id');
    if ($_column == null) return null;
    final manager = $$SuppliersTableTableManager(
      $_db,
      $_db.suppliers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_defaultSupplierIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $ArticleSupplierPricesTable,
    List<ArticleSupplierPrice>
  >
  _articleSupplierPricesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.articleSupplierPrices,
        aliasName: 'articles__id__article_supplier_prices__article_id',
      );

  $$ArticleSupplierPricesTableProcessedTableManager
  get articleSupplierPricesRefs {
    final manager = $$ArticleSupplierPricesTableTableManager(
      $_db,
      $_db.articleSupplierPrices,
    ).filter((f) => f.articleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _articleSupplierPricesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$InvoiceItemsTable, List<InvoiceItem>>
  _invoiceItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.invoiceItems,
    aliasName: 'articles__id__invoice_items__article_id',
  );

  $$InvoiceItemsTableProcessedTableManager get invoiceItemsRefs {
    final manager = $$InvoiceItemsTableTableManager(
      $_db,
      $_db.invoiceItems,
    ).filter((f) => f.articleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_invoiceItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $RecurringInvoiceTemplateItemsTable,
    List<RecurringInvoiceTemplateItem>
  >
  _recurringInvoiceTemplateItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.recurringInvoiceTemplateItems,
        aliasName: 'articles__id__recurring_invoice_template_items__article_id',
      );

  $$RecurringInvoiceTemplateItemsTableProcessedTableManager
  get recurringInvoiceTemplateItemsRefs {
    final manager = $$RecurringInvoiceTemplateItemsTableTableManager(
      $_db,
      $_db.recurringInvoiceTemplateItems,
    ).filter((f) => f.articleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _recurringInvoiceTemplateItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ArticlesTableFilterComposer
    extends Composer<_$AppDatabase, $ArticlesTable> {
  $$ArticlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get manualSalePriceCents => $composableBuilder(
    column: $table.manualSalePriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CompaniesTableFilterComposer get companyId {
    final $$CompaniesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableFilterComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ArticleGroupsTableFilterComposer get articleGroupId {
    final $$ArticleGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleGroupId,
      referencedTable: $db.articleGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticleGroupsTableFilterComposer(
            $db: $db,
            $table: $db.articleGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SuppliersTableFilterComposer get defaultSupplierId {
    final $$SuppliersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.defaultSupplierId,
      referencedTable: $db.suppliers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliersTableFilterComposer(
            $db: $db,
            $table: $db.suppliers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> articleSupplierPricesRefs(
    Expression<bool> Function($$ArticleSupplierPricesTableFilterComposer f) f,
  ) {
    final $$ArticleSupplierPricesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.articleSupplierPrices,
          getReferencedColumn: (t) => t.articleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ArticleSupplierPricesTableFilterComposer(
                $db: $db,
                $table: $db.articleSupplierPrices,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> invoiceItemsRefs(
    Expression<bool> Function($$InvoiceItemsTableFilterComposer f) f,
  ) {
    final $$InvoiceItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.invoiceItems,
      getReferencedColumn: (t) => t.articleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoiceItemsTableFilterComposer(
            $db: $db,
            $table: $db.invoiceItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recurringInvoiceTemplateItemsRefs(
    Expression<bool> Function(
      $$RecurringInvoiceTemplateItemsTableFilterComposer f,
    )
    f,
  ) {
    final $$RecurringInvoiceTemplateItemsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.recurringInvoiceTemplateItems,
          getReferencedColumn: (t) => t.articleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecurringInvoiceTemplateItemsTableFilterComposer(
                $db: $db,
                $table: $db.recurringInvoiceTemplateItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ArticlesTableOrderingComposer
    extends Composer<_$AppDatabase, $ArticlesTable> {
  $$ArticlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get manualSalePriceCents => $composableBuilder(
    column: $table.manualSalePriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompaniesTableOrderingComposer get companyId {
    final $$CompaniesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableOrderingComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ArticleGroupsTableOrderingComposer get articleGroupId {
    final $$ArticleGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleGroupId,
      referencedTable: $db.articleGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticleGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.articleGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SuppliersTableOrderingComposer get defaultSupplierId {
    final $$SuppliersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.defaultSupplierId,
      referencedTable: $db.suppliers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliersTableOrderingComposer(
            $db: $db,
            $table: $db.suppliers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArticlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArticlesTable> {
  $$ArticlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get manualSalePriceCents => $composableBuilder(
    column: $table.manualSalePriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CompaniesTableAnnotationComposer get companyId {
    final $$CompaniesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableAnnotationComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ArticleGroupsTableAnnotationComposer get articleGroupId {
    final $$ArticleGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleGroupId,
      referencedTable: $db.articleGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticleGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.articleGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SuppliersTableAnnotationComposer get defaultSupplierId {
    final $$SuppliersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.defaultSupplierId,
      referencedTable: $db.suppliers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliersTableAnnotationComposer(
            $db: $db,
            $table: $db.suppliers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> articleSupplierPricesRefs<T extends Object>(
    Expression<T> Function($$ArticleSupplierPricesTableAnnotationComposer a) f,
  ) {
    final $$ArticleSupplierPricesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.articleSupplierPrices,
          getReferencedColumn: (t) => t.articleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ArticleSupplierPricesTableAnnotationComposer(
                $db: $db,
                $table: $db.articleSupplierPrices,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> invoiceItemsRefs<T extends Object>(
    Expression<T> Function($$InvoiceItemsTableAnnotationComposer a) f,
  ) {
    final $$InvoiceItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.invoiceItems,
      getReferencedColumn: (t) => t.articleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoiceItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.invoiceItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> recurringInvoiceTemplateItemsRefs<T extends Object>(
    Expression<T> Function(
      $$RecurringInvoiceTemplateItemsTableAnnotationComposer a,
    )
    f,
  ) {
    final $$RecurringInvoiceTemplateItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.recurringInvoiceTemplateItems,
          getReferencedColumn: (t) => t.articleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecurringInvoiceTemplateItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.recurringInvoiceTemplateItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ArticlesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ArticlesTable,
          Article,
          $$ArticlesTableFilterComposer,
          $$ArticlesTableOrderingComposer,
          $$ArticlesTableAnnotationComposer,
          $$ArticlesTableCreateCompanionBuilder,
          $$ArticlesTableUpdateCompanionBuilder,
          (Article, $$ArticlesTableReferences),
          Article,
          PrefetchHooks Function({
            bool companyId,
            bool articleGroupId,
            bool defaultSupplierId,
            bool articleSupplierPricesRefs,
            bool invoiceItemsRefs,
            bool recurringInvoiceTemplateItemsRefs,
          })
        > {
  $$ArticlesTableTableManager(_$AppDatabase db, $ArticlesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArticlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArticlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArticlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<String?> articleGroupId = const Value.absent(),
                Value<String?> defaultSupplierId = const Value.absent(),
                Value<int?> manualSalePriceCents = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArticlesCompanion(
                id: id,
                companyId: companyId,
                name: name,
                unit: unit,
                articleGroupId: articleGroupId,
                defaultSupplierId: defaultSupplierId,
                manualSalePriceCents: manualSalePriceCents,
                active: active,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String name,
                Value<String?> unit = const Value.absent(),
                Value<String?> articleGroupId = const Value.absent(),
                Value<String?> defaultSupplierId = const Value.absent(),
                Value<int?> manualSalePriceCents = const Value.absent(),
                Value<bool> active = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ArticlesCompanion.insert(
                id: id,
                companyId: companyId,
                name: name,
                unit: unit,
                articleGroupId: articleGroupId,
                defaultSupplierId: defaultSupplierId,
                manualSalePriceCents: manualSalePriceCents,
                active: active,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ArticlesTable, Article>(table),
                  $$ArticlesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                companyId = false,
                articleGroupId = false,
                defaultSupplierId = false,
                articleSupplierPricesRefs = false,
                invoiceItemsRefs = false,
                recurringInvoiceTemplateItemsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (articleSupplierPricesRefs) db.articleSupplierPrices,
                    if (invoiceItemsRefs) db.invoiceItems,
                    if (recurringInvoiceTemplateItemsRefs)
                      db.recurringInvoiceTemplateItems,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (companyId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.companyId,
                                    referencedTable: $$ArticlesTableReferences
                                        ._companyIdTable(db),
                                    referencedColumn: $$ArticlesTableReferences
                                        ._companyIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (articleGroupId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.articleGroupId,
                                    referencedTable: $$ArticlesTableReferences
                                        ._articleGroupIdTable(db),
                                    referencedColumn: $$ArticlesTableReferences
                                        ._articleGroupIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (defaultSupplierId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.defaultSupplierId,
                                    referencedTable: $$ArticlesTableReferences
                                        ._defaultSupplierIdTable(db),
                                    referencedColumn: $$ArticlesTableReferences
                                        ._defaultSupplierIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (articleSupplierPricesRefs)
                        await $_getPrefetchedData<
                          Article,
                          $ArticlesTable,
                          ArticleSupplierPrice
                        >(
                          currentTable: table,
                          referencedTable: $$ArticlesTableReferences
                              ._articleSupplierPricesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ArticlesTableReferences(
                                db,
                                table,
                                p0,
                              ).articleSupplierPricesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.articleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (invoiceItemsRefs)
                        await $_getPrefetchedData<
                          Article,
                          $ArticlesTable,
                          InvoiceItem
                        >(
                          currentTable: table,
                          referencedTable: $$ArticlesTableReferences
                              ._invoiceItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ArticlesTableReferences(
                                db,
                                table,
                                p0,
                              ).invoiceItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.articleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (recurringInvoiceTemplateItemsRefs)
                        await $_getPrefetchedData<
                          Article,
                          $ArticlesTable,
                          RecurringInvoiceTemplateItem
                        >(
                          currentTable: table,
                          referencedTable: $$ArticlesTableReferences
                              ._recurringInvoiceTemplateItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ArticlesTableReferences(
                                db,
                                table,
                                p0,
                              ).recurringInvoiceTemplateItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.articleId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ArticlesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ArticlesTable,
      Article,
      $$ArticlesTableFilterComposer,
      $$ArticlesTableOrderingComposer,
      $$ArticlesTableAnnotationComposer,
      $$ArticlesTableCreateCompanionBuilder,
      $$ArticlesTableUpdateCompanionBuilder,
      (Article, $$ArticlesTableReferences),
      Article,
      PrefetchHooks Function({
        bool companyId,
        bool articleGroupId,
        bool defaultSupplierId,
        bool articleSupplierPricesRefs,
        bool invoiceItemsRefs,
        bool recurringInvoiceTemplateItemsRefs,
      })
    >;
typedef $$ArticleSupplierPricesTableCreateCompanionBuilder =
    ArticleSupplierPricesCompanion Function({
      required String id,
      required String articleId,
      required String supplierId,
      required int purchasePriceCents,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ArticleSupplierPricesTableUpdateCompanionBuilder =
    ArticleSupplierPricesCompanion Function({
      Value<String> id,
      Value<String> articleId,
      Value<String> supplierId,
      Value<int> purchasePriceCents,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ArticleSupplierPricesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ArticleSupplierPricesTable,
          ArticleSupplierPrice
        > {
  $$ArticleSupplierPricesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ArticlesTable _articleIdTable(_$AppDatabase db) => db.articles
      .createAlias('article_supplier_prices__article_id__articles__id');

  $$ArticlesTableProcessedTableManager get articleId {
    final $_column = $_itemColumn<String>('article_id')!;

    final manager = $$ArticlesTableTableManager(
      $_db,
      $_db.articles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_articleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SuppliersTable _supplierIdTable(_$AppDatabase db) => db.suppliers
      .createAlias('article_supplier_prices__supplier_id__suppliers__id');

  $$SuppliersTableProcessedTableManager get supplierId {
    final $_column = $_itemColumn<String>('supplier_id')!;

    final manager = $$SuppliersTableTableManager(
      $_db,
      $_db.suppliers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_supplierIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ArticleSupplierPricesTableFilterComposer
    extends Composer<_$AppDatabase, $ArticleSupplierPricesTable> {
  $$ArticleSupplierPricesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get purchasePriceCents => $composableBuilder(
    column: $table.purchasePriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ArticlesTableFilterComposer get articleId {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableFilterComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SuppliersTableFilterComposer get supplierId {
    final $$SuppliersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplierId,
      referencedTable: $db.suppliers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliersTableFilterComposer(
            $db: $db,
            $table: $db.suppliers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArticleSupplierPricesTableOrderingComposer
    extends Composer<_$AppDatabase, $ArticleSupplierPricesTable> {
  $$ArticleSupplierPricesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get purchasePriceCents => $composableBuilder(
    column: $table.purchasePriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ArticlesTableOrderingComposer get articleId {
    final $$ArticlesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableOrderingComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SuppliersTableOrderingComposer get supplierId {
    final $$SuppliersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplierId,
      referencedTable: $db.suppliers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliersTableOrderingComposer(
            $db: $db,
            $table: $db.suppliers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArticleSupplierPricesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArticleSupplierPricesTable> {
  $$ArticleSupplierPricesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get purchasePriceCents => $composableBuilder(
    column: $table.purchasePriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ArticlesTableAnnotationComposer get articleId {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableAnnotationComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SuppliersTableAnnotationComposer get supplierId {
    final $$SuppliersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplierId,
      referencedTable: $db.suppliers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SuppliersTableAnnotationComposer(
            $db: $db,
            $table: $db.suppliers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArticleSupplierPricesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ArticleSupplierPricesTable,
          ArticleSupplierPrice,
          $$ArticleSupplierPricesTableFilterComposer,
          $$ArticleSupplierPricesTableOrderingComposer,
          $$ArticleSupplierPricesTableAnnotationComposer,
          $$ArticleSupplierPricesTableCreateCompanionBuilder,
          $$ArticleSupplierPricesTableUpdateCompanionBuilder,
          (ArticleSupplierPrice, $$ArticleSupplierPricesTableReferences),
          ArticleSupplierPrice,
          PrefetchHooks Function({bool articleId, bool supplierId})
        > {
  $$ArticleSupplierPricesTableTableManager(
    _$AppDatabase db,
    $ArticleSupplierPricesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArticleSupplierPricesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ArticleSupplierPricesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ArticleSupplierPricesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> articleId = const Value.absent(),
                Value<String> supplierId = const Value.absent(),
                Value<int> purchasePriceCents = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArticleSupplierPricesCompanion(
                id: id,
                articleId: articleId,
                supplierId: supplierId,
                purchasePriceCents: purchasePriceCents,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String articleId,
                required String supplierId,
                required int purchasePriceCents,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ArticleSupplierPricesCompanion.insert(
                id: id,
                articleId: articleId,
                supplierId: supplierId,
                purchasePriceCents: purchasePriceCents,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ArticleSupplierPricesTable,
                    ArticleSupplierPrice
                  >(table),
                  $$ArticleSupplierPricesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({articleId = false, supplierId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (articleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.articleId,
                                referencedTable:
                                    $$ArticleSupplierPricesTableReferences
                                        ._articleIdTable(db),
                                referencedColumn:
                                    $$ArticleSupplierPricesTableReferences
                                        ._articleIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (supplierId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.supplierId,
                                referencedTable:
                                    $$ArticleSupplierPricesTableReferences
                                        ._supplierIdTable(db),
                                referencedColumn:
                                    $$ArticleSupplierPricesTableReferences
                                        ._supplierIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ArticleSupplierPricesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ArticleSupplierPricesTable,
      ArticleSupplierPrice,
      $$ArticleSupplierPricesTableFilterComposer,
      $$ArticleSupplierPricesTableOrderingComposer,
      $$ArticleSupplierPricesTableAnnotationComposer,
      $$ArticleSupplierPricesTableCreateCompanionBuilder,
      $$ArticleSupplierPricesTableUpdateCompanionBuilder,
      (ArticleSupplierPrice, $$ArticleSupplierPricesTableReferences),
      ArticleSupplierPrice,
      PrefetchHooks Function({bool articleId, bool supplierId})
    >;
typedef $$ProjectsTableCreateCompanionBuilder =
    ProjectsCompanion Function({
      required String id,
      required String companyId,
      required String name,
      Value<String?> customerId,
      Value<String?> notes,
      Value<ProjectStatus> status,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ProjectsTableUpdateCompanionBuilder =
    ProjectsCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> name,
      Value<String?> customerId,
      Value<String?> notes,
      Value<ProjectStatus> status,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ProjectsTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectsTable, Project> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CompaniesTable _companyIdTable(_$AppDatabase db) =>
      db.companies.createAlias('projects__company_id__companies__id');

  $$CompaniesTableProcessedTableManager get companyId {
    final $_column = $_itemColumn<String>('company_id')!;

    final manager = $$CompaniesTableTableManager(
      $_db,
      $_db.companies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_companyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CustomersTable _customerIdTable(_$AppDatabase db) =>
      db.customers.createAlias('projects__customer_id__customers__id');

  $$CustomersTableProcessedTableManager? get customerId {
    final $_column = $_itemColumn<String>('customer_id');
    if ($_column == null) return null;
    final manager = $$CustomersTableTableManager(
      $_db,
      $_db.customers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_customerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$InvoicesTable, List<Invoice>> _invoicesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.invoices,
    aliasName: 'projects__id__invoices__project_id',
  );

  $$InvoicesTableProcessedTableManager get invoicesRefs {
    final manager = $$InvoicesTableTableManager(
      $_db,
      $_db.invoices,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_invoicesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$VehicleCostEntriesTable, List<VehicleCostEntry>>
  _vehicleCostEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.vehicleCostEntries,
        aliasName: 'projects__id__vehicle_cost_entries__project_id',
      );

  $$VehicleCostEntriesTableProcessedTableManager get vehicleCostEntriesRefs {
    final manager = $$VehicleCostEntriesTableTableManager(
      $_db,
      $_db.vehicleCostEntries,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _vehicleCostEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ExpensesTable, List<Expense>> _expensesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.expenses,
    aliasName: 'projects__id__expenses__project_id',
  );

  $$ExpensesTableProcessedTableManager get expensesRefs {
    final manager = $$ExpensesTableTableManager(
      $_db,
      $_db.expenses,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_expensesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ProjectStatus, ProjectStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CompaniesTableFilterComposer get companyId {
    final $$CompaniesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableFilterComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CustomersTableFilterComposer get customerId {
    final $$CustomersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomersTableFilterComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> invoicesRefs(
    Expression<bool> Function($$InvoicesTableFilterComposer f) f,
  ) {
    final $$InvoicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableFilterComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> vehicleCostEntriesRefs(
    Expression<bool> Function($$VehicleCostEntriesTableFilterComposer f) f,
  ) {
    final $$VehicleCostEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.vehicleCostEntries,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehicleCostEntriesTableFilterComposer(
            $db: $db,
            $table: $db.vehicleCostEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> expensesRefs(
    Expression<bool> Function($$ExpensesTableFilterComposer f) f,
  ) {
    final $$ExpensesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenses,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpensesTableFilterComposer(
            $db: $db,
            $table: $db.expenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompaniesTableOrderingComposer get companyId {
    final $$CompaniesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableOrderingComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CustomersTableOrderingComposer get customerId {
    final $$CustomersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomersTableOrderingComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ProjectStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CompaniesTableAnnotationComposer get companyId {
    final $$CompaniesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableAnnotationComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CustomersTableAnnotationComposer get customerId {
    final $$CustomersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomersTableAnnotationComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> invoicesRefs<T extends Object>(
    Expression<T> Function($$InvoicesTableAnnotationComposer a) f,
  ) {
    final $$InvoicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableAnnotationComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> vehicleCostEntriesRefs<T extends Object>(
    Expression<T> Function($$VehicleCostEntriesTableAnnotationComposer a) f,
  ) {
    final $$VehicleCostEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.vehicleCostEntries,
          getReferencedColumn: (t) => t.projectId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$VehicleCostEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.vehicleCostEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> expensesRefs<T extends Object>(
    Expression<T> Function($$ExpensesTableAnnotationComposer a) f,
  ) {
    final $$ExpensesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenses,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpensesTableAnnotationComposer(
            $db: $db,
            $table: $db.expenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectsTable,
          Project,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (Project, $$ProjectsTableReferences),
          Project,
          PrefetchHooks Function({
            bool companyId,
            bool customerId,
            bool invoicesRefs,
            bool vehicleCostEntriesRefs,
            bool expensesRefs,
          })
        > {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<ProjectStatus> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                companyId: companyId,
                name: name,
                customerId: customerId,
                notes: notes,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String name,
                Value<String?> customerId = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<ProjectStatus> status = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                companyId: companyId,
                name: name,
                customerId: customerId,
                notes: notes,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProjectsTable, Project>(table),
                  $$ProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                companyId = false,
                customerId = false,
                invoicesRefs = false,
                vehicleCostEntriesRefs = false,
                expensesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (invoicesRefs) db.invoices,
                    if (vehicleCostEntriesRefs) db.vehicleCostEntries,
                    if (expensesRefs) db.expenses,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (companyId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.companyId,
                                    referencedTable: $$ProjectsTableReferences
                                        ._companyIdTable(db),
                                    referencedColumn: $$ProjectsTableReferences
                                        ._companyIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (customerId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.customerId,
                                    referencedTable: $$ProjectsTableReferences
                                        ._customerIdTable(db),
                                    referencedColumn: $$ProjectsTableReferences
                                        ._customerIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (invoicesRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          Invoice
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._invoicesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).invoicesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (vehicleCostEntriesRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          VehicleCostEntry
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._vehicleCostEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).vehicleCostEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (expensesRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          Expense
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._expensesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).expensesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectsTable,
      Project,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (Project, $$ProjectsTableReferences),
      Project,
      PrefetchHooks Function({
        bool companyId,
        bool customerId,
        bool invoicesRefs,
        bool vehicleCostEntriesRefs,
        bool expensesRefs,
      })
    >;
typedef $$InvoicesTableCreateCompanionBuilder =
    InvoicesCompanion Function({
      required String id,
      required String companyId,
      required String customerId,
      Value<DocumentKind> kind,
      required InvoiceStatus status,
      Value<String?> invoiceNumber,
      Value<int?> numberYear,
      required DateTime issueDate,
      required DateTime serviceDate,
      Value<String?> paymentTerms,
      Value<String?> notes,
      Value<String?> customerSnapshotName,
      Value<String?> customerSnapshotAddress,
      Value<String?> customerSnapshotVatId,
      Value<String?> companySnapshotName,
      Value<String?> companySnapshotAddress,
      Value<String?> companySnapshotTaxNumber,
      Value<String?> companySnapshotVatId,
      Value<String?> companySnapshotIban,
      Value<String?> pdfIntroTextSnapshot,
      Value<String?> pdfClosingTextSnapshot,
      Value<String?> pdfFooterTextSnapshot,
      Value<DateTime?> finalizedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String?> convertedFromId,
      Value<String?> projectId,
      Value<bool> isAdvancePayment,
      Value<DateTime?> dueDate,
      Value<PaymentStatus> paymentStatus,
      Value<DateTime?> paidAt,
      Value<int> rowid,
    });
typedef $$InvoicesTableUpdateCompanionBuilder =
    InvoicesCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> customerId,
      Value<DocumentKind> kind,
      Value<InvoiceStatus> status,
      Value<String?> invoiceNumber,
      Value<int?> numberYear,
      Value<DateTime> issueDate,
      Value<DateTime> serviceDate,
      Value<String?> paymentTerms,
      Value<String?> notes,
      Value<String?> customerSnapshotName,
      Value<String?> customerSnapshotAddress,
      Value<String?> customerSnapshotVatId,
      Value<String?> companySnapshotName,
      Value<String?> companySnapshotAddress,
      Value<String?> companySnapshotTaxNumber,
      Value<String?> companySnapshotVatId,
      Value<String?> companySnapshotIban,
      Value<String?> pdfIntroTextSnapshot,
      Value<String?> pdfClosingTextSnapshot,
      Value<String?> pdfFooterTextSnapshot,
      Value<DateTime?> finalizedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> convertedFromId,
      Value<String?> projectId,
      Value<bool> isAdvancePayment,
      Value<DateTime?> dueDate,
      Value<PaymentStatus> paymentStatus,
      Value<DateTime?> paidAt,
      Value<int> rowid,
    });

final class $$InvoicesTableReferences
    extends BaseReferences<_$AppDatabase, $InvoicesTable, Invoice> {
  $$InvoicesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CompaniesTable _companyIdTable(_$AppDatabase db) =>
      db.companies.createAlias('invoices__company_id__companies__id');

  $$CompaniesTableProcessedTableManager get companyId {
    final $_column = $_itemColumn<String>('company_id')!;

    final manager = $$CompaniesTableTableManager(
      $_db,
      $_db.companies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_companyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CustomersTable _customerIdTable(_$AppDatabase db) =>
      db.customers.createAlias('invoices__customer_id__customers__id');

  $$CustomersTableProcessedTableManager get customerId {
    final $_column = $_itemColumn<String>('customer_id')!;

    final manager = $$CustomersTableTableManager(
      $_db,
      $_db.customers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_customerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $InvoicesTable _convertedFromIdTable(_$AppDatabase db) =>
      db.invoices.createAlias('invoices__converted_from_id__invoices__id');

  $$InvoicesTableProcessedTableManager? get convertedFromId {
    final $_column = $_itemColumn<String>('converted_from_id');
    if ($_column == null) return null;
    final manager = $$InvoicesTableTableManager(
      $_db,
      $_db.invoices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_convertedFromIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('invoices__project_id__projects__id');

  $$ProjectsTableProcessedTableManager? get projectId {
    final $_column = $_itemColumn<String>('project_id');
    if ($_column == null) return null;
    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$InvoiceItemsTable, List<InvoiceItem>>
  _invoiceItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.invoiceItems,
    aliasName: 'invoices__id__invoice_items__invoice_id',
  );

  $$InvoiceItemsTableProcessedTableManager get invoiceItemsRefs {
    final manager = $$InvoiceItemsTableTableManager(
      $_db,
      $_db.invoiceItems,
    ).filter((f) => f.invoiceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_invoiceItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BankTransactionsTable, List<BankTransaction>>
  _bankTransactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bankTransactions,
    aliasName: 'invoices__id__bank_transactions__matched_invoice_id',
  );

  $$BankTransactionsTableProcessedTableManager get bankTransactionsRefs {
    final manager =
        $$BankTransactionsTableTableManager($_db, $_db.bankTransactions).filter(
          (f) => f.matchedInvoiceId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _bankTransactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$InvoicesTableFilterComposer
    extends Composer<_$AppDatabase, $InvoicesTable> {
  $$InvoicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DocumentKind, DocumentKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<InvoiceStatus, InvoiceStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get invoiceNumber => $composableBuilder(
    column: $table.invoiceNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get numberYear => $composableBuilder(
    column: $table.numberYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get issueDate => $composableBuilder(
    column: $table.issueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serviceDate => $composableBuilder(
    column: $table.serviceDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentTerms => $composableBuilder(
    column: $table.paymentTerms,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerSnapshotName => $composableBuilder(
    column: $table.customerSnapshotName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerSnapshotAddress => $composableBuilder(
    column: $table.customerSnapshotAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerSnapshotVatId => $composableBuilder(
    column: $table.customerSnapshotVatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companySnapshotName => $composableBuilder(
    column: $table.companySnapshotName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companySnapshotAddress => $composableBuilder(
    column: $table.companySnapshotAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companySnapshotTaxNumber => $composableBuilder(
    column: $table.companySnapshotTaxNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companySnapshotVatId => $composableBuilder(
    column: $table.companySnapshotVatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companySnapshotIban => $composableBuilder(
    column: $table.companySnapshotIban,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfIntroTextSnapshot => $composableBuilder(
    column: $table.pdfIntroTextSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfClosingTextSnapshot => $composableBuilder(
    column: $table.pdfClosingTextSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pdfFooterTextSnapshot => $composableBuilder(
    column: $table.pdfFooterTextSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finalizedAt => $composableBuilder(
    column: $table.finalizedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAdvancePayment => $composableBuilder(
    column: $table.isAdvancePayment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PaymentStatus, PaymentStatus, String>
  get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CompaniesTableFilterComposer get companyId {
    final $$CompaniesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableFilterComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CustomersTableFilterComposer get customerId {
    final $$CustomersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomersTableFilterComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$InvoicesTableFilterComposer get convertedFromId {
    final $$InvoicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.convertedFromId,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableFilterComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> invoiceItemsRefs(
    Expression<bool> Function($$InvoiceItemsTableFilterComposer f) f,
  ) {
    final $$InvoiceItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.invoiceItems,
      getReferencedColumn: (t) => t.invoiceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoiceItemsTableFilterComposer(
            $db: $db,
            $table: $db.invoiceItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bankTransactionsRefs(
    Expression<bool> Function($$BankTransactionsTableFilterComposer f) f,
  ) {
    final $$BankTransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bankTransactions,
      getReferencedColumn: (t) => t.matchedInvoiceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BankTransactionsTableFilterComposer(
            $db: $db,
            $table: $db.bankTransactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$InvoicesTableOrderingComposer
    extends Composer<_$AppDatabase, $InvoicesTable> {
  $$InvoicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invoiceNumber => $composableBuilder(
    column: $table.invoiceNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get numberYear => $composableBuilder(
    column: $table.numberYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get issueDate => $composableBuilder(
    column: $table.issueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serviceDate => $composableBuilder(
    column: $table.serviceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentTerms => $composableBuilder(
    column: $table.paymentTerms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerSnapshotName => $composableBuilder(
    column: $table.customerSnapshotName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerSnapshotAddress => $composableBuilder(
    column: $table.customerSnapshotAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerSnapshotVatId => $composableBuilder(
    column: $table.customerSnapshotVatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companySnapshotName => $composableBuilder(
    column: $table.companySnapshotName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companySnapshotAddress => $composableBuilder(
    column: $table.companySnapshotAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companySnapshotTaxNumber => $composableBuilder(
    column: $table.companySnapshotTaxNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companySnapshotVatId => $composableBuilder(
    column: $table.companySnapshotVatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companySnapshotIban => $composableBuilder(
    column: $table.companySnapshotIban,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfIntroTextSnapshot => $composableBuilder(
    column: $table.pdfIntroTextSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfClosingTextSnapshot => $composableBuilder(
    column: $table.pdfClosingTextSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pdfFooterTextSnapshot => $composableBuilder(
    column: $table.pdfFooterTextSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finalizedAt => $composableBuilder(
    column: $table.finalizedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAdvancePayment => $composableBuilder(
    column: $table.isAdvancePayment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompaniesTableOrderingComposer get companyId {
    final $$CompaniesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableOrderingComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CustomersTableOrderingComposer get customerId {
    final $$CustomersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomersTableOrderingComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$InvoicesTableOrderingComposer get convertedFromId {
    final $$InvoicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.convertedFromId,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableOrderingComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InvoicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InvoicesTable> {
  $$InvoicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DocumentKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<InvoiceStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get invoiceNumber => $composableBuilder(
    column: $table.invoiceNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get numberYear => $composableBuilder(
    column: $table.numberYear,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get issueDate =>
      $composableBuilder(column: $table.issueDate, builder: (column) => column);

  GeneratedColumn<DateTime> get serviceDate => $composableBuilder(
    column: $table.serviceDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paymentTerms => $composableBuilder(
    column: $table.paymentTerms,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get customerSnapshotName => $composableBuilder(
    column: $table.customerSnapshotName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerSnapshotAddress => $composableBuilder(
    column: $table.customerSnapshotAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerSnapshotVatId => $composableBuilder(
    column: $table.customerSnapshotVatId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get companySnapshotName => $composableBuilder(
    column: $table.companySnapshotName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get companySnapshotAddress => $composableBuilder(
    column: $table.companySnapshotAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get companySnapshotTaxNumber => $composableBuilder(
    column: $table.companySnapshotTaxNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get companySnapshotVatId => $composableBuilder(
    column: $table.companySnapshotVatId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get companySnapshotIban => $composableBuilder(
    column: $table.companySnapshotIban,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfIntroTextSnapshot => $composableBuilder(
    column: $table.pdfIntroTextSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfClosingTextSnapshot => $composableBuilder(
    column: $table.pdfClosingTextSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pdfFooterTextSnapshot => $composableBuilder(
    column: $table.pdfFooterTextSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get finalizedAt => $composableBuilder(
    column: $table.finalizedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isAdvancePayment => $composableBuilder(
    column: $table.isAdvancePayment,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PaymentStatus, String> get paymentStatus =>
      $composableBuilder(
        column: $table.paymentStatus,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get paidAt =>
      $composableBuilder(column: $table.paidAt, builder: (column) => column);

  $$CompaniesTableAnnotationComposer get companyId {
    final $$CompaniesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableAnnotationComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CustomersTableAnnotationComposer get customerId {
    final $$CustomersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomersTableAnnotationComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$InvoicesTableAnnotationComposer get convertedFromId {
    final $$InvoicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.convertedFromId,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableAnnotationComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> invoiceItemsRefs<T extends Object>(
    Expression<T> Function($$InvoiceItemsTableAnnotationComposer a) f,
  ) {
    final $$InvoiceItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.invoiceItems,
      getReferencedColumn: (t) => t.invoiceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoiceItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.invoiceItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bankTransactionsRefs<T extends Object>(
    Expression<T> Function($$BankTransactionsTableAnnotationComposer a) f,
  ) {
    final $$BankTransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bankTransactions,
      getReferencedColumn: (t) => t.matchedInvoiceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BankTransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.bankTransactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$InvoicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InvoicesTable,
          Invoice,
          $$InvoicesTableFilterComposer,
          $$InvoicesTableOrderingComposer,
          $$InvoicesTableAnnotationComposer,
          $$InvoicesTableCreateCompanionBuilder,
          $$InvoicesTableUpdateCompanionBuilder,
          (Invoice, $$InvoicesTableReferences),
          Invoice,
          PrefetchHooks Function({
            bool companyId,
            bool customerId,
            bool convertedFromId,
            bool projectId,
            bool invoiceItemsRefs,
            bool bankTransactionsRefs,
          })
        > {
  $$InvoicesTableTableManager(_$AppDatabase db, $InvoicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InvoicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InvoicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InvoicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> customerId = const Value.absent(),
                Value<DocumentKind> kind = const Value.absent(),
                Value<InvoiceStatus> status = const Value.absent(),
                Value<String?> invoiceNumber = const Value.absent(),
                Value<int?> numberYear = const Value.absent(),
                Value<DateTime> issueDate = const Value.absent(),
                Value<DateTime> serviceDate = const Value.absent(),
                Value<String?> paymentTerms = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> customerSnapshotName = const Value.absent(),
                Value<String?> customerSnapshotAddress = const Value.absent(),
                Value<String?> customerSnapshotVatId = const Value.absent(),
                Value<String?> companySnapshotName = const Value.absent(),
                Value<String?> companySnapshotAddress = const Value.absent(),
                Value<String?> companySnapshotTaxNumber = const Value.absent(),
                Value<String?> companySnapshotVatId = const Value.absent(),
                Value<String?> companySnapshotIban = const Value.absent(),
                Value<String?> pdfIntroTextSnapshot = const Value.absent(),
                Value<String?> pdfClosingTextSnapshot = const Value.absent(),
                Value<String?> pdfFooterTextSnapshot = const Value.absent(),
                Value<DateTime?> finalizedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> convertedFromId = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                Value<bool> isAdvancePayment = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<PaymentStatus> paymentStatus = const Value.absent(),
                Value<DateTime?> paidAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvoicesCompanion(
                id: id,
                companyId: companyId,
                customerId: customerId,
                kind: kind,
                status: status,
                invoiceNumber: invoiceNumber,
                numberYear: numberYear,
                issueDate: issueDate,
                serviceDate: serviceDate,
                paymentTerms: paymentTerms,
                notes: notes,
                customerSnapshotName: customerSnapshotName,
                customerSnapshotAddress: customerSnapshotAddress,
                customerSnapshotVatId: customerSnapshotVatId,
                companySnapshotName: companySnapshotName,
                companySnapshotAddress: companySnapshotAddress,
                companySnapshotTaxNumber: companySnapshotTaxNumber,
                companySnapshotVatId: companySnapshotVatId,
                companySnapshotIban: companySnapshotIban,
                pdfIntroTextSnapshot: pdfIntroTextSnapshot,
                pdfClosingTextSnapshot: pdfClosingTextSnapshot,
                pdfFooterTextSnapshot: pdfFooterTextSnapshot,
                finalizedAt: finalizedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                convertedFromId: convertedFromId,
                projectId: projectId,
                isAdvancePayment: isAdvancePayment,
                dueDate: dueDate,
                paymentStatus: paymentStatus,
                paidAt: paidAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String customerId,
                Value<DocumentKind> kind = const Value.absent(),
                required InvoiceStatus status,
                Value<String?> invoiceNumber = const Value.absent(),
                Value<int?> numberYear = const Value.absent(),
                required DateTime issueDate,
                required DateTime serviceDate,
                Value<String?> paymentTerms = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> customerSnapshotName = const Value.absent(),
                Value<String?> customerSnapshotAddress = const Value.absent(),
                Value<String?> customerSnapshotVatId = const Value.absent(),
                Value<String?> companySnapshotName = const Value.absent(),
                Value<String?> companySnapshotAddress = const Value.absent(),
                Value<String?> companySnapshotTaxNumber = const Value.absent(),
                Value<String?> companySnapshotVatId = const Value.absent(),
                Value<String?> companySnapshotIban = const Value.absent(),
                Value<String?> pdfIntroTextSnapshot = const Value.absent(),
                Value<String?> pdfClosingTextSnapshot = const Value.absent(),
                Value<String?> pdfFooterTextSnapshot = const Value.absent(),
                Value<DateTime?> finalizedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String?> convertedFromId = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                Value<bool> isAdvancePayment = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<PaymentStatus> paymentStatus = const Value.absent(),
                Value<DateTime?> paidAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvoicesCompanion.insert(
                id: id,
                companyId: companyId,
                customerId: customerId,
                kind: kind,
                status: status,
                invoiceNumber: invoiceNumber,
                numberYear: numberYear,
                issueDate: issueDate,
                serviceDate: serviceDate,
                paymentTerms: paymentTerms,
                notes: notes,
                customerSnapshotName: customerSnapshotName,
                customerSnapshotAddress: customerSnapshotAddress,
                customerSnapshotVatId: customerSnapshotVatId,
                companySnapshotName: companySnapshotName,
                companySnapshotAddress: companySnapshotAddress,
                companySnapshotTaxNumber: companySnapshotTaxNumber,
                companySnapshotVatId: companySnapshotVatId,
                companySnapshotIban: companySnapshotIban,
                pdfIntroTextSnapshot: pdfIntroTextSnapshot,
                pdfClosingTextSnapshot: pdfClosingTextSnapshot,
                pdfFooterTextSnapshot: pdfFooterTextSnapshot,
                finalizedAt: finalizedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                convertedFromId: convertedFromId,
                projectId: projectId,
                isAdvancePayment: isAdvancePayment,
                dueDate: dueDate,
                paymentStatus: paymentStatus,
                paidAt: paidAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InvoicesTable, Invoice>(table),
                  $$InvoicesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                companyId = false,
                customerId = false,
                convertedFromId = false,
                projectId = false,
                invoiceItemsRefs = false,
                bankTransactionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (invoiceItemsRefs) db.invoiceItems,
                    if (bankTransactionsRefs) db.bankTransactions,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (companyId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.companyId,
                                    referencedTable: $$InvoicesTableReferences
                                        ._companyIdTable(db),
                                    referencedColumn: $$InvoicesTableReferences
                                        ._companyIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (customerId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.customerId,
                                    referencedTable: $$InvoicesTableReferences
                                        ._customerIdTable(db),
                                    referencedColumn: $$InvoicesTableReferences
                                        ._customerIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (convertedFromId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.convertedFromId,
                                    referencedTable: $$InvoicesTableReferences
                                        ._convertedFromIdTable(db),
                                    referencedColumn: $$InvoicesTableReferences
                                        ._convertedFromIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable: $$InvoicesTableReferences
                                        ._projectIdTable(db),
                                    referencedColumn: $$InvoicesTableReferences
                                        ._projectIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (invoiceItemsRefs)
                        await $_getPrefetchedData<
                          Invoice,
                          $InvoicesTable,
                          InvoiceItem
                        >(
                          currentTable: table,
                          referencedTable: $$InvoicesTableReferences
                              ._invoiceItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$InvoicesTableReferences(
                                db,
                                table,
                                p0,
                              ).invoiceItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.invoiceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bankTransactionsRefs)
                        await $_getPrefetchedData<
                          Invoice,
                          $InvoicesTable,
                          BankTransaction
                        >(
                          currentTable: table,
                          referencedTable: $$InvoicesTableReferences
                              ._bankTransactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$InvoicesTableReferences(
                                db,
                                table,
                                p0,
                              ).bankTransactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.matchedInvoiceId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$InvoicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InvoicesTable,
      Invoice,
      $$InvoicesTableFilterComposer,
      $$InvoicesTableOrderingComposer,
      $$InvoicesTableAnnotationComposer,
      $$InvoicesTableCreateCompanionBuilder,
      $$InvoicesTableUpdateCompanionBuilder,
      (Invoice, $$InvoicesTableReferences),
      Invoice,
      PrefetchHooks Function({
        bool companyId,
        bool customerId,
        bool convertedFromId,
        bool projectId,
        bool invoiceItemsRefs,
        bool bankTransactionsRefs,
      })
    >;
typedef $$InvoiceItemsTableCreateCompanionBuilder =
    InvoiceItemsCompanion Function({
      required String id,
      required String invoiceId,
      required InvoiceItemKind kind,
      Value<String?> articleId,
      required String description,
      required String quantity,
      required int unitPriceCents,
      required double vatRatePercent,
      Value<String?> unit,
      Value<double> discountPercent,
      Value<String?> groupLabel,
      required int sortOrder,
      Value<int> rowid,
    });
typedef $$InvoiceItemsTableUpdateCompanionBuilder =
    InvoiceItemsCompanion Function({
      Value<String> id,
      Value<String> invoiceId,
      Value<InvoiceItemKind> kind,
      Value<String?> articleId,
      Value<String> description,
      Value<String> quantity,
      Value<int> unitPriceCents,
      Value<double> vatRatePercent,
      Value<String?> unit,
      Value<double> discountPercent,
      Value<String?> groupLabel,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$InvoiceItemsTableReferences
    extends BaseReferences<_$AppDatabase, $InvoiceItemsTable, InvoiceItem> {
  $$InvoiceItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $InvoicesTable _invoiceIdTable(_$AppDatabase db) =>
      db.invoices.createAlias('invoice_items__invoice_id__invoices__id');

  $$InvoicesTableProcessedTableManager get invoiceId {
    final $_column = $_itemColumn<String>('invoice_id')!;

    final manager = $$InvoicesTableTableManager(
      $_db,
      $_db.invoices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_invoiceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ArticlesTable _articleIdTable(_$AppDatabase db) =>
      db.articles.createAlias('invoice_items__article_id__articles__id');

  $$ArticlesTableProcessedTableManager? get articleId {
    final $_column = $_itemColumn<String>('article_id');
    if ($_column == null) return null;
    final manager = $$ArticlesTableTableManager(
      $_db,
      $_db.articles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_articleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$InvoiceItemsTableFilterComposer
    extends Composer<_$AppDatabase, $InvoiceItemsTable> {
  $$InvoiceItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<InvoiceItemKind, InvoiceItemKind, String>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitPriceCents => $composableBuilder(
    column: $table.unitPriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get vatRatePercent => $composableBuilder(
    column: $table.vatRatePercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get discountPercent => $composableBuilder(
    column: $table.discountPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupLabel => $composableBuilder(
    column: $table.groupLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$InvoicesTableFilterComposer get invoiceId {
    final $$InvoicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.invoiceId,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableFilterComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ArticlesTableFilterComposer get articleId {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableFilterComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InvoiceItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $InvoiceItemsTable> {
  $$InvoiceItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitPriceCents => $composableBuilder(
    column: $table.unitPriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get vatRatePercent => $composableBuilder(
    column: $table.vatRatePercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get discountPercent => $composableBuilder(
    column: $table.discountPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupLabel => $composableBuilder(
    column: $table.groupLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$InvoicesTableOrderingComposer get invoiceId {
    final $$InvoicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.invoiceId,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableOrderingComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ArticlesTableOrderingComposer get articleId {
    final $$ArticlesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableOrderingComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InvoiceItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InvoiceItemsTable> {
  $$InvoiceItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<InvoiceItemKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<int> get unitPriceCents => $composableBuilder(
    column: $table.unitPriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<double> get vatRatePercent => $composableBuilder(
    column: $table.vatRatePercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<double> get discountPercent => $composableBuilder(
    column: $table.discountPercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get groupLabel => $composableBuilder(
    column: $table.groupLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$InvoicesTableAnnotationComposer get invoiceId {
    final $$InvoicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.invoiceId,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableAnnotationComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ArticlesTableAnnotationComposer get articleId {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableAnnotationComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InvoiceItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InvoiceItemsTable,
          InvoiceItem,
          $$InvoiceItemsTableFilterComposer,
          $$InvoiceItemsTableOrderingComposer,
          $$InvoiceItemsTableAnnotationComposer,
          $$InvoiceItemsTableCreateCompanionBuilder,
          $$InvoiceItemsTableUpdateCompanionBuilder,
          (InvoiceItem, $$InvoiceItemsTableReferences),
          InvoiceItem,
          PrefetchHooks Function({bool invoiceId, bool articleId})
        > {
  $$InvoiceItemsTableTableManager(_$AppDatabase db, $InvoiceItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InvoiceItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InvoiceItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InvoiceItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> invoiceId = const Value.absent(),
                Value<InvoiceItemKind> kind = const Value.absent(),
                Value<String?> articleId = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> quantity = const Value.absent(),
                Value<int> unitPriceCents = const Value.absent(),
                Value<double> vatRatePercent = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<double> discountPercent = const Value.absent(),
                Value<String?> groupLabel = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvoiceItemsCompanion(
                id: id,
                invoiceId: invoiceId,
                kind: kind,
                articleId: articleId,
                description: description,
                quantity: quantity,
                unitPriceCents: unitPriceCents,
                vatRatePercent: vatRatePercent,
                unit: unit,
                discountPercent: discountPercent,
                groupLabel: groupLabel,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String invoiceId,
                required InvoiceItemKind kind,
                Value<String?> articleId = const Value.absent(),
                required String description,
                required String quantity,
                required int unitPriceCents,
                required double vatRatePercent,
                Value<String?> unit = const Value.absent(),
                Value<double> discountPercent = const Value.absent(),
                Value<String?> groupLabel = const Value.absent(),
                required int sortOrder,
                Value<int> rowid = const Value.absent(),
              }) => InvoiceItemsCompanion.insert(
                id: id,
                invoiceId: invoiceId,
                kind: kind,
                articleId: articleId,
                description: description,
                quantity: quantity,
                unitPriceCents: unitPriceCents,
                vatRatePercent: vatRatePercent,
                unit: unit,
                discountPercent: discountPercent,
                groupLabel: groupLabel,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InvoiceItemsTable, InvoiceItem>(table),
                  $$InvoiceItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({invoiceId = false, articleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (invoiceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.invoiceId,
                                referencedTable: $$InvoiceItemsTableReferences
                                    ._invoiceIdTable(db),
                                referencedColumn: $$InvoiceItemsTableReferences
                                    ._invoiceIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (articleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.articleId,
                                referencedTable: $$InvoiceItemsTableReferences
                                    ._articleIdTable(db),
                                referencedColumn: $$InvoiceItemsTableReferences
                                    ._articleIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$InvoiceItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InvoiceItemsTable,
      InvoiceItem,
      $$InvoiceItemsTableFilterComposer,
      $$InvoiceItemsTableOrderingComposer,
      $$InvoiceItemsTableAnnotationComposer,
      $$InvoiceItemsTableCreateCompanionBuilder,
      $$InvoiceItemsTableUpdateCompanionBuilder,
      (InvoiceItem, $$InvoiceItemsTableReferences),
      InvoiceItem,
      PrefetchHooks Function({bool invoiceId, bool articleId})
    >;
typedef $$NumberSequencesTableCreateCompanionBuilder =
    NumberSequencesCompanion Function({
      required String companyId,
      required String documentType,
      required int year,
      Value<int> lastNumber,
      Value<int> rowid,
    });
typedef $$NumberSequencesTableUpdateCompanionBuilder =
    NumberSequencesCompanion Function({
      Value<String> companyId,
      Value<String> documentType,
      Value<int> year,
      Value<int> lastNumber,
      Value<int> rowid,
    });

final class $$NumberSequencesTableReferences
    extends
        BaseReferences<_$AppDatabase, $NumberSequencesTable, NumberSequence> {
  $$NumberSequencesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CompaniesTable _companyIdTable(_$AppDatabase db) =>
      db.companies.createAlias('number_sequences__company_id__companies__id');

  $$CompaniesTableProcessedTableManager get companyId {
    final $_column = $_itemColumn<String>('company_id')!;

    final manager = $$CompaniesTableTableManager(
      $_db,
      $_db.companies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_companyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NumberSequencesTableFilterComposer
    extends Composer<_$AppDatabase, $NumberSequencesTable> {
  $$NumberSequencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get documentType => $composableBuilder(
    column: $table.documentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastNumber => $composableBuilder(
    column: $table.lastNumber,
    builder: (column) => ColumnFilters(column),
  );

  $$CompaniesTableFilterComposer get companyId {
    final $$CompaniesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableFilterComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NumberSequencesTableOrderingComposer
    extends Composer<_$AppDatabase, $NumberSequencesTable> {
  $$NumberSequencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get documentType => $composableBuilder(
    column: $table.documentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastNumber => $composableBuilder(
    column: $table.lastNumber,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompaniesTableOrderingComposer get companyId {
    final $$CompaniesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableOrderingComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NumberSequencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NumberSequencesTable> {
  $$NumberSequencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get documentType => $composableBuilder(
    column: $table.documentType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get lastNumber => $composableBuilder(
    column: $table.lastNumber,
    builder: (column) => column,
  );

  $$CompaniesTableAnnotationComposer get companyId {
    final $$CompaniesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableAnnotationComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NumberSequencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NumberSequencesTable,
          NumberSequence,
          $$NumberSequencesTableFilterComposer,
          $$NumberSequencesTableOrderingComposer,
          $$NumberSequencesTableAnnotationComposer,
          $$NumberSequencesTableCreateCompanionBuilder,
          $$NumberSequencesTableUpdateCompanionBuilder,
          (NumberSequence, $$NumberSequencesTableReferences),
          NumberSequence,
          PrefetchHooks Function({bool companyId})
        > {
  $$NumberSequencesTableTableManager(
    _$AppDatabase db,
    $NumberSequencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NumberSequencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NumberSequencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NumberSequencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> companyId = const Value.absent(),
                Value<String> documentType = const Value.absent(),
                Value<int> year = const Value.absent(),
                Value<int> lastNumber = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NumberSequencesCompanion(
                companyId: companyId,
                documentType: documentType,
                year: year,
                lastNumber: lastNumber,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String companyId,
                required String documentType,
                required int year,
                Value<int> lastNumber = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NumberSequencesCompanion.insert(
                companyId: companyId,
                documentType: documentType,
                year: year,
                lastNumber: lastNumber,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NumberSequencesTable, NumberSequence>(table),
                  $$NumberSequencesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({companyId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (companyId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.companyId,
                                referencedTable:
                                    $$NumberSequencesTableReferences
                                        ._companyIdTable(db),
                                referencedColumn:
                                    $$NumberSequencesTableReferences
                                        ._companyIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NumberSequencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NumberSequencesTable,
      NumberSequence,
      $$NumberSequencesTableFilterComposer,
      $$NumberSequencesTableOrderingComposer,
      $$NumberSequencesTableAnnotationComposer,
      $$NumberSequencesTableCreateCompanionBuilder,
      $$NumberSequencesTableUpdateCompanionBuilder,
      (NumberSequence, $$NumberSequencesTableReferences),
      NumberSequence,
      PrefetchHooks Function({bool companyId})
    >;
typedef $$VehiclesTableCreateCompanionBuilder =
    VehiclesCompanion Function({
      required String id,
      required String companyId,
      required String name,
      Value<String?> licensePlate,
      Value<String?> notes,
      Value<DateTime?> nextInspectionDate,
      Value<bool> active,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$VehiclesTableUpdateCompanionBuilder =
    VehiclesCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> name,
      Value<String?> licensePlate,
      Value<String?> notes,
      Value<DateTime?> nextInspectionDate,
      Value<bool> active,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$VehiclesTableReferences
    extends BaseReferences<_$AppDatabase, $VehiclesTable, Vehicle> {
  $$VehiclesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CompaniesTable _companyIdTable(_$AppDatabase db) =>
      db.companies.createAlias('vehicles__company_id__companies__id');

  $$CompaniesTableProcessedTableManager get companyId {
    final $_column = $_itemColumn<String>('company_id')!;

    final manager = $$CompaniesTableTableManager(
      $_db,
      $_db.companies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_companyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$VehicleCostEntriesTable, List<VehicleCostEntry>>
  _vehicleCostEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.vehicleCostEntries,
        aliasName: 'vehicles__id__vehicle_cost_entries__vehicle_id',
      );

  $$VehicleCostEntriesTableProcessedTableManager get vehicleCostEntriesRefs {
    final manager = $$VehicleCostEntriesTableTableManager(
      $_db,
      $_db.vehicleCostEntries,
    ).filter((f) => f.vehicleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _vehicleCostEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VehiclesTableFilterComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get licensePlate => $composableBuilder(
    column: $table.licensePlate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextInspectionDate => $composableBuilder(
    column: $table.nextInspectionDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CompaniesTableFilterComposer get companyId {
    final $$CompaniesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableFilterComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> vehicleCostEntriesRefs(
    Expression<bool> Function($$VehicleCostEntriesTableFilterComposer f) f,
  ) {
    final $$VehicleCostEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.vehicleCostEntries,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehicleCostEntriesTableFilterComposer(
            $db: $db,
            $table: $db.vehicleCostEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VehiclesTableOrderingComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get licensePlate => $composableBuilder(
    column: $table.licensePlate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextInspectionDate => $composableBuilder(
    column: $table.nextInspectionDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompaniesTableOrderingComposer get companyId {
    final $$CompaniesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableOrderingComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VehiclesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get licensePlate => $composableBuilder(
    column: $table.licensePlate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get nextInspectionDate => $composableBuilder(
    column: $table.nextInspectionDate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CompaniesTableAnnotationComposer get companyId {
    final $$CompaniesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableAnnotationComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> vehicleCostEntriesRefs<T extends Object>(
    Expression<T> Function($$VehicleCostEntriesTableAnnotationComposer a) f,
  ) {
    final $$VehicleCostEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.vehicleCostEntries,
          getReferencedColumn: (t) => t.vehicleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$VehicleCostEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.vehicleCostEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$VehiclesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VehiclesTable,
          Vehicle,
          $$VehiclesTableFilterComposer,
          $$VehiclesTableOrderingComposer,
          $$VehiclesTableAnnotationComposer,
          $$VehiclesTableCreateCompanionBuilder,
          $$VehiclesTableUpdateCompanionBuilder,
          (Vehicle, $$VehiclesTableReferences),
          Vehicle,
          PrefetchHooks Function({bool companyId, bool vehicleCostEntriesRefs})
        > {
  $$VehiclesTableTableManager(_$AppDatabase db, $VehiclesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VehiclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VehiclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VehiclesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> licensePlate = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> nextInspectionDate = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehiclesCompanion(
                id: id,
                companyId: companyId,
                name: name,
                licensePlate: licensePlate,
                notes: notes,
                nextInspectionDate: nextInspectionDate,
                active: active,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String name,
                Value<String?> licensePlate = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> nextInspectionDate = const Value.absent(),
                Value<bool> active = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => VehiclesCompanion.insert(
                id: id,
                companyId: companyId,
                name: name,
                licensePlate: licensePlate,
                notes: notes,
                nextInspectionDate: nextInspectionDate,
                active: active,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VehiclesTable, Vehicle>(table),
                  $$VehiclesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({companyId = false, vehicleCostEntriesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (vehicleCostEntriesRefs) db.vehicleCostEntries,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (companyId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.companyId,
                                    referencedTable: $$VehiclesTableReferences
                                        ._companyIdTable(db),
                                    referencedColumn: $$VehiclesTableReferences
                                        ._companyIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (vehicleCostEntriesRefs)
                        await $_getPrefetchedData<
                          Vehicle,
                          $VehiclesTable,
                          VehicleCostEntry
                        >(
                          currentTable: table,
                          referencedTable: $$VehiclesTableReferences
                              ._vehicleCostEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VehiclesTableReferences(
                                db,
                                table,
                                p0,
                              ).vehicleCostEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.vehicleId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$VehiclesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VehiclesTable,
      Vehicle,
      $$VehiclesTableFilterComposer,
      $$VehiclesTableOrderingComposer,
      $$VehiclesTableAnnotationComposer,
      $$VehiclesTableCreateCompanionBuilder,
      $$VehiclesTableUpdateCompanionBuilder,
      (Vehicle, $$VehiclesTableReferences),
      Vehicle,
      PrefetchHooks Function({bool companyId, bool vehicleCostEntriesRefs})
    >;
typedef $$VehicleCostEntriesTableCreateCompanionBuilder =
    VehicleCostEntriesCompanion Function({
      required String id,
      required String companyId,
      required String vehicleId,
      required DateTime date,
      required int amountCents,
      required VehicleCostCategory category,
      Value<String?> description,
      Value<String?> projectId,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$VehicleCostEntriesTableUpdateCompanionBuilder =
    VehicleCostEntriesCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> vehicleId,
      Value<DateTime> date,
      Value<int> amountCents,
      Value<VehicleCostCategory> category,
      Value<String?> description,
      Value<String?> projectId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$VehicleCostEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $VehicleCostEntriesTable,
          VehicleCostEntry
        > {
  $$VehicleCostEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CompaniesTable _companyIdTable(_$AppDatabase db) => db.companies
      .createAlias('vehicle_cost_entries__company_id__companies__id');

  $$CompaniesTableProcessedTableManager get companyId {
    final $_column = $_itemColumn<String>('company_id')!;

    final manager = $$CompaniesTableTableManager(
      $_db,
      $_db.companies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_companyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $VehiclesTable _vehicleIdTable(_$AppDatabase db) =>
      db.vehicles.createAlias('vehicle_cost_entries__vehicle_id__vehicles__id');

  $$VehiclesTableProcessedTableManager get vehicleId {
    final $_column = $_itemColumn<String>('vehicle_id')!;

    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vehicleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('vehicle_cost_entries__project_id__projects__id');

  $$ProjectsTableProcessedTableManager? get projectId {
    final $_column = $_itemColumn<String>('project_id');
    if ($_column == null) return null;
    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$VehicleCostEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $VehicleCostEntriesTable> {
  $$VehicleCostEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    VehicleCostCategory,
    VehicleCostCategory,
    String
  >
  get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CompaniesTableFilterComposer get companyId {
    final $$CompaniesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableFilterComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VehiclesTableFilterComposer get vehicleId {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VehicleCostEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $VehicleCostEntriesTable> {
  $$VehicleCostEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompaniesTableOrderingComposer get companyId {
    final $$CompaniesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableOrderingComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VehiclesTableOrderingComposer get vehicleId {
    final $$VehiclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableOrderingComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VehicleCostEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VehicleCostEntriesTable> {
  $$VehicleCostEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<VehicleCostCategory, String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CompaniesTableAnnotationComposer get companyId {
    final $$CompaniesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableAnnotationComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$VehiclesTableAnnotationComposer get vehicleId {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$VehicleCostEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VehicleCostEntriesTable,
          VehicleCostEntry,
          $$VehicleCostEntriesTableFilterComposer,
          $$VehicleCostEntriesTableOrderingComposer,
          $$VehicleCostEntriesTableAnnotationComposer,
          $$VehicleCostEntriesTableCreateCompanionBuilder,
          $$VehicleCostEntriesTableUpdateCompanionBuilder,
          (VehicleCostEntry, $$VehicleCostEntriesTableReferences),
          VehicleCostEntry,
          PrefetchHooks Function({
            bool companyId,
            bool vehicleId,
            bool projectId,
          })
        > {
  $$VehicleCostEntriesTableTableManager(
    _$AppDatabase db,
    $VehicleCostEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VehicleCostEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VehicleCostEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VehicleCostEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<VehicleCostCategory> category = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehicleCostEntriesCompanion(
                id: id,
                companyId: companyId,
                vehicleId: vehicleId,
                date: date,
                amountCents: amountCents,
                category: category,
                description: description,
                projectId: projectId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String vehicleId,
                required DateTime date,
                required int amountCents,
                required VehicleCostCategory category,
                Value<String?> description = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => VehicleCostEntriesCompanion.insert(
                id: id,
                companyId: companyId,
                vehicleId: vehicleId,
                date: date,
                amountCents: amountCents,
                category: category,
                description: description,
                projectId: projectId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VehicleCostEntriesTable, VehicleCostEntry>(
                    table,
                  ),
                  $$VehicleCostEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({companyId = false, vehicleId = false, projectId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (companyId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.companyId,
                                    referencedTable:
                                        $$VehicleCostEntriesTableReferences
                                            ._companyIdTable(db),
                                    referencedColumn:
                                        $$VehicleCostEntriesTableReferences
                                            ._companyIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (vehicleId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.vehicleId,
                                    referencedTable:
                                        $$VehicleCostEntriesTableReferences
                                            ._vehicleIdTable(db),
                                    referencedColumn:
                                        $$VehicleCostEntriesTableReferences
                                            ._vehicleIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable:
                                        $$VehicleCostEntriesTableReferences
                                            ._projectIdTable(db),
                                    referencedColumn:
                                        $$VehicleCostEntriesTableReferences
                                            ._projectIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$VehicleCostEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VehicleCostEntriesTable,
      VehicleCostEntry,
      $$VehicleCostEntriesTableFilterComposer,
      $$VehicleCostEntriesTableOrderingComposer,
      $$VehicleCostEntriesTableAnnotationComposer,
      $$VehicleCostEntriesTableCreateCompanionBuilder,
      $$VehicleCostEntriesTableUpdateCompanionBuilder,
      (VehicleCostEntry, $$VehicleCostEntriesTableReferences),
      VehicleCostEntry,
      PrefetchHooks Function({bool companyId, bool vehicleId, bool projectId})
    >;
typedef $$RecurringInvoiceTemplatesTableCreateCompanionBuilder =
    RecurringInvoiceTemplatesCompanion Function({
      required String id,
      required String companyId,
      required String customerId,
      required String label,
      required RecurrenceInterval interval,
      required DateTime nextDueDate,
      Value<String?> paymentTerms,
      Value<String?> notes,
      Value<bool> active,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$RecurringInvoiceTemplatesTableUpdateCompanionBuilder =
    RecurringInvoiceTemplatesCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> customerId,
      Value<String> label,
      Value<RecurrenceInterval> interval,
      Value<DateTime> nextDueDate,
      Value<String?> paymentTerms,
      Value<String?> notes,
      Value<bool> active,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$RecurringInvoiceTemplatesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $RecurringInvoiceTemplatesTable,
          RecurringInvoiceTemplate
        > {
  $$RecurringInvoiceTemplatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CompaniesTable _companyIdTable(_$AppDatabase db) => db.companies
      .createAlias('recurring_invoice_templates__company_id__companies__id');

  $$CompaniesTableProcessedTableManager get companyId {
    final $_column = $_itemColumn<String>('company_id')!;

    final manager = $$CompaniesTableTableManager(
      $_db,
      $_db.companies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_companyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CustomersTable _customerIdTable(_$AppDatabase db) => db.customers
      .createAlias('recurring_invoice_templates__customer_id__customers__id');

  $$CustomersTableProcessedTableManager get customerId {
    final $_column = $_itemColumn<String>('customer_id')!;

    final manager = $$CustomersTableTableManager(
      $_db,
      $_db.customers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_customerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $RecurringInvoiceTemplateItemsTable,
    List<RecurringInvoiceTemplateItem>
  >
  _recurringInvoiceTemplateItemsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.recurringInvoiceTemplateItems,
    aliasName:
        'recurring_invoice_templates__id__recurring_invoice_template_items__template_id',
  );

  $$RecurringInvoiceTemplateItemsTableProcessedTableManager
  get recurringInvoiceTemplateItemsRefs {
    final manager = $$RecurringInvoiceTemplateItemsTableTableManager(
      $_db,
      $_db.recurringInvoiceTemplateItems,
    ).filter((f) => f.templateId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _recurringInvoiceTemplateItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RecurringInvoiceTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $RecurringInvoiceTemplatesTable> {
  $$RecurringInvoiceTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RecurrenceInterval, RecurrenceInterval, String>
  get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get nextDueDate => $composableBuilder(
    column: $table.nextDueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentTerms => $composableBuilder(
    column: $table.paymentTerms,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CompaniesTableFilterComposer get companyId {
    final $$CompaniesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableFilterComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CustomersTableFilterComposer get customerId {
    final $$CustomersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomersTableFilterComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> recurringInvoiceTemplateItemsRefs(
    Expression<bool> Function(
      $$RecurringInvoiceTemplateItemsTableFilterComposer f,
    )
    f,
  ) {
    final $$RecurringInvoiceTemplateItemsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.recurringInvoiceTemplateItems,
          getReferencedColumn: (t) => t.templateId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecurringInvoiceTemplateItemsTableFilterComposer(
                $db: $db,
                $table: $db.recurringInvoiceTemplateItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$RecurringInvoiceTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecurringInvoiceTemplatesTable> {
  $$RecurringInvoiceTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextDueDate => $composableBuilder(
    column: $table.nextDueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentTerms => $composableBuilder(
    column: $table.paymentTerms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompaniesTableOrderingComposer get companyId {
    final $$CompaniesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableOrderingComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CustomersTableOrderingComposer get customerId {
    final $$CustomersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomersTableOrderingComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecurringInvoiceTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecurringInvoiceTemplatesTable> {
  $$RecurringInvoiceTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RecurrenceInterval, String> get interval =>
      $composableBuilder(column: $table.interval, builder: (column) => column);

  GeneratedColumn<DateTime> get nextDueDate => $composableBuilder(
    column: $table.nextDueDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paymentTerms => $composableBuilder(
    column: $table.paymentTerms,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CompaniesTableAnnotationComposer get companyId {
    final $$CompaniesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableAnnotationComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CustomersTableAnnotationComposer get customerId {
    final $$CustomersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.customers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomersTableAnnotationComposer(
            $db: $db,
            $table: $db.customers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> recurringInvoiceTemplateItemsRefs<T extends Object>(
    Expression<T> Function(
      $$RecurringInvoiceTemplateItemsTableAnnotationComposer a,
    )
    f,
  ) {
    final $$RecurringInvoiceTemplateItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.recurringInvoiceTemplateItems,
          getReferencedColumn: (t) => t.templateId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecurringInvoiceTemplateItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.recurringInvoiceTemplateItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$RecurringInvoiceTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecurringInvoiceTemplatesTable,
          RecurringInvoiceTemplate,
          $$RecurringInvoiceTemplatesTableFilterComposer,
          $$RecurringInvoiceTemplatesTableOrderingComposer,
          $$RecurringInvoiceTemplatesTableAnnotationComposer,
          $$RecurringInvoiceTemplatesTableCreateCompanionBuilder,
          $$RecurringInvoiceTemplatesTableUpdateCompanionBuilder,
          (
            RecurringInvoiceTemplate,
            $$RecurringInvoiceTemplatesTableReferences,
          ),
          RecurringInvoiceTemplate,
          PrefetchHooks Function({
            bool companyId,
            bool customerId,
            bool recurringInvoiceTemplateItemsRefs,
          })
        > {
  $$RecurringInvoiceTemplatesTableTableManager(
    _$AppDatabase db,
    $RecurringInvoiceTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurringInvoiceTemplatesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$RecurringInvoiceTemplatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RecurringInvoiceTemplatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> customerId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<RecurrenceInterval> interval = const Value.absent(),
                Value<DateTime> nextDueDate = const Value.absent(),
                Value<String?> paymentTerms = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecurringInvoiceTemplatesCompanion(
                id: id,
                companyId: companyId,
                customerId: customerId,
                label: label,
                interval: interval,
                nextDueDate: nextDueDate,
                paymentTerms: paymentTerms,
                notes: notes,
                active: active,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String customerId,
                required String label,
                required RecurrenceInterval interval,
                required DateTime nextDueDate,
                Value<String?> paymentTerms = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> active = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => RecurringInvoiceTemplatesCompanion.insert(
                id: id,
                companyId: companyId,
                customerId: customerId,
                label: label,
                interval: interval,
                nextDueDate: nextDueDate,
                paymentTerms: paymentTerms,
                notes: notes,
                active: active,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $RecurringInvoiceTemplatesTable,
                    RecurringInvoiceTemplate
                  >(table),
                  $$RecurringInvoiceTemplatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                companyId = false,
                customerId = false,
                recurringInvoiceTemplateItemsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (recurringInvoiceTemplateItemsRefs)
                      db.recurringInvoiceTemplateItems,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (companyId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.companyId,
                                    referencedTable:
                                        $$RecurringInvoiceTemplatesTableReferences
                                            ._companyIdTable(db),
                                    referencedColumn:
                                        $$RecurringInvoiceTemplatesTableReferences
                                            ._companyIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (customerId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.customerId,
                                    referencedTable:
                                        $$RecurringInvoiceTemplatesTableReferences
                                            ._customerIdTable(db),
                                    referencedColumn:
                                        $$RecurringInvoiceTemplatesTableReferences
                                            ._customerIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (recurringInvoiceTemplateItemsRefs)
                        await $_getPrefetchedData<
                          RecurringInvoiceTemplate,
                          $RecurringInvoiceTemplatesTable,
                          RecurringInvoiceTemplateItem
                        >(
                          currentTable: table,
                          referencedTable:
                              $$RecurringInvoiceTemplatesTableReferences
                                  ._recurringInvoiceTemplateItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecurringInvoiceTemplatesTableReferences(
                                db,
                                table,
                                p0,
                              ).recurringInvoiceTemplateItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.templateId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RecurringInvoiceTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecurringInvoiceTemplatesTable,
      RecurringInvoiceTemplate,
      $$RecurringInvoiceTemplatesTableFilterComposer,
      $$RecurringInvoiceTemplatesTableOrderingComposer,
      $$RecurringInvoiceTemplatesTableAnnotationComposer,
      $$RecurringInvoiceTemplatesTableCreateCompanionBuilder,
      $$RecurringInvoiceTemplatesTableUpdateCompanionBuilder,
      (RecurringInvoiceTemplate, $$RecurringInvoiceTemplatesTableReferences),
      RecurringInvoiceTemplate,
      PrefetchHooks Function({
        bool companyId,
        bool customerId,
        bool recurringInvoiceTemplateItemsRefs,
      })
    >;
typedef $$RecurringInvoiceTemplateItemsTableCreateCompanionBuilder =
    RecurringInvoiceTemplateItemsCompanion Function({
      required String id,
      required String templateId,
      required InvoiceItemKind kind,
      Value<String?> articleId,
      required String description,
      required String quantity,
      required int unitPriceCents,
      required double vatRatePercent,
      Value<String?> unit,
      Value<double> discountPercent,
      Value<String?> groupLabel,
      required int sortOrder,
      Value<int> rowid,
    });
typedef $$RecurringInvoiceTemplateItemsTableUpdateCompanionBuilder =
    RecurringInvoiceTemplateItemsCompanion Function({
      Value<String> id,
      Value<String> templateId,
      Value<InvoiceItemKind> kind,
      Value<String?> articleId,
      Value<String> description,
      Value<String> quantity,
      Value<int> unitPriceCents,
      Value<double> vatRatePercent,
      Value<String?> unit,
      Value<double> discountPercent,
      Value<String?> groupLabel,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$RecurringInvoiceTemplateItemsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $RecurringInvoiceTemplateItemsTable,
          RecurringInvoiceTemplateItem
        > {
  $$RecurringInvoiceTemplateItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RecurringInvoiceTemplatesTable _templateIdTable(
    _$AppDatabase db,
  ) => db.recurringInvoiceTemplates.createAlias(
    'recurring_invoice_template_items__template_id__recurring_invoice_templates__id',
  );

  $$RecurringInvoiceTemplatesTableProcessedTableManager get templateId {
    final $_column = $_itemColumn<String>('template_id')!;

    final manager = $$RecurringInvoiceTemplatesTableTableManager(
      $_db,
      $_db.recurringInvoiceTemplates,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_templateIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ArticlesTable _articleIdTable(_$AppDatabase db) =>
      db.articles.createAlias(
        'recurring_invoice_template_items__article_id__articles__id',
      );

  $$ArticlesTableProcessedTableManager? get articleId {
    final $_column = $_itemColumn<String>('article_id');
    if ($_column == null) return null;
    final manager = $$ArticlesTableTableManager(
      $_db,
      $_db.articles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_articleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecurringInvoiceTemplateItemsTableFilterComposer
    extends Composer<_$AppDatabase, $RecurringInvoiceTemplateItemsTable> {
  $$RecurringInvoiceTemplateItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<InvoiceItemKind, InvoiceItemKind, String>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitPriceCents => $composableBuilder(
    column: $table.unitPriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get vatRatePercent => $composableBuilder(
    column: $table.vatRatePercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get discountPercent => $composableBuilder(
    column: $table.discountPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupLabel => $composableBuilder(
    column: $table.groupLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$RecurringInvoiceTemplatesTableFilterComposer get templateId {
    final $$RecurringInvoiceTemplatesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.templateId,
          referencedTable: $db.recurringInvoiceTemplates,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecurringInvoiceTemplatesTableFilterComposer(
                $db: $db,
                $table: $db.recurringInvoiceTemplates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$ArticlesTableFilterComposer get articleId {
    final $$ArticlesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableFilterComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecurringInvoiceTemplateItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecurringInvoiceTemplateItemsTable> {
  $$RecurringInvoiceTemplateItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitPriceCents => $composableBuilder(
    column: $table.unitPriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get vatRatePercent => $composableBuilder(
    column: $table.vatRatePercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get discountPercent => $composableBuilder(
    column: $table.discountPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupLabel => $composableBuilder(
    column: $table.groupLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecurringInvoiceTemplatesTableOrderingComposer get templateId {
    final $$RecurringInvoiceTemplatesTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.templateId,
          referencedTable: $db.recurringInvoiceTemplates,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecurringInvoiceTemplatesTableOrderingComposer(
                $db: $db,
                $table: $db.recurringInvoiceTemplates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$ArticlesTableOrderingComposer get articleId {
    final $$ArticlesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableOrderingComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecurringInvoiceTemplateItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecurringInvoiceTemplateItemsTable> {
  $$RecurringInvoiceTemplateItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<InvoiceItemKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<int> get unitPriceCents => $composableBuilder(
    column: $table.unitPriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<double> get vatRatePercent => $composableBuilder(
    column: $table.vatRatePercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<double> get discountPercent => $composableBuilder(
    column: $table.discountPercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get groupLabel => $composableBuilder(
    column: $table.groupLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$RecurringInvoiceTemplatesTableAnnotationComposer get templateId {
    final $$RecurringInvoiceTemplatesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.templateId,
          referencedTable: $db.recurringInvoiceTemplates,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecurringInvoiceTemplatesTableAnnotationComposer(
                $db: $db,
                $table: $db.recurringInvoiceTemplates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$ArticlesTableAnnotationComposer get articleId {
    final $$ArticlesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.articleId,
      referencedTable: $db.articles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArticlesTableAnnotationComposer(
            $db: $db,
            $table: $db.articles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecurringInvoiceTemplateItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecurringInvoiceTemplateItemsTable,
          RecurringInvoiceTemplateItem,
          $$RecurringInvoiceTemplateItemsTableFilterComposer,
          $$RecurringInvoiceTemplateItemsTableOrderingComposer,
          $$RecurringInvoiceTemplateItemsTableAnnotationComposer,
          $$RecurringInvoiceTemplateItemsTableCreateCompanionBuilder,
          $$RecurringInvoiceTemplateItemsTableUpdateCompanionBuilder,
          (
            RecurringInvoiceTemplateItem,
            $$RecurringInvoiceTemplateItemsTableReferences,
          ),
          RecurringInvoiceTemplateItem,
          PrefetchHooks Function({bool templateId, bool articleId})
        > {
  $$RecurringInvoiceTemplateItemsTableTableManager(
    _$AppDatabase db,
    $RecurringInvoiceTemplateItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurringInvoiceTemplateItemsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$RecurringInvoiceTemplateItemsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RecurringInvoiceTemplateItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> templateId = const Value.absent(),
                Value<InvoiceItemKind> kind = const Value.absent(),
                Value<String?> articleId = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> quantity = const Value.absent(),
                Value<int> unitPriceCents = const Value.absent(),
                Value<double> vatRatePercent = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<double> discountPercent = const Value.absent(),
                Value<String?> groupLabel = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecurringInvoiceTemplateItemsCompanion(
                id: id,
                templateId: templateId,
                kind: kind,
                articleId: articleId,
                description: description,
                quantity: quantity,
                unitPriceCents: unitPriceCents,
                vatRatePercent: vatRatePercent,
                unit: unit,
                discountPercent: discountPercent,
                groupLabel: groupLabel,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String templateId,
                required InvoiceItemKind kind,
                Value<String?> articleId = const Value.absent(),
                required String description,
                required String quantity,
                required int unitPriceCents,
                required double vatRatePercent,
                Value<String?> unit = const Value.absent(),
                Value<double> discountPercent = const Value.absent(),
                Value<String?> groupLabel = const Value.absent(),
                required int sortOrder,
                Value<int> rowid = const Value.absent(),
              }) => RecurringInvoiceTemplateItemsCompanion.insert(
                id: id,
                templateId: templateId,
                kind: kind,
                articleId: articleId,
                description: description,
                quantity: quantity,
                unitPriceCents: unitPriceCents,
                vatRatePercent: vatRatePercent,
                unit: unit,
                discountPercent: discountPercent,
                groupLabel: groupLabel,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $RecurringInvoiceTemplateItemsTable,
                    RecurringInvoiceTemplateItem
                  >(table),
                  $$RecurringInvoiceTemplateItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({templateId = false, articleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (templateId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.templateId,
                                referencedTable:
                                    $$RecurringInvoiceTemplateItemsTableReferences
                                        ._templateIdTable(db),
                                referencedColumn:
                                    $$RecurringInvoiceTemplateItemsTableReferences
                                        ._templateIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (articleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.articleId,
                                referencedTable:
                                    $$RecurringInvoiceTemplateItemsTableReferences
                                        ._articleIdTable(db),
                                referencedColumn:
                                    $$RecurringInvoiceTemplateItemsTableReferences
                                        ._articleIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RecurringInvoiceTemplateItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecurringInvoiceTemplateItemsTable,
      RecurringInvoiceTemplateItem,
      $$RecurringInvoiceTemplateItemsTableFilterComposer,
      $$RecurringInvoiceTemplateItemsTableOrderingComposer,
      $$RecurringInvoiceTemplateItemsTableAnnotationComposer,
      $$RecurringInvoiceTemplateItemsTableCreateCompanionBuilder,
      $$RecurringInvoiceTemplateItemsTableUpdateCompanionBuilder,
      (
        RecurringInvoiceTemplateItem,
        $$RecurringInvoiceTemplateItemsTableReferences,
      ),
      RecurringInvoiceTemplateItem,
      PrefetchHooks Function({bool templateId, bool articleId})
    >;
typedef $$ExpenseCategoriesTableCreateCompanionBuilder =
    ExpenseCategoriesCompanion Function({
      required String id,
      required String companyId,
      required String label,
      Value<String?> skr03Account,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ExpenseCategoriesTableUpdateCompanionBuilder =
    ExpenseCategoriesCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<String> label,
      Value<String?> skr03Account,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ExpenseCategoriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ExpenseCategoriesTable,
          ExpenseCategory
        > {
  $$ExpenseCategoriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CompaniesTable _companyIdTable(_$AppDatabase db) =>
      db.companies.createAlias('expense_categories__company_id__companies__id');

  $$CompaniesTableProcessedTableManager get companyId {
    final $_column = $_itemColumn<String>('company_id')!;

    final manager = $$CompaniesTableTableManager(
      $_db,
      $_db.companies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_companyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ExpensesTable, List<Expense>> _expensesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.expenses,
    aliasName: 'expense_categories__id__expenses__category_id',
  );

  $$ExpensesTableProcessedTableManager get expensesRefs {
    final manager = $$ExpensesTableTableManager(
      $_db,
      $_db.expenses,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_expensesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ExpenseCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $ExpenseCategoriesTable> {
  $$ExpenseCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skr03Account => $composableBuilder(
    column: $table.skr03Account,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CompaniesTableFilterComposer get companyId {
    final $$CompaniesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableFilterComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> expensesRefs(
    Expression<bool> Function($$ExpensesTableFilterComposer f) f,
  ) {
    final $$ExpensesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenses,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpensesTableFilterComposer(
            $db: $db,
            $table: $db.expenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExpenseCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExpenseCategoriesTable> {
  $$ExpenseCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skr03Account => $composableBuilder(
    column: $table.skr03Account,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompaniesTableOrderingComposer get companyId {
    final $$CompaniesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableOrderingComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExpenseCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExpenseCategoriesTable> {
  $$ExpenseCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get skr03Account => $composableBuilder(
    column: $table.skr03Account,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CompaniesTableAnnotationComposer get companyId {
    final $$CompaniesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableAnnotationComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> expensesRefs<T extends Object>(
    Expression<T> Function($$ExpensesTableAnnotationComposer a) f,
  ) {
    final $$ExpensesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenses,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpensesTableAnnotationComposer(
            $db: $db,
            $table: $db.expenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExpenseCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExpenseCategoriesTable,
          ExpenseCategory,
          $$ExpenseCategoriesTableFilterComposer,
          $$ExpenseCategoriesTableOrderingComposer,
          $$ExpenseCategoriesTableAnnotationComposer,
          $$ExpenseCategoriesTableCreateCompanionBuilder,
          $$ExpenseCategoriesTableUpdateCompanionBuilder,
          (ExpenseCategory, $$ExpenseCategoriesTableReferences),
          ExpenseCategory,
          PrefetchHooks Function({bool companyId, bool expensesRefs})
        > {
  $$ExpenseCategoriesTableTableManager(
    _$AppDatabase db,
    $ExpenseCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpenseCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpenseCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpenseCategoriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String?> skr03Account = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpenseCategoriesCompanion(
                id: id,
                companyId: companyId,
                label: label,
                skr03Account: skr03Account,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required String label,
                Value<String?> skr03Account = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ExpenseCategoriesCompanion.insert(
                id: id,
                companyId: companyId,
                label: label,
                skr03Account: skr03Account,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExpenseCategoriesTable, ExpenseCategory>(table),
                  $$ExpenseCategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({companyId = false, expensesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (expensesRefs) db.expenses],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (companyId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.companyId,
                                referencedTable:
                                    $$ExpenseCategoriesTableReferences
                                        ._companyIdTable(db),
                                referencedColumn:
                                    $$ExpenseCategoriesTableReferences
                                        ._companyIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (expensesRefs)
                    await $_getPrefetchedData<
                      ExpenseCategory,
                      $ExpenseCategoriesTable,
                      Expense
                    >(
                      currentTable: table,
                      referencedTable: $$ExpenseCategoriesTableReferences
                          ._expensesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ExpenseCategoriesTableReferences(
                            db,
                            table,
                            p0,
                          ).expensesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.categoryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ExpenseCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExpenseCategoriesTable,
      ExpenseCategory,
      $$ExpenseCategoriesTableFilterComposer,
      $$ExpenseCategoriesTableOrderingComposer,
      $$ExpenseCategoriesTableAnnotationComposer,
      $$ExpenseCategoriesTableCreateCompanionBuilder,
      $$ExpenseCategoriesTableUpdateCompanionBuilder,
      (ExpenseCategory, $$ExpenseCategoriesTableReferences),
      ExpenseCategory,
      PrefetchHooks Function({bool companyId, bool expensesRefs})
    >;
typedef $$ExpensesTableCreateCompanionBuilder =
    ExpensesCompanion Function({
      required String id,
      required String companyId,
      required DateTime date,
      required String description,
      required int amountGrossCents,
      required double vatRatePercent,
      Value<String?> categoryId,
      Value<String?> supplierReference,
      Value<String?> projectId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ExpensesTableUpdateCompanionBuilder =
    ExpensesCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<DateTime> date,
      Value<String> description,
      Value<int> amountGrossCents,
      Value<double> vatRatePercent,
      Value<String?> categoryId,
      Value<String?> supplierReference,
      Value<String?> projectId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ExpensesTableReferences
    extends BaseReferences<_$AppDatabase, $ExpensesTable, Expense> {
  $$ExpensesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CompaniesTable _companyIdTable(_$AppDatabase db) =>
      db.companies.createAlias('expenses__company_id__companies__id');

  $$CompaniesTableProcessedTableManager get companyId {
    final $_column = $_itemColumn<String>('company_id')!;

    final manager = $$CompaniesTableTableManager(
      $_db,
      $_db.companies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_companyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ExpenseCategoriesTable _categoryIdTable(_$AppDatabase db) => db
      .expenseCategories
      .createAlias('expenses__category_id__expense_categories__id');

  $$ExpenseCategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$ExpenseCategoriesTableTableManager(
      $_db,
      $_db.expenseCategories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias('expenses__project_id__projects__id');

  $$ProjectsTableProcessedTableManager? get projectId {
    final $_column = $_itemColumn<String>('project_id');
    if ($_column == null) return null;
    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ExpensesTableFilterComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountGrossCents => $composableBuilder(
    column: $table.amountGrossCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get vatRatePercent => $composableBuilder(
    column: $table.vatRatePercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supplierReference => $composableBuilder(
    column: $table.supplierReference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CompaniesTableFilterComposer get companyId {
    final $$CompaniesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableFilterComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExpenseCategoriesTableFilterComposer get categoryId {
    final $$ExpenseCategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.expenseCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpenseCategoriesTableFilterComposer(
            $db: $db,
            $table: $db.expenseCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExpensesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountGrossCents => $composableBuilder(
    column: $table.amountGrossCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get vatRatePercent => $composableBuilder(
    column: $table.vatRatePercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supplierReference => $composableBuilder(
    column: $table.supplierReference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompaniesTableOrderingComposer get companyId {
    final $$CompaniesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableOrderingComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExpenseCategoriesTableOrderingComposer get categoryId {
    final $$ExpenseCategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.expenseCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpenseCategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.expenseCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExpensesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExpensesTable> {
  $$ExpensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amountGrossCents => $composableBuilder(
    column: $table.amountGrossCents,
    builder: (column) => column,
  );

  GeneratedColumn<double> get vatRatePercent => $composableBuilder(
    column: $table.vatRatePercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get supplierReference => $composableBuilder(
    column: $table.supplierReference,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CompaniesTableAnnotationComposer get companyId {
    final $$CompaniesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableAnnotationComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExpenseCategoriesTableAnnotationComposer get categoryId {
    final $$ExpenseCategoriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.categoryId,
          referencedTable: $db.expenseCategories,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ExpenseCategoriesTableAnnotationComposer(
                $db: $db,
                $table: $db.expenseCategories,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExpensesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExpensesTable,
          Expense,
          $$ExpensesTableFilterComposer,
          $$ExpensesTableOrderingComposer,
          $$ExpensesTableAnnotationComposer,
          $$ExpensesTableCreateCompanionBuilder,
          $$ExpensesTableUpdateCompanionBuilder,
          (Expense, $$ExpensesTableReferences),
          Expense,
          PrefetchHooks Function({
            bool companyId,
            bool categoryId,
            bool projectId,
          })
        > {
  $$ExpensesTableTableManager(_$AppDatabase db, $ExpensesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> amountGrossCents = const Value.absent(),
                Value<double> vatRatePercent = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> supplierReference = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpensesCompanion(
                id: id,
                companyId: companyId,
                date: date,
                description: description,
                amountGrossCents: amountGrossCents,
                vatRatePercent: vatRatePercent,
                categoryId: categoryId,
                supplierReference: supplierReference,
                projectId: projectId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required DateTime date,
                required String description,
                required int amountGrossCents,
                required double vatRatePercent,
                Value<String?> categoryId = const Value.absent(),
                Value<String?> supplierReference = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ExpensesCompanion.insert(
                id: id,
                companyId: companyId,
                date: date,
                description: description,
                amountGrossCents: amountGrossCents,
                vatRatePercent: vatRatePercent,
                categoryId: categoryId,
                supplierReference: supplierReference,
                projectId: projectId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExpensesTable, Expense>(table),
                  $$ExpensesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({companyId = false, categoryId = false, projectId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (companyId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.companyId,
                                    referencedTable: $$ExpensesTableReferences
                                        ._companyIdTable(db),
                                    referencedColumn: $$ExpensesTableReferences
                                        ._companyIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (categoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.categoryId,
                                    referencedTable: $$ExpensesTableReferences
                                        ._categoryIdTable(db),
                                    referencedColumn: $$ExpensesTableReferences
                                        ._categoryIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable: $$ExpensesTableReferences
                                        ._projectIdTable(db),
                                    referencedColumn: $$ExpensesTableReferences
                                        ._projectIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$ExpensesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExpensesTable,
      Expense,
      $$ExpensesTableFilterComposer,
      $$ExpensesTableOrderingComposer,
      $$ExpensesTableAnnotationComposer,
      $$ExpensesTableCreateCompanionBuilder,
      $$ExpensesTableUpdateCompanionBuilder,
      (Expense, $$ExpensesTableReferences),
      Expense,
      PrefetchHooks Function({bool companyId, bool categoryId, bool projectId})
    >;
typedef $$BankTransactionsTableCreateCompanionBuilder =
    BankTransactionsCompanion Function({
      required String id,
      required String companyId,
      required DateTime date,
      required int amountCents,
      Value<String?> purpose,
      Value<String?> counterparty,
      Value<String?> matchedInvoiceId,
      required String importHash,
      required DateTime importedAt,
      Value<int> rowid,
    });
typedef $$BankTransactionsTableUpdateCompanionBuilder =
    BankTransactionsCompanion Function({
      Value<String> id,
      Value<String> companyId,
      Value<DateTime> date,
      Value<int> amountCents,
      Value<String?> purpose,
      Value<String?> counterparty,
      Value<String?> matchedInvoiceId,
      Value<String> importHash,
      Value<DateTime> importedAt,
      Value<int> rowid,
    });

final class $$BankTransactionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $BankTransactionsTable, BankTransaction> {
  $$BankTransactionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CompaniesTable _companyIdTable(_$AppDatabase db) =>
      db.companies.createAlias('bank_transactions__company_id__companies__id');

  $$CompaniesTableProcessedTableManager get companyId {
    final $_column = $_itemColumn<String>('company_id')!;

    final manager = $$CompaniesTableTableManager(
      $_db,
      $_db.companies,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_companyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $InvoicesTable _matchedInvoiceIdTable(_$AppDatabase db) => db.invoices
      .createAlias('bank_transactions__matched_invoice_id__invoices__id');

  $$InvoicesTableProcessedTableManager? get matchedInvoiceId {
    final $_column = $_itemColumn<String>('matched_invoice_id');
    if ($_column == null) return null;
    final manager = $$InvoicesTableTableManager(
      $_db,
      $_db.invoices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_matchedInvoiceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BankTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $BankTransactionsTable> {
  $$BankTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importHash => $composableBuilder(
    column: $table.importHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CompaniesTableFilterComposer get companyId {
    final $$CompaniesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableFilterComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$InvoicesTableFilterComposer get matchedInvoiceId {
    final $$InvoicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchedInvoiceId,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableFilterComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BankTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $BankTransactionsTable> {
  $$BankTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importHash => $composableBuilder(
    column: $table.importHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CompaniesTableOrderingComposer get companyId {
    final $$CompaniesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableOrderingComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$InvoicesTableOrderingComposer get matchedInvoiceId {
    final $$InvoicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchedInvoiceId,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableOrderingComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BankTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BankTransactionsTable> {
  $$BankTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get purpose =>
      $composableBuilder(column: $table.purpose, builder: (column) => column);

  GeneratedColumn<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importHash => $composableBuilder(
    column: $table.importHash,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  $$CompaniesTableAnnotationComposer get companyId {
    final $$CompaniesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.companyId,
      referencedTable: $db.companies,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CompaniesTableAnnotationComposer(
            $db: $db,
            $table: $db.companies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$InvoicesTableAnnotationComposer get matchedInvoiceId {
    final $$InvoicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchedInvoiceId,
      referencedTable: $db.invoices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InvoicesTableAnnotationComposer(
            $db: $db,
            $table: $db.invoices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BankTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BankTransactionsTable,
          BankTransaction,
          $$BankTransactionsTableFilterComposer,
          $$BankTransactionsTableOrderingComposer,
          $$BankTransactionsTableAnnotationComposer,
          $$BankTransactionsTableCreateCompanionBuilder,
          $$BankTransactionsTableUpdateCompanionBuilder,
          (BankTransaction, $$BankTransactionsTableReferences),
          BankTransaction,
          PrefetchHooks Function({bool companyId, bool matchedInvoiceId})
        > {
  $$BankTransactionsTableTableManager(
    _$AppDatabase db,
    $BankTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BankTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BankTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BankTransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<String?> purpose = const Value.absent(),
                Value<String?> counterparty = const Value.absent(),
                Value<String?> matchedInvoiceId = const Value.absent(),
                Value<String> importHash = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BankTransactionsCompanion(
                id: id,
                companyId: companyId,
                date: date,
                amountCents: amountCents,
                purpose: purpose,
                counterparty: counterparty,
                matchedInvoiceId: matchedInvoiceId,
                importHash: importHash,
                importedAt: importedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String companyId,
                required DateTime date,
                required int amountCents,
                Value<String?> purpose = const Value.absent(),
                Value<String?> counterparty = const Value.absent(),
                Value<String?> matchedInvoiceId = const Value.absent(),
                required String importHash,
                required DateTime importedAt,
                Value<int> rowid = const Value.absent(),
              }) => BankTransactionsCompanion.insert(
                id: id,
                companyId: companyId,
                date: date,
                amountCents: amountCents,
                purpose: purpose,
                counterparty: counterparty,
                matchedInvoiceId: matchedInvoiceId,
                importHash: importHash,
                importedAt: importedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BankTransactionsTable, BankTransaction>(table),
                  $$BankTransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({companyId = false, matchedInvoiceId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (companyId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.companyId,
                                    referencedTable:
                                        $$BankTransactionsTableReferences
                                            ._companyIdTable(db),
                                    referencedColumn:
                                        $$BankTransactionsTableReferences
                                            ._companyIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (matchedInvoiceId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.matchedInvoiceId,
                                    referencedTable:
                                        $$BankTransactionsTableReferences
                                            ._matchedInvoiceIdTable(db),
                                    referencedColumn:
                                        $$BankTransactionsTableReferences
                                            ._matchedInvoiceIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$BankTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BankTransactionsTable,
      BankTransaction,
      $$BankTransactionsTableFilterComposer,
      $$BankTransactionsTableOrderingComposer,
      $$BankTransactionsTableAnnotationComposer,
      $$BankTransactionsTableCreateCompanionBuilder,
      $$BankTransactionsTableUpdateCompanionBuilder,
      (BankTransaction, $$BankTransactionsTableReferences),
      BankTransaction,
      PrefetchHooks Function({bool companyId, bool matchedInvoiceId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CompaniesTableTableManager get companies =>
      $$CompaniesTableTableManager(_db, _db.companies);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db, _db.customers);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db, _db.suppliers);
  $$ArticleGroupsTableTableManager get articleGroups =>
      $$ArticleGroupsTableTableManager(_db, _db.articleGroups);
  $$ArticlesTableTableManager get articles =>
      $$ArticlesTableTableManager(_db, _db.articles);
  $$ArticleSupplierPricesTableTableManager get articleSupplierPrices =>
      $$ArticleSupplierPricesTableTableManager(_db, _db.articleSupplierPrices);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$InvoicesTableTableManager get invoices =>
      $$InvoicesTableTableManager(_db, _db.invoices);
  $$InvoiceItemsTableTableManager get invoiceItems =>
      $$InvoiceItemsTableTableManager(_db, _db.invoiceItems);
  $$NumberSequencesTableTableManager get numberSequences =>
      $$NumberSequencesTableTableManager(_db, _db.numberSequences);
  $$VehiclesTableTableManager get vehicles =>
      $$VehiclesTableTableManager(_db, _db.vehicles);
  $$VehicleCostEntriesTableTableManager get vehicleCostEntries =>
      $$VehicleCostEntriesTableTableManager(_db, _db.vehicleCostEntries);
  $$RecurringInvoiceTemplatesTableTableManager get recurringInvoiceTemplates =>
      $$RecurringInvoiceTemplatesTableTableManager(
        _db,
        _db.recurringInvoiceTemplates,
      );
  $$RecurringInvoiceTemplateItemsTableTableManager
  get recurringInvoiceTemplateItems =>
      $$RecurringInvoiceTemplateItemsTableTableManager(
        _db,
        _db.recurringInvoiceTemplateItems,
      );
  $$ExpenseCategoriesTableTableManager get expenseCategories =>
      $$ExpenseCategoriesTableTableManager(_db, _db.expenseCategories);
  $$ExpensesTableTableManager get expenses =>
      $$ExpensesTableTableManager(_db, _db.expenses);
  $$BankTransactionsTableTableManager get bankTransactions =>
      $$BankTransactionsTableTableManager(_db, _db.bankTransactions);
}
