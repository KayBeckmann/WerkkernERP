@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'quote_validity_test.dart';
import 'support/module_harness.dart';

void main() => runOnPostgres('Postgres-Angebotsbindefrist', runQuoteValidityTests);
