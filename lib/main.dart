import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_painter.dart';
import 'game_simulation.dart';

enum _ShellScreen { home, game, setup, store }

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
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
  PlayerAvatar _selectedAvatar = PlayerAvatar.blue;
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
    final unlockedNames = prefs.getStringList('unlocked_avatars');
    final selected = _avatarFromName(selectedName) ?? PlayerAvatar.blue;
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
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins', _coins);
    await prefs.setString('selected_avatar', _selectedAvatar.name);
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
            ),
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
              selectedAvatar: _selectedAvatar,
              avatars: _avatarSprites,
              onPlay: _startGame,
              onStore: _openStore,
              onSetup: _openSetup,
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
    required this.selectedAvatar,
    required this.avatars,
    required this.onPlay,
    required this.onStore,
    required this.onSetup,
  });

  final int coins;
  final PlayerAvatar selectedAvatar;
  final Map<PlayerAvatar, ui.Image> avatars;
  final VoidCallback onPlay;
  final VoidCallback onStore;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final selectedSkin = _skinForAvatar(selectedAvatar);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 360,
              child: _Panel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Kicker('Playground Blitz'),
                    const Text(
                      'Tag Tag',
                      style: TextStyle(
                        color: Color(0xff182035),
                        fontSize: 54,
                        height: 0.88,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _CoinStrip(coins: coins),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _SkinPortrait(
                          image: avatars[selectedAvatar],
                          color: selectedSkin.color,
                          size: 96,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedSkin.name,
                                style: const TextStyle(
                                  color: Color(0xff182035),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Selected runner',
                                style: TextStyle(
                                  color: const Color(
                                    0xff182035,
                                  ).withValues(alpha: 0.62),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xffff405f),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: onPlay,
                        icon: const Icon(Icons.play_arrow_rounded, size: 30),
                        label: const Text(
                          'Play',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MenuButton(
                            icon: Icons.storefront_rounded,
                            label: 'Store',
                            onPressed: onStore,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MenuButton(
                            icon: Icons.tune_rounded,
                            label: 'Setup',
                            onPressed: onSetup,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
          ],
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
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: _Panel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Home',
                        onPressed: onBack,
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xff182035),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Runner Store',
                          style: TextStyle(
                            color: Color(0xff182035),
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _CoinStrip(coins: coins),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 760;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final skin in _storeSkins)
                            SizedBox(
                              width: compact
                                  ? (constraints.maxWidth - 10) / 2
                                  : (constraints.maxWidth - 30) / 3,
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
                      );
                    },
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
        ? 'Selected'
        : unlocked
        ? 'Select'
        : canBuy
        ? '${skin.price}'
        : '${skin.price}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: selected ? null : onTap,
        child: Container(
          height: 172,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? skin.color.withValues(alpha: 0.24)
                : const Color(0xff182035).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? skin.color
                  : const Color(0xff182035).withValues(alpha: 0.18),
              width: selected ? 3 : 2,
            ),
          ),
          child: Column(
            children: [
              _SkinPortrait(image: image, color: skin.color, size: 82),
              const SizedBox(height: 6),
              Text(
                skin.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xff182035),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xff182035)
                      : unlocked || canBuy
                      ? skin.color
                      : const Color(0xff68717b),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!unlocked) ...[
                      const Icon(
                        Icons.stars_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        actionText,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
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
  });

  final ui.Image? image;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color, width: 3),
      ),
      child: image == null
          ? Icon(Icons.person_rounded, color: color, size: size * 0.5)
          : RawImage(image: image, fit: BoxFit.contain),
    );
  }
}

class _CoinStrip extends StatelessWidget {
  const _CoinStrip({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xff182035),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xffffd64c), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, color: Color(0xffffd64c), size: 19),
          const SizedBox(width: 6),
          Text(
            coins.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
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
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xff182035),
        side: const BorderSide(color: Color(0xff182035), width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

_StoreSkin _skinForAvatar(PlayerAvatar avatar) {
  return _storeSkins.firstWhere(
    (skin) => skin.avatar == avatar,
    orElse: () => _storeSkins.first,
  );
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
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              left: 12,
              top: 10,
              child: _ModeBanner(title: _modeTitle(simulation)),
            ),
            Positioned(
              right: 12,
              top: 10,
              child: Row(
                children: [
                  _TimerPlate(text: timerText),
                  const SizedBox(width: 8),
                  _TagsPlate(value: totalTags, target: 15),
                ],
              ),
            ),
            Positioned(
              left: 18,
              top: 92,
              child: _RosterStack(players: simulation.players.take(4).toList()),
            ),
            Positioned(
              top: 78,
              left: 0,
              right: 0,
              child: Center(child: _EventBanner(simulation: simulation)),
            ),
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Center(child: _ObjectiveToast(simulation: simulation)),
            ),
          ],
        ),
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
  const _ModeBanner({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 206,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
  const _TimerPlate({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: _arcadePlate(borderColor: const Color(0xff657480)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 25),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
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
  const _TagsPlate({required this.value, required this.target});

  final int value;
  final int target;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 56,
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
  const _RosterStack({required this.players});

  final List<PlayerState> players;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final player in players) ...[
          _RosterRow(player: player),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.player});

  final PlayerState player;

  @override
  Widget build(BuildContext context) {
    final staminaColor = player.stamina < 18
        ? const Color(0xffff405f)
        : player.stamina < 45
        ? const Color(0xffffc845)
        : const Color(0xff26c9ff);
    return Container(
      width: 128,
      height: 48,
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
          _AvatarDot(player: player, size: 39),
          const SizedBox(width: 7),
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
  const _EventBanner({required this.simulation});

  final PlaygroundBlitzSimulation simulation;

  @override
  Widget build(BuildContext context) {
    if (simulation.frenzy) {
      return _CenterEventPlate(
        icon: Icons.flash_on_rounded,
        label: 'FRENZY',
        value: _countdown(simulation.timer),
        color: const Color(0xffff7a1a),
      );
    }
    if (simulation.shrinkProgress > 0.42) {
      final seconds = (12 - simulation.shrinkProgress * 9).ceil().clamp(1, 12);
      return _CenterEventPlate(
        icon: Icons.warning_rounded,
        label: 'YARD CLOSING',
        value: seconds.toString(),
        color: const Color(0xffff405f),
      );
    }
    if (simulation.bellZone.active) {
      return _CenterEventPlate(
        icon: Icons.notifications_active_rounded,
        label: 'Bell Zone',
        value: simulation.bellZone.timeLeft.ceil().toString().padLeft(2, '0'),
        color: const Color(0xff9d55ff),
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
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      constraints: const BoxConstraints(minWidth: 168, maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.88),
            const Color(0xff171923).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.96), width: 3),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.64), blurRadius: 24),
          const BoxShadow(
            color: Color(0x99000000),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xffffd64c), size: 34),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color == const Color(0xffff405f)
                      ? const Color(0xffffcfd5)
                      : const Color(0xffffd64c),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  shadows: [Shadow(color: Colors.black, offset: Offset(2, 2))],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ObjectiveToast extends StatelessWidget {
  const _ObjectiveToast({required this.simulation});

  final PlaygroundBlitzSimulation simulation;

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
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: _arcadePlate(borderColor: const Color(0xff657480)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xffffd64c), size: 28),
          const SizedBox(width: 10),
          Flexible(
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Joystick(
                stickOffset: stickOffset,
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
                onPressed: onDash,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Joystick extends StatelessWidget {
  const _Joystick({
    required this.stickOffset,
    required this.onChanged,
    required this.onReleased,
  });

  final Offset stickOffset;
  final void Function(Offset localPosition, Size size) onChanged;
  final VoidCallback onReleased;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 126,
      height: 126,
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
                      width: 84,
                      height: 84,
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
                    left: 39 + stickOffset.dx,
                    top: 39 + stickOffset.dy,
                    child: Container(
                      width: 48,
                      height: 48,
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
    required this.onPressed,
  });

  final String cooldownText;
  final bool enabled;
  final double progress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: enabled ? (_) => onPressed() : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.5,
        duration: const Duration(milliseconds: 120),
        child: SizedBox(
          width: 118,
          height: 118,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(118),
                painter: _CooldownRingPainter(
                  progress: progress,
                  enabled: enabled,
                ),
              ),
              Container(
                width: 96,
                height: 96,
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
                child: const Icon(
                  Icons.directions_run_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              Positioned(
                bottom: 14,
                child: Text(
                  cooldownText,
                  style: TextStyle(
                    color: enabled ? Colors.white : Colors.white70,
                    fontSize: 15,
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
