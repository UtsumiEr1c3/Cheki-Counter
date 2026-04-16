import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cheki_counter/data/csv_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('导入 CSV'),
            subtitle: const Text('从文件合并导入切奇数据'),
            onTap: () => _importCsv(context),
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('导出 CSV'),
            subtitle: const Text('导出所有数据到 CSV 文件'),
            onTap: () => _exportCsv(context),
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('团体总览'),
            subtitle: const Text('查看各团体汇总数据'),
            onTap: () => Navigator.pushNamed(context, '/group-overview'),
          ),
        ],
      ),
    );
  }

  Future<void> _importCsv(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    final bytes = await File(filePath).readAsBytes();
    final service = CsvService();

    if (!context.mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final importResult = await service.importCsv(bytes);

    if (!context.mounted) return;
    Navigator.pop(context); // dismiss loading

    // Show summary
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入完成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('新增偶像: ${importResult.newIdols} 个'),
            Text('新增记录: ${importResult.newRecords} 条'),
            Text('跳过重复: ${importResult.skipped} 条'),
            Text('错误: ${importResult.errors} 条'),
            if (importResult.errorDetails.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('错误详情:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...importResult.errorDetails
                  .take(10)
                  .map((e) => Text(e, style: const TextStyle(fontSize: 12))),
              if (importResult.errorDetails.length > 10)
                Text('...及其他 ${importResult.errorDetails.length - 10} 条错误'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final service = CsvService();
    final path = await service.exportCsv();

    await Share.shareXFiles([XFile(path)]);
  }
}
