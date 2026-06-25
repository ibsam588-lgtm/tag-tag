// ignore_for_file: unused_element, unused_element_parameter

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_painter.dart';
import 'game_simulation.dart';

enum _ShellScreen { home, game, setup, store, arenas, tutorial }

class _StoreSkin {
  const _StoreSkin({
    required this.avatar,
    required this.name,
    required this.price,
    required this.color,
  });

  final PlayerAvatar avatar;
  final String name;
  final int price;
  final Color color;
}

class _ArenaOption {
  const _ArenaOption({
    required this.arena,
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final ArenaBackground arena;
  final String title;
  final String detail;
  final IconData icon;
  final Color color;
}

const _storeSkins = [
  _StoreSkin(
    avatar: PlayerAvatar.blue,
    name: 'Blue Blitz',
    price: 0,
    color: Color(0xff36d6ff),
  ),
  _StoreSkin(
    avatar: PlayerAvatar.red,
    name: 'Tag Spark',
    price: 150,
    color: Color(0xffff405f),
  ),
  _StoreSkin(
    avatar: PlayerAvatar.yellow,
    name: 'Bell Bolt',
    price: 120,
    color: Color(0xffffd64c),
  ),
  _StoreSkin(
    avatar: PlayerAvatar.green,
    name: 'Yard Dash',
    price: 120,
    color: Color(0xff6ee75f),
  ),
  _StoreSkin(
    avatar: PlayerAvatar.pink,
    name: 'Hop Star',
    price: 180,
    color: Color(0xffff6da7),
  ),
  _StoreSkin(
    avatar: PlayerAvatar.purple,
    name: 'Frenzy Pop',
    price: 200,
    color: Color(0xff9d55ff),
  ),
];

const _arenaOptions = [
  _ArenaOption(
    arena: ArenaBackground.base,
    title: 'Playground',
    detail: 'Classic chase yard',
    icon: Icons.sports_soccer_rounded,
    color: Color(0xff39d9ff),
  ),
  _ArenaOption(
    arena: ArenaBackground.bellZone,
    title: 'Bell Zone',
    detail: 'Score inside the glow',
    icon: Icons.notifications_active_rounded,
    color: Color(0xff9d55ff),
  ),
  _ArenaOption(
    arena: ArenaBackground.shrinkingYard,
    title: 'Shrinking Yard',
    detail: 'Stay inside the cones',
    icon: Icons.warning_rounded,
    color: Color(0xffff405f),
  ),
  _ArenaOption(
    arena: ArenaBackground.frenzy,
    title: 'Tag Frenzy',
    detail: 'Fast final chase',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xffff8a18),
  ),
];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const TagTagApp());
}

class TagTagApp extends StatelessWidget {
  const TagTagApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tag Tag: Playground Blitz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffff3f68),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: const GameShell(),
    );
  }
}

class GameShell extends StatefulWidget {
  const GameShell({super.key});

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration? _previousTick;
  final GameInput _input = GameInput();
  final TextEditingController _nameController = TextEditingController(
    text: 'Ibsam',
  );

  GameSettings _settings = const GameSettings(
    playerName: 'Ibsam',
    botCount: 5,
    roundLength: 90,
    difficulty: Difficulty.balanced,
  );
  late PlaygroundBlitzSimulation _simulation;
  final Map<ArenaBackground, ui.Image> _arenaBackgrounds = {};
  final Map<PlayerAvatar, ui.Image> _avatarSprites = {};
  _ShellScreen _screen = _ShellScreen.home;
  int _coins = 150;
  int _lastReward = 0;
  bool _roundRewardGranted = false;
  bool _darkMode = false;
  PlayerAvatar _selectedAvatar = PlayerAvatar.blue;
  ArenaBackground _selectedArena = ArenaBackground.base;
  Set<PlayerAvatar> _unlockedAvatars = {PlayerAvatar.blue};
  Offset _stickOffset = Offset.zero;
  double _animationSeconds = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _simulation = PlaygroundBlitzSimulation(_settings);
    _loadArenaBackgrounds();
    _loadProgress();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _nameController.dispose();
    for (final image in _arenaBackgrounds.values) {
      image.dispose();
    }
    for (final image in _avatarSprites.values) {
      image.dispose();
    }
    super.dispose();
  }

  Future<void> _loadArenaBackgrounds() async {
    const assetPaths = {
      ArenaBackground.base: 'assets/backgrounds/playground_base.png',
      ArenaBackground.bellZone: 'assets/backgrounds/playground_bell_zone.png',
      ArenaBackground.shrinkingYard:
          'assets/backgrounds/playground_shrinking_yard.png',
      ArenaBackground.frenzy: 'assets/backgrounds/playground_frenzy.png',
    };
    final loaded = <ArenaBackground, ui.Image>{};
    for (final entry in assetPaths.entries) {
      final data = await rootBundle.load(entry.value);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      loaded[entry.key] = frame.image;
    }
    if (!mounted) {
      for (final image in loaded.values) {
        image.dispose();
      }
      return;
    }
    setState(() => _arenaBackgrounds.addAll(loaded));
    await _loadAvatarSprites();
  }

  Future<void> _loadAvatarSprites() async {
    const assetPaths = {
      PlayerAvatar.blue: 'assets/avatars/avatar_blue.png',
      PlayerAvatar.red: 'assets/avatars/avatar_red.png',
      PlayerAvatar.yellow: 'assets/avatars/avatar_yellow.png',
      PlayerAvatar.green: 'assets/avatars/avatar_green.png',
      PlayerAvatar.pink: 'assets/avatars/avatar_pink.png',
      PlayerAvatar.purple: 'assets/avatars/avatar_purple.png',
    };
    final loaded = <PlayerAvatar, ui.Image>{};
    for (final entry in assetPaths.entries) {
      final data = await rootBundle.load(entry.value);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      loaded[entry.key] = frame.image;
    }
    if (!mounted) {
      for (final image in loaded.values) {
        image.dispose();
      }
      return;
    }
    setState(() => _avatarSprites.addAll(loaded));
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedName = prefs.getString('selected_avatar');
    final selectedArenaName = prefs.getString('selected_arena');
    final unlockedNames = prefs.getStringList('unlocked_avatars');
    final selected = _avatarFromName(selectedName) ?? PlayerAvatar.blue;
    final selectedArena =
        _arenaFromName(selectedArenaName) ?? ArenaBackground.base;
    final unlocked = unlockedNames
        ?.map(_avatarFromName)
        .whereType<PlayerAvatar>()
        .toSet();
    if (!mounted) {
      return;
    }
    setState(() {
      _coins = prefs.getInt('coins') ?? 150;
      _unlockedAvatars = (unlocked == null || unlocked.isEmpty)
          ? {PlayerAvatar.blue}
          : {...unlocked, PlayerAvatar.blue};
      _selectedAvatar = _unlockedAvatars.contains(selected)
          ? selected
          : PlayerAvatar.blue;
      _selectedArena = selectedArena;
      _darkMode = prefs.getBool('dark_mode') ?? false;
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins', _coins);
    await prefs.setBool('dark_mode', _darkMode);
    await prefs.setString('selected_avatar', _selectedAvatar.name);
    await prefs.setString('selected_arena', _selectedArena.name);
    await prefs.setStringList(
      'unlocked_avatars',
      _unlockedAvatars.map((avatar) => avatar.name).toList(),
    );
  }

  PlayerAvatar? _avatarFromName(String? name) {
    if (name == null) {
      return null;
    }
    for (final avatar in PlayerAvatar.values) {
      if (avatar.name == name) {
        return avatar;
      }
    }
    return null;
  }

  ArenaBackground? _arenaFromName(String? name) {
    if (name == null) {
      return null;
    }
    for (final arena in ArenaBackground.values) {
      if (arena.name == name) {
        return arena;
      }
    }
    return null;
  }

  void _tick(Duration elapsed) {
    final previous = _previousTick;
    _previousTick = elapsed;
    if (previous == null) {
      return;
    }

    final dt =
        (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond;
    if (_screen == _ShellScreen.game && !_simulation.roundOver) {
      _simulation.update(dt, _input);
    }
    _input.consumePresses();
    _animationSeconds += dt;
    if (_screen == _ShellScreen.game &&
        _simulation.roundOver &&
        !_roundRewardGranted) {
      _grantRoundReward();
    }
    setState(() {});
    if (_simulation.roundOver) {
      _ticker.stop();
    }
  }

  void _grantRoundReward() {
    final human = _simulation.human;
    final won = _simulation.winner.id == human.id;
    final reward =
        20 + (human.score / 12).floor() + human.tags * 12 + (won ? 40 : 0);
    _lastReward = reward.clamp(20, 260);
    _coins += _lastReward;
    _roundRewardGranted = true;
    unawaited(_saveProgress());
  }

  void _startGame() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    final playerName = _nameController.text.trim().isEmpty
        ? 'Player'
        : _nameController.text.trim();
    _settings = GameSettings(
      playerName: playerName.length > 16
          ? playerName.substring(0, 16)
          : playerName,
      botCount: _settings.botCount,
      roundLength: _settings.roundLength,
      difficulty: _settings.difficulty,
    );
    _simulation = PlaygroundBlitzSimulation(_settings);
    _screen = _ShellScreen.game;
    _previousTick = null;
    _animationSeconds = 0;
    _lastReward = 0;
    _roundRewardGranted = false;
    _input.move = Offset.zero;
    _input.sprint = false;
    _stickOffset = Offset.zero;
    _ticker.start();
    setState(() {});
  }

  void _openHome() {
    _ticker.stop();
    _input.move = Offset.zero;
    _input.sprint = false;
    _stickOffset = Offset.zero;
    _screen = _ShellScreen.home;
    setState(() {});
  }

  void _openSetup() {
    _ticker.stop();
    _input.move = Offset.zero;
    _input.sprint = false;
    _stickOffset = Offset.zero;
    _screen = _ShellScreen.setup;
    setState(() {});
  }

  void _openStore() {
    _ticker.stop();
    _input.move = Offset.zero;
    _input.sprint = false;
    _stickOffset = Offset.zero;
    _screen = _ShellScreen.store;
    setState(() {});
  }

  void _openArenas() {
    _ticker.stop();
    _input.move = Offset.zero;
    _input.sprint = false;
    _stickOffset = Offset.zero;
    _screen = _ShellScreen.arenas;
    setState(() {});
  }

  void _openTutorial() {
    _ticker.stop();
    _input.move = Offset.zero;
    _input.sprint = false;
    _stickOffset = Offset.zero;
    _screen = _ShellScreen.tutorial;
    setState(() {});
  }

  void _toggleDarkMode() {
    setState(() => _darkMode = !_darkMode);
    unawaited(_saveProgress());
  }

  void _selectArena(ArenaBackground arena) {
    setState(() => _selectedArena = arena);
    unawaited(_saveProgress());
  }

  void _selectOrBuySkin(_StoreSkin skin) {
    if (_unlockedAvatars.contains(skin.avatar)) {
      setState(() => _selectedAvatar = skin.avatar);
      unawaited(_saveProgress());
      return;
    }
    if (_coins < skin.price) {
      return;
    }
    setState(() {
      _coins -= skin.price;
      _unlockedAvatars = {..._unlockedAvatars, skin.avatar};
      _selectedAvatar = skin.avatar;
    });
    unawaited(_saveProgress());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff2db86c),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: PlaygroundPainter(
              simulation: _simulation,
              animationTime: _animationSeconds,
              backgrounds: _arenaBackgrounds,
              avatars: _avatarSprites,
              humanAvatar: _selectedAvatar,
              baseArena: _selectedArena,
            ),
          ),
          if (_darkMode) const _DarkModeTint(),
          if (_screen != _ShellScreen.game)
            _MenuSceneBackdrop(
              arena: _screen == _ShellScreen.home
                  ? ArenaBackground.base
                  : _selectedArena,
              darkMode: _darkMode,
            ),
          if (_screen == _ShellScreen.game) _GameHud(simulation: _simulation),
          if (_screen == _ShellScreen.game && !_simulation.roundOver)
            _TopActions(onSetup: _openSetup, onRestart: _startGame),
          if (_screen == _ShellScreen.game && !_simulation.roundOver)
            _ControlsOverlay(
              simulation: _simulation,
              stickOffset: _stickOffset,
              onStickChanged: _handleStickChanged,
              onStickReleased: _releaseStick,
              onDash: () => _input.dashPressed = true,
            ),
          if (_screen == _ShellScreen.home)
            _HomeOverlay(
              coins: _coins,
              darkMode: _darkMode,
              selectedArena: _selectedArena,
              selectedAvatar: _selectedAvatar,
              avatars: _avatarSprites,
              onPlay: _startGame,
              onStore: _openStore,
              onSetup: _openSetup,
              onArenas: _openArenas,
              onTutorial: _openTutorial,
              onToggleDarkMode: _toggleDarkMode,
            ),
          if (_screen == _ShellScreen.setup)
            _SetupMenu(
              settings: _settings,
              nameController: _nameController,
              onSettingsChanged: (settings) =>
                  setState(() => _settings = settings),
              onPlay: _startGame,
              onBack: _openHome,
            ),
          if (_screen == _ShellScreen.store)
            _StoreOverlay(
              coins: _coins,
              selectedAvatar: _selectedAvatar,
              unlockedAvatars: _unlockedAvatars,
              avatars: _avatarSprites,
              onSelect: _selectOrBuySkin,
              onBack: _openHome,
            ),
          if (_screen == _ShellScreen.arenas)
            _ArenasOverlay(
              selectedArena: _selectedArena,
              darkMode: _darkMode,
              onSelect: _selectArena,
              onBack: _openHome,
            ),
          if (_screen == _ShellScreen.tutorial)
            _TutorialOverlay(
              darkMode: _darkMode,
              onPlay: _startGame,
              onBack: _openHome,
            ),
          if (_screen == _ShellScreen.game && _simulation.roundOver)
            _ResultsOverlay(
              simulation: _simulation,
              coins: _coins,
              reward: _lastReward,
              onPlayAgain: _startGame,
              onStore: _openStore,
              onHome: _openHome,
            ),
        ],
      ),
    );
  }

  void _handleStickChanged(Offset localPosition, Size size) {
    final center = size.center(Offset.zero);
    final raw = localPosition - center;
    const maxDistance = 44.0;
    final distance = raw.distance;
    final clamped = distance > maxDistance ? raw / distance * maxDistance : raw;
    setState(() {
      _stickOffset = clamped;
      _input.move = clamped / maxDistance;
      _input.sprint = clamped.distance > 34;
    });
  }

  void _releaseStick() {
    setState(() {
      _stickOffset = Offset.zero;
      _input.move = Offset.zero;
      _input.sprint = false;
    });
  }
}

class _DarkModeTint extends StatelessWidget {
  const _DarkModeTint();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xff02060d).withValues(alpha: 0.28),
        ),
      ),
    );
  }
}

class _MenuSceneBackdrop extends StatelessWidget {
  const _MenuSceneBackdrop({required this.arena, required this.darkMode});

  final ArenaBackground arena;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          _arenaAssetPath(arena),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: darkMode ? 0.34 : 0.08),
                Colors.black.withValues(alpha: darkMode ? 0.18 : 0.02),
                Colors.black.withValues(alpha: darkMode ? 0.58 : 0.3),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopActions extends StatelessWidget {
  const _TopActions({required this.onSetup, required this.onRestart});

  final VoidCallback onSetup;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 74, right: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconAction(
                icon: Icons.tune_rounded,
                label: 'Setup',
                onTap: onSetup,
              ),
              const SizedBox(height: 8),
              _IconAction(
                icon: Icons.refresh_rounded,
                label: 'Restart',
                onTap: onRestart,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: const Color(0xff182035).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.62),
                width: 2,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _SetupMenu extends StatelessWidget {
  const _SetupMenu({
    required this.settings,
    required this.nameController,
    required this.onSettingsChanged,
    required this.onPlay,
    required this.onBack,
  });

  final GameSettings settings;
  final TextEditingController nameController;
  final ValueChanged<GameSettings> onSettingsChanged;
  final VoidCallback onPlay;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Playground Blitz',
                  style: TextStyle(
                    color: Color(0xffffd447),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const Text(
                  'Tag Tag',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 58,
                    height: 0.9,
                  ),
                ),
                const SizedBox(height: 10),
                _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Kicker('Round Setup'),
                      const Text(
                        'Start a chase that cannot stall',
                        style: TextStyle(
                          color: Color(0xff182035),
                          fontWeight: FontWeight.w900,
                          fontSize: 23,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: nameController,
                        maxLength: 16,
                        style: const TextStyle(
                          color: Color(0xff182035),
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: _inputDecoration('Player name'),
                      ),
                      const SizedBox(height: 4),
                      _SliderRow(
                        label: 'Bot players',
                        value: settings.botCount.toDouble(),
                        min: 3,
                        max: 7,
                        divisions: 4,
                        display: '${settings.botCount} bots',
                        onChanged: (value) => onSettingsChanged(
                          GameSettings(
                            playerName: nameController.text,
                            botCount: value.round(),
                            roundLength: settings.roundLength,
                            difficulty: settings.difficulty,
                          ),
                        ),
                      ),
                      _SliderRow(
                        label: 'Round length',
                        value: settings.roundLength,
                        min: 60,
                        max: 120,
                        divisions: 2,
                        display: '${settings.roundLength.round()}s',
                        onChanged: (value) => onSettingsChanged(
                          GameSettings(
                            playerName: nameController.text,
                            botCount: settings.botCount,
                            roundLength: value,
                            difficulty: settings.difficulty,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _TempoSelector(
                        difficulty: settings.difficulty,
                        onChanged: (difficulty) => onSettingsChanged(
                          GameSettings(
                            playerName: nameController.text,
                            botCount: settings.botCount,
                            roundLength: settings.roundLength,
                            difficulty: difficulty,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xff182035),
                                side: const BorderSide(
                                  color: Color(0xff182035),
                                  width: 2,
                                ),
                              ),
                              onPressed: onBack,
                              icon: const Icon(Icons.home_rounded),
                              label: const Text('Home'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xffff3f68),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: onPlay,
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text(
                                  'Play',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      counterText: '',
      filled: true,
      fillColor: const Color(0xfffffdf3),
      labelStyle: const TextStyle(
        color: Color(0xff182035),
        fontWeight: FontWeight.w800,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: const Color(0xff182035).withValues(alpha: 0.16),
          width: 2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xff6e62db), width: 2),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    );
  }
}

class _HomeOverlay extends StatelessWidget {
  const _HomeOverlay({
    required this.coins,
    required this.darkMode,
    required this.selectedArena,
    required this.selectedAvatar,
    required this.avatars,
    required this.onPlay,
    required this.onStore,
    required this.onSetup,
    required this.onArenas,
    required this.onTutorial,
    required this.onToggleDarkMode,
  });

  final int coins;
  final bool darkMode;
  final ArenaBackground selectedArena;
  final PlayerAvatar selectedAvatar;
  final Map<PlayerAvatar, ui.Image> avatars;
  final VoidCallback onPlay;
  final VoidCallback onStore;
  final VoidCallback onSetup;
  final VoidCallback onArenas;
  final VoidCallback onTutorial;
  final VoidCallback onToggleDarkMode;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stateFingerprint = Object.hash(
            coins,
            darkMode,
            selectedArena,
            selectedAvatar,
            avatars.length,
          );
          assert(stateFingerprint != -1);
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/home/home_screen_reference.png',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
              _HomeImageButton(
                label: 'PLAY',
                left: 0.24,
                top: 0.73,
                width: 0.54,
                height: 0.13,
                onTap: onPlay,
              ),
              _HomeImageButton(
                label: 'STORE',
                left: 0.05,
                top: 0.89,
                width: 0.18,
                height: 0.10,
                onTap: onStore,
              ),
              _HomeImageButton(
                label: 'SETUP',
                left: 0.28,
                top: 0.89,
                width: 0.18,
                height: 0.10,
                onTap: onSetup,
              ),
              _HomeImageButton(
                label: 'AVATARS',
                left: 0.49,
                top: 0.89,
                width: 0.21,
                height: 0.10,
                onTap: onStore,
              ),
              _HomeImageButton(
                label: 'MISSIONS',
                left: 0.73,
                top: 0.89,
                width: 0.21,
                height: 0.10,
                onTap: onTutorial,
              ),
              _HomeImageButton(
                label: 'GEAR',
                left: 0.86,
                top: 0.01,
                width: 0.12,
                height: 0.07,
                onTap: onSetup,
              ),
              _HomeImageButton(
                label: 'ARENAS',
                left: 0.69,
                top: 0.34,
                width: 0.30,
                height: 0.37,
                onTap: onArenas,
              ),
              _HomeImageButton(
                label: 'SKINS',
                left: 0.03,
                top: 0.54,
                width: 0.20,
                height: 0.19,
                onTap: onStore,
              ),
              Positioned(
                left: 0,
                top: 0,
                child: SizedBox(
                  width: 1,
                  height: 1,
                  child: Opacity(
                    opacity: 0,
                    child: Column(children: const [Text('TAG TAG')]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeImageButton extends StatelessWidget {
  const _HomeImageButton({
    required this.label,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final String label;
  final double left;
  final double top;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: FractionallySizedBox(
        alignment: Alignment.topLeft,
        widthFactor: width,
        heightFactor: height,
        child: FractionalTranslation(
          translation: Offset(left / width, top / height),
          child: Semantics(
            button: true,
            label: label,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                splashColor: Colors.white.withValues(alpha: 0.05),
                highlightColor: Colors.white.withValues(alpha: 0.03),
                child: Opacity(opacity: 0, child: Center(child: Text(label))),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreOverlay extends StatelessWidget {
  const _StoreOverlay({
    required this.coins,
    required this.selectedAvatar,
    required this.unlockedAvatars,
    required this.avatars,
    required this.onSelect,
    required this.onBack,
  });

  final int coins;
  final PlayerAvatar selectedAvatar;
  final Set<PlayerAvatar> unlockedAvatars;
  final Map<PlayerAvatar, ui.Image> avatars;
  final ValueChanged<_StoreSkin> onSelect;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 860 || constraints.maxHeight < 590;
          final selectedSkin = _skinForAvatar(selectedAvatar);

          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.18),
                      Colors.black.withValues(alpha: 0.28),
                      Colors.black.withValues(alpha: 0.46),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: compact
                    ? SingleChildScrollView(
                        child: Column(
                          children: [
                            _StoreHeader(
                              coins: coins,
                              onBack: onBack,
                              compact: true,
                            ),
                            const SizedBox(height: 12),
                            _StoreFeaturePanel(
                              skin: selectedSkin,
                              image: avatars[selectedAvatar],
                            ),
                            const SizedBox(height: 12),
                            _StoreGrid(
                              coins: coins,
                              selectedAvatar: selectedAvatar,
                              unlockedAvatars: unlockedAvatars,
                              avatars: avatars,
                              onSelect: onSelect,
                              compact: true,
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          _StoreHeader(coins: coins, onBack: onBack),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: 300,
                                  child: _StoreFeaturePanel(
                                    skin: selectedSkin,
                                    image: avatars[selectedAvatar],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StoreGrid(
                                    coins: coins,
                                    selectedAvatar: selectedAvatar,
                                    unlockedAvatars: unlockedAvatars,
                                    avatars: avatars,
                                    onSelect: onSelect,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ArenasOverlay extends StatelessWidget {
  const _ArenasOverlay({
    required this.selectedArena,
    required this.darkMode,
    required this.onSelect,
    required this.onBack,
  });

  final ArenaBackground selectedArena;
  final bool darkMode;
  final ValueChanged<ArenaBackground> onSelect;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: Column(
          children: [
            _ArcadeScreenHeader(
              title: 'ARENAS',
              icon: Icons.map_rounded,
              color: const Color(0xff39d9ff),
              onBack: onBack,
              trailing: Text(
                '${_arenaOptions.length} selected',
                style: const TextStyle(
                  color: Color(0xffffd64c),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 620;
                final spacing = twoColumns ? 10.0 : 9.0;
                final width = twoColumns
                    ? (constraints.maxWidth - spacing) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final option in _arenaOptions)
                      SizedBox(
                        width: width,
                        child: _ArenaCard(
                          option: option,
                          selected: option.arena == selectedArena,
                          darkMode: darkMode,
                          onTap: () => onSelect(option.arena),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ArenaCard extends StatelessWidget {
  const _ArenaCard({
    required this.option,
    required this.selected,
    required this.darkMode,
    required this.onTap,
  });

  final _ArenaOption option;
  final bool selected;
  final bool darkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: selected ? null : onTap,
        child: Container(
          height: 184,
          padding: const EdgeInsets.all(9),
          decoration: _arcadePlate(
            borderColor: selected ? option.color : const Color(0xff617380),
            shadowColor: selected
                ? option.color.withValues(alpha: 0.36)
                : Colors.black.withValues(alpha: 0.44),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        _arenaAssetPath(option.arena),
                        fit: BoxFit.cover,
                      ),
                      if (darkMode)
                        ColoredBox(
                          color: const Color(
                            0xff05080d,
                          ).withValues(alpha: 0.22),
                        ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xffffd64c)
                                : Colors.black.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            selected ? 'SELECTED' : 'SELECT',
                            style: TextStyle(
                              color: selected
                                  ? const Color(0xff182035)
                                  : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Icon(option.icon, color: option.color, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        Text(
                          option.detail,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialOverlay extends StatelessWidget {
  const _TutorialOverlay({
    required this.darkMode,
    required this.onPlay,
    required this.onBack,
  });

  final bool darkMode;
  final VoidCallback onPlay;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    const tips = [
      _TutorialTip(
        icon: Icons.touch_app_rounded,
        color: Color(0xff39d9ff),
        title: 'Move',
        body: 'Drag the joystick to run. Push farther to sprint.',
      ),
      _TutorialTip(
        icon: Icons.directions_run_rounded,
        color: Color(0xff9d55ff),
        title: 'Dash',
        body: 'Tap DASH for a burst. It costs stamina and has cooldown.',
      ),
      _TutorialTip(
        icon: Icons.local_fire_department_rounded,
        color: Color(0xffff405f),
        title: 'Tag',
        body: 'The red runner is IT. Tag runners to score and pass IT.',
      ),
      _TutorialTip(
        icon: Icons.bolt_rounded,
        color: Color(0xffffd64c),
        title: 'Stamina',
        body: 'Keep moving smart. Low stamina makes you slower.',
      ),
      _TutorialTip(
        icon: Icons.notifications_active_rounded,
        color: Color(0xff9d55ff),
        title: 'Bell Zone',
        body: 'Stand in the glowing zone to earn extra points.',
      ),
      _TutorialTip(
        icon: Icons.warning_rounded,
        color: Color(0xffff8a18),
        title: 'Final Rules',
        body: 'The yard shrinks, then Frenzy makes tags worth double.',
      ),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: Column(
          children: [
            _ArcadeScreenHeader(
              title: 'TUTORIAL',
              icon: Icons.school_rounded,
              color: const Color(0xffffd64c),
              onBack: onBack,
              trailing: Icon(
                darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: _arcadePlate(borderColor: const Color(0xffffd64c)),
              child: const Row(
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xffffd64c),
                    size: 30,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Win by scoring tags, surviving chases, and grabbing objective points.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            for (final tip in tips) ...[
              _TutorialTipCard(tip: tip),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              height: 62,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xffffa229),
                  foregroundColor: const Color(0xff182035),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow_rounded, size: 30),
                label: const Text(
                  'START ROUND',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialTip {
  const _TutorialTip({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

class _TutorialTipCard extends StatelessWidget {
  const _TutorialTipCard({required this.tip});

  final _TutorialTip tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: _arcadePlate(borderColor: tip.color),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tip.color.withValues(alpha: 0.2),
              border: Border.all(color: tip.color, width: 2),
            ),
            child: Icon(tip.icon, color: tip.color, size: 24),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tip.body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcadeScreenHeader extends StatelessWidget {
  const _ArcadeScreenHeader({
    required this.title,
    required this.icon,
    required this.color,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIconButton(
          icon: Icons.home_rounded,
          tooltip: 'Home',
          onPressed: onBack,
          compact: true,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: _arcadePlate(borderColor: color),
            child: Row(
              children: [
                Icon(icon, color: color, size: 27),
                const SizedBox(width: 9),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: Colors.black, offset: Offset(2, 2)),
                        ],
                      ),
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeResourcePill extends StatelessWidget {
  const _HomeResourcePill({
    required this.icon,
    required this.value,
    required this.color,
    required this.width,
    this.subLabel,
  });

  final IconData icon;
  final String value;
  final Color color;
  final double width;
  final String? subLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: subLabel == null ? 50 : 58,
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      decoration: _arcadePlate(
        borderColor: color,
        shadowColor: Colors.black.withValues(alpha: 0.56),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 27),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      height: 0.92,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: Colors.black, offset: Offset(1.5, 1.5)),
                      ],
                    ),
                  ),
                ),
                if (subLabel != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subLabel!,
                    style: const TextStyle(
                      color: Color(0xff39d9ff),
                      fontSize: 13,
                      height: 0.9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 5),
          Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xff47f7ff), Color(0xff0b93bf)],
              ),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _LogoPlaque extends StatelessWidget {
  const _LogoPlaque({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 96,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff384049), Color(0xff15191f)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff76818a), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0xbb000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(left: 4, top: 2, child: _PlaqueScrew()),
          const Positioned(right: 4, top: 2, child: _PlaqueScrew()),
          const Positioned(left: 4, bottom: 2, child: _PlaqueScrew()),
          const Positioned(right: 4, bottom: 2, child: _PlaqueScrew()),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'TAG TAG',
                    style: TextStyle(
                      color: Color(0xfffffbef),
                      fontSize: 47,
                      height: 0.86,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: Colors.black, offset: Offset(3, 3)),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'PLAYGROUND BLITZ',
                    style: TextStyle(
                      color: Color(0xffffd64c),
                      fontSize: 18,
                      height: 0.9,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: Colors.black, offset: Offset(2, 2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 12,
            top: 46,
            child: Icon(
              Icons.star_border_rounded,
              color: Color(0xff39d9ff),
              size: 25,
            ),
          ),
          const Positioned(
            right: 12,
            top: 48,
            child: Icon(
              Icons.flash_on_rounded,
              color: Color(0xffff405f),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaqueScrew extends StatelessWidget {
  const _PlaqueScrew();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xffadb6bd), Color(0xff14171b)],
        ),
        border: Border.all(color: Colors.black, width: 1),
      ),
    );
  }
}

class _HomeRunnerStage extends StatelessWidget {
  const _HomeRunnerStage({
    required this.selectedSkin,
    required this.selectedImage,
    required this.rivalOne,
    required this.rivalTwo,
    this.compact = false,
  });

  final _StoreSkin selectedSkin;
  final ui.Image? selectedImage;
  final ui.Image? rivalOne;
  final ui.Image? rivalTwo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroWidth = compact ? 222.0 : 244.0;
        final heroHeight = compact ? 222.0 : 244.0;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _SpotlightPainter(
                  color: selectedSkin.color,
                  compact: compact,
                ),
              ),
            ),
            Positioned(
              left: constraints.maxWidth * 0.12,
              top: 88,
              child: Transform.rotate(
                angle: -0.16,
                child: _RunnerCutout(
                  image: rivalOne,
                  color: const Color(0xff9d55ff),
                  width: 104,
                  height: 104,
                  flip: true,
                  opacity: 0.94,
                ),
              ),
            ),
            Positioned(
              right: constraints.maxWidth * 0.12,
              top: 58,
              child: Transform.rotate(
                angle: 0.18,
                child: _RunnerCutout(
                  image: rivalTwo,
                  color: const Color(0xffffd64c),
                  width: 100,
                  height: 100,
                  opacity: 0.94,
                ),
              ),
            ),
            Positioned(
              left: (constraints.maxWidth - heroWidth) / 2,
              bottom: compact ? 56 : 62,
              child: _RunnerCutout(
                image: selectedImage,
                color: selectedSkin.color,
                width: heroWidth,
                height: heroHeight,
                hero: true,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RunnerCutout extends StatelessWidget {
  const _RunnerCutout({
    required this.image,
    required this.color,
    required this.width,
    required this.height,
    this.hero = false,
    this.flip = false,
    this.opacity = 1,
  });

  final ui.Image? image;
  final Color color;
  final double width;
  final double height;
  final bool hero;
  final bool flip;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final character = image == null
        ? Icon(Icons.person_rounded, color: color, size: height * 0.48)
        : RawImage(
            image: image,
            fit: BoxFit.contain,
            alignment: Alignment.center,
          );

    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              bottom: hero ? 5 : 3,
              child: Container(
                width: width * (hero ? 0.58 : 0.62),
                height: hero ? 18 : 13,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: hero ? 0.38 : 0.26),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _SpeedTrailPainter(color: color, hero: hero),
              ),
            ),
            Positioned.fill(
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(flip ? -1 : 1, 1, 1),
                child: Padding(
                  padding: EdgeInsets.all(hero ? 0 : 5),
                  child: character,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedTrailPainter extends CustomPainter {
  const _SpeedTrailPainter({required this.color, required this.hero});

  final Color color;
  final bool hero;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = hero ? 3.5 : 2.2
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: hero ? 0.36 : 0.26);
    final startX = size.width * 0.12;
    final baseY = size.height * 0.58;
    for (var i = 0; i < 3; i += 1) {
      final y = baseY + i * (hero ? 18 : 11);
      canvas.drawLine(
        Offset(startX, y),
        Offset(size.width * (hero ? 0.42 : 0.46), y - 10),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedTrailPainter oldDelegate) {
    return color != oldDelegate.color || hero != oldDelegate.hero;
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.color, required this.compact});

  final Color color;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height * (compact ? 0.52 : 0.56),
    );
    final radius = math.min(size.width, size.height) * (compact ? 0.34 : 0.37);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.24),
          color.withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.5));
    canvas.drawCircle(center, radius * 1.5, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.56);
    canvas.drawCircle(center, radius, ring);
    canvas.drawCircle(
      center,
      radius * 0.62,
      ring..color = Colors.white.withValues(alpha: 0.24),
    );

    final chalk = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.28);
    for (var i = 0; i < 18; i += 1) {
      final angle = i * math.pi / 9;
      final inner = radius * 0.76;
      final outer = radius * 0.92;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        chalk,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return color != oldDelegate.color || compact != oldDelegate.compact;
  }
}

class _HomeMissionPanel extends StatelessWidget {
  const _HomeMissionPanel({
    required this.coins,
    required this.selectedArena,
    required this.selectedSkin,
    required this.selectedImage,
    this.compact = false,
  });

  final int coins;
  final ArenaBackground selectedArena;
  final _StoreSkin selectedSkin;
  final ui.Image? selectedImage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _HomeRewardCard(),
        const SizedBox(height: 8),
        _HomeAdCard(coins: coins),
        const SizedBox(height: 8),
        _HomeSkinCard(
          selectedArena: selectedArena,
          selectedSkin: selectedSkin,
          selectedImage: selectedImage,
        ),
      ],
    );
  }
}

class _HomeRewardCard extends StatelessWidget {
  const _HomeRewardCard();

  @override
  Widget build(BuildContext context) {
    return _HomeSideCard(
      height: 106,
      borderColor: const Color(0xffffd64c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DAILY REWARD',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black, offset: Offset(1, 1))],
            ),
          ),
          const Spacer(),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xffffd64c),
                  size: 43,
                ),
                Positioned(
                  right: 8,
                  bottom: 5,
                  child: Icon(
                    Icons.stars_rounded,
                    color: Colors.amber.shade200,
                    size: 17,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, color: Colors.white, size: 15),
                  SizedBox(width: 4),
                  Text(
                    '18h 45m',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeAdCard extends StatelessWidget {
  const _HomeAdCard({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return _HomeSideCard(
      height: 82,
      borderColor: const Color(0xff39d9ff),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.stars_rounded,
                color: Color(0xffffd64c),
                size: 22,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '+${math.min(250, coins + 100)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: Colors.black, offset: Offset(1, 1)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff31cdfc), Color(0xff0b74a9)],
              ),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: const Color(0xff84f5ff), width: 2),
            ),
            child: const Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'WATCH AD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 5),
                    Icon(Icons.smart_display_rounded, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSkinCard extends StatelessWidget {
  const _HomeSkinCard({
    required this.selectedArena,
    required this.selectedSkin,
    required this.selectedImage,
  });

  final ArenaBackground selectedArena;
  final _StoreSkin selectedSkin;
  final ui.Image? selectedImage;

  @override
  Widget build(BuildContext context) {
    return _HomeSideCard(
      height: 136,
      borderColor: selectedSkin.color,
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'SELECTED SKIN',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Positioned(
                  left: 0,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                const Positioned(
                  right: 0,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                _RunnerCutout(
                  image: selectedImage,
                  color: selectedSkin.color,
                  width: 76,
                  height: 76,
                  hero: true,
                ),
              ],
            ),
          ),
          Text(
            selectedSkin.name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xff39d9ff),
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: selectedSkin.color.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: selectedSkin.color, width: 2),
            ),
            child: Text(
              _arenaOptionFor(selectedArena).title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSideCard extends StatelessWidget {
  const _HomeSideCard({
    required this.child,
    required this.height,
    required this.borderColor,
  });

  final Widget child;
  final double height;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            borderColor.withValues(alpha: 0.28),
            const Color(0xf2121820),
            const Color(0xf205080b),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.58),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
          BoxShadow(color: borderColor.withValues(alpha: 0.18), blurRadius: 10),
        ],
      ),
      child: child,
    );
  }
}

class _HomeEnergyMeter extends StatelessWidget {
  const _HomeEnergyMeter();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: _arcadePlate(borderColor: const Color(0xff39d9ff)),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: Color(0xffffd64c), size: 24),
          const SizedBox(width: 7),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < 5; i += 1) ...[
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: i < 4
                              ? const [Color(0xff52ecff), Color(0xff0797d7)]
                              : const [Color(0xff24313b), Color(0xff11191f)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.34),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  if (i != 4) const SizedBox(width: 4),
                ],
              ],
            ),
          ),
          const SizedBox(width: 7),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xff0aa4cc),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress({
    required this.label,
    required this.value,
    required this.text,
  });

  final String label;
  final double value;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              text,
              style: const TextStyle(
                color: Color(0xffffd64c),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: value,
            color: const Color(0xff39d9ff),
            backgroundColor: Colors.black.withValues(alpha: 0.56),
          ),
        ),
      ],
    );
  }
}

class _ModeRail extends StatelessWidget {
  const _ModeRail({this.compact = false, this.onTap});

  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const modes = [
      _ModePreview(
        icon: Icons.bolt_rounded,
        title: 'Stamina Chase',
        badge: '3',
        color: Color(0xff39d9ff),
      ),
      _ModePreview(
        icon: Icons.notifications_active_rounded,
        title: 'Bell Zone',
        badge: '2',
        color: Color(0xff9d55ff),
      ),
      _ModePreview(
        icon: Icons.warning_rounded,
        title: 'Shrinking Yard',
        badge: '1',
        color: Color(0xffff405f),
      ),
      _ModePreview(
        icon: Icons.local_fire_department_rounded,
        title: 'Tag Frenzy',
        badge: '2',
        color: Color(0xffff8a18),
      ),
    ];

    if (compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < modes.length; i += 1) ...[
            _ModeCard(mode: modes[i], compact: true, onTap: onTap),
            if (i != modes.length - 1) const SizedBox(height: 9),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'MODES',
          style: TextStyle(
            color: Color(0xffffd64c),
            fontSize: 15,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black, offset: Offset(1, 1))],
          ),
        ),
        const SizedBox(height: 8),
        for (final mode in modes) ...[
          _ModeCard(mode: mode, onTap: onTap),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ModePreview {
  const _ModePreview({
    required this.icon,
    required this.title,
    required this.badge,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String badge;
  final Color color;
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, this.compact = false, this.onTap});

  final _ModePreview mode;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          height: compact ? 63 : 74,
          padding: EdgeInsets.fromLTRB(
            compact ? 8 : 9,
            compact ? 7 : 9,
            compact ? 7 : 9,
            compact ? 7 : 9,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                mode.color.withValues(alpha: 0.30),
                const Color(0xf213171d),
                const Color(0xf206080b),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: mode.color, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.60),
                blurRadius: 12,
                offset: const Offset(0, 7),
              ),
              BoxShadow(
                color: mode.color.withValues(alpha: 0.22),
                blurRadius: 10,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  Container(
                    width: compact ? 36 : 46,
                    height: compact ? 36 : 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          mode.color.withValues(alpha: 0.42),
                          const Color(0xff071016),
                        ],
                      ),
                      border: Border.all(color: mode.color, width: 2),
                    ),
                    child: Icon(
                      mode.icon,
                      color: mode.color,
                      size: compact ? 21 : 26,
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 10),
                  Expanded(
                    child: Text(
                      mode.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 15 : 18,
                        fontWeight: FontWeight.w900,
                        height: 0.92,
                        shadows: const [
                          Shadow(color: Colors.black, offset: Offset(1.5, 1.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: -12,
                top: -14,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xffffd64c),
                    border: Border.all(
                      color: const Color(0xff182035),
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0xaa000000), blurRadius: 8),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      mode.badge,
                      style: const TextStyle(
                        color: Color(0xff182035),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBottomDock extends StatelessWidget {
  const _HomeBottomDock({
    required this.onStore,
    required this.onSetup,
    required this.onAvatars,
    required this.onMissions,
    this.compact = false,
  });

  final VoidCallback onStore;
  final VoidCallback onSetup;
  final VoidCallback onAvatars;
  final VoidCallback onMissions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final nav = [
      _MenuButton(
        icon: Icons.storefront_rounded,
        label: 'STORE',
        onPressed: onStore,
      ),
      _MenuButton(icon: Icons.tune_rounded, label: 'SETUP', onPressed: onSetup),
      _MenuButton(
        icon: Icons.diversity_3_rounded,
        label: 'AVATARS',
        onPressed: onAvatars,
      ),
      _MenuButton(
        icon: Icons.assignment_rounded,
        label: 'MISSIONS',
        onPressed: onMissions,
      ),
    ];

    if (compact) {
      return Row(
        children: [
          Expanded(
            child: _MiniDockButton(
              icon: Icons.storefront_rounded,
              label: 'STORE',
              onPressed: onStore,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _MiniDockButton(
              icon: Icons.tune_rounded,
              label: 'SETUP',
              onPressed: onSetup,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _MiniDockButton(
              icon: Icons.diversity_3_rounded,
              label: 'AVATARS',
              onPressed: onAvatars,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _MiniDockButton(
              icon: Icons.assignment_rounded,
              label: 'MISSIONS',
              onPressed: onMissions,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        nav[0],
        const SizedBox(width: 8),
        nav[1],
        const SizedBox(width: 8),
        nav[2],
        const SizedBox(width: 8),
        nav[3],
      ],
    );
  }
}

class _MiniDockButton extends StatelessWidget {
  const _MiniDockButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xff303940), Color(0xff080c10)],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xff7c8992), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0xaa000000),
                blurRadius: 12,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xff39d9ff).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xff39d9ff).withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(icon, color: const Color(0xff39d9ff), size: 25),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    shadows: [
                      Shadow(color: Colors.black, offset: Offset(1, 1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryPlayButton extends StatelessWidget {
  const _PrimaryPlayButton({
    required this.onPressed,
    this.compact = false,
    this.height,
  });

  final VoidCallback onPressed;
  final bool compact;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? double.infinity : 252,
      height: height ?? (compact ? 82 : 76),
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xfffff06a), Color(0xffff9d16)],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0xcc000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
              BoxShadow(
                color: Color(0x88ffdd35),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.directions_run_rounded,
                    color: Color(0xff182035),
                    size: 42,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'PLAY',
                    style: TextStyle(
                      color: const Color(0xff182035),
                      fontSize: compact ? 43 : 30,
                      height: 0.9,
                      fontWeight: FontWeight.w900,
                      shadows: const [
                        Shadow(color: Colors.white, offset: Offset(1.5, 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xff332310).withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Text(
                  'QUICK MATCH',
                  style: TextStyle(
                    color: Color(0xffffd64c),
                    fontSize: 15,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({
    required this.coins,
    required this.onBack,
    this.compact = false,
  });

  final int coins;
  final VoidCallback onBack;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIconButton(
          icon: Icons.home_rounded,
          tooltip: 'Home',
          onPressed: onBack,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: compact ? 58 : 66,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: _arcadePlate(borderColor: const Color(0xffffd64c)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const Icon(
                    Icons.storefront_rounded,
                    color: Color(0xffffd64c),
                    size: 28,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    compact ? 'STORE' : 'RUNNER STORE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: Colors.black, offset: Offset(2, 2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _CoinStrip(coins: coins, large: !compact),
      ],
    );
  }
}

class _StoreFeaturePanel extends StatelessWidget {
  const _StoreFeaturePanel({required this.skin, required this.image});

  final _StoreSkin skin;
  final ui.Image? image;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _arcadePlate(borderColor: skin.color),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'SELECTED RUNNER',
            style: TextStyle(
              color: Color(0xffffd64c),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _SkinPortrait(image: image, color: skin.color, size: 170, hero: true),
          const SizedBox(height: 12),
          Text(
            skin.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black, offset: Offset(2, 2))],
            ),
          ),
          const SizedBox(height: 10),
          const _MiniProgress(label: 'Sprint Style', value: 0.82, text: '82%'),
          const SizedBox(height: 8),
          const _MiniProgress(label: 'Tag Flair', value: 0.68, text: '68%'),
        ],
      ),
    );
  }
}

class _StoreGrid extends StatelessWidget {
  const _StoreGrid({
    required this.coins,
    required this.selectedAvatar,
    required this.unlockedAvatars,
    required this.avatars,
    required this.onSelect,
    this.compact = false,
  });

  final int coins;
  final PlayerAvatar selectedAvatar;
  final Set<PlayerAvatar> unlockedAvatars;
  final Map<PlayerAvatar, ui.Image> avatars;
  final ValueChanged<_StoreSkin> onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _arcadePlate(borderColor: const Color(0xff617380)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = compact || constraints.maxWidth < 600 ? 2 : 3;
          final spacing = compact ? 8.0 : 10.0;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return SingleChildScrollView(
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final skin in _storeSkins)
                  SizedBox(
                    width: width,
                    child: _StoreSkinCard(
                      skin: skin,
                      image: avatars[skin.avatar],
                      coins: coins,
                      selected: selectedAvatar == skin.avatar,
                      unlocked: unlockedAvatars.contains(skin.avatar),
                      onTap: () => onSelect(skin),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.compact = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            width: compact ? 44 : 52,
            height: compact ? 44 : 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xee242d35), Color(0xee05080b)],
              ),
              border: Border.all(color: Colors.white70, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 14,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: compact ? 22 : 25),
          ),
        ),
      ),
    );
  }
}

class _StoreSkinCard extends StatelessWidget {
  const _StoreSkinCard({
    required this.skin,
    required this.image,
    required this.coins,
    required this.selected,
    required this.unlocked,
    required this.onTap,
  });

  final _StoreSkin skin;
  final ui.Image? image;
  final int coins;
  final bool selected;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canBuy = coins >= skin.price;
    final actionText = selected
        ? 'SELECTED'
        : unlocked
        ? 'SELECT'
        : canBuy
        ? '${skin.price}'
        : '${skin.price}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: selected ? null : onTap,
        child: Container(
          height: 184,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? [
                      skin.color.withValues(alpha: 0.56),
                      const Color(0xee10171d),
                    ]
                  : [const Color(0xee26323a), const Color(0xee0a0f14)],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? skin.color
                  : Colors.white.withValues(alpha: 0.2),
              width: selected ? 3 : 2,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: skin.color.withValues(alpha: 0.38),
                  blurRadius: 18,
                ),
              const BoxShadow(
                color: Color(0x77000000),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xffffd64c)
                        : unlocked
                        ? const Color(0xff39d9ff)
                        : Colors.black.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    selected
                        ? 'ON'
                        : unlocked
                        ? 'OWNED'
                        : 'LOCKED',
                    style: TextStyle(
                      color: selected ? const Color(0xff182035) : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: _SkinPortrait(
                    image: image,
                    color: skin.color,
                    size: 92,
                    showBadge: false,
                  ),
                ),
              ),
              Text(
                skin.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black, offset: Offset(1, 1))],
                ),
              ),
              const SizedBox(height: 7),
              Container(
                height: 32,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: selected
                        ? const [Color(0xffffed61), Color(0xffffa229)]
                        : unlocked || canBuy
                        ? [skin.color, skin.color.withValues(alpha: 0.68)]
                        : const [Color(0xff747b82), Color(0xff444b52)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white38, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      unlocked
                          ? Icons.check_circle_rounded
                          : Icons.stars_rounded,
                      size: 17,
                      color: selected ? const Color(0xff182035) : Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        actionText,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xff182035)
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkinPortrait extends StatelessWidget {
  const _SkinPortrait({
    required this.image,
    required this.color,
    required this.size,
    this.hero = false,
    this.showBadge = true,
  });

  final ui.Image? image;
  final Color color;
  final double size;
  final bool hero;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: hero ? 0.46 : 0.26),
                    const Color(0xff0b1116).withValues(alpha: 0.92),
                  ],
                ),
                border: Border.all(color: color, width: hero ? 5 : 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: hero ? 0.48 : 0.28),
                    blurRadius: hero ? 28 : 12,
                  ),
                  const BoxShadow(
                    color: Color(0xaa000000),
                    blurRadius: 14,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: ClipOval(
              child: Padding(
                padding: EdgeInsets.all(hero ? 6 : 3),
                child: image == null
                    ? Icon(Icons.person_rounded, color: color, size: size * 0.5)
                    : RawImage(image: image, fit: BoxFit.contain),
              ),
            ),
          ),
          if (showBadge)
            Positioned(
              right: hero ? 10 : -2,
              bottom: hero ? 12 : -2,
              child: Container(
                width: hero ? 42 : 27,
                height: hero ? 42 : 27,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xffffd64c),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0xaa000000), blurRadius: 8),
                  ],
                ),
                child: Icon(
                  Icons.directions_run_rounded,
                  size: hero ? 25 : 16,
                  color: const Color(0xff182035),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoinStrip extends StatelessWidget {
  const _CoinStrip({required this.coins, this.large = false});

  final int coins;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: large ? 52 : 44,
      padding: EdgeInsets.symmetric(horizontal: large ? 14 : 11),
      decoration: _arcadePlate(borderColor: const Color(0xffffd64c)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.stars_rounded,
            color: const Color(0xffffd64c),
            size: large ? 24 : 20,
          ),
          const SizedBox(width: 7),
          Text(
            coins.toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: large ? 20 : 16,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(color: Colors.black, offset: Offset(1, 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xee10171d),
          side: const BorderSide(color: Color(0xff6f7f89), width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: onPressed,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xff39d9ff), size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

_StoreSkin _skinForAvatar(PlayerAvatar avatar) {
  return _storeSkins.firstWhere(
    (skin) => skin.avatar == avatar,
    orElse: () => _storeSkins.first,
  );
}

_ArenaOption _arenaOptionFor(ArenaBackground arena) {
  return _arenaOptions.firstWhere(
    (option) => option.arena == arena,
    orElse: () => _arenaOptions.first,
  );
}

String _arenaAssetPath(ArenaBackground arena) {
  return switch (arena) {
    ArenaBackground.base => 'assets/backgrounds/playground_base.png',
    ArenaBackground.bellZone => 'assets/backgrounds/playground_bell_zone.png',
    ArenaBackground.shrinkingYard =>
      'assets/backgrounds/playground_shrinking_yard.png',
    ArenaBackground.frenzy => 'assets/backgrounds/playground_frenzy.png',
  };
}

String _formatNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index += 1) {
    final remaining = digits.length - index;
    if (index > 0 && remaining % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

class _GameHud extends StatelessWidget {
  const _GameHud({required this.simulation});

  final PlaygroundBlitzSimulation simulation;

  @override
  Widget build(BuildContext context) {
    final seconds = simulation.timer.ceil();
    final timerText =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    final totalTags = simulation.players.fold<int>(
      0,
      (total, player) => total + player.tags,
    );

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          return IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  left: 12,
                  top: 10,
                  child: _ModeBanner(
                    title: _modeTitle(simulation),
                    compact: compact,
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 10,
                  child: Row(
                    children: [
                      _TimerPlate(text: timerText, compact: compact),
                      SizedBox(width: compact ? 6 : 8),
                      _TagsPlate(
                        value: totalTags,
                        target: 15,
                        compact: compact,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: compact ? 12 : 18,
                  top: compact ? 84 : 92,
                  child: _RosterStack(
                    players: simulation.players.take(compact ? 3 : 4).toList(),
                    compact: compact,
                  ),
                ),
                Positioned(
                  top: compact ? 74 : 78,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _EventBanner(
                      simulation: simulation,
                      compact: compact,
                    ),
                  ),
                ),
                Positioned(
                  bottom: compact ? 148 : 28,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _ObjectiveToast(
                      simulation: simulation,
                      compact: compact,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _modeTitle(PlaygroundBlitzSimulation simulation) {
    if (simulation.frenzy) {
      return 'Tag Frenzy';
    }
    if (simulation.shrinkProgress > 0.42) {
      return 'Shrinking Yard';
    }
    if (simulation.bellZone.active) {
      return 'Bell Zone';
    }
    return 'Stamina Chase';
  }
}

class _ModeBanner extends StatelessWidget {
  const _ModeBanner({required this.title, this.compact = false});

  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 168 : 206,
      height: compact ? 52 : 56,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
      decoration: _arcadePlate(
        borderColor: const Color(0xff607080),
        shadowColor: Colors.black.withValues(alpha: 0.42),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black, offset: Offset(2, 2))],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimerPlate extends StatelessWidget {
  const _TimerPlate({required this.text, this.compact = false});

  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 48 : 50,
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 13),
      decoration: _arcadePlate(borderColor: const Color(0xff657480)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            color: Colors.white,
            size: compact ? 21 : 25,
          ),
          SizedBox(width: compact ? 5 : 7),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 17 : 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagsPlate extends StatelessWidget {
  const _TagsPlate({
    required this.value,
    required this.target,
    this.compact = false,
  });

  final int value;
  final int target;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 62 : 72,
      height: compact ? 52 : 56,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: _arcadePlate(borderColor: const Color(0xff657480)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TAGS',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black, offset: Offset(1, 1))],
                ),
                children: [
                  TextSpan(
                    text: value.toString().padLeft(2, '0'),
                    style: const TextStyle(color: Color(0xffff405f)),
                  ),
                  const TextSpan(
                    text: '/',
                    style: TextStyle(color: Colors.white),
                  ),
                  TextSpan(
                    text: target.toString(),
                    style: const TextStyle(color: Colors.white),
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

class _RosterStack extends StatelessWidget {
  const _RosterStack({required this.players, this.compact = false});

  final List<PlayerState> players;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final player in players) ...[
          _RosterRow(player: player, compact: compact),
          SizedBox(height: compact ? 6 : 8),
        ],
      ],
    );
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.player, this.compact = false});

  final PlayerState player;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final staminaColor = player.stamina < 18
        ? const Color(0xffff405f)
        : player.stamina < 45
        ? const Color(0xffffc845)
        : const Color(0xff26c9ff);
    return Container(
      width: compact ? 118 : 128,
      height: compact ? 44 : 48,
      padding: const EdgeInsets.fromLTRB(5, 4, 8, 4),
      decoration: _arcadePlate(
        borderColor: player.isIt
            ? const Color(0xffff405f)
            : player.isHuman
            ? const Color(0xff28c7ff)
            : const Color(0xff64717d),
      ),
      child: Row(
        children: [
          _AvatarDot(player: player, size: compact ? 35 : 39),
          SizedBox(width: compact ? 6 : 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      player.isIt ? Icons.local_fire_department : Icons.star,
                      color: player.isIt
                          ? const Color(0xffff405f)
                          : const Color(0xffffd64c),
                      size: 16,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        player.isIt
                            ? 'IT'
                            : player.score.round().toString().padLeft(2, '0'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: (player.stamina / 100).clamp(0.0, 1.0).toDouble(),
                    color: staminaColor,
                    backgroundColor: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarDot extends StatelessWidget {
  const _AvatarDot({required this.player, required this.size});

  final PlayerState player;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xff10161c),
        border: Border.all(color: player.color, width: 3),
        boxShadow: [
          BoxShadow(
            color: player.color.withValues(alpha: 0.42),
            blurRadius: 10,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size - 10,
          height: size - 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xffffc48d),
                player.color.withValues(alpha: 0.9),
              ],
            ),
          ),
          child: Center(
            child: Text(
              player.name.isEmpty
                  ? '?'
                  : player.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Color(0xff111820),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventBanner extends StatelessWidget {
  const _EventBanner({required this.simulation, this.compact = false});

  final PlaygroundBlitzSimulation simulation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (simulation.frenzy) {
      return _CenterEventPlate(
        icon: Icons.flash_on_rounded,
        label: 'FRENZY',
        value: _countdown(simulation.timer),
        color: const Color(0xffff7a1a),
        compact: compact,
      );
    }
    if (simulation.shrinkProgress > 0.42) {
      final seconds = (12 - simulation.shrinkProgress * 9).ceil().clamp(1, 12);
      return _CenterEventPlate(
        icon: Icons.warning_rounded,
        label: 'YARD CLOSING',
        value: seconds.toString(),
        color: const Color(0xffff405f),
        compact: compact,
      );
    }
    if (simulation.bellZone.active) {
      return _CenterEventPlate(
        icon: Icons.notifications_active_rounded,
        label: 'Bell Zone',
        value: simulation.bellZone.timeLeft.ceil().toString().padLeft(2, '0'),
        color: const Color(0xff9d55ff),
        compact: compact,
      );
    }
    return const SizedBox.shrink();
  }

  String _countdown(double seconds) {
    final whole = seconds.ceil();
    return '0:${whole.toString().padLeft(2, '0')}';
  }
}

class _CenterEventPlate extends StatelessWidget {
  const _CenterEventPlate({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconColor = color == const Color(0xff9d55ff)
        ? const Color(0xffffd64c)
        : color == const Color(0xffff405f)
        ? const Color(0xffffd64c)
        : color;
    return Container(
      height: compact ? 46 : 66,
      constraints: BoxConstraints(
        minWidth: compact ? 150 : 190,
        maxWidth: compact ? 184 : 240,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 14,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xf0212833), Color(0xf0060a10)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.88),
          width: compact ? 2 : 3,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: compact ? 0.22 : 0.34),
            blurRadius: compact ? 12 : 18,
          ),
          BoxShadow(
            color: const Color(0x99000000),
            blurRadius: compact ? 10 : 16,
            offset: Offset(0, compact ? 5 : 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 31 : 40,
            height: compact ? 31 : 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
              border: Border.all(
                color: color.withValues(alpha: 0.82),
                width: 2,
              ),
            ),
            child: Icon(icon, color: iconColor, size: compact ? 19 : 25),
          ),
          SizedBox(width: compact ? 7 : 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 13 : 17,
                fontWeight: FontWeight.w900,
                height: 1,
                shadows: const [
                  Shadow(color: Colors.black, offset: Offset(1, 1)),
                ],
              ),
            ),
          ),
          SizedBox(width: compact ? 7 : 10),
          Container(
            constraints: BoxConstraints(minWidth: compact ? 42 : 58),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 7 : 10,
              vertical: compact ? 4 : 5,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: color.withValues(alpha: 0.82),
                width: 2,
              ),
            ),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 20 : 28,
                fontWeight: FontWeight.w900,
                height: 1,
                shadows: const [
                  Shadow(color: Colors.black, offset: Offset(1.5, 1.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObjectiveToast extends StatelessWidget {
  const _ObjectiveToast({required this.simulation, this.compact = false});

  final PlaygroundBlitzSimulation simulation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final icon = simulation.frenzy
        ? Icons.local_fire_department_rounded
        : simulation.shrinkProgress > 0.42
        ? Icons.warning_amber_rounded
        : simulation.bellZone.active
        ? Icons.star_rounded
        : Icons.bolt_rounded;
    final title = simulation.frenzy
        ? 'Tag streak x2'
        : simulation.shrinkProgress > 0.42
        ? 'Yard closing'
        : simulation.bellZone.active
        ? 'Stay in the zone'
        : 'Watch your stamina';
    final body = simulation.frenzy
        ? 'Quick tags score double!'
        : simulation.shrinkProgress > 0.42
        ? 'Stay inside the cones!'
        : simulation.bellZone.active
        ? 'to earn points!'
        : 'Low stamina = slower!';
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 250 : 360),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 8 : 10,
      ),
      decoration: _arcadePlate(borderColor: const Color(0xff657480)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xffffd64c), size: compact ? 22 : 28),
          SizedBox(width: compact ? 8 : 10),
          Flexible(
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 13 : 16,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
                children: [
                  TextSpan(
                    text: '$title\n',
                    style: const TextStyle(
                      color: Color(0xffffe36a),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({
    required this.simulation,
    required this.stickOffset,
    required this.onStickChanged,
    required this.onStickReleased,
    required this.onDash,
  });

  final PlaygroundBlitzSimulation simulation;
  final Offset stickOffset;
  final void Function(Offset localPosition, Size size) onStickChanged;
  final VoidCallback onStickReleased;
  final VoidCallback onDash;

  @override
  Widget build(BuildContext context) {
    final human = simulation.human;
    final cooldownProgress = human.dashCooldown <= 0
        ? 1.0
        : (1 - human.dashCooldown / 3.8).clamp(0.0, 1.0).toDouble();
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 20 : 24,
              14,
              compact ? 20 : 24,
              compact ? 18 : 24,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Joystick(
                    stickOffset: stickOffset,
                    size: compact ? 112 : 126,
                    onChanged: onStickChanged,
                    onReleased: onStickReleased,
                  ),
                  const Spacer(),
                  _ShoeDashButton(
                    cooldownText: human.dashCooldown <= 0
                        ? 'DASH'
                        : '${human.dashCooldown.toStringAsFixed(1)}s',
                    enabled: human.dashCooldown <= 0 && human.stamina >= 18,
                    progress: cooldownProgress,
                    size: compact ? 108 : 118,
                    onPressed: onDash,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Joystick extends StatelessWidget {
  const _Joystick({
    required this.stickOffset,
    required this.size,
    required this.onChanged,
    required this.onReleased,
  });

  final Offset stickOffset;
  final double size;
  final void Function(Offset localPosition, Size size) onChanged;
  final VoidCallback onReleased;

  @override
  Widget build(BuildContext context) {
    final innerSize = size * 0.67;
    final knobSize = size * 0.38;
    final knobBase = (size - knobSize) / 2;
    return SizedBox(
      width: size,
      height: size,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onPanDown: (details) => onChanged(details.localPosition, size),
            onPanUpdate: (details) => onChanged(details.localPosition, size),
            onPanEnd: (_) => onReleased(),
            onPanCancel: onReleased,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xff080d12).withValues(alpha: 0.38),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.34),
                  width: 5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: innerSize,
                      height: innerSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: knobBase + stickOffset.dx,
                    top: knobBase + stickOffset.dy,
                    child: Container(
                      width: knobSize,
                      height: knobSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xff46dcff), Color(0xff066d95)],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.62),
                          width: 3,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0x8800b7ff), blurRadius: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ShoeDashButton extends StatelessWidget {
  const _ShoeDashButton({
    required this.cooldownText,
    required this.enabled,
    required this.progress,
    required this.size,
    required this.onPressed,
  });

  final String cooldownText;
  final bool enabled;
  final double progress;
  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: enabled ? (_) => onPressed() : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.5,
        duration: const Duration(milliseconds: 120),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _CooldownRingPainter(
                  progress: progress,
                  enabled: enabled,
                ),
              ),
              Container(
                width: size * 0.81,
                height: size * 0.81,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: enabled
                        ? const [Color(0xffb244ff), Color(0xff4d146f)]
                        : const [Color(0xff27313c), Color(0xff0f1419)],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.36),
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xaa000000),
                      blurRadius: 22,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
              ),
              Transform.rotate(
                angle: -0.35,
                child: Icon(
                  Icons.directions_run_rounded,
                  size: size * 0.41,
                  color: Colors.white,
                ),
              ),
              Positioned(
                bottom: size * 0.12,
                child: Text(
                  cooldownText,
                  style: TextStyle(
                    color: enabled ? Colors.white : Colors.white70,
                    fontSize: size < 112 ? 13 : 15,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(color: Colors.black, offset: Offset(2, 2)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CooldownRingPainter extends CustomPainter {
  const _CooldownRingPainter({required this.progress, required this.enabled});

  final double progress;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 7;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.22);
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: enabled
            ? const [Color(0xfff9f7ff), Color(0xff7adfff), Color(0xfff9f7ff)]
            : const [Color(0xff6f7780), Color(0xff444b52), Color(0xff6f7780)],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, radius, base);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _CooldownRingPainter oldDelegate) {
    return progress != oldDelegate.progress || enabled != oldDelegate.enabled;
  }
}

class _ResultsOverlay extends StatelessWidget {
  const _ResultsOverlay({
    required this.simulation,
    required this.coins,
    required this.reward,
    required this.onPlayAgain,
    required this.onStore,
    required this.onHome,
  });

  final PlaygroundBlitzSimulation simulation;
  final int coins;
  final int reward;
  final VoidCallback onPlayAgain;
  final VoidCallback onStore;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final winner = simulation.winner;
    final human = simulation.human;
    return ColoredBox(
      color: const Color(0xaa182035),
      child: Center(
        child: _Panel(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Kicker('Round Complete'),
              Text(
                winner.isHuman
                    ? 'You won the yard'
                    : '${winner.name} won the yard',
                style: const TextStyle(
                  color: Color(0xff182035),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You scored ${human.score.round()} with ${human.tags} tag${human.tags == 1 ? '' : 's'}. Reward: +$reward coins.',
                style: TextStyle(
                  color: const Color(0xff182035).withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _CoinStrip(coins: coins),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: onPlayAgain,
                      child: const Text('Play again'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onStore,
                      child: const Text('Store'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onHome,
                      child: const Text('Home'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfffffbec).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.76),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4d182035),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xffffc743),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xff182035),
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Text(
              display,
              style: TextStyle(
                color: const Color(0xff182035).withValues(alpha: 0.66),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: const Color(0xffff3f68),
          inactiveColor: const Color(0xff182035).withValues(alpha: 0.24),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TempoSelector extends StatelessWidget {
  const _TempoSelector({required this.difficulty, required this.onChanged});

  final Difficulty difficulty;
  final ValueChanged<Difficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<Difficulty>(
      segments: const [
        ButtonSegment(value: Difficulty.chill, label: Text('Chill')),
        ButtonSegment(value: Difficulty.balanced, label: Text('Balanced')),
        ButtonSegment(value: Difficulty.blitz, label: Text('Blitz')),
      ],
      selected: {difficulty},
      showSelectedIcon: false,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xff182035)
              : const Color(0xff182035),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xffffe3a1)
              : const Color(0xfffffdf3),
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? const Color(0xffff3f68)
                : const Color(0x33182035),
            width: 2,
          ),
        ),
      ),
      onSelectionChanged: (value) => onChanged(value.first),
    );
  }
}

BoxDecoration _arcadePlate({Color? borderColor, Color? shadowColor}) {
  return BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xee1b2229), Color(0xee05080b)],
    ),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: (borderColor ?? Colors.white).withValues(alpha: 0.68),
      width: 2,
    ),
    boxShadow: [
      BoxShadow(
        color: shadowColor ?? const Color(0xaa000000),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
