import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'models.dart';
import 'public_api.dart';

typedef UserLoc = ({double lat, double lng});

/// Posição do usuário pra ordenar "perto de você". Pede a permissão de
/// localização na primeira vez. Retorna null se o GPS estiver desligado, a
/// permissão for negada, ou der timeout — a Home cai no fallback (ordem por
/// pedidos). Nunca lança.
final userLocationProvider = FutureProvider<UserLoc?>((ref) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return null;
    }
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 6));
    } catch (_) {
      // GPS lento/indoor (ou emulador): cai pra última posição conhecida.
      pos = await Geolocator.getLastKnownPosition();
    }
    if (pos == null) return null;
    return (lat: pos.latitude, lng: pos.longitude);
  } catch (_) {
    return null;
  }
});

/// Distância em km do usuário até o bar; null se faltam coordenadas.
double? distanceKm(UserLoc user, Establishment e) {
  final lat = e.lat, lng = e.lng;
  if (lat == null || lng == null) return null;
  return Geolocator.distanceBetween(user.lat, user.lng, lat, lng) / 1000;
}

/// Ordena os bares do mais perto pro mais longe; sem coords vão pro fim,
/// mantendo a ordem original (por pedidos). Se não há posição, devolve como veio.
List<Establishment> sortByDistance(List<Establishment> ests, UserLoc? user) {
  if (user == null) return ests;
  final list = [...ests];
  list.sort((a, b) {
    final da = distanceKm(user, a);
    final db = distanceKm(user, b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });
  return list;
}

/// "850 m" / "2,3 km" pra exibir no card.
String fmtDistance(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// "Bairro, Cidade" do usuário (reverse geocode via backend) pro header. Null
/// enquanto carrega, sem GPS, ou se o backend não resolver.
final userPlaceProvider = FutureProvider<String?>((ref) async {
  final loc = await ref.watch(userLocationProvider.future);
  if (loc == null) return null;
  try {
    return await ref.watch(publicApiProvider).reverseGeocode(loc.lat, loc.lng);
  } catch (_) {
    return null;
  }
});
