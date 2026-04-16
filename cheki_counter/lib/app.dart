import 'package:flutter/material.dart';
import 'package:cheki_counter/features/home/home_page.dart';
import 'package:cheki_counter/features/idol_detail/idol_detail_page.dart';
import 'package:cheki_counter/features/statistics/statistics_page.dart';
import 'package:cheki_counter/features/statistics/group_overview_page.dart';
import 'package:cheki_counter/features/settings/settings_page.dart';

class ChekiCounterApp extends StatelessWidget {
  const ChekiCounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cheki Counter',
      theme: ThemeData(
        colorSchemeSeed: Colors.pink,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/statistics': (context) => const StatisticsPage(),
        '/settings': (context) => const SettingsPage(),
        '/group-overview': (context) => const GroupOverviewPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/idol-detail') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => IdolDetailPage(
              idolId: args['idolId'] as int,
              idolName: args['idolName'] as String,
              idolColor: args['idolColor'] as String,
            ),
          );
        }
        return null;
      },
    );
  }
}
