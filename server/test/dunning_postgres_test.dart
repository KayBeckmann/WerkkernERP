@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'dunning_test.dart';
import 'support/module_harness.dart';

void main() => runOnPostgres('Postgres-Mahnwesentests', runDunningTests);
