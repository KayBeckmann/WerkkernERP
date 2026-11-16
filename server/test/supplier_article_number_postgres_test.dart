@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'supplier_article_number_test.dart';
import 'support/module_harness.dart';

void main() => runOnPostgres('Postgres-Lieferantenartikelnummer', runSupplierArticleNumberTests);
