import 'package:flutter/material.dart';

import '../theme/stitch_theme.dart';

class AppSettingsData {
  const AppSettingsData({
    required this.brandName,
    required this.primaryColor,
    this.logoUrl,
  });

  final String brandName;
  final String primaryColor;
  final String? logoUrl;

  factory AppSettingsData.defaults() {
    return const AppSettingsData(
      brandName: 'Job ClickOn',
      primaryColor: '#04BC5C',
      logoUrl: null,
    );
  }

  factory AppSettingsData.fromJson(Map<String, dynamic> json) {
    return AppSettingsData(
      brandName: (json['brand_name'] ?? 'Job ClickOn').toString(),
      primaryColor: (json['primary_color'] ?? '#04BC5C').toString(),
      logoUrl:
          (json['logo_url'] ?? '').toString().isEmpty
              ? null
              : (json['logo_url'] ?? '').toString(),
    );
  }
}

class AppSettingsStore extends ChangeNotifier {
  AppSettingsData _settings = AppSettingsData.defaults();

  AppSettingsData get settings => _settings;

  void apply(AppSettingsData data) {
    _settings = data;
    final Color? primary = _parseColor(data.primaryColor);
    if (primary != null) {
      StitchTheme.applyPrimary(primary);
    }
    notifyListeners();
  }

  Color? _parseColor(String value) {
    final String hex = value.replaceAll('#', '').trim();
    if (hex.length != 6) return null;
    final int? colorValue = int.tryParse('FF$hex', radix: 16);
    if (colorValue == null) return null;
    return Color(colorValue);
  }
}

final AppSettingsStore appSettingsStore = AppSettingsStore();
