@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'company_import_test.dart';
import 'support/module_harness.dart';

void main() => runOnPostgres('Postgres-Umzugstests', (create) => runCompanyImportTests(create, transactional: true));
