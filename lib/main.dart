import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/backup/backup_service.dart';
import 'data/database/database.dart';
import 'data/repositories/article_group_repository.dart';
import 'data/repositories/article_repository.dart';
import 'data/repositories/bank_transaction_repository.dart';
import 'data/repositories/company_repository.dart';
import 'data/repositories/customer_repository.dart';
import 'data/repositories/expense_category_repository.dart';
import 'data/repositories/expense_repository.dart';
import 'data/repositories/invoice_repository.dart';
import 'data/repositories/number_sequence_repository.dart';
import 'data/repositories/project_repository.dart';
import 'data/repositories/purchase_order_repository.dart';
import 'data/repositories/recurring_invoice_template_repository.dart';
import 'data/repositories/supplier_repository.dart';
import 'data/repositories/vehicle_repository.dart';
import 'domain/services/active_company_service.dart';
import 'domain/services/database_encryption_io.dart' show resolveDatabaseFilePath;
import 'domain/services/database_encryption_service.dart';
import 'domain/services/smtp_credential_store.dart';
import 'domain/services/theme_preference_service.dart';
import 'ui/screens/company_switcher_screen.dart';
import 'ui/screens/database_unlock_screen.dart';
import 'ui/theme/app_theme.dart';

/// Startreihenfolge wegen F4 (Kay-Entscheidung 2026-10-19: optionale
/// Verschlüsselung, Geräteschlüssel ODER Passwort): bevor die
/// eigentliche App (und damit `AppDatabase()`) entsteht, muss der
/// Schlüssel feststehen — bei einem Geräteschlüssel geht das lautlos,
/// bei einem Passwort erst nach einer Eingabe. Deshalb `main()` async
/// und zwei mögliche `runApp()`-Aufrufe (Flutter erlaubt das
/// ausdrücklich, um die Wurzel auszutauschen) statt alles synchron in
/// `WerkkernErpApp.build()` zu versuchen — der `Provider<AppDatabase>`-
/// `create`-Callback dort ist synchron und kann nicht auf eine
/// Passwort-Eingabe warten.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web bleibt bewusst ohne F4 (siehe Doc-Kommentar in
  // `database_encryption_io_web.dart`) — direkt normal starten.
  if (kIsWeb) {
    runApp(const WerkkernErpApp());
    return;
  }

  final encryptionService = DatabaseEncryptionService();
  final config = await encryptionService.loadConfig();

  if (!config.enabled || config.keyType == DbKeyType.device) {
    final key = await encryptionService.resolveKey(config: config);
    runApp(WerkkernErpApp(databaseEncryptionKey: key));
    return;
  }

  // Passwortgeschützt -> erst entsperren, dann die eigentliche App
  // starten (zweiter runApp()-Aufruf tauscht die Wurzel aus).
  final dbPath = await resolveDatabaseFilePath();
  runApp(
    DatabaseUnlockScreen(
      encryptionService: encryptionService,
      dbPath: dbPath,
      onUnlocked: (password) => runApp(WerkkernErpApp(databaseEncryptionKey: password)),
    ),
  );
}

class WerkkernErpApp extends StatelessWidget {
  /// [database] erlaubt Widget-Tests, eine In-Memory-Datenbank statt der
  /// echten, dateibasierten Verbindung einzusetzen (die über
  /// `path_provider` läuft, das in Tests ohne echte Plattform nicht
  /// verfügbar ist).
  const WerkkernErpApp({
    super.key,
    this.database,
    this.databaseEncryptionKey,
    this.databaseEncryptionService,
  });

  final AppDatabase? database;

  /// Siehe Doc-Kommentar bei `main()` — wird ignoriert, wenn [database]
  /// gesetzt ist (Tests).
  final String? databaseEncryptionKey;

  /// Erlaubt Widget-Tests, eine In-Memory-Variante statt der echten
  /// `SecureDbEncryptionSettingsStore` einzusetzen (deren
  /// `shared_preferences`/`flutter_secure_storage`-Plattform-Kanäle in
  /// `flutter test` ohne Mock nicht verfügbar sind).
  final DatabaseEncryptionService? databaseEncryptionService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseEncryptionService>(
          create: (_) => databaseEncryptionService ?? DatabaseEncryptionService(),
        ),
        Provider<ActiveDbKey>.value(
          value: ActiveDbKey(database != null ? null : databaseEncryptionKey),
        ),
        Provider<AppDatabase>(
          create: (_) => database ?? AppDatabase(encryptionKey: databaseEncryptionKey),
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
        Provider<ProjectRepository>(
          create: (context) => ProjectRepository(context.read<AppDatabase>()),
        ),
        Provider<VehicleRepository>(
          create: (context) => VehicleRepository(context.read<AppDatabase>()),
        ),
        Provider<PurchaseOrderRepository>(
          create: (context) => PurchaseOrderRepository(
            context.read<AppDatabase>(),
            context.read<NumberSequenceRepository>(),
          ),
        ),
        Provider<RecurringInvoiceTemplateRepository>(
          create: (context) => RecurringInvoiceTemplateRepository(
            context.read<AppDatabase>(),
            context.read<InvoiceRepository>(),
          ),
        ),
        Provider<SmtpCredentialStore>(
          create: (_) => SecureSmtpCredentialStore(),
        ),
        Provider<ExpenseCategoryRepository>(
          create: (context) => ExpenseCategoryRepository(context.read<AppDatabase>()),
        ),
        Provider<ExpenseRepository>(
          create: (context) => ExpenseRepository(context.read<AppDatabase>()),
        ),
        Provider<BankTransactionRepository>(
          create: (context) => BankTransactionRepository(context.read<AppDatabase>()),
        ),
        ChangeNotifierProvider<ActiveCompanyService>(
          create: (context) => ActiveCompanyService(context.read<CompanyRepository>()),
        ),
        ChangeNotifierProvider<ThemePreferenceService>(
          create: (_) => ThemePreferenceService()..load(),
        ),
      ],
      child: Consumer<ThemePreferenceService>(
        builder: (context, themePreference, _) => MaterialApp(
          title: 'WerkkernERP',
          theme: buildAppTheme(brightness: Brightness.light),
          darkTheme: buildAppTheme(brightness: Brightness.dark),
          themeMode: themePreference.mode,
          home: const CompanySwitcherScreen(),
        ),
      ),
    );
  }
}
