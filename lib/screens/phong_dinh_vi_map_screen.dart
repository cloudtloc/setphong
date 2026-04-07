import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/phong_dinh_vi.dart';
import '../services/phong_dinh_vi_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

class PhongDinhViMapScreen extends StatefulWidget {
  const PhongDinhViMapScreen({super.key});

  @override
  State<PhongDinhViMapScreen> createState() => _PhongDinhViMapScreenState();
}

class _PhongDinhViMapScreenState extends State<PhongDinhViMapScreen> {
  final PhongDinhViService _service = PhongDinhViService();
  final TextEditingController _phongIdController = TextEditingController();
  final TextEditingController _toaNhaIdController = TextEditingController();

  GoogleMapController? _mapController;
  LatLng? _selectedLatLng;
  double _banKinh = 20;
  MapType _mapType = MapType.normal;

  bool _loading = false;
  String? _message;
  bool _success = false;

  static const LatLng _defaultLatLng = LatLng(10.762622, 106.660172);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCurrentLocation();
    });
  }

  @override
  void dispose() {
    _phongIdController.dispose();
    _toaNhaIdController.dispose();
    super.dispose();
  }

  Future<void> _initCurrentLocation() async {
    try {
      var serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        permission = await Geolocator.checkPermission();
      }

      if (!serviceEnabled ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _message = 'Không thể lấy vị trí hiện tại. Bật GPS và cấp quyền vị trí.';
          _success = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLatLng = latLng;
        _message = null;
        _success = false;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 17),
      );
    } catch (e) {
      debugPrint('Get current location error: $e');
      setState(() {
        _message = 'Không lấy được vị trí hiện tại.';
        _success = false;
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _initCurrentLocation();
  }

  void _toggleMapType() {
    setState(() {
      _mapType =
          _mapType == MapType.normal ? MapType.satellite : MapType.normal;
    });
  }

  void _onTap(LatLng latLng) {
    setState(() {
      _selectedLatLng = latLng;
      _message = null;
      _success = false;
    });
  }

  Future<void> _submit() async {
    final phongId = int.tryParse(_phongIdController.text.trim());
    if (phongId == null) {
      setState(() {
        _message = 'Nhập mã phòng (số).';
        _success = false;
      });
      return;
    }
    if (_selectedLatLng == null) {
      setState(() {
        _message = 'Chọn vị trí trên bản đồ.';
        _success = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
      _success = false;
    });

    try {
      final toaNhaId = int.tryParse(_toaNhaIdController.text.trim());

      final existing = await _service.getPhong(phongId);
      if (existing == null) {
        await _service.createPhong(
          PhongDinhVi(
            phongId: phongId,
            long: _selectedLatLng!.longitude,
            lat: _selectedLatLng!.latitude,
            banKinh: _banKinh,
            toaNhaId: toaNhaId,
          ),
        );
      } else {
        await _service.updateLocation(
          phongId: phongId,
          long: _selectedLatLng!.longitude,
          lat: _selectedLatLng!.latitude,
          banKinh: _banKinh,
        );
      }

      setState(() {
        _loading = false;
        _success = true;
        _message = 'Lưu vị trí phòng thành công.';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _success = false;
        _message = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thiết lập vị trí phòng'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Thông tin phòng',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _phongIdController,
                  decoration: const InputDecoration(
                    labelText: 'Mã phòng',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _toaNhaIdController,
                  decoration: const InputDecoration(
                    labelText: 'Mã tòa nhà (tùy chọn)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Bán kính cho phép (mét)',
                  style: theme.textTheme.titleSmall,
                ),
                Slider(
                  min: 5,
                  max: 100,
                  divisions: 19,
                  value: _banKinh,
                  label: _banKinh.toStringAsFixed(0),
                  onChanged: (v) {
                    setState(() {
                      _banKinh = v;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: const CameraPosition(
                    target: _defaultLatLng,
                    zoom: 15,
                  ),
                  onTap: _onTap,
                  myLocationEnabled: true,
                  mapType: _mapType,
                  markers: {
                    if (_selectedLatLng != null)
                      Marker(
                        markerId: const MarkerId('phong'),
                        position: _selectedLatLng!,
                      ),
                  },
                  circles: {
                    if (_selectedLatLng != null)
                      Circle(
                        circleId: const CircleId('phong-radius'),
                        center: _selectedLatLng!,
                        radius: _banKinh,
                        strokeWidth: 2,
                        strokeColor:
                            theme.colorScheme.primary.withValues(alpha: 0.85),
                        fillColor:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                      ),
                  },
                ),
              ),
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _loading ? null : _initCurrentLocation,
                        child: const Text('Về vị trí hiện tại'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _loading ? null : _toggleMapType,
                        child: Text(
                          _mapType == MapType.normal
                              ? 'Chế độ vệ tinh'
                              : 'Chế độ thường',
                        ),
                      ),
                    ),
                  ],
                ),
                if (_message != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppStatusBanner(
                    positive: _success,
                    child: Text(
                      _message!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Lưu vị trí phòng'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
