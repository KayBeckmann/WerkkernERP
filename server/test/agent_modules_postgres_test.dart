@Tags(['postgres'])
library;

import 'package:test/test.dart';

import 'agent_modules_test.dart';
import 'support/module_harness.dart';

void main() => runOnPostgres('Postgres-Agent-Modultests', runAgentModuleTests);
