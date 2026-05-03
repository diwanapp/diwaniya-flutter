/// Centralized endpoint paths for the Diwaniya backend.
///
/// All paths are relative to [ApiConfig.baseUrl] and must start with `/`.
abstract final class Endpoints {
  Endpoints._();

  // ── Auth ──
  static const String otpRequest = '/auth/otp/request';
  static const String otpVerify = '/auth/otp/verify';

  // ── Current User ──
  static const String me = '/me';
  static const String meDiwaniyas = '/me/diwaniyas';
  static const String meProfile = '/me/profile';
  static const String meJoinRequests = '/me/join-requests';

  // ── Join Requests ──
  static const String joinRequests = '/join-requests';
  static String joinRequestApprove(String id) => '/join-requests/$id/approve';
  static String joinRequestReject(String id) => '/join-requests/$id/reject';

  // ── Diwaniya Management / Join Requests ──
  static String diwaniyaJoinRequests(String id) => '/diwaniyas/$id/join-requests';
  static String diwaniyaMemberPromote(String diwaniyaId, String userId) =>
      '/diwaniyas/$diwaniyaId/members/$userId/promote';
  static String diwaniyaMemberDemote(String diwaniyaId, String userId) =>
      '/diwaniyas/$diwaniyaId/members/$userId/demote';
  static String diwaniyaLeave(String id) => '/diwaniyas/$id/leave';
  static String diwaniyaRegenerateInvite(String id) =>
      '/diwaniyas/$id/regenerate-invite';

  // ── Diwaniyas ──
  static const String diwaniyas = '/diwaniyas';
  static String diwaniya(String id) => '/diwaniyas/$id';
  static String diwaniyaInvites(String id) => '/diwaniyas/$id/invites';
  static String diwaniyaMembers(String id) => '/diwaniyas/$id/members';

  // ── Expenses / Settlements ──
  static String diwaniyaExpenses(String diwaniyaId) =>
      '/diwaniyas/$diwaniyaId/expenses';
  static String diwaniyaExpense(String diwaniyaId, String expenseId) =>
      '/diwaniyas/$diwaniyaId/expenses/$expenseId';
  static String diwaniyaSettlements(String diwaniyaId) =>
      '/diwaniyas/$diwaniyaId/settlements';
  static String diwaniyaSettlementConfirm(String diwaniyaId, String settlementId) =>
      '/diwaniyas/$diwaniyaId/settlements/$settlementId/confirm';

  // ── Polls ──
  static String polls(String diwaniyaId, {int endedLimit = 30, int recentDays = 7}) =>
      '/diwaniyas/$diwaniyaId/polls?ended_limit=$endedLimit&recent_days=$recentDays';
  static String createPoll(String diwaniyaId) => '/diwaniyas/$diwaniyaId/polls';
  static String votePoll(String diwaniyaId, String pollId) =>
      '/diwaniyas/$diwaniyaId/polls/$pollId/vote';
  static String closePoll(String diwaniyaId, String pollId) =>
      '/diwaniyas/$diwaniyaId/polls/$pollId/close';

  // ── Maqadi ──
  static String maqadiItems(String id) => '/diwaniyas/$id/maqadi/items';
  static String maqadiItemsBatch(String id) => '/diwaniyas/$id/maqadi/items/batch';
  static String maqadiItem(String diwaniyaId, String itemId) =>
      '/diwaniyas/$diwaniyaId/maqadi/items/$itemId';
  static String maqadiCategories(String id) => '/diwaniyas/$id/maqadi/categories';
  static String maqadiCategory(String diwaniyaId, String name) =>
      '/diwaniyas/$diwaniyaId/maqadi/categories/${Uri.encodeComponent(name)}';

  // ── Album ──
  static String albumFolders(String id) => '/diwaniyas/$id/album/folders';
  static String albumFolder(String diwaniyaId, String folderId) =>
      '/diwaniyas/$diwaniyaId/album/folders/$folderId';
  static String albumPhotos(String id) => '/diwaniyas/$id/album/photos';
  static String albumPhoto(String diwaniyaId, String photoId) =>
      '/diwaniyas/$diwaniyaId/album/photos/$photoId';
  static String albumPhotoFile(String diwaniyaId, String photoId) =>
      '/diwaniyas/$diwaniyaId/album/photos/$photoId/file';

  // ── Invites ──
  static String inviteAccept(String code) => '/invites/$code/accept';
}
