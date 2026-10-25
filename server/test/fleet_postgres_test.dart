@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'fleet_test.dart';
import 'support/module_harness.dart';

void main() => runOnPostgres('Postgres-Fuhrparktests', runFleetTests);
