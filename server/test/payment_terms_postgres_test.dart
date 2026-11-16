@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'payment_terms_test.dart';
import 'support/module_harness.dart';

void main() => runOnPostgres('Postgres-Zahlungsbedingungen', runPaymentTermTests);
