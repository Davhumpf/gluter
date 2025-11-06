import 'dart:async';

import 'package:flutter/material.dart';
import '../services/tmdb_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'movie_detail_page.dart';

class TopMoviesPage extends StatefulWidget {
  const TopMoviesPage({super.key});

  @override
  State<TopMoviesPage> createState() => _TopMoviesPageState();
}

class _TopMoviesPageState extends State<TopMoviesPage> {
  final _tmdb = TmdbClient.instance;
  List<Map<String, dynamic>> _movies = [];
  List<Map<String, dynamic>> _trailers = [];
  List<Map<String, String>> _trailerVideos = [];
  String _query = '';
  bool _loading = true;
  Timer? _debounce;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    final byDay = await _tmdb.getTopBoxOfficeForDate(_selectedDate);
    final List<Map<String, dynamic>> items = byDay.isNotEmpty
        ? byDay
        : await _tmdb.getTrendingMovies(timeWindow: 'day');
    setState(() {
      _movies = items;
      _trailers = items;
      _loading = false;
    });
    _loadTrailersFrom(items.take(8).toList());
  }

  Future<void> _loadTrailersFrom(List<Map<String, dynamic>> items) async {
    final videosLists = await Future.wait(
      items.map((m) => _tmdb.getMovieVideos(m['id'] as int)),
    );
    final List<Map<String, String>> trailers = [];
    for (final vids in videosLists) {
      final yt = vids.firstWhere(
        (v) => (v['type'] == 'Trailer') && (v['site'] == 'YouTube'),
        orElse: () => {},
      );
      final key = yt['key'] as String?;
      if (key != null && key.isNotEmpty) {
        final thumb = _tmdb.youtubeThumbnail(key);
        trailers.add({'key': key, 'thumb': thumb ?? ''});
      }
    }
    setState(() => _trailerVideos = trailers);
  }

  void _onSearchChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (_query.trim().isEmpty) {
        _loadInitial();
      } else {
        setState(() => _loading = true);
        final results = await _tmdb.searchMovies(_query.trim());
        setState(() {
          _movies = results;
          _trailers = results;
          _loading = false;
        });
      }
    });
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: TextField(
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search',
          prefixIcon: const Icon(Icons.search, color: Colors.black87),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDayChips() {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.add(Duration(days: i - 1)));
    const weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fri', 'Sat', 'Sun'];
    return days.map((d) {
      final isSelected =
          d.year == _selectedDate.year &&
          d.month == _selectedDate.month &&
          d.day == _selectedDate.day;
      final labelTop = weekdays[d.weekday - 1];
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: InkWell(
          onTap: () async {
            setState(() => _selectedDate = d);
            await _loadInitial();
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: isSelected ? Colors.red : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  labelTop,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${d.day}',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Explore',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Top Movies',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovies() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Top del día',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
        SizedBox(
          height: 320,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final m = _movies[index];
              return FutureBuilder<String?>(
                future: _tmdb.posterUrl(m['poster_path'] as String?),
                builder: (context, snap) {
                  final url = snap.data;
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MovieDetailPage(id: m['id'] as int),
                      ),
                    ),
                    child: Container(
                      width: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        color: Colors.grey.shade200,
                        image: url != null
                            ? DecorationImage(
                                image: NetworkImage(url),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                    ),
                  );
                },
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemCount: _movies.length,
          ),
        ),
      ],
    );
  }

  Widget _buildTrailers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Trailers',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final item = _trailerVideos[index];
              final thumb = item['thumb'];
              return GestureDetector(
                onTap: () async {
                  final url = Uri.parse(
                    'https://www.youtube.com/watch?v=${item['key']}',
                  );
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                },
                child: Container(
                  width: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.grey.shade200,
                    image: (thumb != null && thumb.isNotEmpty)
                        ? DecorationImage(
                            image: NetworkImage(thumb),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: _trailerVideos.length,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          children: [
            _buildSearchBar(),
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: _buildDayChips()),
            ),
            const SizedBox(height: 12),
            _buildMovies(),
            const SizedBox(height: 12),
            _buildTrailers(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
