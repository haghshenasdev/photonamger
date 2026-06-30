import 'package:fluent_ui/fluent_ui.dart';
import 'ui/pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MediaOrganizerApp());
}

class MediaOrganizerApp extends StatelessWidget {
  const MediaOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      debugShowCheckedModeBanner: false,
      title: 'Media Organizer',
      theme: FluentThemeData(brightness: Brightness.light),

      locale: const Locale('fa'),

      supportedLocales: const [Locale('fa')],

      home: const HomePage(),
    );
  }
}
