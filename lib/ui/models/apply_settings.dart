class ApplySettings {
  Map<String, dynamic> toJson() => {
        'outputFolder': outputFolder,
        'createYearFolder': createYearFolder,
        'createMonthFolder': createMonthFolder,
        'createGroupFolder': createGroupFolder,
        'moveFiles': moveFiles,
        'appendDateToGroupName': appendDateToGroupName,
      };

  factory ApplySettings.fromJson(Map<String, dynamic> json) {
    return ApplySettings(
      outputFolder: json['outputFolder']?.toString() ?? '',
      createYearFolder: json['createYearFolder'] != false,
      createMonthFolder: json['createMonthFolder'] != false,
      createGroupFolder: json['createGroupFolder'] != false,
      moveFiles: json['moveFiles'] != false,
      appendDateToGroupName: json['appendDateToGroupName'] != false,
    );
  }

  /// مسیر خروجی
  final String outputFolder;

  final bool appendDateToGroupName;

  /// ایجاد پوشه سال
  final bool createYearFolder;

  /// ایجاد پوشه ماه
  final bool createMonthFolder;

  /// ایجاد پوشه گروه
  final bool createGroupFolder;

  /// true = انتقال
  /// false = کپی
  final bool moveFiles;

  const ApplySettings({
    required this.outputFolder,
    required this.createYearFolder,
    required this.createMonthFolder,
    required this.createGroupFolder,
    required this.moveFiles,
    required this.appendDateToGroupName,
  });

  ApplySettings copyWith({
    String? outputFolder,
    bool? createYearFolder,
    bool? createMonthFolder,
    bool? createGroupFolder,
    bool? moveFiles,
    bool? appendDateToGroupName,
  }) {
    return ApplySettings(
      outputFolder: outputFolder ?? this.outputFolder,
      createYearFolder: createYearFolder ?? this.createYearFolder,
      createMonthFolder: createMonthFolder ?? this.createMonthFolder,
      createGroupFolder: createGroupFolder ?? this.createGroupFolder,
      moveFiles: moveFiles ?? this.moveFiles,
      appendDateToGroupName:
          appendDateToGroupName ?? this.appendDateToGroupName,
    );
  }
}
