import 'package:flutter/material.dart';
import '../services/tmdb_client.dart';

class MovieDetailPage extends StatefulWidget {
  final int id;
  const MovieDetailPage({super.key, required this.id});
  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  final _tmdb = TmdbClient.instance;
  Map<String, dynamic>? _details;
  Map<String, dynamic>? _credits;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await _tmdb.getMovieDetails(widget.id);
    final c = await _tmdb.getMovieCredits(widget.id);
    setState(() {
      _details = d;
      _credits = c;
      _loading = false;
    });
  }

  String _year(Map<String, dynamic> d) {
    final date = (d['release_date'] as String?) ?? '';
    return date.isNotEmpty ? date.split('-').first : '-';
  }

  String _runtime(Map<String, dynamic> d) {
    final mins = (d['runtime'] as int?) ?? 0;
    final h = mins ~/ 60, m = mins % 60;
    if (mins == 0) return '-';
    return '${h}h ${m}min';
  }

  String _director(Map<String, dynamic>? credits) {
    final crew = (credits?['crew'] as List<dynamic>? ?? []);
    final dir = crew.cast<Map<String, dynamic>>().firstWhere(
      (e) => (e['job'] as String?) == 'Director',
      orElse: () => {},
    );
    return (dir['name'] as String?) ?? '-';
  }

  List<String> _genres(Map<String, dynamic> d) {
    final gs = (d['genres'] as List<dynamic>? ?? []);
    return gs
        .map((e) => (e['name'] as String?) ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  double _rating(Map<String, dynamic> d) {
    final v = (d['vote_average'] as num?)?.toDouble() ?? 0.0;
    return (v / 2).clamp(0, 5);
  }

  Widget _buildBackdrop(String? path) {
    return FutureBuilder<String?>(
      future: _tmdb.backdropUrl(path),
      builder: (context, snap) {
        final url = snap.data;
        return Container(
          height: 320,
          decoration: BoxDecoration(
            color: Colors.black12,
            image: url != null
                ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                : null,
          ),
          child: SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> d) {
    final rating = _rating(d);
    return Positioned(
      bottom: -24,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (d['title'] as String?) ?? (d['name'] as String?) ?? '-',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'IMDb',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i + 1 <= rating ? Icons.star : Icons.star_border,
                  color: Colors.orange,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _infoTile('Year', _year(d)),
                _infoTile(
                  'Type',
                  _genres(d).isNotEmpty ? _genres(d).first : '-',
                ),
                _infoTile('Hour', _runtime(d)),
                _infoTile('Director', _director(_credits)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String title, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildGenres(List<String> genres) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: genres
          .map(
            (g) => Chip(label: Text(g), backgroundColor: Colors.grey.shade200),
          )
          .toList(),
    );
  }

  Widget _buildCast(Map<String, dynamic>? credits) {
    final cast = (credits?['cast'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .take(8)
        .toList();
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final c = cast[i];
          return Column(
            children: [
              FutureBuilder<String?>(
                future: _tmdb.posterUrl(c['profile_path'] as String?),
                builder: (context, snap) {
                  final url = snap.data;
                  return CircleAvatar(
                    radius: 28,
                    backgroundImage: url != null ? NetworkImage(url) : null,
                  );
                },
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 80,
                child: Text(
                  (c['name'] as String?) ?? '-',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: cast.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    return Scaffold(
      backgroundColor: Colors.white,
      body: _loading || details == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildBackdrop(details['backdrop_path'] as String?),
                      _buildInfoCard(details),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Plot Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (details['overview'] as String?) ?? '-',
                          style: const TextStyle(height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        _buildGenres(_genres(details)),
                        const SizedBox(height: 20),
                        const Text(
                          'Cast',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCast(_credits),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
