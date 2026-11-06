import 'package:dsh_app/ui/agents/chem_team_bootstrap_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new local install loads the official Team bundle exactly once', () {
    expect(chemTeamOfficialSpec, contains('@0.2.1-rc.4'));
    expect(chemTeamBootstrapPlan(local: true, writable: true, safeMode: false,
      seen: false, installed: false, enabled: false), ChemTeamBootstrapAction.install);
    expect(chemTeamBootstrapPlan(local: true, writable: true, safeMode: false,
      seen: false, installed: true, enabled: false), ChemTeamBootstrapAction.enable);
  });
  test('user opt-out, remote hosts, safe mode and read-only never install/enable', () {
    for (final row in [(true, true, false, true), (false, true, false, false),
                       (true, false, false, false), (true, true, true, false)]) {
      expect(chemTeamBootstrapPlan(local: row.$1, writable: row.$2, safeMode: row.$3,
        seen: row.$4, installed: false, enabled: false), ChemTeamBootstrapAction.skip);
    }
  });
  test('an already enabled official bundle is recorded, not reinstalled', () {
    expect(chemTeamBootstrapPlan(local: true, writable: true, safeMode: false,
      seen: false, installed: true, enabled: true), ChemTeamBootstrapAction.remember);
  });
}
