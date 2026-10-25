@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'mail_test.dart';
import 'support/module_harness.dart';

void main() => runOnPostgres('Postgres-Mailtests', runMailTests);
