// lib/services/notification_service.dart

import 'package:firebase_database/firebase_database.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Save a notification to Firebase under notifications/{lawyerId}
  Future<void> saveNotificationToFirebase(
      String lawyerId,
      String caseTitle,
      String message,
      ) async {
    final database = FirebaseDatabase.instance.ref();
    final notifRef = database.child('notifications/$lawyerId').push();
    await notifRef.set({
      'title': caseTitle,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}