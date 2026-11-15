@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'einvoice_snapshot_test.dart';
import 'support/module_harness.dart';

void main() => runOnPostgres('Postgres-E-Rechnung-Schnappschuss', runEInvoiceSnapshotTests);
