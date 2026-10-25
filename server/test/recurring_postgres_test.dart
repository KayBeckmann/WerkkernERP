@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'recurring_test.dart';
import 'support/module_harness.dart';

void main() => runOnPostgres('Postgres-Wiederkehrend-Tests', runRecurringTests);
