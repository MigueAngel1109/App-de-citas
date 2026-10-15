import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

@JS('getGooglePlacePhoto')
external void _getGooglePlacePhoto(JSString query, JSFunction callback);

@JS('searchGooglePlaceWeb')
external void _searchGooglePlaceWeb(JSString query, JSFunction callback);

Future<String?> fetchPlacePhotoFromJs(String query) {
  final completer = Completer<String?>();
  try {
    _getGooglePlacePhoto(
      query.toJS,
      ((JSString? photoUrl) {
        if (!completer.isCompleted) {
          completer.complete(photoUrl?.toDart);
        }
      }).toJS,
    );
    Future.delayed(const Duration(seconds: 4), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });
  } catch (e) {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  }
  return completer.future;
}

Future<Map<String, dynamic>?> fetchPlaceDetailsFromJs(String query) {
  final completer = Completer<Map<String, dynamic>?>();
  try {
    _searchGooglePlaceWeb(
      query.toJS,
      ((JSString? jsonResult) {
        if (!completer.isCompleted) {
          if (jsonResult != null) {
            try {
              final str = jsonResult.toDart;
              final decoded = json.decode(str) as Map<String, dynamic>;
              completer.complete(decoded);
              return;
            } catch (_) {}
          }
          completer.complete(null);
        }
      }).toJS,
    );
    Future.delayed(const Duration(seconds: 4), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });
  } catch (e) {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  }
  return completer.future;
}
