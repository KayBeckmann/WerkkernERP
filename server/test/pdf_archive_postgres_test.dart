@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'pdf_archive_test.dart';
import 'support/module_harness.dart';

void main() => runOnPostgres('Postgres-PDF-Archiv', runPdfArchiveTests);
