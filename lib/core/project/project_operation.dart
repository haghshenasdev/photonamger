import 'dart:convert';

enum ProjectOperationType {
  copy,
  move,
}

enum ProjectOperationStatus {
  pending,
  processing,
  completed,
  failed,
}

class ProjectOperation {
  final String id;
  final String sourcePath;
  String destinationPath;
  final ProjectOperationType type;

  ProjectOperationStatus status;
  String? error;
  DateTime createdAt;
  DateTime? startedAt;
  DateTime? completedAt;

  ProjectOperation({
    required this.id,
    required this.sourcePath,
    required this.destinationPath,
    required this.type,
    this.status = ProjectOperationStatus.pending,
    this.error,
    DateTime? createdAt,
    this.startedAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isFinished => status == ProjectOperationStatus.completed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourcePath': sourcePath,
        'destinationPath': destinationPath,
        'type': type.name,
        'status': status.name,
        'error': error,
        'createdAt': createdAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory ProjectOperation.fromJson(Map<String, dynamic> json) {
    return ProjectOperation(
      id: json['id']?.toString() ?? '',
      sourcePath: json['sourcePath']?.toString() ?? '',
      destinationPath: json['destinationPath']?.toString() ?? '',
      type: ProjectOperationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ProjectOperationType.copy,
      ),
      status: ProjectOperationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ProjectOperationStatus.pending,
      ),
      error: json['error']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? ''),
      completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
    );
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
