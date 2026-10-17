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

enum MapStyle {
  googleStreet(
    name: 'Google Maps (Mặc định)',
    url: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
    subdomains: ['a', 'b', 'c', 'd'],
    fallbackUrl: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
    icon: Icons.map_outlined,
  ),
  cartoVoyager(
    name: 'Đường phố (Carto)',
    url: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
    subdomains: ['a', 'b', 'c', 'd'],
    fallbackUrl: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
    icon: Icons.directions_outlined,
  ),
  googleSatellite(
    name: 'Vệ tinh (Google Satellite)',
    url: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
    subdomains: ['a', 'b', 'c', 'd'],
    fallbackUrl: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    icon: Icons.satellite_alt_outlined,
  ),
  cartoDark(
    name: 'Chế độ Tối (Dark Map)',
    url: 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
    subdomains: ['a', 'b', 'c', 'd'],
    fallbackUrl: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
    icon: Icons.dark_mode_outlined,
  );

  final String name;
  final String url;
  final List<String> subdomains;
  final String fallbackUrl;
  final IconData icon;

  const MapStyle({
    required this.name,
    required this.url,
    required this.subdomains,
    required this.fallbackUrl,
    required this.icon,
  });
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
  MapStyle _currentStyle = MapStyle.googleStreet;

  // Tọa độ mặc định (Hà Nội: 21.0285, 105.8542)
  static const LatLng _defaultCenter = LatLng(21.0285, 105.8542);

  // Các địa điểm tiện ích để nhảy nhanh
  static const List<Map<String, dynamic>> _quickLocations = [
    {'name': 'Hà Nội', 'lat': 21.0285, 'lng': 105.8542},
    {'name': 'ĐH Thủy Lợi', 'lat': 21.0073, 'lng': 105.8249},
    {'name': 'ĐH Quốc Gia', 'lat': 21.0378, 'lng': 105.7820},
    {'name': 'Đà Nẵng', 'lat': 16.0544, 'lng': 108.2022},
    {'name': 'TP.HCM', 'lat': 10.7769, 'lng': 106.7009},
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLocation = widget.initialLocation;

    // Nếu chỉ có 1 tài liệu, tự động chọn tài liệu đó
    final docsWithLocation = widget.documents
        .where((d) => d.latitude != null && d.longitude != null)
        .toList();
    if (docsWithLocation.length == 1) {
      _selectedDoc = docsWithLocation.first;
    }
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

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  void _recenterMap() {
    final center = _calculateInitialCenter();
    _mapController.move(center, 15.0);
  }

  void _pickCurrentCenter() {
    setState(() {
      _selectedLocation = _mapController.camera.center;
    });
  }

  Future<void> _openInGoogleMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) await launchUrl(uri);
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
          isPicker
              ? 'Ghim vị trí tài liệu trên bản đồ'
              : 'Bản đồ vị trí tài liệu (${docsWithLocation.length})',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Menu đổi kiểu bản đồ
          PopupMenuButton<MapStyle>(
            tooltip: 'Đổi kiểu bản đồ',
            icon: const Icon(Icons.layers_rounded, color: Color(0xFF38BDF8)),
            color: const Color(0xFF1E293B),
            onSelected: (style) => setState(() => _currentStyle = style),
            itemBuilder: (ctx) => MapStyle.values.map((style) {
              final isSelected = style == _currentStyle;
              return PopupMenuItem<MapStyle>(
                value: style,
                child: Row(
                  children: [
                    Icon(style.icon, size: 18, color: isSelected ? const Color(0xFF38BDF8) : Colors.white70),
                    const SizedBox(width: 10),
                    Text(
                      style.name,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          if (isPicker && _selectedLocation != null)
            TextButton.icon(
              icon: const Icon(Icons.check, color: Color(0xFF10B981)),
              label: const Text('Xong', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(context, _selectedLocation),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Bản đồ chính
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 15.0,
              minZoom: 3.0,
              maxZoom: 19.0,
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
                key: ValueKey(_currentStyle),
                urlTemplate: _currentStyle.url,
                subdomains: _currentStyle.subdomains,
                fallbackUrl: _currentStyle.fallbackUrl,
                maxZoom: 19,
                userAgentPackageName: 'com.example.th1',
              ),

              // Marker ghim ở chế độ Picker
              if (isPicker && _selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 60,
                      height: 60,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFEF4444)),
                            ),
                            child: const Text(
                              'Vị trí ghim',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFEF4444),
                            size: 38,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

              // Markers các tài liệu ở chế độ View
              if (!isPicker)
                MarkerLayer(
                  markers: docsWithLocation.map((doc) {
                    final isSelected = _selectedDoc?.id == doc.id;
                    return Marker(
                      point: LatLng(doc.latitude!, doc.longitude!),
                      width: isSelected ? 80 : 54,
                      height: isSelected ? 80 : 54,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedDoc = doc);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isSelected ? Colors.white : const Color(0xFF38BDF8),
                                ),
                              ),
                              child: Text(
                                doc.subject,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 2),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.all(isSelected ? 6 : 4),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : const Color(0xFF38BDF8),
                                  width: isSelected ? 3 : 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.menu_book_rounded,
                                size: isSelected ? 24 : 18,
                                color: isSelected ? Colors.white : const Color(0xFF38BDF8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // Bản quyền bản đồ
              SimpleAttributionWidget(
                source: Text(
                  _currentStyle.name,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ),
            ],
          ),

          // Thanh công cụ nhảy nhanh địa điểm (Quick jump)
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.near_me_rounded, size: 14, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 4),
                        const Text('Đến nhanh:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        const SizedBox(width: 6),
                        ..._quickLocations.map((loc) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ActionChip(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              backgroundColor: const Color(0xFF0F172A),
                              side: const BorderSide(color: Color(0xFF38BDF8)),
                              label: Text(
                                loc['name'] as String,
                                style: const TextStyle(fontSize: 11, color: Colors.white),
                              ),
                              onPressed: () {
                                final point = LatLng(loc['lat'] as double, loc['lng'] as double);
                                _mapController.move(point, 16.0);
                                if (isPicker) {
                                  setState(() => _selectedLocation = point);
                                }
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Nút điều khiển Zoom và Vị trí tâm (Floating controls)
          Positioned(
            right: 14,
            top: 60,
            child: Column(
              children: [
                _buildMapControlBtn(
                  icon: Icons.add,
                  tooltip: 'Phóng to (+)',
                  onPressed: _zoomIn,
                ),
                const SizedBox(height: 6),
                _buildMapControlBtn(
                  icon: Icons.remove,
                  tooltip: 'Thu nhỏ (-)',
                  onPressed: _zoomOut,
                ),
                const SizedBox(height: 6),
                _buildMapControlBtn(
                  icon: Icons.center_focus_strong_rounded,
                  tooltip: 'Về vị trí tài liệu',
                  onPressed: _recenterMap,
                ),
                if (isPicker) ...[
                  const SizedBox(height: 6),
                  _buildMapControlBtn(
                    icon: Icons.my_location_rounded,
                    tooltip: 'Ghim tại tâm bản đồ',
                    color: const Color(0xFF10B981),
                    onPressed: _pickCurrentCenter,
                  ),
                ],
              ],
            ),
          ),

          // Thông báo nếu không có tài liệu nào có GPS ở chế độ View
          if (!isPicker && docsWithLocation.isEmpty)
            Positioned(
              top: 64,
              left: 16,
              right: 64,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chưa có tài liệu nào có tọa độ GPS. Hãy vào Chi tiết tài liệu hoặc Tải lên mới để ghim vị trí.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Thanh hiển thị tọa độ ở chế độ Picker
          if (isPicker)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF38BDF8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.touch_app_rounded, color: Color(0xFF38BDF8), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedLocation == null
                                    ? 'Chạm vào bất kỳ điểm nào trên bản đồ'
                                    : 'Tọa độ GPS đã chọn:',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _selectedLocation == null
                                    ? 'Hoặc bấm "Ghim tại tâm" ở cột nút bên phải'
                                    : 'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                  color: _selectedLocation == null ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
                                  fontSize: 12,
                                  fontFamily: _selectedLocation == null ? null : 'monospace',
                                  fontWeight: _selectedLocation == null ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_selectedLocation != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(context, _selectedLocation),
                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                          label: const Text(
                            'Xác nhận vị trí GPS này',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Bottom card hiển thị thông tin chi tiết tài liệu khi click marker
          if (!isPicker && _selectedDoc != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildDocDetailCard(_selectedDoc!),
            ),
        ],
      ),
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        shape: BoxShape.circle,
        border: Border.all(color: color ?? const Color(0xFF38BDF8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: color ?? const Color(0xFF38BDF8)),
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
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
                    color: const Color(0xFF0284C7).withValues(alpha: 0.2),
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
            if (doc.latitude != null && doc.longitude != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.gps_fixed_rounded, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(
                    'Tọa độ: ${doc.latitude!.toStringAsFixed(5)}, ${doc.longitude!.toStringAsFixed(5)}',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontFamily: 'monospace'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.directions_rounded, size: 14, color: Color(0xFF38BDF8)),
                    label: const Text('Chỉ đường', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
                    onPressed: () => _openInGoogleMaps(doc.latitude!, doc.longitude!),
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
