part of '../repository_memory.dart';

mixin _InMemoryFleet implements FleetStore {
  final List<Vehicle> _vehicles = [];
  final List<VehicleCostEntry> _vehicleCosts = [];

  @override
  Future<List<Vehicle>> listVehicles(String companyId, {bool includeInactive = false}) async =>
      _vehicles.where((v) => v.companyId == companyId && (includeInactive || v.active)).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Future<Vehicle?> findVehicle(String companyId, String id) async =>
      _vehicles.where((v) => v.companyId == companyId && v.id == id).firstOrNull;

  @override
  Future<void> createVehicle(Vehicle vehicle) async => _vehicles.add(vehicle);

  @override
  Future<bool> updateVehicle(Vehicle vehicle) async {
    final index = _vehicles.indexWhere((v) => v.companyId == vehicle.companyId && v.id == vehicle.id);
    if (index == -1) return false;
    _vehicles[index] = vehicle;
    return true;
  }

  @override
  Future<List<VehicleCostEntry>> listVehicleCosts(String companyId, {String? vehicleId, DateTime? from, DateTime? to}) async =>
      _vehicleCosts
          .where((c) =>
              c.companyId == companyId &&
              (vehicleId == null || c.vehicleId == vehicleId) &&
              (from == null || !c.date.isBefore(from)) &&
              (to == null || !c.date.isAfter(to)))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<void> createVehicleCost(VehicleCostEntry entry) async => _vehicleCosts.add(entry);

  @override
  Future<bool> deleteVehicleCost(String companyId, String id) async {
    final before = _vehicleCosts.length;
    _vehicleCosts.removeWhere((c) => c.companyId == companyId && c.id == id);
    return _vehicleCosts.length != before;
  }
}
