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
  static const _radiusMeters = 2500;

  // Mirrors do Overpass (ordem de tentativa)
  static const List<String> _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.openstreetmap.ru/api/interpreter',
  ];

  final _mapController = MapController();
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'User-Agent': 'meditrack-app/1.0'},
  ));

  Position? _pos;
  List<Pharmacy> _results = [];
  bool _loading = true;
  String? _error;

  // Retry contínuo
  bool _retrying = false;
  bool _stopRequested = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _load(); // tentativa única inicial
  }

  Future<void> _openDirections(Pharmacy p) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lng}&travelmode=driving',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
  }

  Future<void> _load({bool untilSuccess = false}) async {
    _stopRequested = false;
    _attempt = 0;

    setState(() {
      _retrying = untilSuccess;
      _loading = true;
      _error = null;
      _results = [];
    });

    while (mounted && !_stopRequested) {
      try {
        // 1) Permissão + localização
        final hasPerm = await _ensurePermission();
        if (!hasPerm) {
          throw 'Permissão de localização negada/desativada.';
        }

        // Move provisoriamente pro last known (UX melhor) enquanto busca atual
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && mounted) {
          _pos = last;
          _mapController.move(LatLng(last.latitude, last.longitude), 14);
        }

        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _pos = pos;

        // 2) Busca farmácias via Overpass
        final list = await _fetchPharmacies(pos.latitude, pos.longitude, _radiusMeters)
          ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

        // 3) Sucesso — sai do loop
        if (!mounted) return;
        setState(() {
          _results = list;
          _loading = false;
          _retrying = false;
          _error = null;
        });

        _mapController.move(LatLng(pos.latitude, pos.longitude), 14);
        return;
      } catch (e) {
        _attempt++;
        if (!untilSuccess) {
          // tentativa única
          if (!mounted) return;
          setState(() {
            _loading = false;
            _retrying = false;
            _error = 'Não foi possível buscar farmácias reais. ${e.toString()}';
          });
          return;
        }

        // retry contínuo com backoff (1,2,4,8,16,30,30…)
        final secs = [1, 2, 4, 8, 16, 30];
        final idx = _attempt - 1 >= secs.length ? secs.length - 1 : _attempt - 1;
        final delay = Duration(seconds: secs[idx]);

        if (!mounted || _stopRequested) return;
        setState(() {
          _loading = true; // mantém spinner
          _error =
              'Tentando novamente em ${delay.inSeconds}s (tentativa $_attempt)… ${e.toString()}';
        });
        await Future.delayed(delay);
        // volta ao loop
      }
    }

    // Cancelado manualmente
    if (mounted) {
      setState(() {
        _loading = false;
        _retrying = false;
      });
    }
  }

  Future<bool> _ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      perm = await Geolocator.checkPermission();
    }
    return perm == LocationPermission.whileInUse || perm == LocationPermission.always;
  }

  Future<Response> _postOverpass(String endpoint, String query) {
    return _dio.post(
      endpoint,
      data: query,
      options: Options(
        responseType: ResponseType.json,
        headers: const {
          'Content-Type': 'text/plain; charset=UTF-8',
          'Accept-Encoding': 'gzip',
        },
      ),
    );
  }

  Future<List<Pharmacy>> _fetchPharmacies(double lat, double lng, int radius) async {
    final q = """
[out:json][timeout:30];
(
  node["amenity"="pharmacy"](around:$radius,$lat,$lng);
  way["amenity"="pharmacy"](around:$radius,$lat,$lng);
  relation["amenity"="pharmacy"](around:$radius,$lat,$lng);
  node["shop"="chemist"](around:$radius,$lat,$lng);
  way["shop"="chemist"](around:$radius,$lat,$lng);
  relation["shop"="chemist"](around:$radius,$lat,$lng);
);
out center tags;
""";

    Response? res;
    DioException? lastErr;

    // tenta cada endpoint com pequeno backoff
    for (final ep in _overpassEndpoints) {
      try {
        res = await _postOverpass(ep, q);
        break;
      } on DioException catch (e) {
        lastErr = e;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    if (res == null) {
      throw lastErr ?? Exception('Falha ao consultar Overpass.');
    }

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
    void add(dynamic v) {
      if (v is String && v.trim().isNotEmpty) parts.add(v.trim());
    }

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
        actions: [
          if (_retrying)
            IconButton(
              tooltip: 'Parar',
              onPressed: () => setState(() => _stopRequested = true),
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
            )
          else
            IconButton(
              tooltip: 'Tentar continuamente',
              onPressed: () => _load(untilSuccess: true),
              icon: const Icon(Icons.autorenew_outlined, color: Colors.black87),
            ),
          IconButton(
            tooltip: 'Atualizar (1x)',
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh_outlined, color: Colors.black87),
          ),
        ],
      ),
      body: _loading
          ? Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _InfoBanner(
                      text: _error!,
                      onClose: () => setState(() => _error = null),
                    ),
                  ),
                const Expanded(child: Center(child: CircularProgressIndicator())),
              ],
            )
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
                  height: 300,
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
                            : const LatLng(-23.5505, -46.6333),
                        initialZoom: 14,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                          userAgentPackageName: 'com.meditrack.app',
                        ),
                        MarkerLayer(markers: markers),
                        RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution(
                              '© OpenStreetMap contributors',
                              onTap: () => launchUrl(
                                Uri.parse('https://www.openstreetmap.org/copyright'),
                                mode: LaunchMode.externalApplication,
                              ),
                            ),
                          ],
                        ),
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
                    ],
                  ),
                ),

                // LISTA
                Expanded(
                  child: _results.isEmpty
                      ? Center(
                          child: Text(
                            _error == null
                                ? 'Nenhuma farmácia encontrada neste raio.'
                                : 'Falha ao carregar.\n${_error!}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(color: Colors.black54),
                          ),
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
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
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              p.address ?? 'Endereço indisponível',
              style: GoogleFonts.poppins(color: const Color(0xFF6B6B75)),
            ),
            const SizedBox(height: 8),
            Text(
              '${(p.distanceMeters / 1000).toStringAsFixed(2)} km de você',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 12),
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
        color: const Color(0xFFFFF8E1),
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
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    return tooltip == null ? dot : Tooltip(message: tooltip!, child: dot);
  }
}
