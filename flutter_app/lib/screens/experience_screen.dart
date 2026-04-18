import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/charts.dart';
import '../services/auth_service.dart';
import '../services/media_service.dart';
import '../widgets/media_player_widget.dart';
import '../providers/player_state_provider.dart';
import '../utils/toast_util.dart';
import '../l10n/app_localizations.dart';
import 'chart_detail_screen.dart';

/// Curated genre tags for the mood board (must align loosely with artist `genre` tags).
const List<String> kMoodGenrePalette = [
  'Pop',
  'Electronic',
  'Hip-Hop',
  'Rock',
  'Jazz',
  'R&B',
  'Indie',
  'Latin',
  'Afrobeat',
  'Classical',
  'Metal',
  'Country',
  'Soul',
  'Reggae',
  'K-Pop',
  'Folk',
];

/// Accent stripe / chip hues aligned with [kMoodGenrePalette] (same length).
const List<Color> kMoodGenreAccents = [
  Color(0xFFFF6B9D),
  Color(0xFF00D4FF),
  Color(0xFFFFB347),
  Color(0xFFE74C3C),
  Color(0xFF9B59B6),
  Color(0xFFFF6B81),
  Color(0xFF78E08F),
  Color(0xFFFFD93D),
  Color(0xFFE67E22),
  Color(0xFF74B9FF),
  Color(0xFF95A5A6),
  Color(0xFF3498DB),
  Color(0xFFF39C12),
  Color(0xFF1ABC9C),
  Color(0xFFFF71CE),
  Color(0xFFD4A574),
];

class ExperienceScreen extends StatefulWidget {
  final Color accent;
  /// Logged-in [user_role] == `guest`: entry funnel — no monetisation surfaces; conversion → NOIZE Listen.
  final bool isNoizeGuestTier;

  const ExperienceScreen({super.key, required this.accent, this.isNoizeGuestTier = false});

  @override
  State<ExperienceScreen> createState() => _ExperienceScreenState();
}

class _ExperienceScreenState extends State<ExperienceScreen> {
  final AuthService _auth = AuthService();
  final MediaService _media = MediaService();

  Map<String, dynamic> _expPrefs = {};
  List<String> _moodBoard = [];
  String _chartStyle = 'balanced';

  List<dynamic> _moodSongs = [];
  List<dynamic> _newReleases = [];
  List<dynamic> _trending = [];
  List<dynamic> _events = [];
  List<dynamic> _merch = [];

  bool _loading = true;
  bool _saving = false;

  Map<String, dynamic>? _currentlyPlayingSong;
  List<Map<String, dynamic>> _currentPlaylist = [];
  int _currentPlaylistIndex = -1;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      if (_auth.isLoggedIn) {
        final s = await _auth.getSettings();
        final exp = s['experience_preferences'];
        if (exp is Map) {
          _expPrefs = Map<String, dynamic>.from(exp);
          final mb = _expPrefs['mood_board_genres'];
          if (mb is List) {
            _moodBoard = mb.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
          }
          final cs = _expPrefs['chart_style']?.toString();
          if (cs != null && cs.isNotEmpty) _chartStyle = cs;
        }
      }
      await Future.wait([
        _loadMood(),
        _loadNewTrending(),
        _loadEventsMerch(),
      ]);
    } catch (_) {
      await _loadNewTrending();
      await _loadEventsMerch();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMood() async {
    if (!_auth.isLoggedIn) return;
    try {
      final list = await _media.getMoodForYou(limit: 24);
      if (mounted) setState(() => _moodSongs = list);
    } catch (_) {
      if (mounted) setState(() => _moodSongs = []);
    }
  }

  Future<void> _loadNewTrending() async {
    try {
      final nr = await _media.getExperienceNewReleases(limit: 20);
      final tr = await _media.getExperienceTrending(limit: 18);
      if (mounted) {
        setState(() {
          _newReleases = nr;
          _trending = tr;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadEventsMerch() async {
    try {
      final ev = await _media.getExperienceEvents(limit: 10);
      if (mounted) setState(() => _events = ev);
    } catch (_) {
      if (mounted) setState(() => _events = []);
    }
    if (!_auth.isLoggedIn) return;
    try {
      final m = await _media.getExperienceMerchFollowed(limit: 12);
      if (mounted) setState(() => _merch = m);
    } catch (_) {
      if (mounted) setState(() => _merch = []);
    }
  }

  void _onGuestSkipLimitReached() {
    showToast(
      AppLocalizations.of(context)?.guestSkipLimitReached ??
          'Skip limit reached. Upgrade to NOIZE Listen for unlimited skips.',
    );
  }

  void _expAdvanceNext() {
    if (_currentPlaylist.isEmpty) return;
    var i = _currentPlaylistIndex + 1;
    if (i >= _currentPlaylist.length) i = 0;
    setState(() {
      _currentPlaylistIndex = i;
      _currentlyPlayingSong = _currentPlaylist[i];
    });
  }

  void _expAdvancePrev() {
    if (_currentPlaylist.isEmpty) return;
    var i = _currentPlaylistIndex - 1;
    if (i < 0) i = _currentPlaylist.length - 1;
    setState(() {
      _currentPlaylistIndex = i;
      _currentlyPlayingSong = _currentPlaylist[i];
    });
  }

  Future<void> _persistExperience() async {
    if (!_auth.isLoggedIn) return;
    setState(() => _saving = true);
    try {
      final merged = Map<String, dynamic>.from(_expPrefs);
      merged['mood_board_genres'] = _moodBoard;
      merged['chart_style'] = _chartStyle;
      await _auth.updateSettings(experiencePreferences: merged);
      _expPrefs = merged;
      await _loadMood();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addGenre(String g) {
    if (_moodBoard.contains(g) || _moodBoard.length >= 10) return;
    setState(() => _moodBoard = [..._moodBoard, g]);
    _persistExperience();
  }

  void _removeGenre(String g) {
    setState(() => _moodBoard = _moodBoard.where((x) => x != g).toList());
    _persistExperience();
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final next = List<String>.from(_moodBoard);
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    setState(() => _moodBoard = next);
    _persistExperience();
  }

  Color _accentForGenre(String g) {
    final i = kMoodGenrePalette.indexOf(g);
    if (i >= 0 && i < kMoodGenreAccents.length) return kMoodGenreAccents[i];
    return widget.accent;
  }

  Widget _buildMoodBoardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    widget.accent.withValues(alpha: 0.25),
                    widget.accent.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: widget.accent.withValues(alpha: 0.35)),
              ),
              child: Icon(Icons.palette_outlined, color: widget.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mood board',
                    style: TextStyle(
                      color: widget.accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Stack genres in order — we bias discovery toward what you pick.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A2224),
                Color(0xFF121618),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_auth.isLoggedIn)
                _buildMoodSignOutCallout()
              else ...[
                if (_saving)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: widget.accent,
                        backgroundColor: Colors.grey.shade800,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Text(
                      'Your vibe',
                      style: TextStyle(
                        color: Colors.grey.shade200,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Text(
                        '${_moodBoard.length} / 10',
                        style: TextStyle(
                          color: _moodBoard.length >= 10 ? Colors.orange.shade200 : Colors.grey.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_moodBoard.isEmpty)
                  _buildMoodEmptyState()
                else
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: _onReorder,
                    children: [
                      for (int i = 0; i < _moodBoard.length; i++)
                        _buildMoodPriorityTile(i, _moodBoard[i]),
                    ],
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 18, color: widget.accent.withValues(alpha: 0.9)),
                    const SizedBox(width: 8),
                    Text(
                      'Add genres',
                      style: TextStyle(color: Colors.grey.shade300, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in kMoodGenrePalette)
                      if (!_moodBoard.contains(g)) _buildGenreAddChip(g),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMoodSignOutCallout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline, color: Colors.grey.shade500, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sign in to save your mood',
                style: TextStyle(color: Colors.grey.shade300, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Your picks sync across sessions and tune mood-based recommendations.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMoodEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.accent.withValues(alpha: 0.2), style: BorderStyle.solid),
        color: Colors.black.withValues(alpha: 0.2),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_outlined, size: 36, color: widget.accent.withValues(alpha: 0.85)),
          const SizedBox(height: 12),
          Text(
            'Start your stack',
            style: TextStyle(color: Colors.grey.shade200, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap a genre below — top items get the strongest signal.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodPriorityTile(int index, String genre) {
    final accent = _accentForGenre(genre);
    return Padding(
      key: ValueKey('mood_${genre}_$index'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF0D1012),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: accent),
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Center(
                        child: Icon(Icons.drag_indicator_rounded, color: Colors.grey.shade600, size: 22),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withValues(alpha: 0.2),
                              border: Border.all(color: accent.withValues(alpha: 0.45)),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              genre,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _removeGenre(genre),
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(Icons.close_rounded, color: Colors.grey.shade500, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenreAddChip(String g) {
    final accent = _accentForGenre(g);
    final disabled = _moodBoard.length >= 10;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : () => _addGenre(g),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1E2629),
                Color(0xFF151A1C),
              ],
            ),
            border: Border.all(
              color: disabled ? Colors.grey.shade800 : accent.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: disabled ? Colors.grey.shade700 : accent),
                ),
                const SizedBox(width: 8),
                Text(
                  g,
                  style: TextStyle(
                    color: disabled ? Colors.grey.shade600 : Colors.grey.shade200,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _artistLabel(Map<String, dynamic> song) {
    final a = song['artist'];
    if (a is Map) return a['channel_name']?.toString() ?? 'Unknown';
    return a?.toString() ?? 'Unknown';
  }

  bool _isVideo(String? contentType) {
    if (contentType == null) return false;
    return contentType.startsWith('video/');
  }

  void _playSong(Map<String, dynamic> song, List<dynamic> source) {
    final mod = song['moderation_status']?.toString().toLowerCase();
    if (mod == 'flagged') return;
    final playList = source.map((s) => s as Map<String, dynamic>).toList();
    final idx = playList.indexWhere((s) => s['r2_key'] == song['r2_key']);
    final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
    playerState.showMini();
    setState(() {
      _currentlyPlayingSong = song;
      _currentPlaylist = playList;
      _currentPlaylistIndex = idx >= 0 ? idx : 0;
    });
    playerState.initializeShuffle(playList, _currentPlaylistIndex);
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final u = Uri.tryParse(url);
    if (u == null) return;
    if (!await launchUrl(u, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF111414);
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF78E08F)));
    }

    return Container(
      color: bg,
      child: Stack(
      children: [
        RefreshIndicator(
          color: widget.accent,
          onRefresh: _bootstrap,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              Text(
                'Experience',
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Shape your mood, charts, and discovery',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildMoodBoardSection(),
              const SizedBox(height: 24),
              _sectionTitle('Chart mix', widget.accent),
              const SizedBox(height: 8),
              Text(
                'How Top 50 & charts blend new uploads vs trending heat.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'trending_only', label: Text('Trending'), icon: Icon(Icons.whatshot, size: 18)),
                  ButtonSegment(value: 'balanced', label: Text('Balanced'), icon: Icon(Icons.balance, size: 18)),
                  ButtonSegment(
                    value: 'new_music_heavy',
                    label: Text('New'),
                    icon: Icon(Icons.fiber_new, size: 18),
                  ),
                ],
                selected: {_chartStyle},
                onSelectionChanged: (s) {
                  if (!_auth.isLoggedIn) return;
                  setState(() => _chartStyle = s.first);
                  _persistExperience();
                },
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.black;
                    }
                    return Colors.white70;
                  }),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return widget.accent;
                    }
                    return Colors.grey.shade800;
                  }),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  final c = chartsCatalog.isNotEmpty ? chartsCatalog.first : null;
                  if (c == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChartDetailScreen(chart: c, chartStyle: _chartStyle),
                    ),
                  );
                },
                icon: const Icon(Icons.show_chart, color: Colors.white70),
                label: const Text('Open Top 50 with this mix'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Suggested for your mood', widget.accent),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: _moodSongs.isEmpty
                    ? Center(
                        child: Text(
                          _auth.isLoggedIn
                              ? 'Add genres or listen more — mood picks appear here.'
                              : 'Sign in for mood-based suggestions.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _moodSongs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final s = _moodSongs[i] as Map<String, dynamic>;
                          return _songCard(s, () => _playSong(s, _moodSongs), widget.accent);
                        },
                      ),
              ),
              const SizedBox(height: 24),
              _sectionTitle('New releases', widget.accent),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: _newReleases.isEmpty
                    ? Center(child: Text('No new tracks yet.', style: TextStyle(color: Colors.grey.shade600)))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _newReleases.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final s = _newReleases[i] as Map<String, dynamic>;
                          return _songCard(s, () => _playSong(s, _newReleases), widget.accent);
                        },
                      ),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Trending now', widget.accent),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: _trending.isEmpty
                    ? Center(child: Text('Trending will grow as people listen.', style: TextStyle(color: Colors.grey.shade600)))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _trending.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final s = _trending[i] as Map<String, dynamic>;
                          return _songCard(s, () => _playSong(s, _trending), widget.accent);
                        },
                      ),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Events & concerts', widget.accent),
              const SizedBox(height: 6),
              Text(
                'Top upcoming shows on NOIZE (soonest first).',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 10),
              if (_events.isEmpty)
                Text('No upcoming events listed yet.', style: TextStyle(color: Colors.grey.shade600))
              else
                ..._events.map((raw) {
                  final e = raw as Map<String, dynamic>;
                  final merch = (e['merch'] as List<dynamic>?) ?? [];
                  final artist = e['artist'] as Map<String, dynamic>? ?? {};
                  return Card(
                    color: Colors.grey.shade900,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e['title']?.toString() ?? 'Event', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            '${e['date'] ?? ''} · ${e['location'] ?? ''}',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          ),
                          if (artist['channel_name'] != null)
                            Text('Artist: ${artist['channel_name']}', style: TextStyle(color: widget.accent, fontSize: 13)),
                          const SizedBox(height: 8),
                          if (widget.isNoizeGuestTier)
                            Text(
                              AppLocalizations.of(context)?.noizeGuestExperienceNoMonetisation ??
                                  'Tickets, merch, and tipping are available with NOIZE Listen.',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              children: [
                                if (e['ticket_link'] != null && e['ticket_link'].toString().isNotEmpty)
                                  TextButton.icon(
                                    onPressed: () => _openUrl(e['ticket_link']?.toString()),
                                    icon: const Icon(Icons.confirmation_number, size: 18),
                                    label: const Text('Tickets'),
                                  ),
                                for (final m in merch)
                                  Builder(
                                    builder: (context) {
                                      final mm = Map<String, dynamic>.from(m as Map);
                                      return TextButton.icon(
                                        onPressed: () => _openUrl(mm['purchase_link']?.toString()),
                                        icon: const Icon(Icons.shopping_bag, size: 18),
                                        label: Text('Merch: ${mm['title'] ?? 'Shop'}'),
                                      );
                                    },
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 16),
              _sectionTitle('Merch from favourites', widget.accent),
              const SizedBox(height: 10),
              if (widget.isNoizeGuestTier)
                Text(
                  AppLocalizations.of(context)?.noizeGuestExperienceNoMonetisation ??
                      'Tickets, merch, and tipping are available with NOIZE Listen.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                )
              else if (!_auth.isLoggedIn)
                Text('Follow artists to see their store links here.', style: TextStyle(color: Colors.grey.shade600))
              else if (_merch.isEmpty)
                Text('No merchandise from followed artists yet.', style: TextStyle(color: Colors.grey.shade600))
              else
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _merch.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final m = _merch[i] as Map<String, dynamic>;
                      final img = m['image_url']?.toString();
                      return GestureDetector(
                        onTap: () => _openUrl(m['purchase_link']?.toString()),
                        child: Container(
                          width: 160,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade900,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade800),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  child: img != null && img.isNotEmpty
                                      ? Image.network(img, fit: BoxFit.cover, width: double.infinity)
                                      : Container(color: Colors.grey.shade800, child: Icon(Icons.storefront, color: widget.accent, size: 40)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m['title']?.toString() ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      m['artist'] is Map ? (m['artist']['channel_name'] ?? '') : '',
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        if (_currentlyPlayingSong != null)
          Consumer<PlayerStateProvider>(
            builder: (context, playerState, child) {
              if (playerState.isFull) return const SizedBox.shrink();
              return Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MediaPlayerWidget(
                  r2Key: _currentlyPlayingSong!['r2_key'],
                  title: _currentlyPlayingSong!['title'],
                  artist: _artistLabel(_currentlyPlayingSong!),
                  coverPhotoUrl: _currentlyPlayingSong!['cover_photo_url'],
                  contentType: _currentlyPlayingSong!['content_type'],
                  isVideo: _isVideo(_currentlyPlayingSong!['content_type']?.toString()),
                  playlist: _currentPlaylist,
                  currentIndex: _currentPlaylistIndex,
                  isMini: true,
                  moderationStatus: _currentlyPlayingSong!['moderation_status']?.toString(),
                  isNoizeGuest: widget.isNoizeGuestTier,
                  onQueueAdvanceWithoutSkip: _expAdvanceNext,
                  onNext: _expAdvanceNext,
                  onPrevious: _expAdvancePrev,
                  onGuestSkipLimitReached: _onGuestSkipLimitReached,
                  onClose: () {
                    playerState.hide();
                    setState(() {
                      _currentlyPlayingSong = null;
                      _currentPlaylist = [];
                      _currentPlaylistIndex = -1;
                    });
                  },
                  onSelectTrackIndex: (ix) {
                    if (ix < 0 || ix >= _currentPlaylist.length) return;
                    setState(() {
                      _currentPlaylistIndex = ix;
                      _currentlyPlayingSong = _currentPlaylist[ix];
                    });
                  },
                ),
              );
            },
          ),
      ],
    ),
    );
  }

  Widget _sectionTitle(String t, Color accent) {
    return Text(
      t,
      style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _songCard(Map<String, dynamic> s, VoidCallback onTap, Color accent) {
    final cover = s['cover_photo_url']?.toString();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade900,
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                child: cover != null && cover.isNotEmpty
                    ? Image.network(cover, fit: BoxFit.cover, width: double.infinity)
                    : Container(
                        color: Colors.grey.shade800,
                        child: Icon(Icons.music_note, color: accent, size: 36),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s['title']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _artistLabel(s),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
