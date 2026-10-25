@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'stock_test.dart';
import 'support/module_harness.dart';

void main() => runOnPostgres('Postgres-Lagertests', runStockTests);
