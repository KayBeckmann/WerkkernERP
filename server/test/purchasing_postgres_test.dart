@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'purchasing_test.dart';
import 'support/module_harness.dart';

void main() => runOnPostgres('Postgres-Bestellwesentests', runPurchasingTests);
