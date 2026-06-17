// packages/shared/lib/data/models/user_model.dart
//
// Isar Schema لبيانات المستخدم
// isar_generator يولد UserModelSchema تلقائياً

import 'package:isar/isar.dart';
import 'package:shared/domain/entities/user_entity.dart';

part 'user_model.g.dart';

/// نموذج Isar للمستخدم
@Collection()
class UserModel {
  Id get isarId => Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  late String email;
  late String role;
  late String name;
  String? phone;
  double? height;
  double? weight;
  int? age;
  String? gender;
  String? profileImageUrl;
  late String subscriptionStatus;
  String? subscriptionPlan;
  DateTime? subscriptionExpiresAt;
  String? assignedCoachId;
  String? referralCode;
  String? referredBy;
  late List<String> registeredDevices;
  late int maxDevices;
  late bool isBanned;
  late String preferredLanguage;
  late String selectedTheme;
  DateTime? createdAt;
  DateTime? updatedAt;

  /// تحويل إلى Entity للاستخدام في الـ Domain
  UserEntity toEntity() => UserEntity(
        id:                   id,
        email:                email,
        role:                 role,
        name:                 name,
        phone:                phone,
        height:               height,
        weight:               weight,
        age:                  age,
        gender:               gender,
        profileImageUrl:      profileImageUrl,
        subscriptionStatus:   _parseStatus(subscriptionStatus),
        subscriptionPlan:     subscriptionPlan,
        subscriptionExpiresAt: subscriptionExpiresAt,
        assignedCoachId:      assignedCoachId,
        referralCode:         referralCode,
        referredBy:           referredBy,
        registeredDevices:    registeredDevices,
        maxDevices:           maxDevices,
        isBanned:             isBanned,
        preferredLanguage:    preferredLanguage,
        selectedTheme:        selectedTheme,
        createdAt:            createdAt,
        updatedAt:            updatedAt,
      );

  /// تحديث من بيانات GAS (Field-Level Merge)
  void fromRemote(Map<String, dynamic> data) {
    if (data['name']  != null) name  = data['name']  as String;
    if (data['phone'] != null) phone = data['phone'] as String?;
    if (data['height'] != null) height = (data['height'] as num).toDouble();
    if (data['weight'] != null) weight = (data['weight'] as num).toDouble();
    if (data['subscriptionStatus'] != null) {
      subscriptionStatus = data['subscriptionStatus'] as String;
    }
    updatedAt = DateTime.tryParse(data['updatedAt']?.toString() ?? '');
  }

  static UserModel fromEntity(UserEntity e) => UserModel()
    ..id                   = e.id
    ..email                = e.email
    ..role                 = e.role
    ..name                 = e.name
    ..phone                = e.phone
    ..height               = e.height
    ..weight               = e.weight
    ..age                  = e.age
    ..gender               = e.gender
    ..profileImageUrl      = e.profileImageUrl
    ..subscriptionStatus   = e.subscriptionStatus.name
    ..subscriptionPlan     = e.subscriptionPlan
    ..subscriptionExpiresAt = e.subscriptionExpiresAt
    ..assignedCoachId      = e.assignedCoachId
    ..referralCode         = e.referralCode
    ..referredBy           = e.referredBy
    ..registeredDevices    = e.registeredDevices
    ..maxDevices           = e.maxDevices
    ..isBanned             = e.isBanned
    ..preferredLanguage    = e.preferredLanguage
    ..selectedTheme        = e.selectedTheme
    ..createdAt            = e.createdAt
    ..updatedAt            = e.updatedAt;

  static SubscriptionStatus _parseStatus(String s) {
    return SubscriptionStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => SubscriptionStatus.pending,
    );
  }
}
