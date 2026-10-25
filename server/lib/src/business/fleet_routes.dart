import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../auth.dart';
import '../util/responses.dart';
import 'fleet.dart';
import 'repository.dart';
import 'request_util.dart';

/// Fuhrpark — `fleet.read`/`fleet.write`, Modul `fleet` (über den
/// Rechte-Katalog erzwungen).
class FleetRoutes {
  FleetRoutes({required this.business, required this.auth});

  final BusinessRepository business;
  final SessionAuthenticator auth;
  static const _uuid = Uuid();

  void mount(Router router) {
    router.get('/vehicles', _listVehicles);
    router.post('/vehicles', _createVehicle);
    router.get('/vehicles/<id>', _getVehicle);
    router.put('/vehicles/<id>', _updateVehicle);
    router.get('/vehicle-costs', _listCosts);
    router.post('/vehicle-costs', _createCost);
    router.delete('/vehicle-costs/<id>', _deleteCost);
  }

  Vehicle? _vehicleFromBody(Map<String, Object?> body, {required String id, required String companyId, required DateTime createdAt, required bool defaultActive}) {
    final name = trimmedOrNull(body['name']);
    if (name == null) return null;
    final inspection = body['nextInspectionDate'];
    final parsedInspection = dateOrNull(inspection);
    if (inspection != null && parsedInspection == null) throw const FormatException('nextInspectionDate: JJJJ-MM-TT');
    return Vehicle(
      id: id,
      companyId: companyId,
      name: name,
      licensePlate: trimmedOrNull(body['licensePlate']),
      notes: trimmedOrNull(body['notes']),
      nextInspectionDate: parsedInspection,
      active: body['active'] as bool? ?? defaultActive,
      createdAt: createdAt,
    );
  }

  Future<Response> _listVehicles(Request request) async {
    final check = await auth.requirePermission(request, 'fleet.read');
    if (check.error != null) return check.error!;
    final vehicles = await business.listVehicles(
      check.auth!.session.companyId,
      includeInactive: request.url.queryParameters['includeInactive'] == 'true',
    );
    return jsonOk({'vehicles': [for (final v in vehicles) v.toJson()]});
  }

  Future<Response> _getVehicle(Request request, String id) async {
    final check = await auth.requirePermission(request, 'fleet.read');
    if (check.error != null) return check.error!;
    final vehicle = await business.findVehicle(check.auth!.session.companyId, id);
    if (vehicle == null) return jsonError('Fahrzeug nicht gefunden.', status: 404);
    return jsonOk(vehicle.toJson());
  }

  Future<Response> _createVehicle(Request request) async {
    final check = await auth.requirePermission(request, 'fleet.write');
    if (check.error != null) return check.error!;
    final vehicle = _vehicleFromBody(
      await readJsonBody(request),
      id: _uuid.v4(),
      companyId: check.auth!.session.companyId,
      createdAt: DateTime.now().toUtc(),
      defaultActive: true,
    );
    if (vehicle == null) return jsonError('name ist Pflicht.');
    await business.createVehicle(vehicle);
    await auth.audit(check.auth!, 'vehicle.create', 'vehicle', vehicle.id);
    return jsonOk(vehicle.toJson(), status: 201);
  }

  /// Deaktivieren statt löschen — Kostenbuchungen bleiben erhalten.
  Future<Response> _updateVehicle(Request request, String id) async {
    final check = await auth.requirePermission(request, 'fleet.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final existing = await business.findVehicle(companyId, id);
    if (existing == null) return jsonError('Fahrzeug nicht gefunden.', status: 404);
    final vehicle = _vehicleFromBody(
      await readJsonBody(request),
      id: id,
      companyId: companyId,
      createdAt: existing.createdAt,
      defaultActive: existing.active,
    );
    if (vehicle == null) return jsonError('name ist Pflicht.');
    await business.updateVehicle(vehicle);
    await auth.audit(check.auth!, 'vehicle.update', 'vehicle', id);
    return jsonOk(vehicle.toJson());
  }

  /// Buchungen + Summen je Kategorie (und Tilgung/Zins) für Filter
  /// `vehicleId`, `from`, `to` (JJJJ-MM-TT).
  Future<Response> _listCosts(Request request) async {
    final check = await auth.requirePermission(request, 'fleet.read');
    if (check.error != null) return check.error!;
    final params = request.url.queryParameters;
    final costs = await business.listVehicleCosts(
      check.auth!.session.companyId,
      vehicleId: trimmedOrNull(params['vehicleId']),
      from: dateOrNull(params['from']),
      to: dateOrNull(params['to']),
    );
    final byCategory = <String, int>{for (final c in vehicleCostCategories) c: 0};
    var principal = 0;
    var interest = 0;
    for (final c in costs) {
      byCategory[c.category] = byCategory[c.category]! + c.amountCents;
      principal += c.principalAmountCents ?? 0;
      interest += c.interestAmountCents ?? 0;
    }
    return jsonOk({
      'costs': [for (final c in costs) c.toJson()],
      'totals': {
        'totalCents': byCategory.values.fold<int>(0, (a, b) => a + b),
        'byCategory': byCategory,
        'principalCents': principal,
        'interestCents': interest,
      },
    });
  }

  Future<Response> _createCost(Request request) async {
    final check = await auth.requirePermission(request, 'fleet.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final body = await readJsonBody(request);
    final vehicleId = trimmedOrNull(body['vehicleId']);
    final date = dateOrNull(body['date']);
    final amount = body['amountCents'];
    final category = body['category'];
    final principal = body['principalAmountCents'];
    final interest = body['interestAmountCents'];
    if (vehicleId == null || date == null || amount is! int || amount < 0 || !vehicleCostCategories.contains(category)) {
      return jsonError('vehicleId, date (JJJJ-MM-TT), amountCents (>= 0) und category '
          '(${vehicleCostCategories.join('/')}) sind Pflicht.');
    }
    if ((principal != null && (principal is! int || principal < 0)) || (interest != null && (interest is! int || interest < 0))) {
      return jsonError('principalAmountCents/interestAmountCents müssen Ganzzahlen >= 0 sein.');
    }
    if (((principal as int?) ?? 0) + ((interest as int?) ?? 0) > amount) {
      return jsonError('Tilgung + Zins dürfen den Gesamtbetrag nicht übersteigen.');
    }
    if (await business.findVehicle(companyId, vehicleId) == null) return jsonError('Fahrzeug nicht gefunden.', status: 404);
    final projectId = trimmedOrNull(body['projectId']);
    if (projectId != null && await business.findProject(companyId, projectId) == null) {
      return jsonError('Projekt nicht gefunden.', status: 404);
    }
    final entry = VehicleCostEntry(
      id: _uuid.v4(),
      companyId: companyId,
      vehicleId: vehicleId,
      date: date,
      amountCents: amount,
      category: category as String,
      description: trimmedOrNull(body['description']),
      principalAmountCents: principal,
      interestAmountCents: interest,
      projectId: projectId,
      createdByUserId: check.auth!.session.userId,
      createdAt: DateTime.now().toUtc(),
    );
    await business.createVehicleCost(entry);
    await auth.audit(check.auth!, 'vehicleCost.create', 'vehicleCost', entry.id);
    return jsonOk(entry.toJson(), status: 201);
  }

  Future<Response> _deleteCost(Request request, String id) async {
    final check = await auth.requirePermission(request, 'fleet.write');
    if (check.error != null) return check.error!;
    if (!await business.deleteVehicleCost(check.auth!.session.companyId, id)) {
      return jsonError('Kostenbuchung nicht gefunden.', status: 404);
    }
    await auth.audit(check.auth!, 'vehicleCost.delete', 'vehicleCost', id);
    return Response(204);
  }
}
