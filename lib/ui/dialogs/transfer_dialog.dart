import 'package:fgphoto/core/folder_service.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fgphoto/ui/models/apply_settings.dart';

class TransferDialog extends StatefulWidget {
  const TransferDialog({
    super.key,
    required this.groupCount,
    required this.selectedFiles,
    required this.totalFiles,
  });

  final int groupCount;
  final int selectedFiles;
  final int totalFiles;

  @override
  State<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<TransferDialog> {
  String outputFolder = "";

  bool createYearFolder = true;

  bool createMonthFolder = true;

  bool createGroupFolder = true;

  bool moveFiles = true;
  bool appendDateToGroupName = true;

  Future<void> pickFolder() async {
    final folder = await FolderService.pickFolder();

    if (folder == null) return;

    setState(() {
      outputFolder = folder;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 650),

      title: const Text("انتقال تصاویر"),

      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            "مسیر خروجی",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextBox(
                  readOnly: true,
                  controller: TextEditingController(text: outputFolder),
                ),
              ),

              const SizedBox(width: 8),

              FilledButton(child: const Text("انتخاب"), onPressed: pickFolder),
            ],
          ),

          const SizedBox(height: 25),

          const Text(
            "ساختار پوشه‌ها",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Checkbox(
            checked: appendDateToGroupName,
            content: const Text("افزودن تاریخ شمسی به نام پوشه گروه"),
            onChanged: (v) {
              setState(() {
                appendDateToGroupName = v ?? true;
              });
            },
          ),

          Checkbox(
            checked: createYearFolder,
            content: const Text("ایجاد پوشه سال"),

            onChanged: (v) {
              setState(() {
                createYearFolder = v ?? true;
              });
            },
          ),

          Checkbox(
            checked: createMonthFolder,
            content: const Text("ایجاد پوشه ماه (مثلاً 2-اردیبهشت)"),

            onChanged: (v) {
              setState(() {
                createMonthFolder = v ?? true;
              });
            },
          ),

          Checkbox(
            checked: createGroupFolder,
            content: const Text("ایجاد پوشه برای هر گروه زمانی"),

            onChanged: (v) {
              setState(() {
                createGroupFolder = v ?? true;
              });
            },
          ),

          const SizedBox(height: 25),

          const Text(
            "نوع عملیات",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          Checkbox(
            checked: moveFiles,
            content: const Text("انتقال فایل‌ها (Move)"),

            onChanged: (_) {
              setState(() {
                moveFiles = true;
              });
            },
          ),

          Checkbox(
            checked: !moveFiles,
            content: const Text("کپی فایل‌ها (Copy)"),

            onChanged: (_) {
              setState(() {
                moveFiles = false;
              });
            },
          ),

          const SizedBox(height: 25),

          InfoLabel(
            label: "آمار",

            child: Container(
              padding: const EdgeInsets.all(12),

              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),

                borderRadius: BorderRadius.circular(6),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text("تعداد گروه‌ها : ${widget.groupCount}"),

                  Text("فایل‌های منتخب : ${widget.selectedFiles}"),

                  Text("کل فایل‌ها : ${widget.totalFiles}"),
                ],
              ),
            ),
          ),
        ],
      ),

      actions: [
        FilledButton(
          child: const Text("شروع انتقال"),

          onPressed: outputFolder.isEmpty
              ? null
              : () {
                  Navigator.pop(
                    context,
                    ApplySettings(
                      outputFolder: outputFolder,
                      createYearFolder: createYearFolder,
                      createMonthFolder: createMonthFolder,
                      createGroupFolder: createGroupFolder,
                      moveFiles: moveFiles,
                      appendDateToGroupName: appendDateToGroupName,
                    ),
                  );
                },
        ),

        Button(
          child: const Text("انصراف"),

          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
