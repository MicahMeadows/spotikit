import 'package:flutter/foundation.dart';

@immutable
class AlbumImage {
  final String? url;
  final int? width;
  final int? height;

  const AlbumImage({this.url, this.width, this.height});

  factory AlbumImage.fromJson(Map<String, dynamic> json) {
    return AlbumImage(
      url: json['url'],
      width: json['width'],
      height: json['height'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'url': url, 'width': width, 'height': height};
  }

  @override
  String toString() => 'AlbumImage(${width}x$height,url: $url)';
}
