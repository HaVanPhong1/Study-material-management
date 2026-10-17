import 'package:flutter/material.dart';
import '../models/document_item.dart';
import '../models/permission_item.dart';
import '../services/permission_service.dart';

class ShareScreen extends StatefulWidget {
  final DocumentItem document;

  const ShareScreen({super.key, required this.document});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final _emailController = TextEditingController();
  String _permissionLevel = 'view';
  bool _isSubmitting = false;
  List<PermissionItem> _sharedUsers = [];
  bool _isLoadingList = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    setState(() => _isLoadingList = true);
    try {
      final list = await PermissionService().getPermissions(widget.document.id);
      setState(() => _sharedUsers = list);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  Future<void> _share() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập email người nhận')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await PermissionService().shareDocument(
        documentId: widget.document.id,
        recipientEmail: email,
        permissionLevel: _permissionLevel,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã chia sẻ thành công quyền ${_permissionLevel.toUpperCase()} cho $email'),
            backgroundColor: Colors.green,
          ),
        );
        _emailController.clear();
        _loadPermissions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _revoke(PermissionItem item) async {
    try {
      await PermissionService().revokePermission(widget.document.id, item.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thu hồi quyền chia sẻ.'), backgroundColor: Colors.orange),
        );
        _loadPermissions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Chia sẻ tài liệu', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thông tin tài liệu
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, color: Color(0xFF38BDF8), size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.document.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text('Môn: ${widget.document.subject} • ${widget.document.year}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Form chia sẻ
            const Text('CHIA SẺ CHO NGƯỜI DÙNG MỚI', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nhập email người nhận (VD: userb_viewer@gmail.com)',
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF38BDF8)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 8),

            // Gợi ý email kiểm thử
            Row(
              children: [
                const Text('Gợi ý test:', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('User B (Viewer)', style: TextStyle(fontSize: 11, color: Colors.amber)),
                  backgroundColor: const Color(0xFF1E293B),
                  onPressed: () => setState(() => _emailController.text = 'userb_viewer@gmail.com'),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('User C (Editor)', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
                  backgroundColor: const Color(0xFF1E293B),
                  onPressed: () => setState(() => _emailController.text = 'userc_editor@gmail.com'),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Mức quyền: Xem vs Sửa
            const Text('Mức quyền hạn truy cập:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Chỉ xem (Viewer)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Người nhận chỉ đọc tài liệu, không được phép sửa hay xóa', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    value: 'view',
                    groupValue: _permissionLevel,
                    activeColor: const Color(0xFF38BDF8),
                    onChanged: (val) => setState(() => _permissionLevel = val!),
                  ),
                  const Divider(height: 1, color: Color(0xFF334155)),
                  RadioListTile<String>(
                    title: const Text('Được chỉnh sửa (Editor)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Người nhận được quyền sửa nội dung, nhưng KHÔNG được xóa', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    value: 'edit',
                    groupValue: _permissionLevel,
                    activeColor: const Color(0xFF38BDF8),
                    onChanged: (val) => setState(() => _permissionLevel = val!),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSubmitting ? null : _share,
              icon: _isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.person_add_alt_1_rounded),
              label: Text(_isSubmitting ? 'Đang chia sẻ...' : 'Cấp quyền truy cập', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),

            const SizedBox(height: 28),

            // Danh sách người đã được chia sẻ
            const Text('DANH SÁCH ĐÃ ĐƯỢC CHIA SẺ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            if (_isLoadingList)
              const Center(child: CircularProgressIndicator())
            else if (_sharedUsers.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('Chưa có ai được chia sẻ tài liệu này.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ),
              )
            else
              ..._sharedUsers.map((item) {
                final isEdit = item.permissionLevel == 'edit';
                return Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isEdit ? const Color(0xFF38BDF8).withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                      child: Icon(isEdit ? Icons.edit : Icons.visibility, color: isEdit ? const Color(0xFF38BDF8) : Colors.amber, size: 18),
                    ),
                    title: Text(item.userEmail ?? item.userId, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(item.permissionLabel, style: TextStyle(color: isEdit ? const Color(0xFF38BDF8) : Colors.amber, fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                      tooltip: 'Thu hồi quyền',
                      onPressed: () => _revoke(item),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
