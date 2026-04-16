import 'package:flutter/material.dart';

/// 20 preset fan colors: Chinese name -> hex.
const Map<String, int> presetColors = {
  '红色': 0xFFE53935,
  '橙色': 0xFFFB8C00,
  '黄色': 0xFFFDD835,
  '绿色': 0xFF43A047,
  '蓝色': 0xFF1E88E5,
  '紫色': 0xFF8E24AA,
  '粉色': 0xFFEC407A,
  '白色': 0xFFFFFFFF,
  '黑色': 0xFF212121,
  '金色': 0xFFFFD600,
  '银色': 0xFFBDBDBD,
  '水色': 0xFF00BCD4,
  '青色': 0xFF00ACC1,
  '桃色': 0xFFFF80AB,
  '薄紫': 0xFFCE93D8,
  '薄荷绿': 0xFF80CBC4,
  '珊瑚色': 0xFFFF7043,
  '藤色': 0xFFB39DDB,
  '天蓝': 0xFF42A5F5,
  '酒红': 0xFFC62828,
};

/// Get the Color for a given Chinese color name.
/// Returns grey if the name is not in the preset table.
Color colorFor(String name) {
  final hex = presetColors[name];
  if (hex == null) return Colors.grey;
  return Color(hex);
}

/// All preset color names in display order.
List<String> get presetColorNames => presetColors.keys.toList();
