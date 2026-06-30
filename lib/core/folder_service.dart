import 'package:file_picker/file_picker.dart';

class FolderService {

  static Future<String?> pickFolder() async {

    return await FilePicker.platform.getDirectoryPath();
  }
}