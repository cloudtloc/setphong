import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/benchmark_diem_danh_screen.dart';
import 'screens/tra_cuu_dieu_chinh_api_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: 'env.template');
  } catch (e, st) {
    debugPrint('main dotenv load loi timestamp=${DateTime.now().toIso8601String()} error=$e stack=$st');
  }
  runApp(const DiemDanhFaceApp());
}

class DiemDanhFaceApp extends StatelessWidget {
  const DiemDanhFaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diem danh khuon mat',
      theme: AppTheme.light(),
      home: const _HomeShell(),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _index = 0;

  static const _titles = [
    'Benchmark diem danh',
    'Tra cuu va dieu chinh',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          BenchmarkDiemDanhScreen(),
          TraCuuDieuChinhApiScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(value: 0, label: Text('Benchmark')),
              ButtonSegment<int>(value: 1, label: Text('Tra cuu')),
            ],
            selected: <int>{_index},
            onSelectionChanged: (s) {
              final v = s.first;
              setState(() => _index = v);
            },
          ),
        ),
      ),
    );
  }
}
