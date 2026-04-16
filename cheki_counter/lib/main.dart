import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cheki_counter/data/db.dart';
import 'package:cheki_counter/features/home/idol_list_notifier.dart';
import 'package:cheki_counter/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;

  runApp(
    ChangeNotifierProvider(
      create: (_) => IdolListNotifier(),
      child: const ChekiCounterApp(),
    ),
  );
}
