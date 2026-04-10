// lib/screens/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  String? _currentUserId;
  StreamSubscription<DatabaseEvent>? _notificationSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserIdAndListen();
  }

  @override
  void dispose() {
    // Cancel the subscription when the screen is disposed
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserIdAndListen() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('id');

    if (userId == null || userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user logged in. Please login again.')),
        );
      }
      return;
    }

    setState(() {
      _currentUserId = userId;
    });

    final notifRef = FirebaseDatabase.instance.ref().child('notifications').child(userId);

    // Cancel any existing subscription before creating a new one
    await _notificationSubscription?.cancel();

    _notificationSubscription = notifRef.onValue.listen((DatabaseEvent event) {
      final List<Map<String, dynamic>> loaded = [];

      // Handle no data
      if (!event.snapshot.exists || event.snapshot.value == null) {
        if (mounted) {
          setState(() {
            _notifications = [];
            _isLoading = false;
          });
        }
        return;
      }

      // Firebase returns Map<Object?, Object?>
      final data = event.snapshot.value as Map<Object?, Object?>;

      data.forEach((key, value) {
        // Skip invalid entries
        if (key == null || value == null || value is! Map<Object?, Object?>) {
          return;
        }

        final map = value as Map<Object?, Object?>;

        loaded.add({
          'key': key.toString(),
          'title': (map['title'] ?? 'Case Update').toString(),
          'message': (map['message'] ?? '').toString(),
          'timestamp': (map['timestamp'] ?? '').toString(),
        });
      });

      // Sort newest first
      loaded.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

      if (mounted) {
        setState(() {
          _notifications = loaded;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notifications: $error')),
        );
      }
    });
  }

  String _formatTimestamp(String isoString) {
    if (isoString.isEmpty) return 'Just now';
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('MMM dd, yyyy – HH:mm').format(date);
    } catch (e) {
      return isoString;
    }
  }

  Future<void> _deleteNotification(String key) async {
    if (_currentUserId == null) return;

    await FirebaseDatabase.instance
        .ref()
        .child('notifications')
        .child(_currentUserId!)
        .child(key)
        .remove();
    // UI updates automatically via listener
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No notifications yet\n\nThey will appear here automatically when your case position changes in the queue.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notif = _notifications[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ListTile(
              title: Text(
                notif['title'],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notif['message']),
                    const SizedBox(height: 8),
                    Text(
                      _formatTimestamp(notif['timestamp']),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteNotification(notif['key']),
              ),
            ),
          );
        },
      ),
    );
  }
}