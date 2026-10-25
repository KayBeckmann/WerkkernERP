@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'accounting_test.dart';
import 'support/module_harness.dart';

void main() => runOnPostgres('Postgres-Buchhaltungstests', runAccountingTests);
