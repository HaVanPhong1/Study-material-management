import 'package:flutter/material.dart';
import '../models/document_item.dart';
import '../services/document_service.dart';

class EditDocumentScreen extends StatefulWidget {
  final DocumentItem document;

  const EditDocumentScreen({super.key, required this.document});

  @override
  State<EditDocumentScreen> createState() => _EditDocumentScreenState();
}

class _EditDocumentScreenState extends State<EditDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _subjectController;
  late TextEditingController _authorController;
  late TextEditingController _yearController;
  late String _selectedDocType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.document.title);
    _subjectController = TextEditingController(text: widget.document.subject);
    _authorController = TextEditingController(text: widget.document.author);
    _yearController = TextEditingController(text: widget.document.year.toString());
    _selectedDocType = widget.document.docType;
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    final year = int.tryParse(_yearController.text.trim());
    if (year == null || year < 1900 || year > 2100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Năm phát hành không hợp lệ.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await DocumentService().updateDocument(
        documentId: widget.document.id,
        title: _titleController.text.trim(),
        subject: _subjectController.text.trim(),
        docType: _selectedDocType,
        author: _authorController.text.trim(),
        year: year,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật tài liệu thành công!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Row(
              children: [
                Icon(Icons.gpp_bad_rounded, color: Colors.redAccent),
                SizedBox(width: 8),
                Text('RLS BẢO MẬT CHẶN', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
              ],
            ),
            content: Text(e.toString(), style: const TextStyle(color: Colors.white)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đã hiểu')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Cập nhật tài liệu', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thông tin quyền hiện tại
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Quyền truy cập của bạn: ${widget.document.permissionLevel.toUpperCase()}',
                      style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Tiêu đề
              _buildTextField(
                controller: _titleController,
                label: 'Tiêu đề tài liệu *',
                validator: (val) => val == null || val.trim().isEmpty ? 'Nhập tiêu đề' : null,
              ),
              const SizedBox(height: 14),

              // Môn học
              _buildTextField(
                controller: _subjectController,
                label: 'Môn học *',
                validator: (val) => val == null || val.trim().isEmpty ? 'Nhập môn học' : null,
              ),
              const SizedBox(height: 14),

              // Loại tài liệu
              const Text('Loại tài liệu *', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedDocType,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(),
                items: const [
                  DropdownMenuItem(value: 'bai_giang', child: Text('Bài giảng')),
                  DropdownMenuItem(value: 'bai_tap', child: Text('Bài tập')),
                  DropdownMenuItem(value: 'tai_lieu_tham_khao', child: Text('Tài liệu tham khảo')),
                  DropdownMenuItem(value: 'de_thi', child: Text('Đề thi')),
                ],
                onChanged: (val) => setState(() => _selectedDocType = val!),
              ),
              const SizedBox(height: 14),

              // Tác giả & Năm
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _authorController,
                      label: 'Tác giả *',
                      validator: (val) => val == null || val.trim().isEmpty ? 'Nhập tác giả' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _buildTextField(
                      controller: _yearController,
                      label: 'Năm *',
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Nhập năm' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving ? null : _submitUpdate,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Đang lưu...' : 'Lưu thay đổi', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(),
          validator: validator,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF1E293B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
    );
  }
}
