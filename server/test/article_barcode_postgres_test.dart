@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'article_barcode_test.dart';
import 'support/module_harness.dart';

void main() => runOnPostgres('Postgres-Artikel-Barcode', runArticleBarcodeTests);
