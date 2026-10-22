import 'package:test/test.dart';
import 'package:werkkernerp_server/src/models.dart';
import 'package:werkkernerp_server/src/permission_resolver.dart';

void main() {
  const company = Company(id: 'c1', name: 'Firma A', enabledModules: {'projects'});
  const activeMembership = Membership(
    id: 'm1',
    userId: 'u1',
    companyId: 'c1',
    groupId: 'g1',
    isAdmin: false,
    active: true,
  );

  bool check({
    Membership? membership,
    Company company = company,
    List<GroupPermission> groupPermissions = const [],
    List<MembershipPermissionOverride> overrides = const [],
    String? requiredModule,
  }) =>
      PermissionResolver.hasPermission(
        membership: membership,
        company: company,
        permission: 'projects.read',
        groupPermissions: groupPermissions,
        overrides: overrides,
        requiredModule: requiredModule,
      );

  test('Fehlende Mitgliedschaft (null) ist immer verweigert, egal was sonst gilt', () {
    expect(
      check(
        membership: null,
        groupPermissions: const [GroupPermission(groupId: 'g1', permission: 'projects.read')],
      ),
      isFalse,
    );
  });

  test('Inaktive Mitgliedschaft ist verweigert, auch mit Gruppenrecht und Override=true', () {
    const inactive = Membership(
      id: 'm1',
      userId: 'u1',
      companyId: 'c1',
      groupId: 'g1',
      isAdmin: false,
      active: false,
    );
    expect(
      check(
        membership: inactive,
        groupPermissions: const [GroupPermission(groupId: 'g1', permission: 'projects.read')],
        overrides: const [MembershipPermissionOverride(membershipId: 'm1', permission: 'projects.read', allowed: true)],
      ),
      isFalse,
    );
  });

  test('Deaktivierte Firmenfunktion verweigert, auch mit Gruppenrecht und Override=true', () {
    const companyWithoutProjects = Company(id: 'c1', name: 'Firma A', enabledModules: {});
    expect(
      check(
        membership: activeMembership,
        company: companyWithoutProjects,
        requiredModule: 'projects',
        groupPermissions: const [GroupPermission(groupId: 'g1', permission: 'projects.read')],
        overrides: const [MembershipPermissionOverride(membershipId: 'm1', permission: 'projects.read', allowed: true)],
      ),
      isFalse,
    );
  });

  test('Ohne Gruppenrecht und ohne Override: verweigert (sichere Voreinstellung)', () {
    expect(check(membership: activeMembership), isFalse);
  });

  test('Gruppenrecht ohne Override: gewährt', () {
    expect(
      check(
        membership: activeMembership,
        groupPermissions: const [GroupPermission(groupId: 'g1', permission: 'projects.read')],
      ),
      isTrue,
    );
  });

  test('Override=false übersteuert ein vorhandenes Gruppenrecht (individuelles Sperren)', () {
    expect(
      check(
        membership: activeMembership,
        groupPermissions: const [GroupPermission(groupId: 'g1', permission: 'projects.read')],
        overrides: const [MembershipPermissionOverride(membershipId: 'm1', permission: 'projects.read', allowed: false)],
      ),
      isFalse,
    );
  });

  test('Override=true gewährt trotz fehlendem Gruppenrecht (individuelles Erlauben)', () {
    expect(
      check(
        membership: activeMembership,
        overrides: const [MembershipPermissionOverride(membershipId: 'm1', permission: 'projects.read', allowed: true)],
      ),
      isTrue,
    );
  });

  test('Ein Override einer ANDEREN Mitgliedschaft wirkt sich nicht aus', () {
    expect(
      check(
        membership: activeMembership,
        overrides: const [MembershipPermissionOverride(membershipId: 'ANDERE-MEMBERSHIP', permission: 'projects.read', allowed: true)],
      ),
      isFalse,
    );
  });

  test('requiredModule == null prüft keine Firmenfunktion (z. B. für modul-unabhängige Rechte)', () {
    const companyWithoutProjects = Company(id: 'c1', name: 'Firma A', enabledModules: {});
    expect(
      check(
        membership: activeMembership,
        company: companyWithoutProjects,
        groupPermissions: const [GroupPermission(groupId: 'g1', permission: 'projects.read')],
      ),
      isTrue,
    );
  });
}
