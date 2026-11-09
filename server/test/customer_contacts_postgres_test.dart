@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'customer_contacts_test.dart';
import 'support/module_harness.dart';

void main() => runOnPostgres('Postgres-Kontaktpersonen', runCustomerContactTests);
