class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final bool isHost;
  final bool isAdmin;
  final bool phoneVerified;
  final bool emailVerified;
  final String verificationStatus;
  final String? avatarUrl;

  /// True after an admin issued a temporary password: the app must make the
  /// user choose their own before doing anything else.
  final bool mustChangePassword;

  /// Where a host's earnings are sent. Null until they set it up - a host with
  /// no payout account cannot be paid, so the host app surfaces that state.
  final String? payoutBankName;
  final String? payoutAccountNumber;
  final String? payoutAccountName;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.isHost,
    required this.isAdmin,
    required this.phoneVerified,
    required this.emailVerified,
    required this.verificationStatus,
    required this.avatarUrl,
    this.mustChangePassword = false,
    this.payoutBankName,
    this.payoutAccountNumber,
    this.payoutAccountName,
  });

  /// True once there is enough on file to actually send money.
  bool get hasPayoutAccount =>
      (payoutBankName?.isNotEmpty ?? false) && (payoutAccountNumber?.isNotEmpty ?? false);

  /// Shows only the last four digits, the way banks display an account on a
  /// statement - enough to recognise, not enough to read out over someone's
  /// shoulder.
  String get maskedAccountNumber {
    final number = payoutAccountNumber ?? '';
    if (number.length <= 4) return number;
    return '${'•' * (number.length - 4)}${number.substring(number.length - 4)}';
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'],
        fullName: json['full_name'],
        email: json['email'],
        phoneNumber: json['phone_number'],
        isHost: json['is_host'] ?? false,
        isAdmin: json['is_admin'] ?? false,
        phoneVerified: json['phone_verified'] ?? false,
        emailVerified: json['email_verified'] ?? false,
        verificationStatus: json['verification_status'] ?? 'unverified',
        avatarUrl: json['avatar_url'],
        mustChangePassword: json['must_change_password'] ?? false,
        payoutBankName: json['payout_bank_name'],
        payoutAccountNumber: json['payout_account_number'],
        payoutAccountName: json['payout_account_name'],
      );
}
