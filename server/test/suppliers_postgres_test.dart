@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'support/module_harness.dart';
import 'suppliers_test.dart';

void main() => runOnPostgres('Postgres-Lieferantentests', runSupplierTests);
