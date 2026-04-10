// lib/models/models.dart

class CourtCase {
  final String caseId;
  final String lawyerId;
  final String judgeId;
  final String caseType; // 'regular' or 'supplementary'
  final int orderIndex;
  final String caseTitle;
  final String lawyerName;
  final bool done;

  CourtCase({
    required this.caseId,
    required this.lawyerId,
    required this.judgeId,
    required this.caseType,
    required this.orderIndex,
    required this.caseTitle,
    required this.lawyerName,
    this.done = false,
  });

  factory CourtCase.fromMap(Map<dynamic, dynamic> map, String id) {
    return CourtCase(
      caseId: id,
      lawyerId: map['lawyerId'] ?? '',
      judgeId: map['judgeId'] ?? '',
      caseType: map['caseType'] ?? 'regular',
      orderIndex: map['orderIndex'] ?? -1, // Negative number for done cases without orderIndex (sorts to top)
      caseTitle: map['caseTitle'] ?? '',
      lawyerName: map['lawyerName'] ?? '',
      done: map['done'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lawyerId': lawyerId,
      'judgeId': judgeId,
      'caseType': caseType,
      'orderIndex': orderIndex,
      'caseTitle': caseTitle,
      'lawyerName': lawyerName,
      'done': done,
    };
  }
}

class Judge {
  final String judgeId;
  final String name;
  final String courtRoom;

  Judge({
    required this.judgeId,
    required this.name,
    required this.courtRoom,
  });

  factory Judge.fromMap(Map<dynamic, dynamic> map, String id) {
    return Judge(
      judgeId: id,
      name: map['name'] ?? '',
      courtRoom: map['courtRoom'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'courtRoom': courtRoom,
    };
  }
}

class Lawyer {
  final String lawyerId;
  final String name;
  final String fcmToken;

  Lawyer({
    required this.lawyerId,
    required this.name,
    this.fcmToken = '',
  });

  factory Lawyer.fromMap(Map<dynamic, dynamic> map, String id) {
    return Lawyer(
      lawyerId: id,
      name: map['name'] ?? '',
      fcmToken: map['fcmToken'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'fcmToken': fcmToken,
    };
  }
}

class Manager {
  final String managerId;
  final String name;
  final String assignedJudgeId;

  Manager({
    required this.managerId,
    required this.name,
    required this.assignedJudgeId,
  });

  factory Manager.fromMap(Map<dynamic, dynamic> map, String id) {
    return Manager(
      managerId: id,
      name: map['name'] ?? '',
      assignedJudgeId: map['assignedJudgeId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'assignedJudgeId': assignedJudgeId,
    };
  }
}