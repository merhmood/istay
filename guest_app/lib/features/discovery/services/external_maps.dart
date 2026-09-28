import 'dart:io' show Platform;

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands a listing's location off to the app best suited to the job.
///
/// Our own map is for browsing - where is this, what's nearby, how far. Getting
/// there is a different problem, and most guests are taking a ride rather than
/// driving themselves.
///
/// The goal for every ride app here is the same: the guest lands on a
/// confirm-and-pay screen with the destination already set, never on a blank
/// "Where to?" search box. Which URL achieves that is app-specific and was
/// settled by testing on a real device, not by reading documentation - see
/// [openBolt] in particular, whose documented format does not work.
class ExternalMaps {
  ExternalMaps._();

  /// Android package names, needed both for store fallbacks and for the
  /// `<queries>` declarations that make the apps visible to us on Android 11+.
  static const boltPackage = 'ee.mtakso.client';
  static const uberPackage = 'com.ubercab';
  static const inDrivePackage = 'sinet.startup.inDriver';
  static const googleMapsPackage = 'com.google.android.apps.maps';

  /// A human-readable destination for the driver, e.g.
  /// "Opposite Yabatech main gate, Herbert Macaulay, Lagos, Nigeria".
  static String formatAddress({
    required String landmark,
    required String city,
    String country = 'Nigeria',
  }) {
    final parts = [landmark.trim(), city.trim(), country]..removeWhere((part) => part.isEmpty);
    return parts.join(', ');
  }

  /// Opens the location in Google Maps for directions.
  static Future<bool> openGoogleMaps({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final coordinates = '$latitude,$longitude';
    return _launchFirst([
      // iOS Google Maps app.
      Uri.parse('comgooglemaps://?daddr=$coordinates&directionsmode=driving'),
      // Universal link: opens the Google Maps app when installed, the site if not.
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$coordinates'),
      // Last resort - whatever map app the device has.
      Uri.parse('geo:$coordinates?q=$coordinates'),
    ]);
  }

  /// Opens Bolt on its "Confirm destination" screen with the listing already set.
  ///
  /// Bolt's own `bolt://action/setPickup?destination[latitude]=...` format is
  /// widely quoted online and **does not work**: tested against the current app
  /// it opens on the blank "Where to?" home screen, and the `m.bolt.eu`
  /// universal link is worse, bouncing to bolt.eu marketing in a browser.
  /// Prefilling that way appears to need a registered partner campaign id.
  ///
  /// What does work is a plain `geo:` URI. Bolt's manifest registers the `geo:`
  /// scheme on its DeeplinkActivity precisely so a map app can hand a location
  /// over, and it reverse-geocodes the point itself - our test pin came up as
  /// "Transcorp Hilton Hotel, Entrance Aguiyi Ironsi Str" with a ₦8,900 fare and
  /// a Confirm button.
  ///
  /// The package must be named explicitly or Android raises an app chooser,
  /// which is exactly the extra step this is meant to remove.
  static Future<bool> openBolt({
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    if (await _openGeoIn(boltPackage, latitude, longitude)) return true;

    // Bolt absent or the geo handoff refused: fall back to the app scheme, then
    // the store. Copy the address so a manual entry is at least a paste.
    await copyAddress(address);
    return _launchFirst([
      Uri.parse('bolt://action/setPickup?pickup=my_location'),
      _storeUri(boltPackage),
    ]);
  }

  /// Opens Uber with the drop-off set.
  ///
  /// Uber's deep link is properly documented and long-lived, so it is tried
  /// first; `geo:` is the backstop in case a given build ignores it. Uber was
  /// not installed on the test device, so unlike Bolt this ordering is reasoned
  /// rather than observed.
  static Future<bool> openUber({
    required double latitude,
    required double longitude,
    required String address,
    String? nickname,
  }) async {
    final encodedAddress = Uri.encodeComponent(address);
    final encodedNickname = Uri.encodeComponent(nickname ?? address);
    final query =
        'action=setPickup&pickup=my_location'
        '&dropoff[latitude]=$latitude'
        '&dropoff[longitude]=$longitude'
        '&dropoff[nickname]=$encodedNickname'
        '&dropoff[formatted_address]=$encodedAddress';

    if (await _launchInPackage(uberPackage, 'uber://?$query')) return true;
    if (await _openGeoIn(uberPackage, latitude, longitude)) return true;

    // No app: m.uber.com/ul/ carries the same parameters into the mobile site.
    return _launchFirst([Uri.parse('https://m.uber.com/ul/?$query')]);
  }

  /// Opens inDrive with the destination set.
  ///
  /// inDrive publishes no deep-link parameters at all, so `geo:` is the only
  /// realistic route and is tried first. Not verifiable on the test device,
  /// which did not have inDrive installed, hence the clipboard fallback.
  static Future<bool> openInDrive({
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    if (await _openGeoIn(inDrivePackage, latitude, longitude)) return true;

    await copyAddress(address);
    return _launchFirst([
      Uri.parse('indrive://'),
      Uri.parse('indriver://'),
      _storeUri(inDrivePackage),
    ]);
  }

  /// Puts the address on the clipboard - the reliable fallback when a driver
  /// calls and needs to be told where to go.
  static Future<void> copyAddress(String address) =>
      Clipboard.setData(ClipboardData(text: address));

  /// Sends `geo:lat,lng?q=lat,lng` to one named app.
  ///
  /// The `q=` repeat is not redundant: bare `geo:lat,lng` only centres the map,
  /// whereas `q=` marks an actual destination, which is what a ride app needs
  /// in order to offer a fare.
  static Future<bool> _openGeoIn(String package, double latitude, double longitude) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final coordinates = '$latitude,$longitude';
    return _launchInPackage(package, 'geo:$coordinates?q=$coordinates');
  }

  /// Launches a URI into one specific app, so Android never raises a chooser.
  /// Returns false when that app is absent or cannot handle the URI.
  ///
  /// The action must be the platform's actual action string, not a Dart-style
  /// name - android_intent_plus has no `actionView` shorthand constant and
  /// passes whatever is given straight through to `new Intent(action)`.
  /// `'action_view'` silently resolved to nothing, so every Bolt handoff missed
  /// canResolveActivity and fell through to the bolt:// scheme, which is what a
  /// device test caught: Bolt kept opening on its own home screen instead of
  /// the destination-confirm screen a bare `am start -a android.intent.action.VIEW`
  /// reached from adb.
  static Future<bool> _launchInPackage(String package, String uri) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final intent = AndroidIntent(
      action: 'android.intent.action.VIEW',
      data: uri,
      package: package,
    );
    try {
      // Without this check a missing app throws instead of letting us fall back.
      // Nullable: the plugin returns null when it cannot answer, which we treat
      // as "no" so the caller moves on to its next candidate.
      if (await intent.canResolveActivity() != true) return false;
      await intent.launch();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Uri _storeUri(String package) =>
      Uri.parse('https://play.google.com/store/apps/details?id=$package');

  static Future<bool> _launchFirst(List<Uri> candidates) async {
    for (final uri in candidates) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return true;
      } catch (_) {
        // A missing handler for a custom scheme shouldn't stop the fallback.
      }
    }
    return false;
  }
}
