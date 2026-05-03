/// Centralised route paths — import from any screen without circular deps.
abstract final class AppRoutes {
  static const startup = '/startup';
  static const welcome = '/welcome';
  static const auth = '/auth';
  static const otp = '/otp';
  static const diwaniyaAccess = '/diwaniya-access';
  static const createDiwaniya = '/create-diwaniya';
  static const joinDiwaniya = '/join-diwaniya';
  static const joinRequestPending = '/join-request-pending';
  static const plans = '/plans';

  static const home = '/home';
  static const expenses = '/expenses';
  static const marketplace = '/marketplace';
  static const maqadi = '/maqadi';
  static const scorekeeping = '/scorekeeping';

  static const settings = '/settings';
  static const chat = '/chat';
  static const album = '/album';
  static const inviteMember = '/invite-member';
  static const diwaniyaDetails = '/diwaniya-details';
  static const managerJoinRequests = '/manager/join-requests';
  static const accountDetails = '/account-details';
  static const inquiries = '/inquiries';
  static const notifSettings = '/notification-settings';
  static const storeDetails = '/store-details';
}

class InviteMemberArgs {
  final String diwaniyaName;
  final String invitationCode;

  const InviteMemberArgs({
    required this.diwaniyaName,
    required this.invitationCode,
  });
}