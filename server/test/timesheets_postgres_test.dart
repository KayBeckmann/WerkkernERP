@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'support/module_harness.dart';
import 'timesheets_test.dart';

void main() => runOnPostgres('Postgres-Stundenzetteltests', runTimeSheetTests);
