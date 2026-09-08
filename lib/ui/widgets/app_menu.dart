import 'package:fgphoto/ui/dialogs/about_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';

class AppMenu extends StatefulWidget {
  const AppMenu({super.key});

  @override
  State<AppMenu> createState() => _AppMenuState();
}

class _AppMenuState extends State<AppMenu> {
  final FlyoutController _controller = FlyoutController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showAbout() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return const AboutDialog();
      },
    );
  }

  Future<void> _showHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return ContentDialog(
          title: const Text('راهنما'),
          content: const Text(
            'برای شروع کار با نرم‌افزار، ابتدا یک یا چند پوشه '
            'را انتخاب کنید و سپس روی «شروع اسکن و آنالیز» کلیک کنید.',
          ),
          actions: [
            Button(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('بستن'),
            ),
          ],
        );
      },
    );
  }

  void _openMenu() {
    _controller.showFlyout<void>(
      builder: (context) {
        return MenuFlyout(
          items: [
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.info),
              text: const Text('درباره نرم‌افزار'),
              onPressed: () {
                _showAbout();
              },
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.questionnaire),
              text: const Text('راهنما'),
              onPressed: () {
                _showHelp();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlyoutTarget(
      controller: _controller,
      child: IconButton(
        icon: const Icon(FluentIcons.more, size: 18),
        onPressed: _openMenu,
      ),
    );
  }
}
