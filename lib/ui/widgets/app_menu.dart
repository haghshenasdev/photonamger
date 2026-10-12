import 'package:fluent_ui/fluent_ui.dart';
import 'package:fgphoto/ui/dialogs/about_dialog.dart' as app_about;

class AppMenu extends StatefulWidget {
  const AppMenu({
    super.key,
    required this.onNewProject,
    required this.onOpenProject,
    required this.onSaveProject,
    required this.onSaveProjectAs,
    required this.onResumeOperations,
    required this.onImportArchive,
    required this.onExportDatabase,
    required this.onShowStatistics,
  });

  final VoidCallback onNewProject;
  final VoidCallback onOpenProject;
  final VoidCallback onSaveProject;
  final VoidCallback onSaveProjectAs;
  final VoidCallback onResumeOperations;
  final VoidCallback onImportArchive;
  final VoidCallback onExportDatabase;
  final VoidCallback onShowStatistics;

  @override
  State<AppMenu> createState() => _AppMenuState();
}

class _AppMenuState extends State<AppMenu> {
  final _projectController = FlyoutController();
  final _archiveController = FlyoutController();
  final _viewController = FlyoutController();
  final _toolsController = FlyoutController();
  final _helpController = FlyoutController();

  @override
  void dispose() {
    _projectController.dispose();
    _archiveController.dispose();
    _viewController.dispose();
    _toolsController.dispose();
    _helpController.dispose();
    super.dispose();
  }

  void _openMenu(FlyoutController controller, List<MenuFlyoutItemBase> items) {
    controller.showFlyout<void>(builder: (context) => MenuFlyout(items: items));
  }

  MenuFlyoutItem _item({
    required IconData icon,
    required String title,
    required VoidCallback onPressed,
  }) {
    return MenuFlyoutItem(
      leading: Icon(icon),
      text: Text(title),
      onPressed: onPressed,
    );
  }

  Future<void> _showHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('راهنمای آرشینو'),
        content: const Text(
          'برای شروع، پوشه‌های تصاویر را انتخاب و اسکن و آنالیز را اجرا کنید.\n\n'
          'برای حفظ تغییرات، پروژه را ذخیره کنید. '
          'پروژه‌های ذخیره‌شده را می‌توانید بعداً دوباره باز کنید.',
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

  Future<void> _showAbout() async {
    await showDialog<void>(
      context: context,
      builder: (context) => const app_about.AboutDialog(),
    );
  }

  Widget _topMenu({
    required String title,
    required IconData icon,
    required FlyoutController controller,
    required List<MenuFlyoutItemBase> items,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 5),
      child: FlyoutTarget(
        controller: controller,
        child: Button(
          onPressed: () => _openMenu(controller, items),
          style: ButtonStyle(
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15),
              const SizedBox(width: 7),
              Text(title),
              const SizedBox(width: 6),
              const Icon(FluentIcons.chevron_down, size: 9),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: theme.micaBackgroundColor,
          border: Border(
            bottom: BorderSide(color: theme.acrylicBackgroundColor, width: 1),
          ),
        ),
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            _topMenu(
              title: 'پروژه',
              icon: FluentIcons.document,
              controller: _projectController,
              items: [
                _item(
                  icon: FluentIcons.add,
                  title: 'پروژه جدید',
                  onPressed: widget.onNewProject,
                ),
                _item(
                  icon: FluentIcons.open_file,
                  title: 'باز کردن پروژه',
                  onPressed: widget.onOpenProject,
                ),
                const MenuFlyoutSeparator(),
                _item(
                  icon: FluentIcons.save,
                  title: 'ذخیره پروژه',
                  onPressed: widget.onSaveProject,
                ),
                _item(
                  icon: FluentIcons.save_as,
                  title: 'ذخیره پروژه با نام جدید',
                  onPressed: widget.onSaveProjectAs,
                ),
              ],
            ),

            // دکمه ذخیره در کنار منوهای بالایی
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 5),
              child: Tooltip(
                message: 'ذخیره پروژه (Ctrl+S)',
                child: Button(
                  onPressed: widget.onSaveProject,
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.save, size: 15),
                      SizedBox(width: 7),
                      Text('ذخیره'),
                    ],
                  ),
                ),
              ),
            ),

            _topMenu(
              title: 'بازیابی',
              icon: FluentIcons.archive,
              controller: _archiveController,
              items: [
                _item(
                  icon: FluentIcons.database,
                  title: 'بارگذاری اطلاعات از آرشیو هارد',
                  onPressed: widget.onImportArchive,
                ),
                _item(
                  icon: FluentIcons.sync,
                  title: 'ادامه عملیات ناتمام',
                  onPressed: widget.onResumeOperations,
                ),
              ],
            ),

            _topMenu(
              title: 'نمایش',
              icon: FluentIcons.view,
              controller: _viewController,
              items: [
                _item(
                  icon: FluentIcons.bar_chart_vertical,
                  title: 'آمار جامع تصاویر',
                  onPressed: widget.onShowStatistics,
                ),
              ],
            ),

            _topMenu(
              title: 'ابزارها',
              icon: FluentIcons.settings,
              controller: _toolsController,
              items: [
                _item(
                  icon: FluentIcons.database,
                  title: 'بارگذاری اطلاعات از آرشیو هارد',
                  onPressed: widget.onImportArchive,
                ),
                _item(
                  icon: FluentIcons.save,
                  title: 'ذخیره دیتابیس اطلاعات در مسیر دلخواه',
                  onPressed: widget.onExportDatabase,
                ),
                _item(
                  icon: FluentIcons.sync,
                  title: 'ادامه عملیات ناتمام',
                  onPressed: widget.onResumeOperations,
                ),
              ],
            ),

            _topMenu(
              title: 'راهنما',
              icon: FluentIcons.help,
              controller: _helpController,
              items: [
                _item(
                  icon: FluentIcons.questionnaire,
                  title: 'راهنمای استفاده',
                  onPressed: _showHelp,
                ),
                _item(
                  icon: FluentIcons.info,
                  title: 'درباره آرشینو',
                  onPressed: _showAbout,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
