// lib/screens/lawyer_cases_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class LawyerCasesScreen extends StatefulWidget {
  final String lawyerId;

  const LawyerCasesScreen({Key? key, required this.lawyerId}) : super(key: key);

  @override
  State<LawyerCasesScreen> createState() => _LawyerCasesScreenState();
}

class _LawyerCasesScreenState extends State<LawyerCasesScreen> {
  final List<CourtCase> _cases = [];
  final Map<String, String> _judgeNames = {};
  bool _isLoading = true;
  DatabaseReference? _casesRef;

  @override
  void initState() {
    super.initState();
    _loadJudges();
    _setupCasesListener();
  }

  Future<void> _loadJudges() async {
    try {
      final database = FirebaseDatabase.instance.ref();
      final judgesSnapshot = await database.child('judges').get();
      if (judgesSnapshot.exists) {
        final judgesMap = judgesSnapshot.value as Map<dynamic, dynamic>;
        judgesMap.forEach((key, value) {
          _judgeNames[key] = value['name'] ?? 'Unknown Judge';
        });
      }
    } catch (e) {
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

  void _setupCasesListener() {
    final database = FirebaseDatabase.instance.ref();
    _casesRef = database.child('cases');

    _casesRef!.onValue.listen((event) {
      if (event.snapshot.exists) {
        final casesMap = event.snapshot.value as Map<dynamic, dynamic>;
        final cases = casesMap.entries
            .map((e) => CourtCase.fromMap(e.value as Map<dynamic, dynamic>, e.key))
            .where((c) => c.lawyerId == widget.lawyerId)
            .toList();

        // Sort by orderIndex
        cases.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

        if (mounted) {
          setState(() {
            _cases.clear();
            _cases.addAll(cases);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _cases.clear();
            _isLoading = false;
          });
        }
      }
    });
  }

  // Calculate display position (only for undone cases)
  String _getDisplayPosition(int index) {
    final courtCase = _cases[index];
    if (courtCase.done) {
      return '✓'; // Checkmark for done cases
    }

    // Count how many undone cases come before this one
    int position = 1;
    for (int i = 0; i < index; i++) {
      if (!_cases[i].done) {
        position++;
      }
    }
    return '$position';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cases'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cases.isEmpty
          ? const Center(
        child: Text(
          'No cases assigned',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _cases.length,
        itemBuilder: (context, index) {
          final courtCase = _cases[index];
          final judgeName = _judgeNames[courtCase.judgeId] ?? 'Unknown Judge';
          final displayPosition = _getDisplayPosition(index);

          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            elevation: courtCase.done ? 1 : 2,
            color: courtCase.done ? Colors.grey[100] : null,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: courtCase.done
                    ? Colors.grey[400]
                    : Colors.green[700],
                child: Text(
                  displayPosition,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      courtCase.caseTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: courtCase.done ? Colors.grey[600] : null,
                        decoration: courtCase.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  if (courtCase.done)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'DONE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                courtCase.caseType.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: courtCase.done
                      ? Colors.grey[500]
                      : (courtCase.caseType == 'supplementary'
                      ? Colors.purple[700]
                      : Colors.blueGrey[900]),
                ),
              ),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Case ID: ${courtCase.caseId}',
                      style: TextStyle(
                        fontSize: 12,
                        color: courtCase.done ? Colors.grey[600] : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Judge: $judgeName',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: courtCase.done ? Colors.grey[600] : Colors.blueGrey[900],
                      ),
                    ),
                    if (!courtCase.done)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Position: #${courtCase.orderIndex + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _casesRef?.onValue.drain();
    super.dispose();
  }
}