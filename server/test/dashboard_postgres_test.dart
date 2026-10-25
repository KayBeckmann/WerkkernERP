@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'dashboard_test.dart';
import 'support/module_harness.dart';

void main() => runOnPostgres('Postgres-Dashboardtests', runDashboardTests);
