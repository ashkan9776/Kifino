import 'package:equatable/equatable.dart';

enum NotificationType {
  installmentDue('installmentDue', 'سررسید قسط'),
  checkDue('checkDue', 'موعد چک'),
  debtDue('debtDue', 'سررسید بدهی / طلب'),
  budgetAlert('budgetAlert', 'هشدار بودجه'),
  lowStock('lowStock', 'کسری موجودی کالا');

  final String code;
  final String titleFa;
  const NotificationType(this.code, this.titleFa);

  static NotificationType fromCode(String code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return NotificationType.budgetAlert;
  }
}

class AppNotificationEntity extends Equatable {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String? referenceId;
  final DateTime scheduledFor;
  final bool isRead;
  final DateTime createdAt;

  const AppNotificationEntity({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.referenceId,
    required this.scheduledFor,
    this.isRead = false,
    required this.createdAt,
  });

  AppNotificationEntity copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    String? referenceId,
    DateTime? scheduledFor,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotificationEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      referenceId: referenceId ?? this.referenceId,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        body,
        type,
        referenceId,
        scheduledFor,
        isRead,
        createdAt,
      ];
}
