import 'package:flutter/foundation.dart';

import '../../data/database/database.dart';
import '../../data/repositories/company_repository.dart';

/// Hält die aktuell gewählte Firma für die Session. Jeder Screen liest
/// ausschließlich über diesen companyId-Kontext — kein globaler,
/// firmenübergreifender Zugriffspfad (Roadmap A0).
class ActiveCompanyService extends ChangeNotifier {
  ActiveCompanyService(this._companyRepository);

  final CompanyRepository _companyRepository;

  List<Company> _companies = const [];
  Company? _active;

  List<Company> get companies => _companies;
  Company? get active => _active;

  Future<void> loadCompanies() async {
    _companies = await _companyRepository.listAll();
    if (_active != null && !_companies.any((c) => c.id == _active!.id)) {
      _active = null;
    }
    notifyListeners();
  }

  void select(Company company) {
    _active = company;
    notifyListeners();
  }

  Future<Company> createCompany({required String name}) async {
    final company = await _companyRepository.create(name: name);
    await loadCompanies();
    select(company);
    return company;
  }
}
