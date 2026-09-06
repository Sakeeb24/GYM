// authz.dart — R10 role authorization. The Flutter client never authorizes
// sensitive ops; edge functions call [roleCan]. Mirrored here for UI
// affordance decisions only.
import 'membership_status.dart';

/// Whether a role may perform an action (owner has all front_desk permissions).
bool roleCan(AppRole role, Capability cap) {
  return switch (cap) {
    Capability.selfCheckIn => role == AppRole.member || role == AppRole.owner,
    Capability.assistedCheckIn => role == AppRole.frontDesk || role == AppRole.owner,
    Capability.createMember => role == AppRole.frontDesk || role == AppRole.owner,
    Capability.editMember => role == AppRole.frontDesk || role == AppRole.owner,
    Capability.manageRedList => role == AppRole.frontDesk || role == AppRole.owner,
    Capability.managePlans => role == AppRole.owner,
    Capability.manageStaff => role == AppRole.owner,
    Capability.manageSettings => role == AppRole.owner,
    Capability.managePayments => role == AppRole.owner,
    Capability.viewReports => role == AppRole.owner || role == AppRole.frontDesk,
    Capability.viewTrainerArea => true, // any authenticated role may view (trainer-specific screens guard further)
  };
}

enum Capability {
  selfCheckIn,
  assistedCheckIn,
  createMember,
  editMember,
  manageRedList,
  managePlans,
  manageStaff,
  manageSettings,
  managePayments,
  viewReports,
  viewTrainerArea,
}
