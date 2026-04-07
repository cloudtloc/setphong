import 'package:flutter/material.dart';

import 'screens/benchmark_diem_danh_screen.dart';
import 'screens/dang_ky_khuon_mat_screen.dart';
import 'screens/diem_danh_khuon_mat_screen.dart';
import 'screens/phong_dinh_vi_map_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diem danh khuon mat',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const TrangChuScreen(),
    );
  }
}

class TrangChuScreen extends StatelessWidget {
  const TrangChuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    void moManHinh(Widget manHinh) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (context) => manHinh),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Điểm danh khuôn mặt'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        children: [
          Text(
            'Chọn chức năng',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Đăng ký khuôn mặt'),
                  subtitle: const Text('Đăng ký ảnh và mesh cho sinh viên hoặc giảng viên'),
                  onTap: () => moManHinh(const DangKyKhuonMatScreen()),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Điểm danh khuôn mặt'),
                  subtitle: const Text('Gửi điểm danh có vị trí và nhận dạng khuôn mặt'),
                  onTap: () => moManHinh(const DiemDanhKhuonMatScreen()),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Benchmark điểm danh'),
                  subtitle: const Text('Giả lập nhiều người dùng, đo thời gian và thống kê'),
                  onTap: () => moManHinh(const BenchmarkDiemDanhScreen()),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Bản đồ định vị phòng'),
                  subtitle: const Text('Xem và thiết lập vùng phòng trên bản đồ'),
                  onTap: () => moManHinh(const PhongDinhViMapScreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
