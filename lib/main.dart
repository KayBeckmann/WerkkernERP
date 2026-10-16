import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/backup/backup_service.dart';
import 'data/database/database.dart';
import 'data/repositories/article_group_repository.dart';
import 'data/repositories/article_repository.dart';
import 'data/repositories/company_repository.dart';
import 'data/repositories/customer_repository.dart';
import 'data/repositories/invoice_repository.dart';
import 'data/repositories/number_sequence_repository.dart';
import 'data/repositories/supplier_repository.dart';
import 'domain/services/active_company_service.dart';
import 'ui/screens/company_switcher_screen.dart';
import 'ui/theme/app_theme.dart';

void main() {
  runApp(const WerkkernErpApp());
}

class WerkkernErpApp extends StatelessWidget {
  /// [database] erlaubt Widget-Tests, eine In-Memory-Datenbank statt der
  /// echten, dateibasierten Verbindung einzusetzen (die über
  /// `path_provider` läuft, das in Tests ohne echte Plattform nicht
  /// verfügbar ist).
  const WerkkernErpApp({super.key, this.database});

  final AppDatabase? database;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>(
          create: (_) => database ?? AppDatabase(),
          dispose: (_, db) => db.close(),
        ),
        Provider<CompanyRepository>(
          create: (context) => CompanyRepository(context.read<AppDatabase>()),
        ),
        Provider<CustomerRepository>(
          create: (context) => CustomerRepository(context.read<AppDatabase>()),
        ),
        Provider<SupplierRepository>(
          create: (context) => SupplierRepository(context.read<AppDatabase>()),
        ),
        Provider<ArticleGroupRepository>(
          create: (context) => ArticleGroupRepository(context.read<AppDatabase>()),
        ),
        Provider<ArticleRepository>(
          create: (context) => ArticleRepository(context.read<AppDatabase>()),
        ),
        Provider<NumberSequenceRepository>(
          create: (context) => NumberSequenceRepository(context.read<AppDatabase>()),
        ),
        Provider<InvoiceRepository>(
          create: (context) =>
              InvoiceRepository(context.read<AppDatabase>(), context.read<NumberSequenceRepository>()),
        ),
        Provider<BackupService>(
          create: (context) => BackupService(context.read<AppDatabase>()),
        ),
        ChangeNotifierProvider<ActiveCompanyService>(
          create: (context) => ActiveCompanyService(context.read<CompanyRepository>()),
        ),
      ],
      child: MaterialApp(
        title: 'WerkkernERP',
        theme: buildAppTheme(brightness: Brightness.light),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        themeMode: ThemeMode.system,
        home: const CompanySwitcherScreen(),
      ),
    );
  }
}
