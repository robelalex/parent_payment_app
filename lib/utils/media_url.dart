// lib/utils/media_url.dart
//
// Same job as the web's utils/imageUrl.js getMediaUrl(): the backend's
// photo fields (Student.photo, etc.) come back either as an already
// absolute Cloudinary URL, or as a relative Django media path — this
// makes sure whichever one we get turns into something Image.network()
// can actually load.
const String _backendRoot = 'https://felege-selam-payment-system.onrender.com';

String? mediaUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  return path.startsWith('/') ? '$_backendRoot$path' : '$_backendRoot/$path';
}
