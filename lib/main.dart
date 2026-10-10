import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'core/project/project_file_association_service.dart';
import 'ui/pages/home_page.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  String? launchProjectPath;
  if (Platform.isWindows) {
    launchProjectPath = ProjectFileAssociationService.projectPathFromArguments(args);
    try {
      await ProjectFileAssociationService.registerForCurrentUser();
    } catch (e) {
      // Opening an already-associated file should still work even if Windows
      // prevents updating the association.
      debugPrint('Project file association registration failed: $e');
    }
  }

  runApp(MediaOrganizerApp(initialProjectPath: launchProjectPath));
}

class MediaOrganizerApp extends StatelessWidget {
  const MediaOrganizerApp({super.key, this.initialProjectPath});

  final String? initialProjectPath;

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      debugShowCheckedModeBanner: false,
      title: 'Archino',
      theme: FluentThemeData(brightness: Brightness.light),
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa')],
      home: HomePage(initialProjectPath: initialProjectPath),
    );
  }
}
