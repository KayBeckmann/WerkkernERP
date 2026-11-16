@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'storage_locations_test.dart';
import 'support/module_harness.dart';

void main() => runOnPostgres('Postgres-Lagerorte', runStorageLocationTests);
