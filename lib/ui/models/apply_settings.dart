class ApplySettings {
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
