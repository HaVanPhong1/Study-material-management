import 'package:flutter_test/flutter_test.dart';
import 'package:th1/main.dart';
import 'package:th1/models/document_item.dart';

void main() {
  testWidgets('App khởi động thành công vào màn hình Login', (WidgetTester tester) async {
    await tester.pumpWidget(const DocumentManagementApp());
    expect(find.text('QUẢN LÝ TÀI LIỆU HỌC TẬP'), findsOneWidget);
  });

  test('parseTags tách đúng chuỗi phẩy và khoảng trắng', () {
    expect(parseTags('toan, dao-ham , ,giai-tich'), ['toan', 'dao-ham', 'giai-tich']);
    expect(parseTags(''), isEmpty);
  });

  test('recommendDocuments xếp hạng tài liệu người khác theo độ trùng tag và môn', () {
    final now = DateTime.now();
    final all = [
      DocumentItem(
        id: '1',
        ownerId: 'user_me',
        title: 'Đại số tuyến tính',
        subject: 'Toán',
        docType: 'bai_giang',
        author: 'GV A',
        year: 2024,
        createdAt: now,
        updatedAt: now,
        tags: const ['toan', 'ma-tran'],
      ),
      DocumentItem(
        id: '2',
        ownerId: 'user_other',
        title: 'Bài tập ma trận',
        subject: 'Toán',
        docType: 'bai_tap',
        author: 'GV B',
        year: 2024,
        createdAt: now,
        updatedAt: now,
        tags: const ['ma-tran'], // trùng tag + trùng môn => 2 điểm
      ),
      DocumentItem(
        id: '3',
        ownerId: 'user_other',
        title: 'Lịch sử triết học',
        subject: 'Triết',
        docType: 'bai_giang',
        author: 'GV C',
        year: 2024,
        createdAt: now,
        updatedAt: now,
        tags: const ['triet'], // 0 điểm
      ),
    ];

    final recs = recommendDocuments(all, 'user_me');
    expect(recs.length, 1);
    expect(recs.first.id, '2');
  });
}
