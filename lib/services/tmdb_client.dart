import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class TmdbClient {
  TmdbClient._internal();
  static final TmdbClient instance = TmdbClient._internal();

  String get _baseUrl => dotenv.env['TMDB_BASE_URL'] ?? 'https://api.themoviedb.org/3';
  String? get _apiKey => dotenv.env['TMDB_API_KEY'];
  String? get _readToken => dotenv.env['TMDB_READ_ACCESS_TOKEN'];

  Map<String, dynamic>? _configurationCache;

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
    };
    if (_readToken != null && _readToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_readToken';
    }
    return headers;
  }

  Uri _buildUri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(_baseUrl);
    final params = <String, String>{...?(query ?? {})};
    // If no bearer token, fall back to v3 api_key param.
    if ((_readToken == null || _readToken!.isEmpty) && _apiKey != null && _apiKey!.isNotEmpty) {
      params['api_key'] = _apiKey!;
    }
    return Uri(
      scheme: base.scheme,
      host: base.host,
      path: '${base.path}/$path'.replaceAll('//', '/'),
      queryParameters: params.isEmpty ? null : params,
    );
  }

  Future<Map<String, dynamic>> _getJson(String path, [Map<String, String>? query]) async {
    final uri = _buildUri(path, query);
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return json.decode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('TMDB request failed [${resp.statusCode}]: ${resp.body}');
  }

  // Basic endpoints
  Future<Map<String, dynamic>> getConfiguration() async {
    if (_configurationCache != null) return _configurationCache!;
    final cfg = await _getJson('configuration');
    _configurationCache = cfg;
    return cfg;
  }

  Future<List<Map<String, dynamic>>> getTrendingMovies({String timeWindow = 'day'}) async {
    final data = await _getJson('trending/movie/$timeWindow');
    final results = (data['results'] as List<dynamic>? ?? []);
    return results.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getPopularMovies({int page = 1}) async {
    final data = await _getJson('movie/popular', {
      'page': '$page',
      'language': 'en-US',
    });
    final results = (data['results'] as List<dynamic>? ?? []);
    return results.cast<Map<String, dynamic>>();
  }

  /// Discover movies released on a specific day, ordered by revenue (box office).
  /// Uses region-specific `release_date` boundaries to approximate daily box office.
  Future<List<Map<String, dynamic>>> getTopBoxOfficeForDate(DateTime date, {String region = 'US'}) async {
    String two(int v) => v.toString().padLeft(2, '0');
    final day = '${date.year}-${two(date.month)}-${two(date.day)}';
    final data = await _getJson('discover/movie', {
      'region': region,
      'release_date.gte': day,
      'release_date.lte': day,
      'include_adult': 'false',
      'include_video': 'false',
      'sort_by': 'revenue.desc',
      'language': 'en-US',
    });
    final results = (data['results'] as List<dynamic>? ?? []);
    return results.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> searchMovies(String query, {int page = 1}) async {
    final data = await _getJson('search/movie', {
      'query': query,
      'page': '$page',
      'include_adult': 'false',
      'language': 'en-US',
    });
    final results = (data['results'] as List<dynamic>? ?? []);
    return results.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getMovieVideos(int id) async {
    final data = await _getJson('movie/$id/videos', {
      'language': 'en-US',
    });
    final results = (data['results'] as List<dynamic>? ?? []);
    return results.cast<Map<String, dynamic>>();
  }

  String? youtubeThumbnail(String? key) {
    if (key == null || key.isEmpty) return null;
    return 'https://img.youtube.com/vi/$key/hqdefault.jpg';
  }

  Future<Map<String, dynamic>> getMovieDetails(int id) async {
    return _getJson('movie/$id', {
      'language': 'en-US',
    });
  }

  Future<Map<String, dynamic>> getMovieCredits(int id) async {
    return _getJson('movie/$id/credits');
  }

  Future<String?> posterUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    final cfg = await getConfiguration();
    final images = cfg['images'] as Map<String, dynamic>?;
    final base = (images?['secure_base_url'] as String?) ?? 'https://image.tmdb.org/t/p/';
    final sizes = (images?['poster_sizes'] as List<dynamic>?)?.cast<String>() ?? ['w500'];
    final size = sizes.contains('w500') ? 'w500' : sizes.last;
    return '$base$size$path';
  }

  Future<String?> backdropUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    final cfg = await getConfiguration();
    final images = cfg['images'] as Map<String, dynamic>?;
    final base = (images?['secure_base_url'] as String?) ?? 'https://image.tmdb.org/t/p/';
    final sizes = (images?['backdrop_sizes'] as List<dynamic>?)?.cast<String>() ?? ['w780'];
    final size = sizes.contains('w780') ? 'w780' : sizes.last;
    return '$base$size$path';
  }
}