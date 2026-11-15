import 'dart:convert';

import 'package:werkkern_core/werkkern_core.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart' show DocumentKind;

bool isEInvoiceKind(DocumentKind kind) => isEInvoiceDocumentKind(kind.name);

/// C15 E-Rechnung — Abbildung der Offline-Stammdaten auf die
/// EN-16931-Parteien aus `werkkern_core`. Strukturierte Felder haben
/// Vorrang, leere werden aus dem Freitext der Anschrift ergänzt.
EInvoiceParty sellerPartyFromCompany(Company company) => EInvoiceParty(
      name: company.name,
      address: addressFromFields(
        street: company.street,
        postalCode: company.postalCode,
        city: company.city,
        countryCode: company.countryCode,
        freeText: company.address,
      ),
      vatId: company.vatId,
      taxNumber: company.taxNumber,
      email: company.email,
      phone: company.phone,
      iban: company.iban,
      bic: company.bic,
    );

EInvoiceParty buyerPartyFromCustomer(Customer customer, {String? contactName, String? contactEmail}) => EInvoiceParty(
      name: customer.name,
      address: addressFromFields(
        street: customer.street,
        postalCode: customer.postalCode,
        city: customer.city,
        countryCode: customer.countryCode,
        freeText: customer.address,
      ),
      vatId: customer.vatId,
      // Rechnungs-E-Mail vor Kontakt vor allgemeiner E-Mail (wie beim Versand).
      email: customer.invoiceEmail ?? contactEmail ?? customer.email,
      phone: customer.phone,
      contactName: contactName,
      leitwegId: customer.leitwegId,
    );

/// Schnappschuss fürs Finalisieren (`Invoices.eInvoiceSnapshot`).
String encodeEInvoiceSnapshot(Company company, Customer customer, {CustomerContact? contact}) => jsonEncode(
      EInvoiceSnapshot(
        seller: sellerPartyFromCompany(company),
        buyer: buyerPartyFromCustomer(customer, contactName: contact?.name, contactEmail: contact?.email),
        format: EInvoiceFormat.parse(customer.eInvoiceFormat),
      ).toJson(),
    );

/// Gespeicherten Schnappschuss lesen; `null` bei Entwürfen und
/// Dokumenten, die vor Schema v36 finalisiert wurden.
EInvoiceSnapshot? decodeEInvoiceSnapshot(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    return EInvoiceSnapshot.fromJson((jsonDecode(json) as Map).cast());
  } on FormatException {
    return null;
  }
}
