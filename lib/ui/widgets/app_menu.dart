import 'package:fgphoto/ui/dialogs/about_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';

class AppMenu extends StatefulWidget {
  const AppMenu({
    super.key,
    required this.onNewProject,
    required this.onOpenProject,
    required this.onSaveProject,
    required this.onSaveProjectAs,
    required this.onResumeOperations,
  });

  final VoidCallback onNewProject;
  final VoidCallback onOpenProject;
  final VoidCallback onSaveProject;
  final VoidCallback onSaveProjectAs;
  final VoidCallback onResumeOperations;

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
      builder: (context) => const AboutDialog(),
    );
  }

  Future<void> _showHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('راهنما'),
        content: const Text(
          'ابتدا یک یا چند پوشه را انتخاب کنید و سپس روی «شروع اسکن و آنالیز» کلیک کنید.\n\n'
          'از منوی پروژه می‌توانید کار فعلی را در یک فایل .photonamger ذخیره کنید '
          'و بعداً با باز کردن همان فایل ادامه دهید.',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  void _openMenu() {
    _controller.showFlyout<void>(
      builder: (context) {
        return MenuFlyout(
          items: [
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.add),
              text: const Text('پروژه جدید'),
              onPressed: widget.onNewProject,
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.open_file),
              text: const Text('باز کردن پروژه'),
              onPressed: widget.onOpenProject,
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.save),
              text: const Text('ذخیره پروژه'),
              onPressed: widget.onSaveProject,
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.save),
              text: const Text('ذخیره پروژه با نام جدید'),
              onPressed: widget.onSaveProjectAs,
            ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.sync),
              text: const Text('ادامه عملیات ناتمام'),
              onPressed: widget.onResumeOperations,
            ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.info),
              text: const Text('درباره نرم‌افزار'),
              onPressed: _showAbout,
            ),
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.questionnaire),
              text: const Text('راهنما'),
              onPressed: _showHelp,
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
