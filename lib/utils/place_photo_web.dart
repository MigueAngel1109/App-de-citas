import 'dart:async';
import 'dart:js_interop';

@JS('getGooglePlacePhoto')
external void _getGooglePlacePhoto(JSString query, JSFunction callback);

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
