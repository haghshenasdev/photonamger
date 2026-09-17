import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'photon_project.dart';
import 'project_repository.dart';

class ProjectFileService {
  static Future<String?> saveProjectAs(PhotonProject project) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'ذخیره پروژه',
      fileName: '${_safeName(project.name)}.${ProjectRepository.extension}',
      type: FileType.custom,
      allowedExtensions: [ProjectRepository.extension],
    );

    if (path == null || path.trim().isEmpty) return null;

    final finalPath = path.toLowerCase().endsWith(
          '.${ProjectRepository.extension}',
        )
        ? path
        : '$path.${ProjectRepository.extension}';

    await ProjectRepository.save(
      path: finalPath,
      project: project,
    );

    await ProjectRepository.rememberProjectPath(finalPath);
    return finalPath;
  }

  static Future<String?> openProjectPath() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'باز کردن پروژه',
      type: FileType.custom,
      allowedExtensions: [ProjectRepository.extension],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final path = result.files.single.path;
    if (path == null || path.trim().isEmpty) return null;

    return path;
  }

  static String _safeName(String value) {
    var name = value.trim();
    if (name.isEmpty) name = 'پروژه';

    for (final char in ['\\', '/', ':', '*', '?', '"', '<', '>', '|']) {
      name = name.replaceAll(char, '_');
    }

    return name;
  }
}
