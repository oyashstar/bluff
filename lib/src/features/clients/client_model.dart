// A row of the client table and its contacts.

class Client {
  const Client({
    required this.id,
    required this.code,
    required this.name,
    this.segment,
    this.city,
    this.state,
    this.erpVersion,
    this.amcStatus,
    this.amcExpiry,
    this.onboardedOn,
    this.accountOwnerUserId,
    this.erpClientCode,
  });

  final String id;
  final String code;
  final String name;
  final String? segment;
  final String? city;
  final String? state;
  final String? erpVersion;
  final String? amcStatus;
  final DateTime? amcExpiry;
  final DateTime? onboardedOn;
  final String? accountOwnerUserId;
  final String? erpClientCode;

  factory Client.fromMap(Map<String, dynamic> m) => Client(
        id: m['id'] as String,
        code: m['code'] as String,
        name: m['name'] as String,
        segment: m['segment'] as String?,
        city: m['city'] as String?,
        state: m['state'] as String?,
        erpVersion: m['erp_version'] as String?,
        amcStatus: m['amc_status'] as String?,
        amcExpiry: _date(m['amc_expiry']),
        onboardedOn: _date(m['onboarded_on']),
        accountOwnerUserId: m['account_owner_user_id'] as String?,
        erpClientCode: m['erp_client_code'] as String?,
      );

  /// Payload for insert/update. Only user-editable columns; the DB owns id,
  /// timestamps and audit.
  Map<String, dynamic> toInsert() => {
        'code': code,
        'name': name,
        'segment': segment,
        'city': city,
        'state': state,
        'erp_version': erpVersion,
        'amc_status': amcStatus,
        'amc_expiry': amcExpiry?.toIso8601String(),
        'onboarded_on': onboardedOn?.toIso8601String(),
        'account_owner_user_id': accountOwnerUserId,
        'erp_client_code': erpClientCode,
      };
}

class ClientContact {
  const ClientContact({
    required this.id,
    required this.clientId,
    required this.name,
    this.role,
    this.phone,
    this.email,
    this.isPrimary = false,
    this.isChampion = false,
  });

  final String id;
  final String clientId;
  final String name;
  final String? role;
  final String? phone;
  final String? email;
  final bool isPrimary;
  final bool isChampion;

  factory ClientContact.fromMap(Map<String, dynamic> m) => ClientContact(
        id: m['id'] as String,
        clientId: m['client_id'] as String,
        name: m['name'] as String,
        role: m['role'] as String?,
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        isPrimary: (m['is_primary'] as bool?) ?? false,
        isChampion: (m['is_champion'] as bool?) ?? false,
      );
}

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v.toString());
