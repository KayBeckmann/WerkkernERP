import 'package:werkkern_core/werkkern_core.dart' show documentRecipient;

/// The accounting recipient for a signed customer time sheet follows the
/// exact same billing priority as an invoice. A project without an identified
/// customer must not be guessed here; the caller then leaves the recipient
/// empty for deliberate review in the mail dialog.
String? timeSheetBillingRecipient({
  String? invoiceEmail,
  String? contactEmail,
  String? customerEmail,
}) => documentRecipient(
  billing: true,
  invoiceEmail: invoiceEmail,
  contactEmail: contactEmail,
  customerEmail: customerEmail,
);
