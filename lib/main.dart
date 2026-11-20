import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Hari Ini (versi 2) - catatan harian bergaya "midnight & gold"
//
// Isi:
//  - Latar aurora yang bergerak pelan
//  - Kartu kaca (glassmorphism)
//  - Judul berkilau (shimmer) + cincin progress
//  - Animasi masuk bertahap (staggered), confetti saat tugas selesai
//  - Game mini "Tangkap Kopi" di dalam daftar
//
// Semua data disimpan di memori (setState). Tanpa package tambahan.
// ---------------------------------------------------------------------------

// ----------------------------- Warna ---------------------------------------
const Color kBg = Color(0xFF0B0B12);
const Color kText = Color(0xFFF4EFE6);
const Color kGold = Color(0xFFE3C17A);
const Color kGoldDark = Color(0xFFB8893B);
const Color kGoldLight = Color(0xFFFFF1C9);

const LinearGradient kGoldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF1D590), Color(0xFFC79A45)],
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: kBg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const HariIniApp());
}

class HariIniApp extends StatelessWidget {
  const HariIniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hari Ini',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kGold,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: kBg,
      ),
      home: const TaskPage(),
    );
  }
}

// ----------------------------- Model ---------------------------------------

class Task {
  Task({
    required this.id,
    required this.title,
    required this.createdAt,
    this.done = false,
  });

  final int id;
  final String title;
  final DateTime createdAt;
  bool done;
}

enum Filter { semua, belum, selesai }

// ----------------------------- Halaman utama -------------------------------

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final GlobalKey<ConfettiLayerState> _confetti = GlobalKey();

  late final List<Task> _tasks = [
    Task(id: 1, title: 'Kerjain tugas Flutter', createdAt: DateTime.now()),
    Task(
      id: 2,
      title: 'Beli kopi susu',
      createdAt: DateTime.now(),
      done: true,
    ),
    Task(id: 3, title: 'Push project ke GitHub', createdAt: DateTime.now()),
  ];

  int _nextId = 4;
  int _best = 0; // skor tertinggi game
  Filter _filter = Filter.semua;
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---------------------------- Logika ------------------------------------

  List<Task> get _visibleTasks {
    switch (_filter) {
      case Filter.belum:
        return _tasks.where((t) => !t.done).toList();
      case Filter.selesai:
        return _tasks.where((t) => t.done).toList();
      case Filter.semua:
        return _tasks;
    }
  }

  int get _doneCount => _tasks.where((t) => t.done).length;

  void _addTask() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      HapticFeedback.mediumImpact();
      setState(() => _showError = true);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _tasks.insert(
        0,
        Task(id: _nextId++, title: text, createdAt: DateTime.now()),
      );
      _showError = false;
    });
    _controller.clear();
    _focus.requestFocus();
  }

  void _toggle(Task task) {
    setState(() => task.done = !task.done);
    if (task.done) {
      HapticFeedback.lightImpact();
      final semuaBeres = _doneCount == _tasks.length;
      _confetti.currentState?.burst(count: semuaBeres ? 90 : 36);
    }
  }

  void _delete(Task task) {
    final index = _tasks.indexOf(task);
    if (index == -1) return;
    setState(() => _tasks.removeAt(index));

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1B1A24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        content: Text(
          '"${task.title}" dihapus',
          style: const TextStyle(color: kText),
        ),
        action: SnackBarAction(
          label: 'Batal',
          textColor: kGold,
          onPressed: () {
            setState(() => _tasks.insert(index.clamp(0, _tasks.length), task));
          },
        ),
      ),
    );
  }

  String get _sapaan {
    final jam = DateTime.now().hour;
    if (jam < 11) return 'Selamat pagi';
    if (jam < 15) return 'Selamat siang';
    if (jam < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  String get _tanggal {
    const hari = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];
    const bulan = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final now = DateTime.now();
    return '${hari[now.weekday - 1]}, ${now.day} ${bulan[now.month - 1]} ${now.year}';
  }

  // ---------------------------- Tampilan ----------------------------------

  @override
  Widget build(BuildContext context) {
    final tasks = _visibleTasks;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _Aurora()),
          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _pad(
                    const EdgeInsets.fromLTRB(22, 22, 22, 0),
                    _Entrance(child: _buildHeader()),
                  ),
                  _pad(
                    const EdgeInsets.fromLTRB(22, 22, 22, 0),
                    _Entrance(
                      delay: const Duration(milliseconds: 120),
                      child: _buildProgress(),
                    ),
                  ),
                  _pad(
                    const EdgeInsets.fromLTRB(22, 16, 22, 0),
                    _Entrance(
                      delay: const Duration(milliseconds: 240),
                      child: _buildInput(),
                    ),
                  ),
                  _pad(
                    const EdgeInsets.fromLTRB(22, 16, 22, 0),
                    _Entrance(
                      delay: const Duration(milliseconds: 360),
                      child: GameCard(
                        best: _best,
                        onNewBest: (s) => setState(() => _best = s),
                      ),
                    ),
                  ),
                  _pad(
                    const EdgeInsets.fromLTRB(22, 22, 22, 12),
                    _Entrance(
                      delay: const Duration(milliseconds: 460),
                      child: _buildFilters(),
                    ),
                  ),
                  if (tasks.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmpty(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
                      sliver: SliverList.separated(
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final task = tasks[i];
                          return _Entrance(
                            key: ValueKey('e-${task.id}'),
                            delay: Duration(milliseconds: min(i, 6) * 60),
                            child: _TaskTile(
                              task: task,
                              onToggle: () => _toggle(task),
                              onDelete: () => _delete(task),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned.fill(child: ConfettiLayer(key: _confetti)),
        ],
      ),
    );
  }

  Widget _pad(EdgeInsets padding, Widget child) {
    return SliverPadding(
      padding: padding,
      sliver: SliverToBoxAdapter(child: child),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_sapaan  ·  $_tanggal'.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            color: kGold.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Hari ini,',
          style: TextStyle(
            fontSize: 38,
            height: 1.05,
            fontWeight: FontWeight.w300,
            letterSpacing: -1,
            color: kText,
          ),
        ),
        const _Shimmer(
          child: Text(
            'mau beresin apa?',
            style: TextStyle(
              fontSize: 38,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    final total = _tasks.length;
    final done = _doneCount;
    final value = total == 0 ? 0.0 : done / total;

    String judul;
    String sub;
    if (total == 0) {
      judul = 'Belum ada catatan';
      sub = 'Mulai dari yang kecil dulu.';
    } else if (done == total) {
      judul = 'Semua beres!';
      sub = 'Saatnya istirahat, ngopi dulu.';
    } else {
      judul = '$done dari $total beres';
      sub = 'Sisa ${total - done}, pelan-pelan aja.';
    }

    return Glass(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            height: 78,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) {
                return CustomPaint(
                  painter: _RingPainter(v),
                  child: Center(
                    child: Text(
                      '${(v * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kText,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    judul,
                    key: ValueKey(judul),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: kText,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 13,
                    color: kText.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Glass(
          radius: 20,
          padding: const EdgeInsets.fromLTRB(18, 6, 6, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  cursorColor: kGold,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addTask(),
                  onChanged: (_) {
                    if (_showError) setState(() => _showError = false);
                  },
                  style: const TextStyle(color: kText, fontSize: 16),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Tulis tugas barumu...',
                    hintStyle: TextStyle(color: kText.withValues(alpha: 0.35)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _GoldButton(
                onTap: _addTask,
                child: const Text(
                  'Simpan',
                  style: TextStyle(
                    color: kBg,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: _showError
              ? const Padding(
                  padding: EdgeInsets.only(left: 6, top: 8),
                  child: Text(
                    'Judulnya jangan kosong ya',
                    style: TextStyle(color: Color(0xFFFF8A80), fontSize: 12),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final belum = _tasks.where((t) => !t.done).length;
    final labels = {
      Filter.semua: 'Semua ${_tasks.length}',
      Filter.belum: 'Belum $belum',
      Filter.selesai: 'Selesai $_doneCount',
    };

    return Row(
      children: Filter.values.map((f) {
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _Pill(
            label: labels[f]!,
            selected: _filter == f,
            onTap: () => setState(() => _filter = f),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmpty() {
    final kosongTotal = _tasks.isEmpty;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Pulse(
            child: Icon(
              kosongTotal
                  ? Icons.auto_awesome_rounded
                  : Icons.filter_list_off_rounded,
              size: 56,
              color: kGold.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            kosongTotal ? 'Masih kosong nih' : 'Nggak ada di sini',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            kosongTotal
                ? 'Tulis tugas pertamamu di atas.'
                : 'Coba ganti filter di atas.',
            style: TextStyle(color: kText.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

// ----------------------------- Item tugas ----------------------------------

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  String get _jam {
    final h = task.createdAt.hour.toString().padLeft(2, '0');
    final m = task.createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('d-${task.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFE2554F).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Glass(
        padding: EdgeInsets.zero,
        highlight: task.done,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 6, 16),
              child: Row(
                children: [
                  _CheckCircle(done: task.done),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: task.done
                                ? kText.withValues(alpha: 0.35)
                                : kText,
                            decoration:
                                task.done ? TextDecoration.lineThrough : null,
                            decorationColor: kGold,
                          ),
                          child: Text(task.title),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'dibuat $_jam',
                          style: TextStyle(
                            fontSize: 11,
                            color: kText.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    tooltip: 'Hapus',
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: kText.withValues(alpha: 0.4),
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
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: done ? kGoldGradient : null,
        border: done
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.8),
        boxShadow: done
            ? [
                BoxShadow(
                  color: kGold.withValues(alpha: 0.45),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: AnimatedScale(
        scale: done ? 1 : 0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        child: const Icon(Icons.check_rounded, size: 18, color: kBg),
      ),
    );
  }
}

// ----------------------------- Game mini -----------------------------------
// "Tangkap Kopi": ketuk biji kopi (+1) dan bintang (+3) sebelum hilang.
// Waktu 15 detik. Skor tertinggi disimpan di memori selama aplikasi jalan.

enum _Phase { idle, playing, over }

class _Target {
  const _Target(this.id, this.fx, this.fy, this.golden);

  final int id;
  final double fx; // posisi horizontal 0..1
  final double fy; // posisi vertikal 0..1
  final bool golden;
}

class _Pop {
  const _Pop(this.id, this.x, this.y, this.text);

  final int id;
  final double x;
  final double y;
  final String text;
}

class GameCard extends StatefulWidget {
  const GameCard({super.key, required this.best, required this.onNewBest});

  final int best;
  final ValueChanged<int> onNewBest;

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  static const int _duration = 15;
  static const double _bubble = 56;

  final Random _rand = Random();
  final List<_Target> _targets = [];
  final List<_Pop> _pops = [];

  _Phase _phase = _Phase.idle;
  bool _open = false;
  bool _record = false;
  int _score = 0;
  int _left = _duration;
  int _nextId = 0;
  Timer? _clock;
  Timer? _spawner;

  @override
  void dispose() {
    _clock?.cancel();
    _spawner?.cancel();
    super.dispose();
  }

  void _toggleOpen() {
    if (_phase == _Phase.playing) return; // jangan ditutup saat main
    setState(() => _open = !_open);
  }

  void _start() {
    _clock?.cancel();
    _spawner?.cancel();
    setState(() {
      _phase = _Phase.playing;
      _record = false;
      _score = 0;
      _left = _duration;
      _targets.clear();
      _pops.clear();
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left <= 1) {
        _finish();
      } else {
        setState(() => _left--);
      }
    });
    _spawner = Timer.periodic(const Duration(milliseconds: 520), (_) => _spawn());
    _spawn();
  }

  void _spawn() {
    if (_phase != _Phase.playing || !mounted) return;
    final golden = _rand.nextInt(6) == 0;
    final target = _Target(
      _nextId++,
      _rand.nextDouble(),
      _rand.nextDouble(),
      golden,
    );
    setState(() => _targets.add(target));
    Future.delayed(Duration(milliseconds: golden ? 800 : 1200), () {
      if (!mounted) return;
      if (_targets.any((t) => t.id == target.id)) {
        setState(() => _targets.removeWhere((t) => t.id == target.id));
      }
    });
  }

  void _hit(_Target target, double x, double y) {
    if (!_targets.any((t) => t.id == target.id)) return;
    final poin = target.golden ? 3 : 1;
    final pop = _Pop(_nextId++, x, y, '+$poin');
    HapticFeedback.selectionClick();
    setState(() {
      _score += poin;
      _targets.removeWhere((t) => t.id == target.id);
      _pops.add(pop);
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _pops.removeWhere((p) => p.id == pop.id));
    });
  }

  void _finish() {
    _clock?.cancel();
    _spawner?.cancel();
    final rekorBaru = _score > widget.best;
    setState(() {
      _phase = _Phase.over;
      _left = 0;
      _record = rekorBaru;
      _targets.clear();
    });
    if (rekorBaru) widget.onNewBest(_score);
  }

  @override
  Widget build(BuildContext context) {
    return Glass(
      highlight: true,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: _toggleOpen,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: kGoldGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.coffee_rounded, color: kBg),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Istirahat dulu, main yuk',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: kText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.best == 0
                                ? 'Tangkap Kopi · belum ada rekor'
                                : 'Tangkap Kopi · rekor ${widget.best}',
                            style: TextStyle(
                              fontSize: 12,
                              color: kText.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: kGold.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _buildGame(),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildGame() {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Skor $_score',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: kGold,
              ),
            ),
            const Spacer(),
            Text(
              '$_left dtk',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kText.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: _left / _duration),
            duration: const Duration(milliseconds: 900),
            builder: (context, v, _) => LinearProgressIndicator(
              value: _phase == _Phase.idle ? 1 : v,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(kGold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  colors: [Color(0xFF1E1B2E), Color(0xFF0E0D16)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth - _bubble;
                  final h = box.maxHeight - _bubble;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      for (final t in _targets)
                        Positioned(
                          key: ValueKey('t-${t.id}'),
                          left: t.fx * w,
                          top: t.fy * h,
                          child: _Bubble(
                            golden: t.golden,
                            onHit: () => _hit(t, t.fx * w, t.fy * h),
                          ),
                        ),
                      for (final p in _pops)
                        Positioned(
                          key: ValueKey('p-${p.id}'),
                          left: p.x + 10,
                          top: p.y,
                          child: IgnorePointer(child: _PopText(text: p.text)),
                        ),
                      if (_phase != _Phase.playing) _buildOverlay(),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverlay() {
    final over = _phase == _Phase.over;
    return Container(
      color: kBg.withValues(alpha: 0.8),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            over ? 'Waktu habis!' : 'Tangkap Kopi',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: kText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            over
                ? (_record ? 'Skor $_score · rekor baru! 🏆' : 'Skor kamu $_score')
                : 'Ketuk biji kopi (+1) dan bintang (+3)\nsecepat mungkin selama $_duration detik.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: kText.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 18),
          _GoldButton(
            onTap: _start,
            child: Text(
              over ? 'Main lagi' : 'Mulai',
              style: const TextStyle(color: kBg, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.golden, required this.onHit});

  final bool golden;
  final VoidCallback onHit;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: GestureDetector(
        onTapDown: (_) => onHit(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: golden
                ? const RadialGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFFFD86B)],
                  )
                : kGoldGradient,
            boxShadow: [
              BoxShadow(
                color: kGold.withValues(alpha: golden ? 0.8 : 0.4),
                blurRadius: golden ? 24 : 14,
              ),
            ],
          ),
          child: Icon(
            golden ? Icons.star_rounded : Icons.coffee_rounded,
            color: kBg,
            size: golden ? 30 : 26,
          ),
        ),
      ),
    );
  }
}

class _PopText extends StatelessWidget {
  const _PopText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      builder: (context, v, _) {
        return Opacity(
          opacity: 1 - v,
          child: Transform.translate(
            offset: Offset(0, -34 * v),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: kGoldLight,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ----------------------------- Elemen UI umum ------------------------------

// Kartu kaca: blur + gradasi tipis + garis tepi.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.highlight = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: border,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: border,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.04),
              ],
            ),
            border: Border.all(
              color: highlight
                  ? kGold.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// Tombol emas dengan efek tekan.
class _GoldButton extends StatefulWidget {
  const _GoldButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<_GoldButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.93 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: kGoldGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: kGold.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// Tombol filter berbentuk pil.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? kGoldGradient : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? kBg : kText.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

// Animasi masuk: fade + geser naik, bisa diberi jeda (delay).
class _Entrance extends StatefulWidget {
  const _Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

// Efek kilau emas yang bergerak di atas teks.
class _SlideGradientTransform extends GradientTransform {
  const _SlideGradientTransform(this.percent);

  final double percent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * percent, 0, 0);
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});

  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [kGoldDark, kGoldLight, kGoldDark],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlideGradientTransform(_c.value * 2 - 1),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

// Ikon yang berdenyut pelan (untuk tampilan kosong).
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.9, end: 1.1).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

// Cincin progress bergradasi emas.
class _RingPainter extends CustomPainter {
  _RingPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = Colors.white.withValues(alpha: 0.1);
    canvas.drawCircle(center, radius, base);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: [kGoldDark, kGold, kGoldLight],
      ).createShader(rect);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * value,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value;
}

// Latar aurora: tiga bola cahaya yang bergerak pelan.
class _Aurora extends StatefulWidget {
  const _Aurora();

  @override
  State<_Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<_Aurora> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ColoredBox(
        color: kBg,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth;
                final h = box.maxHeight;
                final t = _c.value * 2 * pi;

                Widget blob(Color color, double size, double px, double py,
                    double phase) {
                  final x = w * (px + 0.18 * sin(t + phase)) - size / 2;
                  final y = h * (py + 0.10 * cos(t + phase)) - size / 2;
                  return Positioned(
                    left: x,
                    top: y,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            color.withValues(alpha: 0.55),
                            color.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Stack(
                  children: [
                    blob(const Color(0xFF4B2E83), 440, 0.2, 0.12, 0),
                    blob(const Color(0xFF0E5A6B), 400, 0.85, 0.42, 2),
                    blob(const Color(0xFF7A2848), 480, 0.3, 0.88, 4),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ----------------------------- Confetti ------------------------------------

class _Bit {
  const _Bit(this.angle, this.speed, this.size, this.color, this.spin, this.round);

  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double spin;
  final bool round;
}

class ConfettiLayer extends StatefulWidget {
  const ConfettiLayer({super.key});

  @override
  State<ConfettiLayer> createState() => ConfettiLayerState();
}

class ConfettiLayerState extends State<ConfettiLayer>
    with SingleTickerProviderStateMixin {
  static const List<Color> _palette = [
    kGold,
    kGoldLight,
    Color(0xFFFFFFFF),
    Color(0xFFE8A0BF),
    Color(0xFF8FD3E8),
  ];

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  final Random _rand = Random();
  List<_Bit> _bits = [];

  void burst({int count = 36}) {
    _bits = List.generate(count, (_) {
      final angle = -pi / 2 + (_rand.nextDouble() - 0.5) * pi * 1.2;
      return _Bit(
        angle,
        380 + _rand.nextDouble() * 520,
        5 + _rand.nextDouble() * 6,
        _palette[_rand.nextInt(_palette.length)],
        _rand.nextDouble() * 8,
        _rand.nextBool(),
      );
    });
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_bits, _c.value),
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.bits, this.t);

  final List<_Bit> bits;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (bits.isEmpty || t <= 0 || t >= 1) return;

    final origin = Offset(size.width / 2, size.height * 0.6);
    final sec = t * 1.6;
    final fade = (1 - ((t - 0.65) / 0.35)).clamp(0.0, 1.0).toDouble();

    for (final b in bits) {
      final dx = cos(b.angle) * b.speed * sec;
      final dy = sin(b.angle) * b.speed * sec + 0.5 * 1100 * sec * sec;
      final pos = origin + Offset(dx, dy);
      final paint = Paint()..color = b.color.withValues(alpha: fade);

      if (b.round) {
        canvas.drawCircle(pos, b.size / 2, paint);
      } else {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(b.spin * sec);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: b.size,
            height: b.size * 0.55,
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}