import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/document_item.dart';
import '../services/document_service.dart';

enum MapScreenMode {
  viewDocuments,
  pickLocation,
}

class MapScreen extends StatefulWidget {
  final MapScreenMode mode;
  final List<DocumentItem> documents;
  final LatLng? initialLocation;

  const MapScreen({
    super.key,
    this.mode = MapScreenMode.viewDocuments,
    this.documents = const [],
    this.initialLocation,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapController _mapController;
  LatLng? _selectedLocation;
  DocumentItem? _selectedDoc;
  bool _isDownloading = false;

  // Tọa độ mặc định (Hà Nội: 21.0285, 105.8542)
  static const LatLng _defaultCenter = LatLng(21.0285, 105.8542);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLocation = widget.initialLocation;
  }

  LatLng _calculateInitialCenter() {
    if (widget.initialLocation != null) {
      return widget.initialLocation!;
    }

    final docsWithLocation = widget.documents
        .where((d) => d.latitude != null && d.longitude != null)
        .toList();

    if (docsWithLocation.isNotEmpty) {
      final avgLat = docsWithLocation.map((d) => d.latitude!).reduce((a, b) => a + b) / docsWithLocation.length;
      final avgLng = docsWithLocation.map((d) => d.longitude!).reduce((a, b) => a + b) / docsWithLocation.length;
      return LatLng(avgLat, avgLng);
    }

    return _defaultCenter;
  }

  Future<void> _downloadFile(DocumentItem doc) async {
    final path = doc.storagePath;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tài liệu này không có tệp đính kèm.')),
      );
      return;
    }

    setState(() => _isDownloading = true);
    try {
      final signedUrl = await DocumentService().getDownloadUrl(path);
      final uri = Uri.parse(signedUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPicker = widget.mode == MapScreenMode.pickLocation;
    final initialCenter = _calculateInitialCenter();

    final docsWithLocation = widget.documents
        .where((d) => d.latitude != null && d.longitude != null)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          isPicker ? 'Chọn vị trí tài liệu trên bản đồ' : 'Bản đồ vị trí tài liệu vật lý (${docsWithLocation.length})',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isPicker && _selectedLocation != null)
            TextButton.icon(
              icon: const Icon(Icons.check, color: Color(0xFF10B981)),
              label: const Text('Xác nhận', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(context, _selectedLocation),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 14.0,
              onTap: (tapPosition, point) {
                if (isPicker) {
                  setState(() => _selectedLocation = point);
                } else {
                  setState(() => _selectedDoc = null);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.th1',
              ),
              // Layer Markers
              if (isPicker && _selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFFEF4444),
                        size: 46,
                      ),
                    ),
                  ],
                ),
              if (!isPicker)
                MarkerLayer(
                  markers: docsWithLocation.map((doc) {
                    final isSelected = _selectedDoc?.id == doc.id;
                    return Marker(
                      point: LatLng(doc.latitude!, doc.longitude!),
                      width: isSelected ? 60 : 44,
                      height: isSelected ? 60 : 44,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedDoc = doc);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : const Color(0xFF38BDF8),
                              width: isSelected ? 3 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            size: isSelected ? 28 : 20,
                            color: isSelected ? Colors.white : const Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),

          // Hướng dẫn ở chế độ Picker
          if (isPicker)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF38BDF8)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_rounded, color: Color(0xFF38BDF8), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedLocation == null
                            ? 'Chạm vào vị trí trên bản đồ để ghim tọa độ'
                            : 'Đã chọn: ${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom card hiển thị thông tin tài liệu khi click marker
          if (!isPicker && _selectedDoc != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildDocDetailCard(_selectedDoc!),
            ),
        ],
      ),
      floatingActionButton: isPicker
          ? (_selectedLocation != null
              ? FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF10B981),
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text('Lưu vị trí này', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  onPressed: () => Navigator.pop(context, _selectedLocation),
                )
              : null)
          : null,
    );
  }

  Widget _buildDocDetailCard(DocumentItem doc) {
    return Card(
      color: const Color(0xFF1E293B),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF38BDF8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF38BDF8)),
                  ),
                  child: Text(
                    doc.docTypeLabel,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _selectedDoc = null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              doc.title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${doc.subject} • Tác giả: ${doc.author} (${doc.year})',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            if (doc.locationLabel != null && doc.locationLabel!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.place_rounded, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Vị trí: ${doc.locationLabel}',
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
            if (doc.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: doc.tags.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('#$t', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10)),
                )).toList(),
              ),
            ],
            if (doc.storagePath != null && doc.storagePath!.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isDownloading ? null : () => _downloadFile(doc),
                  icon: _isDownloading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_rounded, size: 16),
                  label: Text(_isDownloading ? 'Đang mở tệp...' : 'Tải về / Mở tệp đính kèm'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
