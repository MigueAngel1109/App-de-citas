// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js' as js;

Future<String?> fetchPlacePhotoFromJs(String query) {
  final completer = Completer<String?>();
  try {
    js.context.callMethod('getGooglePlacePhoto', [
      query,
      js.allowInterop((dynamic photoUrl) {
        if (!completer.isCompleted) {
          completer.complete(photoUrl?.toString());
        }
      }),
    ]);
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
