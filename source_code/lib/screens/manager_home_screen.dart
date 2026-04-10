// lib/screens/manager_home_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import '../services/notification_service.dart';

class ManagerHomeScreen extends StatefulWidget {
  final String managerId;

  const ManagerHomeScreen({Key? key, required this.managerId}) : super(key: key);

  @override
  State<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends State<ManagerHomeScreen> {
  String? _assignedJudgeId;
  String _judgeName = '';
  final List<CourtCase> _cases = [];
  bool _isLoading = true;
  DatabaseReference? _casesRef;

  @override
  void initState() {
    super.initState();
    _loadManagerData();
  }

  Future<void> _loadManagerData() async {
    try {
      final database = FirebaseDatabase.instance.ref();

      // Get manager info
      final managerSnapshot = await database.child('managers/${widget.managerId}').get();
      if (managerSnapshot.exists) {
        final managerData = managerSnapshot.value as Map<dynamic, dynamic>;
        _assignedJudgeId = managerData['assignedJudgeId'];

        // Get judge name
        final judgeSnapshot = await database.child('judges/$_assignedJudgeId').get();
        if (judgeSnapshot.exists) {
          final judgeData = judgeSnapshot.value as Map<dynamic, dynamic>;
          _judgeName = judgeData['name'] ?? 'Unknown Judge';
        }

        // Setup real-time listener for cases
        _setupCasesListener();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
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
            .where((c) => c.judgeId == _assignedJudgeId)
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

  Future<void> _logout() async {
    try {
      // Clear local storage (managers don't have FCM tokens in current implementation)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('role');
      await prefs.remove('id');

      if (mounted) {
        // Navigate to login screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addCase() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddCaseDialog(judgeId: _assignedJudgeId!),
    );

    if (result != null) {
      try {
        final database = FirebaseDatabase.instance.ref();
        final newCaseRef = database.child('cases').push();

        // Count only undone cases to get the correct orderIndex
        final undoneCasesCount = _cases.where((c) => !c.done).length;

        await newCaseRef.set({
          ...result,
          'judgeId': _assignedJudgeId,
          'orderIndex': undoneCasesCount,
          'done': false,
        });

        // Send notifications to affected lawyers
        await _notifyAffectedLawyers();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Case added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding case: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCase(String caseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Case'),
        content: const Text('Are you sure you want to delete this case?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final database = FirebaseDatabase.instance.ref();
        await database.child('cases/$caseId').remove();

        // Reorder remaining cases
        await _reorderCases();

        // Send notifications to affected lawyers
        await _notifyAffectedLawyers();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Case deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting case: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _reorderCases() async {
    final database = FirebaseDatabase.instance.ref();

    // Only reorder undone cases
    final undoneCases = _cases.where((c) => !c.done).toList();
    for (int i = 0; i < undoneCases.length; i++) {
      await database.child('cases/${undoneCases[i].caseId}/orderIndex').set(i);
    }
  }

  Future<void> _moveCaseUp(int index) async {
    if (index == 0) return;

    final database = FirebaseDatabase.instance.ref();
    final case1 = _cases[index];
    final case2 = _cases[index - 1];

    await database.child('cases/${case1.caseId}/orderIndex').set(index - 1);
    await database.child('cases/${case2.caseId}/orderIndex').set(index);

    // Send notifications to affected lawyers
    await _notifyAffectedLawyers();
  }

  Future<void> _moveCaseDown(int index) async {
    if (index == _cases.length - 1) return;

    final database = FirebaseDatabase.instance.ref();
    final case1 = _cases[index];
    final case2 = _cases[index + 1];

    await database.child('cases/${case1.caseId}/orderIndex').set(index + 1);
    await database.child('cases/${case2.caseId}/orderIndex').set(index);

    // Send notifications to affected lawyers
    await _notifyAffectedLawyers();
  }

  // Find the first undone case (lowest order index)
  int? _getFirstUndoneCaseIndex() {
    for (int i = 0; i < _cases.length; i++) {
      if (!_cases[i].done) {
        return i;
      }
    }
    return null;
  }

  Future<void> _markCaseAsDone(String caseId) async {
    try {
      final database = FirebaseDatabase.instance.ref();

      // Set done to true and remove orderIndex
      await database.child('cases/$caseId').update({
        'done': true,
      });
      await database.child('cases/$caseId/orderIndex').remove();

      // Reorder remaining undone cases
      await _reorderUndoneCases();

      // Send notifications to affected lawyers
      await _notifyAffectedLawyers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Case marked as done'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking case as done: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reorderUndoneCases() async {
    final database = FirebaseDatabase.instance.ref();
    final undoneCases = _cases.where((c) => !c.done).toList();

    for (int i = 0; i < undoneCases.length; i++) {
      await database.child('cases/${undoneCases[i].caseId}/orderIndex').set(i);
    }
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

  // Notify affected lawyers about position changes
  Future<void> _notifyAffectedLawyers() async {
    // Get current undone cases and their positions
    final undoneCases = _cases.where((c) => !c.done).toList();

    for (int i = 0; i < undoneCases.length; i++) {
      final courtCase = undoneCases[i];
      final position = i + 1;

      // Format position with ordinal suffix (1st, 2nd, 3rd, 4th, etc.)
      String positionText;
      if (position == 1) {
        positionText = '1st';
      } else if (position == 2) {
        positionText = '2nd';
      } else if (position == 3) {
        positionText = '3rd';
      } else {
        positionText = '${position}th';
      }

      final message = 'Your case ${courtCase.caseTitle} is now $positionText in the courtroom of $_judgeName';

      await NotificationService().saveNotificationToFirebase(
        courtCase.lawyerId,
        courtCase.caseTitle,
        message,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstUndoneCaseIndex = _getFirstUndoneCaseIndex();

    return Scaffold(
      appBar: AppBar(
        title: Text('Manager - $_judgeName'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCase,
        icon: const Icon(Icons.add),
        label: const Text('Add Case'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cases.isEmpty
          ? const Center(
        child: Text(
          'No cases. Tap + to add a case.',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _cases.length,
        onReorder: (oldIndex, newIndex) async {
          // Prevent reordering of done cases
          if (_cases[oldIndex].done) return;
          if (oldIndex < newIndex) newIndex--;
          // Prevent dropping before/after a done case
          if (newIndex < _cases.length && _cases[newIndex].done) return;

          final database = FirebaseDatabase.instance.ref();
          final movedCase = _cases[oldIndex];

          // Update all affected cases
          if (oldIndex < newIndex) {
            for (int i = oldIndex + 1; i <= newIndex; i++) {
              await database.child('cases/${_cases[i].caseId}/orderIndex').set(i - 1);
            }
          } else {
            for (int i = newIndex; i < oldIndex; i++) {
              await database.child('cases/${_cases[i].caseId}/orderIndex').set(i + 1);
            }
          }

          await database.child('cases/${movedCase.caseId}/orderIndex').set(newIndex);

          // Send notifications to affected lawyers
          await _notifyAffectedLawyers();
        },
        itemBuilder: (context, index) {
          final courtCase = _cases[index];
          final canMarkAsDone = firstUndoneCaseIndex == index;
          final displayPosition = _getDisplayPosition(index);

          return Card(
            key: ValueKey(courtCase.caseId),
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: courtCase.done
                    ? Colors.grey[400]
                    : Colors.blueGrey[900],
                child: Text(
                  displayPosition,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      courtCase.caseTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (courtCase.done)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'DONE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    courtCase.caseType.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: courtCase.caseType == 'supplementary'
                          ? Colors.purple[700]
                          : Colors.blueGrey[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Case ID: ${courtCase.caseId}'),
                  Text('Lawyer: ${courtCase.lawyerName}'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canMarkAsDone)
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      tooltip: 'Mark as Done',
                      onPressed: () => _markCaseAsDone(courtCase.caseId),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteCase(courtCase.caseId),
                  ),
                ],
              ),
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

class AddCaseDialog extends StatefulWidget {
  final String judgeId;

  const AddCaseDialog({Key? key, required this.judgeId}) : super(key: key);

  @override
  State<AddCaseDialog> createState() => _AddCaseDialogState();
}

class _AddCaseDialogState extends State<AddCaseDialog> {
  final _caseIdController = TextEditingController();
  final _caseTitleController = TextEditingController();
  final _lawyerNameController = TextEditingController();
  String _selectedType = 'regular';
  String? _selectedLawyerId;
  final List<Lawyer> _lawyers = [];

  @override
  void initState() {
    super.initState();
    _loadLawyers();
  }

  Future<void> _loadLawyers() async {
    final database = FirebaseDatabase.instance.ref();
    final snapshot = await database.child('lawyers').get();

    if (snapshot.exists) {
      final lawyersMap = snapshot.value as Map<dynamic, dynamic>;
      final lawyers = lawyersMap.entries
          .map((e) => Lawyer.fromMap(e.value as Map<dynamic, dynamic>, e.key))
          .toList();

      setState(() {
        _lawyers.addAll(lawyers);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Case'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _caseIdController,
              decoration: const InputDecoration(
                labelText: 'Case ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _caseTitleController,
              decoration: const InputDecoration(
                labelText: 'Case Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedLawyerId,
              decoration: const InputDecoration(
                labelText: 'Select Lawyer',
                border: OutlineInputBorder(),
              ),
              items: _lawyers.map((lawyer) {
                return DropdownMenuItem(
                  value: lawyer.lawyerId,
                  child: Text(lawyer.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLawyerId = value;
                  final lawyer = _lawyers.firstWhere((l) => l.lawyerId == value);
                  _lawyerNameController.text = lawyer.name;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Case Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'regular', child: Text('Regular')),
                DropdownMenuItem(value: 'supplementary', child: Text('Supplementary')),
              ],
              onChanged: (value) {
                setState(() => _selectedType = value!);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_caseIdController.text.isEmpty ||
                _caseTitleController.text.isEmpty ||
                _selectedLawyerId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please fill all fields'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            Navigator.pop(context, {
              'caseId': _caseIdController.text,
              'caseTitle': _caseTitleController.text,
              'lawyerId': _selectedLawyerId,
              'lawyerName': _lawyerNameController.text,
              'caseType': _selectedType,
            });
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _caseIdController.dispose();
    _caseTitleController.dispose();
    _lawyerNameController.dispose();
    super.dispose();
  }
}