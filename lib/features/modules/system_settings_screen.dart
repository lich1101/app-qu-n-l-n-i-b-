import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';
import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({
    super.key,
    required this.token,
    required this.apiService,
  });

  final String token;
  final MobileApiService apiService;

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  final TextEditingController brandCtrl = TextEditingController();
  final TextEditingController colorCtrl = TextEditingController();
  final TextEditingController logoUrlCtrl = TextEditingController();
  File? logoFile;
  bool saving = false;
  String message = '';
  static const List<String> _palette = <String>[
    '#0F172A',
    '#1F2937',
    '#334155',
    '#0EA5A6',
    '#2563EB',
    '#10B981',
    '#F59E0B',
    '#F97316',
    '#E11D48',
    '#8B5CF6',
  ];

  Color _colorFromHex(String value, {Color? fallback}) {
    final Color resolvedFallback = fallback ?? StitchTheme.primary;
    final String hex = value.replaceAll('#', '').trim();
    if (hex.length != 6) return resolvedFallback;
    final int? parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return resolvedFallback;
    return Color(0xFF000000 | parsed);
  }

  @override
  void initState() {
    super.initState();
    final AppSettingsData settings = appSettingsStore.settings;
    brandCtrl.text = settings.brandName;
    colorCtrl.text = settings.primaryColor;
    logoUrlCtrl.text = settings.logoUrl ?? '';
  }

  @override
  void dispose() {
    brandCtrl.dispose();
    colorCtrl.dispose();
    logoUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result == null || result.files.single.path == null) return;
    setState(() => logoFile = File(result.files.single.path!));
  }

  Future<void> _save() async {
    setState(() {
      saving = true;
      message = '';
    });
    final Map<String, dynamic> res = await widget.apiService.updateSettings(
      widget.token,
      brandName: brandCtrl.text.trim().isEmpty
          ? null
          : brandCtrl.text.trim(),
      primaryColor: colorCtrl.text.trim().isEmpty
          ? null
          : colorCtrl.text.trim(),
      logoUrl: logoUrlCtrl.text.trim().isEmpty
          ? null
          : logoUrlCtrl.text.trim(),
      logoFile: logoFile,
    );
    if (!mounted) return;
    if (res['error'] == true) {
      setState(() {
        saving = false;
        message = 'Cập nhật thất bại.';
      });
      return;
    }
    final AppSettingsData updated = AppSettingsData.fromJson(res);
    appSettingsStore.apply(updated);
    setState(() {
      saving = false;
      logoFile = null;
      message = 'Đã lưu cài đặt.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt hệ thống'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: <Widget>[
          const Text(
            'Cấu hình thương hiệu',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Đổi tên hiển thị, màu chủ đạo và logo cho app & web.',
            style: TextStyle(color: StitchTheme.textMuted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: brandCtrl,
            decoration: const InputDecoration(labelText: 'Tên brand'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: colorCtrl,
            decoration: InputDecoration(
              labelText: 'Màu chủ đạo (HEX)',
              suffixIcon: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _colorFromHex(colorCtrl.text),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12),
                ),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          const Text(
            'Chọn nhanh màu gợi ý',
            style: TextStyle(color: StitchTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _palette.map((String hex) {
              final bool selected =
                  hex.toLowerCase() == colorCtrl.text.trim().toLowerCase();
              return GestureDetector(
                onTap: () => setState(() => colorCtrl.text = hex),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _colorFromHex(hex),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? StitchTheme.primary : Colors.black12,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x11000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: logoUrlCtrl,
            decoration: const InputDecoration(labelText: 'Logo URL'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickLogo,
            icon: const Icon(Icons.image_outlined),
            label: Text(logoFile == null ? 'Chọn logo' : 'Đổi logo'),
          ),
          if (logoFile != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                logoFile!.path.split('/').last,
                style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12),
              ),
            ),
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                message,
                style: TextStyle(
                  color: message.contains('Đã')
                      ? StitchTheme.success
                      : StitchTheme.danger,
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(saving ? 'Đang lưu...' : 'Lưu cài đặt'),
          ),
        ],
      ),
    );
  }
}
