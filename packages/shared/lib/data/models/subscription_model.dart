// packages/shared/lib/data/models/subscription_model.dart

import 'package:isar/isar.dart';
import 'package:shared/domain/entities/subscription_entity.dart';

part 'subscription_model.g.dart';

@Collection()
class SubscriptionRequestModel {
  Id get isarId => Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  @Index()
  late String userId;

  late String userName;
  late String planId;
  late String requestType;
  late String paymentImageUrl;
  late String status;
  late DateTime createdAt;
  String? reviewedBy;
  DateTime? reviewedAt;
  String? rejectionReason;
  int? approvedDurationDays;
  DateTime? startDate;
  DateTime? expiresAt;

  SubscriptionRequest toEntity() => SubscriptionRequest(
        id:                  id,
        userId:              userId,
        userName:            userName,
        planId:              planId,
        requestType:         requestType,
        paymentImageUrl:     paymentImageUrl,
        status:              SubscriptionRequestStatus.values.firstWhere(
          (s) => s.name == status,
          orElse: () => SubscriptionRequestStatus.pending,
        ),
        createdAt:           createdAt,
        reviewedBy:          reviewedBy,
        reviewedAt:          reviewedAt,
        rejectionReason:     rejectionReason,
        approvedDurationDays: approvedDurationDays,
        startDate:           startDate,
        expiresAt:           expiresAt,
      );

  static SubscriptionRequestModel fromJson(Map<String, dynamic> json) =>
      SubscriptionRequestModel()
        ..id                  = json['id'] as String
        ..userId              = json['userId'] as String
        ..userName            = json['userName'] as String
        ..planId              = json['planId'] as String
        ..requestType         = json['requestType'] as String
        ..paymentImageUrl     = json['paymentImageUrl'] as String
        ..status              = json['status'] as String
        ..createdAt           = DateTime.parse(json['createdAt'] as String)
        ..reviewedBy          = json['reviewedBy'] as String?
        ..reviewedAt          = json['reviewedAt'] != null
            ? DateTime.parse(json['reviewedAt'] as String)
            : null
        ..rejectionReason     = json['rejectionReason'] as String?
        ..approvedDurationDays = json['approvedDurationDays'] as int?
        ..startDate           = json['startDate'] != null
            ? DateTime.parse(json['startDate'] as String)
            : null
        ..expiresAt           = json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'] as String)
            : null;
}
