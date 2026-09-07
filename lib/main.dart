import 'package:fluent_ui/fluent_ui.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'ui/pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  fvp.registerWith();
  runApp(const MediaOrganizerApp());
}

class MediaOrganizerApp extends StatelessWidget {
  const MediaOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      debugShowCheckedModeBanner: false,
      title: 'Archino',
      theme: FluentThemeData(brightness: Brightness.light),

      locale: const Locale('fa'),

      supportedLocales: const [Locale('fa')],

      home: const HomePage(),
    );
  }
}
