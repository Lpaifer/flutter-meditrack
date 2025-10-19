import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_meditrack/ui/input_styles.dart';
import 'package:url_launcher/url_launcher.dart';


class Pharmacy {
  final String name;
  final String? address;
  final double lat;
  final double lng;
  final double distanceMeters;

  Pharmacy({
    required this.name,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    this.address,
  });
}

class NearbyPharmaciesPage extends StatefulWidget {
  const NearbyPharmaciesPage({super.key});

  @override
  State<NearbyPharmaciesPage> createState() => _NearbyPharmaciesPageState();
}

class _NearbyPharmaciesPageState extends State<NearbyPharmaciesPage> {
  static const _radiusMeters = 2500; // raio de busca
  static const _overpassUrl = 'https://overpass-api.de/api/interpreter';

  final _mapController = MapController();
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 12),
    headers: {'User-Agent': 'meditrack-app/1.0'},
  ));

  Position? _pos;
  List<Pharmacy> _results = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openDirections(Pharmacy p) async {
  // rota direta no Google Maps (abre app se disponível ou o navegador)
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lng}&travelmode=driving',
  );
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    // fallback: abre em uma aba do app
    await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  }
}

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // 1) Permissão + localização
      final hasPerm = await _ensurePermission();
      if (!hasPerm) {
        throw 'Permissão de localização negada.';
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _pos = pos;

      // 2) Busca farmácias via Overpass
      final list = await _fetchPharmacies(pos.latitude, pos.longitude, _radiusMeters);

      // 3) Ordena por distância
      list.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

      setState(() {
        _results = list;
        _loading = false;
      });

      // centraliza o mapa
      _mapController.move(LatLng(pos.latitude, pos.longitude), 14);
    } catch (e) {
      // fallback mock se falhar
      if (_pos != null) {
        setState(() {
          _results = _mockAround(_pos!.latitude, _pos!.longitude);
          _loading = false;
          _error = 'Não foi possível buscar farmácias reais. Exibindo mock.';
        });
      } else {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<bool> _ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Tenta ao menos pedir pro usuário ligar localização
      return false;
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  List<Pharmacy> _mockAround(double lat, double lng) {
    final rnd = Random();
    final offsets = List.generate(6, (i) => (rnd.nextDouble() - 0.5) * 0.02);
    final names = [
      'Farmácia Central',
      'Drogaria Popular',
      'Bem+ Saúde',
      'Droga Rápida',
      'Vida Farma',
      'Saúde+'
    ];
    final distance = const Distance();
    return List.generate(6, (i) {
      final dLat = offsets[i];
      final dLng = offsets[(i + 2) % offsets.length];
      final p = LatLng(lat + dLat, lng + dLng);
      final dist = distance(LatLng(lat, lng), p); // em metros
      return Pharmacy(
        name: names[i],
        address: 'Endereço mock ${i + 1}',
        lat: p.latitude,
        lng: p.longitude,
        distanceMeters: dist,
      );
    });
  }

  Future<List<Pharmacy>> _fetchPharmacies(double lat, double lng, int radius) async {
    final q = """
[out:json][timeout:25];
(
  node["amenity"="pharmacy"](around:$radius,$lat,$lng);
  way["amenity"="pharmacy"](around:$radius,$lat,$lng);
  relation["amenity"="pharmacy"](around:$radius,$lat,$lng);
);
out center tags;
""";
    final res = await _dio.post(_overpassUrl, data: q);
    final elements = (res.data?['elements'] as List?) ?? [];

    final distanceCalc = const Distance();
    final list = <Pharmacy>[];

    for (final e in elements) {
      if (e is! Map) continue;
      final type = e['type'];
      double? pLat;
      double? pLng;

      if (type == 'node') {
        pLat = (e['lat'] as num?)?.toDouble();
        pLng = (e['lon'] as num?)?.toDouble();
      } else {
        final center = e['center'];
        pLat = (center?['lat'] as num?)?.toDouble();
        pLng = (center?['lon'] as num?)?.toDouble();
      }
      if (pLat == null || pLng == null) continue;

      final tags = (e['tags'] as Map?) ?? {};
      final name = (tags['name'] as String?)?.trim().isNotEmpty == true
          ? tags['name'] as String
          : 'Farmácia sem nome';
      final addr = _composeAddress(tags);

      final dist = distanceCalc(LatLng(lat, lng), LatLng(pLat, pLng));
      list.add(Pharmacy(
        name: name,
        address: addr,
        lat: pLat,
        lng: pLng,
        distanceMeters: dist,
      ));
    }
    return list;
  }

  String? _composeAddress(Map tags) {
    final parts = <String>[];
    void add(dynamic v) { if (v is String && v.trim().isNotEmpty) parts.add(v.trim()); }

    add(tags['addr:street']);
    add(tags['addr:housenumber']);
    add(tags['addr:neighbourhood']);
    add(tags['addr:city']);
    add(tags['addr:postcode']);
    return parts.isEmpty ? null : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final pos = _pos;
    final markers = <Marker>[
      if (pos != null)
        Marker(
          point: LatLng(pos.latitude, pos.longitude),
          width: 36,
          height: 36,
          child: const _Dot(color: Colors.blue, tooltip: 'Você'),
        ),
      ..._results.map((p) => Marker(
            point: LatLng(p.lat, p.lng),
            width: 32,
            height: 32,
            child: GestureDetector(
              onTap: () => _showPharmacy(p),
              child: const _Dot(color: AppColors.primary),
            ),
          )),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: Text(
          'MEDITRACK',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            letterSpacing: 0.6,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _InfoBanner(  
                      text: _error!,
                      onClose: () => setState(() => _error = null),
                    ),
                  ),
                // MAPA
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  height: 280,
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: pos != null
                            ? LatLng(pos.latitude, pos.longitude)
                            : const LatLng(-23.5505, -46.6333), // fallback SP
                        initialZoom: 14,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                          userAgentPackageName: 'com.meditrack.app',
                        ),
                        MarkerLayer(markers: markers),
                      ],
                    ),
                  ),
                ),

                // Cabeçalho + raio
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'FARMÁCIAS PERTO DE VOCÊ',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF656178),
                        ),
                      ),
                      const Spacer(),
                      Text('${(_radiusMeters / 1000).toStringAsFixed(1)} km',
                          style: GoogleFonts.poppins(color: const Color(0xFF6B6B75))),
                      IconButton(
                        tooltip: 'Atualizar',
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),

                // LISTA
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final p = _results[i];
                      return _PharmacyTile(
                        p: p,
                        onTap: () => _showPharmacy(p),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: (_pos != null)
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: () {
                _mapController.move(LatLng(_pos!.latitude, _pos!.longitude), 14);
              },
              icon: const Icon(Icons.my_location, color: Colors.white),
              label: Text('Minha posição', style: GoogleFonts.poppins(color: Colors.white)),
            )
          : null,
    );
  }

  void _showPharmacy(Pharmacy p) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // dentro de _showPharmacy(Pharmacy p), troque o Row atual por:
Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    FilledButton(
      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
      onPressed: () {
        Navigator.pop(context);
        _mapController.move(LatLng(p.lat, p.lng), 17);
      },
      child: Text('Ver no mapa', style: GoogleFonts.poppins(color: Colors.white)),
    ),
      // NOVO: abre rotas no Google Maps / navegador
      FilledButton.icon(
        onPressed: () async {
          Navigator.pop(context);
          await _openDirections(p);
        },
        icon: const Icon(Icons.directions_outlined),
        label: Text('Como chegar', style: GoogleFonts.poppins()),
      ),

      FilledButton.tonal(
        onPressed: () async {
          Navigator.pop(context);
          await _load();
        },
        child: Text('Atualizar', style: GoogleFonts.poppins()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PharmacyTile extends StatelessWidget {
  final Pharmacy p;
  final VoidCallback onTap;
  const _PharmacyTile({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: const CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Icon(Icons.local_pharmacy, color: Colors.white),
        ),
        title: Text(p.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        subtitle: Text(
          p.address ?? 'Endereço indisponível',
          style: GoogleFonts.poppins(color: const Color(0xFF6B6B75)),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '${(p.distanceMeters / 1000).toStringAsFixed(2)} km',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  final VoidCallback? onClose;

  const _InfoBanner({required this.text, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // amarelo clarinho
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFECB3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline, color: Color(0xFF8A6D3B)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                color: const Color(0xFF8A6D3B),
                height: 1.25,
              ),
            ),
          ),
          if (onClose != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.close, size: 20, color: Color(0xFF8A6D3B)),
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}


class _Dot extends StatelessWidget {
  final Color color;
  final String? tooltip;
  const _Dot({required this.color, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    return Tooltip(message: tooltip ?? '', child: dot);
  }
}
