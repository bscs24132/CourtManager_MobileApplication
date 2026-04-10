// lib/screens/judges_list_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/models.dart';
import 'cases_list_screen.dart';

class JudgesListScreen extends StatefulWidget {
  final String lawyerId;

  const JudgesListScreen({Key? key, required this.lawyerId}) : super(key: key);

  @override
  State<JudgesListScreen> createState() => _JudgesListScreenState();
}

class _JudgesListScreenState extends State<JudgesListScreen> {
  final List<Judge> _judges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJudges();
  }

  Future<void> _loadJudges() async {
    try {
      final database = FirebaseDatabase.instance.ref();
      final snapshot = await database.child('judges').get();

      if (snapshot.exists) {
        final judgesMap = snapshot.value as Map<dynamic, dynamic>;
        final judges = judgesMap.entries
            .map((e) => Judge.fromMap(e.value as Map<dynamic, dynamic>, e.key))
            .toList();

        setState(() {
          _judges.clear();
          _judges.addAll(judges);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading judges: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Judge'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _judges.isEmpty
          ? const Center(
        child: Text(
          'No judges available',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _judges.length,
        itemBuilder: (context, index) {
          final judge = _judges[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              leading: CircleAvatar(
                backgroundColor: Colors.blueGrey[900],
                child: const Icon(
                  Icons.account_balance,
                  color: Colors.white,
                ),
              ),
              title: Text(
                judge.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Text(
                'Court Room: ${judge.courtRoom}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CasesListScreen(
                      judgeId: judge.judgeId,
                      judgeName: judge.name,
                      lawyerId: widget.lawyerId,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}