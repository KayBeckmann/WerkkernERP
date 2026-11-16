@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'support/module_harness.dart';
import 'pdf_layout_snapshot_test.dart';

void main() => runOnPostgres('Postgres-PDF-Layout', runPdfLayoutSnapshotTests);
