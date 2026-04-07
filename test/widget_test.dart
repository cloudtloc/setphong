import 'package:flutter_test/flutter_test.dart';

import 'package:diemdanh_face/main.dart';

void main() {
  testWidgets('Ứng dụng khởi tạo và hiển thị trang chủ', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Điểm danh khuôn mặt'), findsWidgets);
    expect(find.text('Chọn chức năng'), findsOneWidget);
    expect(find.text('Đăng ký khuôn mặt'), findsOneWidget);
  });
}
