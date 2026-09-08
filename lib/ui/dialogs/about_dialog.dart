import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutDialog extends StatelessWidget {
  const AboutDialog({super.key});

  static final Uri _developerWebsite = Uri.parse(
    'https://haghshenasdev.github.io/',
  );

  static final Uri _appWebsite = Uri.parse(
    'https://haghshenasdev.github.io/arshino.html',
  );

  Future<void> _openUrl(Uri url) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('درباره نرم‌افزار'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),

            // Logo
            // Logo
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        color: FluentTheme.of(context).accentColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        FluentIcons.photo2,
                        size: 40,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'آرشینو',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 6),

            Text(
              'مدیریت و سامان‌دهی تصاویر و ویدئوها',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: FluentTheme.of(context).typography.body?.color,
              ),
            ),

            const SizedBox(height: 20),

            const Divider(),

            const SizedBox(height: 14),

            _InfoRow(
              icon: FluentIcons.app_icon_default,
              title: 'نسخه',
              value: '1.0.0',
            ),

            const SizedBox(height: 12),

            _InfoRow(
              icon: FluentIcons.contact,
              title: 'برنامه‌نویس',
              value: 'محمد مهدی حق‌شناس',
            ),

            const SizedBox(height: 18),

            _LinkTile(
              icon: FluentIcons.globe,
              title: 'سایت نرم افزار آرشینو',
              subtitle: 'https://haghshenasdev.github.io/arshino.html',
              onPressed: () {
                _openUrl(_appWebsite);
              },
            ),
            const SizedBox(height: 10),
            _LinkTile(
              icon: FluentIcons.globe,
              title: 'سایت برنامه‌نویس',
              subtitle: 'haghshenasdev.github.io',
              onPressed: () {
                _openUrl(_developerWebsite);
              },
            ),

            const SizedBox(height: 20),

            const Divider(),

            const SizedBox(height: 10),

            Text(
              '© 2026 محمد مهدی حق‌شناس',
              style: TextStyle(
                fontSize: 12,
                color: FluentTheme.of(context).typography.caption?.color,
              ),
            ),
          ],
        ),
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
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 12),
        Text('$title:', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Button(
      onPressed: onPressed,
      style: ButtonStyle(
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: FluentTheme.of(context).typography.caption?.color,
                  ),
                ),
              ],
            ),
          ),
          const Icon(FluentIcons.open_with, size: 14),
        ],
      ),
    );
  }
}
