import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:th1/main.dart';
import 'package:th1/models/document_item.dart';
import 'package:th1/screens/map_screen.dart';

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
    expect(recs.isNotEmpty, true);
    expect(recs.first.id, '2');
  });

  test('DocumentItem hỗ trợ đầy đủ các trường vị trí và tọa độ GPS', () {
    final now = DateTime.now();
    final doc = DocumentItem(
      id: 'doc-geo-1',
      ownerId: 'user-1',
      title: 'Giáo trình Cấu trúc dữ liệu',
      subject: 'CNTT',
      docType: 'bai_giang',
      author: 'Khoa CNTT',
      year: 2025,
      createdAt: now,
      updatedAt: now,
      tags: ['cntt', 'ctdl'],
      locationLabel: 'Thư viện A1, kệ 4',
      latitude: 21.028511,
      longitude: 105.854167,
    );

    expect(doc.locationLabel, 'Thư viện A1, kệ 4');
    expect(doc.latitude, closeTo(21.0285, 0.001));
    expect(doc.longitude, closeTo(105.854, 0.001));
    expect(doc.tags, contains('cntt'));

    final map = doc.toMap();
    expect(map['location_label'], 'Thư viện A1, kệ 3' == doc.locationLabel ? true : 'Thư viện A1, kệ 4');
    expect(map['latitude'], 21.028511);
    expect(map['longitude'], 105.854167);

    final fromMap = DocumentItem.fromMap(map, currentUserId: 'user-1');
    expect(fromMap.latitude, 21.028511);
    expect(fromMap.longitude, 105.854167);
    expect(fromMap.tags, ['cntt', 'ctdl']);
  });

  testWidgets('MapScreen hiển thị ở chế độ Ghim vị trí (pickLocation)', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MapScreen(mode: MapScreenMode.pickLocation),
      ),
    );
    expect(find.text('Ghim vị trí tài liệu trên bản đồ'), findsOneWidget);
    expect(find.byIcon(Icons.layers_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
  });

  testWidgets('MapScreen hiển thị ở chế độ Xem tài liệu (viewDocuments)', (WidgetTester tester) async {
    final now = DateTime.now();
    final docs = [
      DocumentItem(
        id: 'doc-1',
        ownerId: 'user-1',
        title: 'Tài liệu A',
        subject: 'Toán',
        docType: 'bai_giang',
        author: 'GV A',
        year: 2024,
        createdAt: now,
        updatedAt: now,
        latitude: 21.0285,
        longitude: 105.8542,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          mode: MapScreenMode.viewDocuments,
          documents: docs,
        ),
      ),
    );

    expect(find.text('Bản đồ vị trí tài liệu (1)'), findsOneWidget);
    expect(find.text('Toán'), findsOneWidget);
  });
}
