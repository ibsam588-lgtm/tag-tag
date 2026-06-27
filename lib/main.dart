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

enum _ShellScreen { home, game, setup, store, arenas, tutorial, missions }

enum _TutorialStep { move, dash, pickup, bounty, complete }

extension _TutorialStepCopy on _TutorialStep {
  String get title {
    return switch (this) {
      _TutorialStep.move => 'Move To Survive',
      _TutorialStep.dash => 'Dash Out',
      _TutorialStep.pickup => 'Grab A Power-Up',
      _TutorialStep.bounty => 'Tag The Crown',
      _TutorialStep.complete => 'Ready For The Yard',
    };
  }

  String get body {
    return switch (this) {
      _TutorialStep.move => 'Drag the joystick until the meter fills.',
      _TutorialStep.dash => 'Tap the shoe button to burst away.',
      _TutorialStep.pickup => 'Run into the glowing pickup for a bonus.',
      _TutorialStep.bounty =>
        'You are IT. Tag the crown runner for big points.',
      _TutorialStep.complete =>
        'You learned movement, dash, pickups, and bounty tags.',
    };
  }

  IconData get icon {
    return switch (this) {
      _TutorialStep.move => Icons.touch_app_rounded,
      _TutorialStep.dash => Icons.directions_run_rounded,
      _TutorialStep.pickup => Icons.bolt_rounded,
      _TutorialStep.bounty => Icons.emoji_events_rounded,
      _TutorialStep.complete => Icons.check_circle_rounded,
    };
  }
}

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

class _MissionProgress {
  const _MissionProgress({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.progress,
    required this.target,
    required this.reward,
    required this.claimed,
  });

  final String id;
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final int progress;
  final int target;
  final int reward;
  final bool claimed;

  bool get complete => progress >= target;
  double get fraction => (progress / target).clamp(0.0, 1.0).toDouble();
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
  DateTime? _lastDailyRewardClaimedAt;
  int _dailyRewardStreak = 0;
  int _dailyRewardClaims = 0;
  int _roundsPlayed = 0;
  int _totalTags = 0;
  int _bellZoneRounds = 0;
  int _shrinkingYardRounds = 0;
  int _tagFrenzyTags = 0;
  Set<String> _claimedMissions = {};
  PlayerAvatar _selectedAvatar = PlayerAvatar.blue;
  ArenaBackground _selectedArena = ArenaBackground.base;
  Set<PlayerAvatar> _unlockedAvatars = {PlayerAvatar.blue};
  Offset _stickOffset = Offset.zero;
  double _animationSeconds = 0;
  bool _tutorialActive = false;
  bool _tutorialDashPressed = false;
  _TutorialStep _tutorialStep = _TutorialStep.move;
  double _tutorialProgress = 0;
  int? _tutorialPickupId;
  int _tutorialStartTags = 0;
  Offset _tutorialMoveStart = Offset.zero;

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
    final claimedMissionNames = prefs.getStringList('claimed_missions');
    final dailyClaimMs = prefs.getInt('last_daily_reward_claimed_at') ?? 0;
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
      _lastDailyRewardClaimedAt = dailyClaimMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(dailyClaimMs)
          : null;
      _dailyRewardStreak = prefs.getInt('daily_reward_streak') ?? 0;
      _dailyRewardClaims = prefs.getInt('daily_reward_claims') ?? 0;
      _roundsPlayed = prefs.getInt('rounds_played') ?? 0;
      _totalTags = prefs.getInt('total_tags') ?? 0;
      _bellZoneRounds = prefs.getInt('bell_zone_rounds') ?? 0;
      _shrinkingYardRounds = prefs.getInt('shrinking_yard_rounds') ?? 0;
      _tagFrenzyTags = prefs.getInt('tag_frenzy_tags') ?? 0;
      _claimedMissions = claimedMissionNames?.toSet() ?? {};
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins', _coins);
    await prefs.setBool('dark_mode', _darkMode);
    await prefs.setString('selected_avatar', _selectedAvatar.name);
    await prefs.setString('selected_arena', _selectedArena.name);
    await prefs.setInt(
      'last_daily_reward_claimed_at',
      _lastDailyRewardClaimedAt?.millisecondsSinceEpoch ?? 0,
    );
    await prefs.setInt('daily_reward_streak', _dailyRewardStreak);
    await prefs.setInt('daily_reward_claims', _dailyRewardClaims);
    await prefs.setInt('rounds_played', _roundsPlayed);
    await prefs.setInt('total_tags', _totalTags);
    await prefs.setInt('bell_zone_rounds', _bellZoneRounds);
    await prefs.setInt('shrinking_yard_rounds', _shrinkingYardRounds);
    await prefs.setInt('tag_frenzy_tags', _tagFrenzyTags);
    await prefs.setStringList('claimed_missions', _claimedMissions.toList());
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

  BlitzMode _modeForArena(ArenaBackground arena) {
    return switch (arena) {
      ArenaBackground.base => BlitzMode.staminaChase,
      ArenaBackground.bellZone => BlitzMode.bellZone,
      ArenaBackground.shrinkingYard => BlitzMode.shrinkingYard,
      ArenaBackground.frenzy => BlitzMode.tagFrenzy,
    };
  }

  bool get _canClaimDailyReward {
    final lastClaimed = _lastDailyRewardClaimedAt;
    if (lastClaimed == null) {
      return true;
    }
    return DateTime.now().difference(lastClaimed) >= const Duration(hours: 24);
  }

  Duration get _dailyRewardRemaining {
    final lastClaimed = _lastDailyRewardClaimedAt;
    if (lastClaimed == null) {
      return Duration.zero;
    }
    final remaining =
        const Duration(hours: 24) - DateTime.now().difference(lastClaimed);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  int get _dailyRewardAmount {
    return 250 + math.min(_dailyRewardStreak, 5) * 25;
  }

  List<_MissionProgress> get _missions {
    return [
      _MissionProgress(
        id: 'daily_claim',
        title: 'Daily Pickup',
        body: 'Claim the daily reward once.',
        icon: Icons.card_giftcard_rounded,
        color: const Color(0xffffd64c),
        progress: _dailyRewardClaims,
        target: 1,
        reward: 120,
        claimed: _claimedMissions.contains('daily_claim'),
      ),
      _MissionProgress(
        id: 'play_rounds',
        title: 'Playground Warmup',
        body: 'Finish three rounds in any mode.',
        icon: Icons.play_arrow_rounded,
        color: const Color(0xff39d9ff),
        progress: _roundsPlayed,
        target: 3,
        reward: 180,
        claimed: _claimedMissions.contains('play_rounds'),
      ),
      _MissionProgress(
        id: 'tag_runner',
        title: 'Tag Runner',
        body: 'Score ten tags across rounds.',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xffff405f),
        progress: _totalTags,
        target: 10,
        reward: 260,
        claimed: _claimedMissions.contains('tag_runner'),
      ),
      _MissionProgress(
        id: 'bell_zone',
        title: 'Bell Regular',
        body: 'Complete two Bell Zone rounds.',
        icon: Icons.notifications_active_rounded,
        color: const Color(0xff9d55ff),
        progress: _bellZoneRounds,
        target: 2,
        reward: 220,
        claimed: _claimedMissions.contains('bell_zone'),
      ),
      _MissionProgress(
        id: 'yard_escape',
        title: 'Yard Escape',
        body: 'Complete two Shrinking Yard rounds.',
        icon: Icons.warning_rounded,
        color: const Color(0xffff8a18),
        progress: _shrinkingYardRounds,
        target: 2,
        reward: 220,
        claimed: _claimedMissions.contains('yard_escape'),
      ),
      _MissionProgress(
        id: 'frenzy_tags',
        title: 'Frenzy Tags',
        body: 'Land four tags in Tag Frenzy.',
        icon: Icons.flash_on_rounded,
        color: const Color(0xffffd64c),
        progress: _tagFrenzyTags,
        target: 4,
        reward: 300,
        claimed: _claimedMissions.contains('frenzy_tags'),
      ),
    ];
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
      if (_tutorialActive) {
        _updateInteractiveTutorial(dt);
      }
    }
    _input.consumePresses();
    _tutorialDashPressed = false;
    _animationSeconds += dt;
    if (_screen == _ShellScreen.game &&
        !_tutorialActive &&
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
    _roundsPlayed += 1;
    _totalTags += human.tags;
    if (_selectedArena == ArenaBackground.bellZone) {
      _bellZoneRounds += 1;
    } else if (_selectedArena == ArenaBackground.shrinkingYard) {
      _shrinkingYardRounds += 1;
    } else if (_selectedArena == ArenaBackground.frenzy) {
      _tagFrenzyTags += human.tags;
    }
    _roundRewardGranted = true;
    unawaited(_saveProgress());
  }

  void _startGame() {
    _tutorialActive = false;
    _tutorialPickupId = null;
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
    _simulation = PlaygroundBlitzSimulation(
      _settings,
      mode: _modeForArena(_selectedArena),
    );
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

  void _startInteractiveTutorial() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _selectedArena = ArenaBackground.base;
    _settings = GameSettings(
      playerName: _nameController.text.trim().isEmpty
          ? 'Player'
          : _nameController.text.trim(),
      botCount: 3,
      roundLength: 120,
      difficulty: Difficulty.chill,
    );
    _simulation = PlaygroundBlitzSimulation(
      _settings,
      mode: BlitzMode.staminaChase,
    );
    _screen = _ShellScreen.game;
    _tutorialActive = true;
    _tutorialStep = _TutorialStep.move;
    _tutorialProgress = 0;
    _tutorialDashPressed = false;
    _tutorialPickupId = null;
    _tutorialStartTags = _simulation.human.tags;
    _tutorialMoveStart = _simulation.human.position;
    _previousTick = null;
    _animationSeconds = 0;
    _lastReward = 0;
    _roundRewardGranted = false;
    _input.move = Offset.zero;
    _input.sprint = false;
    _stickOffset = Offset.zero;
    _prepareTutorialSandbox();
    _ticker.start();
    setState(() {});
  }

  void _prepareTutorialSandbox() {
    for (final player in _simulation.players) {
      player
        ..isIt = false
        ..safety = 8
        ..velocity = Offset.zero
        ..dashCooldown = 0
        ..fakeOutCooldown = 0
        ..shieldTimer = 0
        ..speedBoostTimer = 0;
    }
    final human = _simulation.human
      ..position = const Offset(380, 760)
      ..safety = 1.2
      ..stamina = 100;
    if (_simulation.players.length > 1) {
      _simulation.players[1]
        ..isIt = true
        ..position = const Offset(380, 380)
        ..safety = 8;
    }
    for (var i = 2; i < _simulation.players.length; i += 1) {
      _simulation.players[i].position = Offset(190 + i * 90.0, 260);
    }
    _simulation.setBountyEnabled(false);
    _simulation.powerUps.clear();
    _tutorialMoveStart = human.position;
    assert(human.position.dx > 0);
  }

  void _updateInteractiveTutorial(double dt) {
    switch (_tutorialStep) {
      case _TutorialStep.move:
        final movedDistance =
            (_simulation.human.position - _tutorialMoveStart).distance;
        if (movedDistance >= 28) {
          _tutorialProgress = 1;
          _advanceTutorialStep(_TutorialStep.dash);
          break;
        }
        final movementProgress = (movedDistance / 55)
            .clamp(0.0, 1.0)
            .toDouble();
        _tutorialProgress = math.max(_tutorialProgress, movementProgress);
        if (_input.move.distance > 0.34) {
          _tutorialProgress = math.min(
            1,
            math.max(_tutorialProgress, 0.72) + dt * 2.4,
          );
        } else {
          _tutorialProgress = math.max(
            movementProgress,
            _tutorialProgress - dt * 0.18,
          );
        }
        if (_tutorialProgress >= 1) {
          _advanceTutorialStep(_TutorialStep.dash);
        }
        break;
      case _TutorialStep.dash:
        _tutorialProgress = _tutorialDashPressed ? 1 : 0;
        if (_tutorialDashPressed || _simulation.human.dashCooldown > 0) {
          _advanceTutorialStep(_TutorialStep.pickup);
        }
        break;
      case _TutorialStep.pickup:
        final pickupId = _tutorialPickupId;
        final collected =
            pickupId != null &&
            !_simulation.powerUps.any((powerUp) => powerUp.id == pickupId);
        _tutorialProgress = collected ? 1 : 0;
        if (collected) {
          _advanceTutorialStep(_TutorialStep.bounty);
        }
        break;
      case _TutorialStep.bounty:
        _tutorialProgress = _simulation.human.tags > _tutorialStartTags
            ? 1
            : (_simulation.human.score / 260).clamp(0.0, 0.95).toDouble();
        if (_simulation.human.tags > _tutorialStartTags) {
          _advanceTutorialStep(_TutorialStep.complete);
        }
        break;
      case _TutorialStep.complete:
        _tutorialProgress = 1;
        break;
    }
  }

  void _advanceTutorialStep(_TutorialStep step) {
    _tutorialStep = step;
    _tutorialProgress = step == _TutorialStep.complete ? 1 : 0;
    if (step == _TutorialStep.pickup) {
      _placeTutorialPickup();
    } else if (step == _TutorialStep.bounty) {
      _prepareTutorialBounty();
    } else if (step == _TutorialStep.complete) {
      _simulation.roundOver = true;
      _ticker.stop();
    }
  }

  void _placeTutorialPickup() {
    final human = _simulation.human;
    _simulation.powerUps.clear();
    final pickup = _simulation.addPracticePowerUp(
      PowerUpKind.lightning,
      human.position.translate(0, -118),
      ttl: 90,
    );
    _tutorialPickupId = pickup.id;
  }

  void _prepareTutorialBounty() {
    final human = _simulation.human;
    for (final player in _simulation.players) {
      player
        ..isIt = false
        ..safety = 8
        ..velocity = Offset.zero;
    }
    human
      ..isIt = true
      ..safety = 0
      ..stamina = 100
      ..dashCooldown = 0
      ..speedBoostTimer = math.max(human.speedBoostTimer, 4);
    _simulation.setBountyEnabled(true);
    final target = _simulation.players.firstWhere(
      (player) => !player.isHuman,
      orElse: () => human,
    );
    if (target.id != human.id) {
      target
        ..isIt = false
        ..position = human.position.translate(0, -150)
        ..safety = 0
        ..stamina = 70
        ..velocity = Offset.zero;
      _simulation.setPracticeBounty(target, seconds: 45);
    }
    _tutorialStartTags = human.tags;
  }

  void _openHome() {
    _ticker.stop();
    _tutorialActive = false;
    _tutorialPickupId = null;
    _input.move = Offset.zero;
    _input.sprint = false;
    _stickOffset = Offset.zero;
    _screen = _ShellScreen.home;
    setState(() {});
  }

  void _openSetup() {
    _ticker.stop();
    _tutorialActive = false;
    _input.move = Offset.zero;
    _input.sprint = false;
    _stickOffset = Offset.zero;
    _screen = _ShellScreen.setup;
    setState(() {});
  }

  void _openStore() {
    _ticker.stop();
    _tutorialActive = false;
    _input.move = Offset.zero;
    _input.sprint = false;
    _stickOffset = Offset.zero;
    _screen = _ShellScreen.store;
    setState(() {});
  }

  void _openArenas() {
    _ticker.stop();
    _tutorialActive = false;
    _input.move = Offset.zero;
    _input.sprint = false;
    _stickOffset = Offset.zero;
    _screen = _ShellScreen.arenas;
    setState(() {});
  }

  void _openTutorial() {
    _ticker.stop();
    _tutorialActive = false;
    _input.move = Offset.zero;
    _input.sprint = false;
    _stickOffset = Offset.zero;
    _screen = _ShellScreen.tutorial;
    setState(() {});
  }

  void _openMissions() {
    _ticker.stop();
    _tutorialActive = false;
    _input.move = Offset.zero;
    _input.sprint = false;
    _stickOffset = Offset.zero;
    _screen = _ShellScreen.missions;
    setState(() {});
  }

  void _startArenaMode(ArenaBackground arena) {
    _selectedArena = arena;
    unawaited(_saveProgress());
    _startGame();
  }

  void _toggleDarkMode() {
    setState(() => _darkMode = !_darkMode);
    unawaited(_saveProgress());
  }

  void _selectArena(ArenaBackground arena) {
    setState(() => _selectedArena = arena);
    unawaited(_saveProgress());
  }

  void _claimDailyReward() {
    if (!_canClaimDailyReward) {
      return;
    }
    setState(() {
      _coins += _dailyRewardAmount;
      _dailyRewardStreak += 1;
      _dailyRewardClaims += 1;
      _lastDailyRewardClaimedAt = DateTime.now();
    });
    unawaited(_saveProgress());
  }

  void _claimMission(_MissionProgress mission) {
    if (!mission.complete || mission.claimed) {
      return;
    }
    setState(() {
      _coins += mission.reward;
      _claimedMissions = {..._claimedMissions, mission.id};
    });
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
          if (_screen == _ShellScreen.game &&
              !_simulation.roundOver &&
              !_tutorialActive)
            _TopActions(onSetup: _openSetup, onRestart: _startGame),
          if (_screen == _ShellScreen.game && !_simulation.roundOver)
            _ControlsOverlay(
              simulation: _simulation,
              stickOffset: _stickOffset,
              onStickChanged: _handleStickChanged,
              onStickReleased: _releaseStick,
              onDash: () {
                _input.dashPressed = true;
                _tutorialDashPressed = true;
              },
            ),
          if (_screen == _ShellScreen.game && _tutorialActive)
            _TutorialTouchTargets(step: _tutorialStep),
          if (_screen == _ShellScreen.game && _tutorialActive)
            _InteractiveTutorialOverlay(
              step: _tutorialStep,
              progress: _tutorialProgress,
              simulation: _simulation,
              onExit: _openHome,
              onRestart: _startInteractiveTutorial,
              onPlay: _startGame,
            ),
          if (_screen == _ShellScreen.home)
            _HomeOverlay(
              coins: _coins,
              darkMode: _darkMode,
              selectedArena: _selectedArena,
              selectedAvatar: _selectedAvatar,
              avatars: _avatarSprites,
              canClaimDailyReward: _canClaimDailyReward,
              dailyRewardAmount: _dailyRewardAmount,
              dailyRewardRemaining: _dailyRewardRemaining,
              onPlay: _startGame,
              onMode: _startArenaMode,
              onClaimDailyReward: _claimDailyReward,
              onStore: _openStore,
              onSetup: _openSetup,
              onArenas: _openArenas,
              onTutorial: _startInteractiveTutorial,
              onMissions: _openMissions,
              onToggleDarkMode: _toggleDarkMode,
            ),
          if (_screen == _ShellScreen.setup)
            _SetupMenu(
              settings: _settings,
              nameController: _nameController,
              onSettingsChanged: (settings) =>
                  setState(() => _settings = settings),
              onPlay: _startGame,
              onTutorial: _startInteractiveTutorial,
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
              onPlay: _startInteractiveTutorial,
              onBack: _openHome,
            ),
          if (_screen == _ShellScreen.missions)
            _MissionsOverlay(
              coins: _coins,
              missions: _missions,
              onClaim: _claimMission,
              onPlay: _startGame,
              onBack: _openHome,
            ),
          if (_screen == _ShellScreen.game &&
              _simulation.roundOver &&
              !_tutorialActive)
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
    required this.onTutorial,
    required this.onBack,
  });

  final GameSettings settings;
  final TextEditingController nameController;
  final ValueChanged<GameSettings> onSettingsChanged;
  final VoidCallback onPlay;
  final VoidCallback onTutorial;
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
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xff182035),
                                side: const BorderSide(
                                  color: Color(0xffffc743),
                                  width: 2,
                                ),
                              ),
                              onPressed: onTutorial,
                              icon: const Icon(Icons.school_rounded),
                              label: const Text('Practice'),
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
    required this.canClaimDailyReward,
    required this.dailyRewardAmount,
    required this.dailyRewardRemaining,
    required this.onPlay,
    required this.onMode,
    required this.onClaimDailyReward,
    required this.onStore,
    required this.onSetup,
    required this.onArenas,
    required this.onTutorial,
    required this.onMissions,
    required this.onToggleDarkMode,
  });

  final int coins;
  final bool darkMode;
  final ArenaBackground selectedArena;
  final PlayerAvatar selectedAvatar;
  final Map<PlayerAvatar, ui.Image> avatars;
  final bool canClaimDailyReward;
  final int dailyRewardAmount;
  final Duration dailyRewardRemaining;
  final VoidCallback onPlay;
  final ValueChanged<ArenaBackground> onMode;
  final VoidCallback onClaimDailyReward;
  final VoidCallback onStore;
  final VoidCallback onSetup;
  final VoidCallback onArenas;
  final VoidCallback onTutorial;
  final VoidCallback onMissions;
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
            canClaimDailyReward,
            dailyRewardAmount,
            dailyRewardRemaining.inMinutes,
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
                onTap: onMissions,
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
                label: 'STAMINA CHASE',
                left: 0.69,
                top: 0.34,
                width: 0.30,
                height: 0.09,
                onTap: () => onMode(ArenaBackground.base),
              ),
              _HomeImageButton(
                label: 'BELL ZONE',
                left: 0.69,
                top: 0.43,
                width: 0.30,
                height: 0.09,
                onTap: () => onMode(ArenaBackground.bellZone),
              ),
              _HomeImageButton(
                label: 'SHRINKING YARD',
                left: 0.69,
                top: 0.52,
                width: 0.30,
                height: 0.09,
                onTap: () => onMode(ArenaBackground.shrinkingYard),
              ),
              _HomeImageButton(
                label: 'TAG FRENZY',
                left: 0.69,
                top: 0.61,
                width: 0.30,
                height: 0.09,
                onTap: () => onMode(ArenaBackground.frenzy),
              ),
              _HomeImageButton(
                label: 'SKINS',
                left: 0.03,
                top: 0.54,
                width: 0.20,
                height: 0.19,
                onTap: onStore,
              ),
              _HomeImageButton(
                label: 'DAILY REWARD',
                left: 0.04,
                top: 0.24,
                width: 0.20,
                height: 0.15,
                onTap: onClaimDailyReward,
              ),
              Positioned(
                left: constraints.maxWidth * 0.055,
                top: constraints.maxHeight * 0.345,
                width: constraints.maxWidth * 0.17,
                child: _HomeDailyRewardBadge(
                  canClaim: canClaimDailyReward,
                  amount: dailyRewardAmount,
                  remaining: dailyRewardRemaining,
                ),
              ),
              Positioned(
                left: constraints.maxWidth * 0.24,
                top: constraints.maxHeight * 0.64,
                width: constraints.maxWidth * 0.52,
                child: _HomePracticeButton(onTap: onTutorial),
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

class _HomePracticeButton extends StatelessWidget {
  const _HomePracticeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Ink(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff41e7ff), Color(0xff147fc9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0xcc000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
              BoxShadow(color: Color(0x9941e7ff), blurRadius: 16),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.school_rounded, color: Colors.white, size: 28),
              SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'LEARN TO PLAY',
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          shadows: [
                            Shadow(color: Colors.black, offset: Offset(2, 2)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Interactive tutorial',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xfffff27a),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeDailyRewardBadge extends StatelessWidget {
  const _HomeDailyRewardBadge({
    required this.canClaim,
    required this.amount,
    required this.remaining,
  });

  final bool canClaim;
  final int amount;
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final label = canClaim ? 'CLAIM +$amount' : _formatDurationShort(remaining);
    return IgnorePointer(
      child: Container(
        height: 27,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: canClaim
                ? const [Color(0xffffdc55), Color(0xffff9d1f)]
                : const [Color(0xff24303a), Color(0xff080b10)],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: canClaim ? Colors.white : const Color(0xff657480),
            width: 2,
          ),
          boxShadow: const [BoxShadow(color: Color(0xaa000000), blurRadius: 8)],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: canClaim ? const Color(0xff182035) : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1,
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
        title: 'Modes',
        body:
            'Pick Stamina, Bell, Shrinking Yard, or Frenzy for different rules.',
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
                  'START PRACTICE',
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

class _InteractiveTutorialOverlay extends StatelessWidget {
  const _InteractiveTutorialOverlay({
    required this.step,
    required this.progress,
    required this.simulation,
    required this.onExit,
    required this.onRestart,
    required this.onPlay,
  });

  final _TutorialStep step;
  final double progress;
  final PlaygroundBlitzSimulation simulation;
  final VoidCallback onExit;
  final VoidCallback onRestart;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final complete = step == _TutorialStep.complete;
    final bounty = simulation.bountyTarget;
    final stepIndex = switch (step) {
      _TutorialStep.move => 1,
      _TutorialStep.dash => 2,
      _TutorialStep.pickup => 3,
      _TutorialStep.bounty => 4,
      _TutorialStep.complete => 4,
    };
    final detail = switch (step) {
      _TutorialStep.move => 'Hold and drag the left joystick.',
      _TutorialStep.dash => 'Tap the shoe button on the right.',
      _TutorialStep.pickup => 'Run through the glowing lightning token.',
      _TutorialStep.bounty =>
        bounty == null ? step.body : 'Tag ${bounty.name}, the crown runner.',
      _TutorialStep.complete => 'Practice complete. Jump into a real match.',
    };
    final actionText = complete
        ? 'You know the loop.'
        : 'Highlighted action advances the tutorial.';

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 112, 12, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: _arcadePlate(
                borderColor: complete
                    ? const Color(0xff8cff6a)
                    : const Color(0xffffd64c),
                shadowColor: Colors.black.withValues(alpha: 0.62),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _TutorialStatusChip(
                        icon: Icons.school_rounded,
                        text: 'INTERACTIVE TUTORIAL',
                        color: const Color(0xff39d9ff),
                      ),
                      const Spacer(),
                      _TutorialStatusChip(
                        icon: Icons.flag_rounded,
                        text: 'STEP $stepIndex/4',
                        color: const Color(0xffffd64c),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xffffd64c).withValues(alpha: 0.2),
                          border: Border.all(
                            color: const Color(0xffffd64c),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          step.icon,
                          color: const Color(0xffffd64c),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    offset: Offset(1, 1),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 9,
                      value: progress.clamp(0.0, 1.0).toDouble(),
                      color: complete
                          ? const Color(0xff8cff6a)
                          : const Color(0xffffd64c),
                      backgroundColor: Colors.black.withValues(alpha: 0.58),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      SizedBox(
                        width: 94,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.54),
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: complete ? onRestart : onExit,
                          child: Text(complete ? 'RETRY' : 'EXIT'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: complete
                            ? FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xffffa229),
                                  foregroundColor: const Color(0xff182035),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: onPlay,
                                child: const Text('PLAY MATCH'),
                              )
                            : Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xff101820,
                                  ).withValues(alpha: 0.78),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xff39d9ff),
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.touch_app_rounded,
                                      color: Color(0xff39d9ff),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          actionText,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
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

class _TutorialStatusChip extends StatelessWidget {
  const _TutorialStatusChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color, width: 1.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialTouchTargets extends StatelessWidget {
  const _TutorialTouchTargets({required this.step});

  final _TutorialStep step;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final joystickSize = compact ? 112.0 : 126.0;
            final dashSize = compact ? 108.0 : 118.0;
            final sidePad = compact ? 20.0 : 24.0;
            final bottomPad = compact ? 18.0 : 24.0;
            return Stack(
              children: [
                if (step == _TutorialStep.move)
                  Positioned(
                    left: sidePad - 8,
                    bottom: bottomPad - 8,
                    width: joystickSize + 16,
                    height: joystickSize + 16,
                    child: const _TutorialPulseTarget(
                      label: 'DRAG',
                      icon: Icons.open_with_rounded,
                      color: Color(0xff39d9ff),
                    ),
                  ),
                if (step == _TutorialStep.dash)
                  Positioned(
                    right: sidePad - 8,
                    bottom: bottomPad - 8,
                    width: dashSize + 16,
                    height: dashSize + 16,
                    child: const _TutorialPulseTarget(
                      label: 'TAP',
                      icon: Icons.directions_run_rounded,
                      color: Color(0xffb244ff),
                    ),
                  ),
                if (step == _TutorialStep.pickup)
                  Positioned(
                    left: constraints.maxWidth * 0.5 - 104,
                    bottom: bottomPad + dashSize + 24,
                    width: 208,
                    child: const _TutorialFloatingCue(
                      label: 'GRAB THE LIGHTNING',
                      icon: Icons.bolt_rounded,
                      color: Color(0xffffd64c),
                    ),
                  ),
                if (step == _TutorialStep.bounty)
                  Positioned(
                    left: constraints.maxWidth * 0.5 - 96,
                    top: constraints.maxHeight * 0.30,
                    width: 192,
                    child: const _TutorialFloatingCue(
                      label: 'CHASE THE CROWN',
                      icon: Icons.emoji_events_rounded,
                      color: Color(0xffff405f),
                    ),
                  ),
                if (step == _TutorialStep.complete)
                  Positioned(
                    left: constraints.maxWidth * 0.5 - 92,
                    bottom: bottomPad + dashSize + 18,
                    width: 184,
                    child: const _TutorialFloatingCue(
                      label: 'READY TO PLAY',
                      icon: Icons.check_circle_rounded,
                      color: Color(0xff8cff6a),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TutorialPulseTarget extends StatelessWidget {
  const _TutorialPulseTarget({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color, width: 5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.64), blurRadius: 24),
          const BoxShadow(
            color: Color(0xaa000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xff101820).withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white, width: 1.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialFloatingCue extends StatelessWidget {
  const _TutorialFloatingCue({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _arcadePlate(
        borderColor: color,
        shadowColor: color.withValues(alpha: 0.44),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 7),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    shadows: [
                      Shadow(color: Colors.black, offset: Offset(1, 1)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionsOverlay extends StatelessWidget {
  const _MissionsOverlay({
    required this.coins,
    required this.missions,
    required this.onClaim,
    required this.onPlay,
    required this.onBack,
  });

  final int coins;
  final List<_MissionProgress> missions;
  final ValueChanged<_MissionProgress> onClaim;
  final VoidCallback onPlay;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final completed = missions
        .where((mission) => mission.complete && !mission.claimed)
        .length;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: Column(
          children: [
            _ArcadeScreenHeader(
              title: 'MISSIONS',
              icon: Icons.assignment_rounded,
              color: const Color(0xffffd64c),
              onBack: onBack,
              trailing: Text(
                '${_formatNumber(coins)} coins',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: _arcadePlate(borderColor: const Color(0xff39d9ff)),
              child: Row(
                children: [
                  Icon(
                    completed > 0
                        ? Icons.stars_rounded
                        : Icons.flag_circle_rounded,
                    color: const Color(0xffffd64c),
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      completed > 0
                          ? '$completed reward${completed == 1 ? '' : 's'} ready to claim.'
                          : 'Finish rounds in each mode to unlock rewards.',
                      style: const TextStyle(
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
            for (final mission in missions) ...[
              _MissionCard(mission: mission, onClaim: onClaim),
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
                  'PLAY A ROUND',
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

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission, required this.onClaim});

  final _MissionProgress mission;
  final ValueChanged<_MissionProgress> onClaim;

  @override
  Widget build(BuildContext context) {
    final buttonLabel = mission.claimed
        ? 'DONE'
        : mission.complete
        ? 'CLAIM'
        : '${mission.progress.clamp(0, mission.target)}/${mission.target}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: _arcadePlate(
        borderColor: mission.claimed
            ? const Color(0xff657480)
            : mission.complete
            ? const Color(0xffffd64c)
            : mission.color,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mission.color.withValues(alpha: 0.2),
              border: Border.all(color: mission.color, width: 2),
            ),
            child: Icon(mission.icon, color: mission.color, size: 26),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        mission.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${mission.reward}',
                      style: const TextStyle(
                        color: Color(0xffffd64c),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  mission.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: mission.fraction,
                    color: mission.complete
                        ? const Color(0xffffd64c)
                        : mission.color,
                    backgroundColor: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 82,
            height: 42,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: mission.claimed
                    ? const Color(0xff657480)
                    : mission.complete
                    ? const Color(0xffffd64c)
                    : const Color(0xff22303a),
                foregroundColor: mission.complete && !mission.claimed
                    ? const Color(0xff182035)
                    : Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: mission.complete && !mission.claimed
                  ? () => onClaim(mission)
                  : null,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
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

String _formatDurationShort(Duration value) {
  if (value <= Duration.zero) {
    return 'READY';
  }
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
  return '${math.max(1, minutes)}m';
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
                        target: simulation.tagTarget,
                        compact: compact,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 12,
                  top: compact ? 68 : 72,
                  child: _GoalPlate(
                    score: simulation.human.score.round(),
                    goal: simulation.scoreGoal,
                    compact: compact,
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
    return simulation.mode.title;
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

class _GoalPlate extends StatelessWidget {
  const _GoalPlate({
    required this.score,
    required this.goal,
    this.compact = false,
  });

  final int score;
  final int goal;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final progress = (score / goal).clamp(0.0, 1.0).toDouble();
    return Container(
      width: compact ? 150 : 168,
      height: compact ? 34 : 38,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: _arcadePlate(borderColor: const Color(0xffffd64c)),
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xffffd64c),
            size: 16,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$score/$goal PTS',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: progress,
                      color: const Color(0xffffd64c),
                      backgroundColor: Colors.black.withValues(alpha: 0.55),
                    ),
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
    final bounty = simulation.bountyTarget;
    if (bounty != null && simulation.bountyTimeLeft > 0) {
      return _CenterEventPlate(
        icon: Icons.emoji_events_rounded,
        label: 'Bounty',
        value: simulation.bountyTimeLeft.ceil().toString().padLeft(2, '0'),
        color: const Color(0xffffd64c),
        compact: compact,
      );
    }
    if (simulation.mode == BlitzMode.tagFrenzy) {
      return _CenterEventPlate(
        icon: Icons.flash_on_rounded,
        label: 'FRENZY',
        value: _countdown(simulation.timer),
        color: const Color(0xffff7a1a),
        compact: compact,
      );
    }
    if (simulation.mode == BlitzMode.shrinkingYard &&
        simulation.shrinkProgress > 0.08) {
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
    final human = simulation.human;
    final bounty = simulation.bountyTarget;
    final isBounty = bounty?.id == human.id;
    final chaseBounty = human.isIt && bounty != null;
    final icon = isBounty || chaseBounty
        ? Icons.emoji_events_rounded
        : switch (simulation.mode) {
            BlitzMode.staminaChase => Icons.bolt_rounded,
            BlitzMode.bellZone => Icons.star_rounded,
            BlitzMode.shrinkingYard => Icons.warning_amber_rounded,
            BlitzMode.tagFrenzy => Icons.local_fire_department_rounded,
          };
    final title = isBounty
        ? 'Survive the crown'
        : chaseBounty
        ? 'Tag the crown'
        : simulation.mode.objectiveTitle;
    final body = isBounty
        ? 'Stay away for bonus points!'
        : chaseBounty
        ? '${bounty.name} is worth a bounty bonus!'
        : simulation.mode.objectiveBody;
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 310 : 380),
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
