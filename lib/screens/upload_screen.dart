import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/document_service.dart';
import 'map_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _authorController = TextEditingController();
  final _yearController = TextEditingController(text: DateTime.now().year.toString());
  final _tagsController = TextEditingController();
  final _locationController = TextEditingController();

  String _selectedDocType = 'bai_giang';
  Uint8List? _fileBytes;
  String? _fileName;
  bool _isUploading = false;
  LatLng? _selectedLatLng;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt', 'zip'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _fileBytes = file.bytes;
        _fileName = file.name;
        if (_titleController.text.isEmpty) {
          // Gợi ý tiêu đề từ tên file
          _titleController.text = file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
        }
      });
    }
  }

  Future<void> _submitUpload() async {
    if (!_formKey.currentState!.validate()) return;

    final year = int.tryParse(_yearController.text.trim());
    if (year == null || year < 1900 || year > 2100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Năm phát hành phải từ 1900 đến 2100.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      await DocumentService().createDocument(
        title: _titleController.text.trim(),
        subject: _subjectController.text.trim(),
        docType: _selectedDocType,
        author: _authorController.text.trim(),
        year: year,
        fileBytes: _fileBytes,
        fileName: _fileName,
        tags: parseTags(_tagsController.text),
        locationLabel: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        latitude: _selectedLatLng?.latitude,
        longitude: _selectedLatLng?.longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tải lên thành công (Supabase Storage + Database)'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải lên: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          mode: MapScreenMode.pickLocation,
          initialLocation: _selectedLatLng,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedLatLng = result;
        if (_locationController.text.trim().isEmpty) {
          _locationController.text = 'Tọa độ: ${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Tải lên tài liệu học tập', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Khu vực chọn file
              Card(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        _fileName != null ? Icons.insert_drive_file_rounded : Icons.cloud_upload_outlined,
                        size: 48,
                        color: _fileName != null ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _fileName ?? 'Chọn file tài liệu (PDF, Word, PPT...)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _fileName != null ? FontWeight.bold : FontWeight.normal,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF38BDF8),
                          side: const BorderSide(color: Color(0xFF38BDF8)),
                        ),
                        onPressed: _isUploading ? null : _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: Text(_fileName != null ? 'Đổi file khác' : 'Chọn tệp tin'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Tiêu đề
              _buildTextField(
                controller: _titleController,
                label: 'Tiêu đề tài liệu *',
                hint: 'VD: Giải tích 1 - Chương 3: Đạo hàm',
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tiêu đề' : null,
              ),

              const SizedBox(height: 14),

              // Môn học
              _buildTextField(
                controller: _subjectController,
                label: 'Môn học *',
                hint: 'VD: Toán cao cấp',
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập môn học' : null,
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
                      label: 'Tác giả / Giảng viên *',
                      hint: 'VD: Nguyễn Văn A',
                      validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tác giả' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _buildTextField(
                      controller: _yearController,
                      label: 'Năm *',
                      hint: '2025',
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Nhập năm' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Gắn thẻ (Tagging)
              _buildTextField(
                controller: _tagsController,
                label: 'Thẻ phân loại (cách nhau bằng dấu phẩy)',
                hint: 'VD: toan, dao-ham, giai-tich',
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('Gợi ý tag: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    ...['toan', 'lap-trinh', 'de-thi', 'giai-tich', 'mobile', 'ai'].map((tag) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(color: Color(0xFF334155)),
                          label: Text('#$tag', style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
                          onPressed: () {
                            final current = _tagsController.text.trim();
                            if (current.isEmpty) {
                              _tagsController.text = tag;
                            } else {
                              final existing = parseTags(current);
                              if (!existing.contains(tag)) {
                                _tagsController.text = '$current, $tag';
                              }
                            }
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Vị trí vật lý (Location)
              _buildTextField(
                controller: _locationController,
                label: 'Vị trí vật lý (kệ, phòng, thư viện)',
                hint: 'VD: Thư viện A1, kệ 3, ngăn 2',
              ),
              const SizedBox(height: 8),

              // Tọa độ bản đồ
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.map_outlined, size: 18, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 8),
                        const Text(
                          'Tọa độ GPS vật lý (Bản đồ):',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(color: Color(0xFF38BDF8)),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _pickLocationOnMap,
                          icon: const Icon(Icons.pin_drop_rounded, size: 15),
                          label: Text(_selectedLatLng != null ? 'Đổi tọa độ' : 'Ghim trên bản đồ'),
                        ),
                      ],
                    ),
                    if (_selectedLatLng != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                            ),
                            child: Text(
                              'Lat: ${_selectedLatLng!.latitude.toStringAsFixed(5)}, Lng: ${_selectedLatLng!.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontFamily: 'monospace'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                            tooltip: 'Xóa tọa độ',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => setState(() => _selectedLatLng = null),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Nút Tải lên
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isUploading ? null : _submitUpload,
                icon: _isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(
                  _isUploading ? 'Đang tải lên Cloud...' : 'Tải lên Supabase Storage & Database',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
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
    required String hint,
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
          decoration: _inputDecoration(hint: hint),
          validator: validator,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
    );
  }
}
