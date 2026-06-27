import 'dart:math' as math;
import 'dart:ui';

enum Difficulty { chill, balanced, blitz }

enum BlitzMode { staminaChase, bellZone, shrinkingYard, tagFrenzy }

extension BlitzModeCopy on BlitzMode {
  String get title {
    return switch (this) {
      BlitzMode.staminaChase => 'Stamina Chase',
      BlitzMode.bellZone => 'Bell Zone',
      BlitzMode.shrinkingYard => 'Shrinking Yard',
      BlitzMode.tagFrenzy => 'Tag Frenzy',
    };
  }

  String get objectiveTitle {
    return switch (this) {
      BlitzMode.staminaChase => 'Grab boosts',
      BlitzMode.bellZone => 'Hold the bell',
      BlitzMode.shrinkingYard => 'Escape & shield',
      BlitzMode.tagFrenzy => 'Combo tags',
    };
  }

  String get objectiveBody {
    return switch (this) {
      BlitzMode.staminaChase => 'Boosts and stamina keep you alive!',
      BlitzMode.bellZone => 'Power-ups help you stay inside!',
      BlitzMode.shrinkingYard => 'Shields can save a close tag!',
      BlitzMode.tagFrenzy => 'Fast repeats build bonus points!',
    };
  }
}

enum ObstacleKind { slide, bench, fence, chalk, cones }

enum PowerUpKind { lightning, shield, stamina, star }

class GameSettings {
  const GameSettings({
    required this.playerName,
    required this.botCount,
    required this.roundLength,
    required this.difficulty,
  });

  final String playerName;
  final int botCount;
  final double roundLength;
  final Difficulty difficulty;
}

class GameInput {
  Offset move = Offset.zero;
  bool sprint = false;
  bool dashPressed = false;
  bool fakeOutPressed = false;

  void consumePresses() {
    dashPressed = false;
    fakeOutPressed = false;
  }
}

class ArenaObstacle {
  const ArenaObstacle(this.id, this.kind, this.rect);

  final String id;
  final ObstacleKind kind;
  final Rect rect;
}

class PlayerState {
  PlayerState({
    required this.id,
    required this.name,
    required this.position,
    required this.color,
    required this.isHuman,
    required this.isIt,
  });

  final String id;
  final String name;
  Offset position;
  Offset velocity = Offset.zero;
  final Color color;
  final bool isHuman;
  bool isIt;
  bool facingRight = true;
  double score = 0;
  double stamina = 100;
  double safety = 1.2;
  double shieldTimer = 0;
  double speedBoostTimer = 0;
  double comboTimer = 0;
  double dashCooldown = 0;
  double dashTimer = 0;
  double fakeOutCooldown = 0;
  double fakeOutTimer = 0;
  int tags = 0;
  int comboCount = 0;
  int starTokens = 0;
}

class BellZone {
  Offset center = const Offset(380, 600);
  double radius = 92;
  bool active = false;
  double timeLeft = 0;
  double nextIn = 5;
}

class Decoy {
  Decoy({
    required this.position,
    required this.color,
    required this.name,
    required this.ttl,
  });

  Offset position;
  Color color;
  String name;
  double ttl;
}

class PowerUp {
  PowerUp({
    required this.id,
    required this.kind,
    required this.position,
    required this.ttl,
  });

  final int id;
  final PowerUpKind kind;
  Offset position;
  double ttl;
}

class FloatingText {
  FloatingText({
    required this.position,
    required this.text,
    required this.color,
    required this.ttl,
  }) : maxTtl = ttl;

  Offset position;
  String text;
  Color color;
  double ttl;
  final double maxTtl;
}

class MoveIntent {
  const MoveIntent(this.direction, {this.sprint = false});

  final Offset direction;
  final bool sprint;
}

class PlaygroundBlitzSimulation {
  PlaygroundBlitzSimulation(this.settings, {this.mode = BlitzMode.staminaChase})
    : timer = _modeRoundLength(settings.roundLength, mode),
      players = _createPlayers(settings) {
    _configureModeStart();
  }

  static const Size worldSize = Size(760, 1200);
  static const Rect startYard = Rect.fromLTWH(64, 64, 632, 1072);
  static const Rect finalYard = Rect.fromLTWH(132, 188, 496, 824);
  static const double playerRadius = 18;
  static const double tagRadius = 42;
  static const double playerSeparationRadius = 58;

  static const List<ArenaObstacle> obstacles = [
    ArenaObstacle(
      'slide',
      ObstacleKind.slide,
      Rect.fromLTWH(112, 154, 128, 82),
    ),
    ArenaObstacle(
      'monkey-bars',
      ObstacleKind.fence,
      Rect.fromLTWH(306, 154, 150, 60),
    ),
    ArenaObstacle(
      'bench-left',
      ObstacleKind.bench,
      Rect.fromLTWH(110, 780, 148, 40),
    ),
    ArenaObstacle(
      'bench-right',
      ObstacleKind.bench,
      Rect.fromLTWH(500, 834, 148, 40),
    ),
    ArenaObstacle(
      'hopscotch',
      ObstacleKind.chalk,
      Rect.fromLTWH(318, 760, 116, 112),
    ),
    ArenaObstacle(
      'cone-row',
      ObstacleKind.cones,
      Rect.fromLTWH(560, 414, 54, 236),
    ),
  ];

  final GameSettings settings;
  final BlitzMode mode;
  final List<PlayerState> players;
  final BellZone bellZone = BellZone();
  final List<Decoy> decoys = [];
  final List<PowerUp> powerUps = [];
  final List<FloatingText> floatingTexts = [];
  final math.Random _random = math.Random();

  double timer;
  double elapsed = 0;
  double noTagTimer = 0;
  double catchupBoost = 1;
  bool roundOver = false;
  bool _bellCelebrated = false;
  bool _frenzyCelebrated = false;
  int _lastBoostSecond = -1;
  double _powerUpSpawnTimer = 0;
  int _nextPowerUpId = 0;
  String? _bountyTargetId;
  double _bountyTimeLeft = 0;
  bool _bountyEnabled = true;

  double get roundLength => _modeRoundLength(settings.roundLength, mode);
  PlayerState get human => players.firstWhere((player) => player.isHuman);
  PlayerState get it =>
      players.firstWhere((player) => player.isIt, orElse: () => players.first);
  bool get bellMode => mode == BlitzMode.bellZone;
  bool get shrinkingMode => mode == BlitzMode.shrinkingYard;
  bool get frenzy => mode == BlitzMode.tagFrenzy;
  int get tagTarget => frenzy ? 12 : 15;
  int get scoreGoal => frenzy
      ? 900
      : shrinkingMode
      ? 1050
      : 1200;
  int get starGoal => 3;
  double get bountyTimeLeft => _bountyTimeLeft;
  String? get bountyTargetId => _bountyTargetId;

  PlayerState? get bountyTarget {
    final id = _bountyTargetId;
    if (id == null || _bountyTimeLeft <= 0) {
      return null;
    }
    for (final player in players) {
      if (player.id == id && !player.isIt) {
        return player;
      }
    }
    return null;
  }

  PlayerState get winner {
    final sorted = [...players]..sort((a, b) => b.score.compareTo(a.score));
    return sorted.first;
  }

  Rect get yard {
    if (!shrinkingMode) {
      return startYard;
    }
    const shrinkStart = 15.0;
    final shrinkDuration = math.max(18.0, roundLength - 32);
    final t = ((elapsed - shrinkStart) / shrinkDuration).clamp(0.0, 1.0);
    return Rect.lerp(startYard, finalYard, t)!;
  }

  double get shrinkProgress {
    if (!shrinkingMode) {
      return 0;
    }
    const shrinkStart = 15.0;
    final shrinkDuration = math.max(18.0, roundLength - 32);
    return ((elapsed - shrinkStart) / shrinkDuration).clamp(0.0, 1.0);
  }

  void reset() {
    final fresh = PlaygroundBlitzSimulation(settings, mode: mode);
    players
      ..clear()
      ..addAll(fresh.players);
    bellZone
      ..center = fresh.bellZone.center
      ..radius = fresh.bellZone.radius
      ..active = fresh.bellZone.active
      ..timeLeft = fresh.bellZone.timeLeft
      ..nextIn = fresh.bellZone.nextIn;
    decoys.clear();
    powerUps
      ..clear()
      ..addAll(fresh.powerUps);
    floatingTexts.clear();
    timer = roundLength;
    elapsed = 0;
    noTagTimer = 0;
    catchupBoost = 1;
    roundOver = false;
    _bellCelebrated = false;
    _frenzyCelebrated = false;
    _lastBoostSecond = -1;
    _powerUpSpawnTimer = fresh._powerUpSpawnTimer;
    _nextPowerUpId = fresh._nextPowerUpId;
    _bountyTargetId = fresh._bountyTargetId;
    _bountyTimeLeft = fresh._bountyTimeLeft;
    _bountyEnabled = fresh._bountyEnabled;
  }

  void update(double deltaSeconds, GameInput input) {
    final dt = deltaSeconds.clamp(0.0, 0.05);
    _updateFloatingTexts(dt);
    if (roundOver) {
      return;
    }

    elapsed += dt;
    timer = math.max(0, timer - dt);
    noTagTimer += dt;
    catchupBoost = noTagTimer > 10
        ? (1 + (noTagTimer - 10) * 0.035).clamp(1.0, frenzy ? 1.45 : 1.28)
        : 1;

    if (frenzy && !_frenzyCelebrated) {
      _frenzyCelebrated = true;
      floatingTexts.add(
        FloatingText(
          position: const Offset(380, 188),
          text: 'FRENZY!',
          color: const Color(0xffff3f68),
          ttl: 1.05,
        ),
      );
    }

    _updateBellZone(dt);
    _updateBounty(dt);
    _updatePowerUps(dt);
    _updateDecoys(dt);
    _updatePlayers(dt, input);
    _collectPowerUps();
    _resolveTags();
    _resolvePlayerSeparation(yard);
    _scoreObjectives(dt);

    if (timer <= 0 || players.any((player) => player.score >= scoreGoal)) {
      roundOver = true;
    }
  }

  static double _modeRoundLength(double baseLength, BlitzMode mode) {
    return switch (mode) {
      BlitzMode.staminaChase => baseLength,
      BlitzMode.bellZone => math.max(75, baseLength),
      BlitzMode.shrinkingYard => math.min(baseLength, 85),
      BlitzMode.tagFrenzy => math.min(baseLength, 70),
    };
  }

  void _configureModeStart() {
    if (bellMode) {
      bellZone
        ..center = const Offset(380, 600)
        ..radius = 128
        ..active = true
        ..timeLeft = 10
        ..nextIn = 0;
    } else {
      bellZone
        ..active = false
        ..timeLeft = 0
        ..nextIn = double.infinity;
    }

    if (frenzy) {
      catchupBoost = 1.18;
    }

    _powerUpSpawnTimer = _nextPowerUpDelay() * 0.55;
    _spawnPowerUp();
    _spawnPowerUp();
    _startNewBounty(initial: true);
  }

  static List<PlayerState> _createPlayers(GameSettings settings) {
    const starts = [
      Offset(380, 650),
      Offset(382, 420),
      Offset(250, 700),
      Offset(510, 720),
      Offset(222, 520),
      Offset(540, 520),
      Offset(312, 890),
      Offset(448, 310),
    ];
    const botNames = ['Zay', 'Mina', 'Rafi', 'June', 'Niko', 'Paz', 'Lena'];
    const colors = [
      Color(0xff36d6ff),
      Color(0xffffcb45),
      Color(0xff8df96f),
      Color(0xffff7ca8),
      Color(0xffb99cff),
      Color(0xffff985f),
      Color(0xff5ef0bf),
      Color(0xff7aa8ff),
    ];

    final players = <PlayerState>[
      PlayerState(
        id: 'human',
        name: settings.playerName.trim().isEmpty
            ? 'Player'
            : settings.playerName.trim(),
        position: starts[0],
        color: colors[0],
        isHuman: true,
        isIt: false,
      ),
    ];

    for (var i = 0; i < settings.botCount; i += 1) {
      final player =
          PlayerState(
              id: 'bot-$i',
              name: botNames[i],
              position: starts[i + 1],
              color: colors[i + 1],
              isHuman: false,
              isIt: i == 0,
            )
            ..stamina = 82 + math.Random(i + 7).nextDouble() * 18
            ..safety = i == 0 ? 0 : 1.5
            ..dashCooldown = 1 + math.Random(i + 20).nextDouble() * 3
            ..fakeOutCooldown = 2 + math.Random(i + 40).nextDouble() * 4;
      players.add(player);
    }
    return players;
  }

  void _updateBellZone(double dt) {
    if (!bellMode) {
      bellZone
        ..active = false
        ..timeLeft = 0
        ..nextIn = double.infinity;
      return;
    }

    if (bellZone.active) {
      bellZone.timeLeft -= dt;
      if (!_bellCelebrated) {
        _bellCelebrated = true;
        floatingTexts.add(
          FloatingText(
            position: bellZone.center,
            text: 'BELL ZONE!',
            color: const Color(0xffffd447),
            ttl: 1.0,
          ),
        );
      }
      if (bellZone.timeLeft <= 0) {
        bellZone.active = false;
        bellZone.nextIn = settings.difficulty == Difficulty.blitz ? 4 : 5;
        _bellCelebrated = false;
      }
      return;
    }

    bellZone.nextIn -= dt;
    if (bellZone.nextIn <= 0) {
      final activeYard = yard;
      bellZone.center = Offset(
        activeYard.left +
            160 +
            _random.nextDouble() * math.max(120, activeYard.width - 320),
        activeYard.top +
            130 +
            _random.nextDouble() * math.max(120, activeYard.height - 260),
      );
      bellZone.active = true;
      bellZone.radius = settings.difficulty == Difficulty.blitz ? 118 : 128;
      bellZone.timeLeft = settings.difficulty == Difficulty.blitz ? 8 : 10;
    }
  }

  void _updateBounty(double dt) {
    if (!_bountyEnabled) {
      _bountyTargetId = null;
      _bountyTimeLeft = 0;
      return;
    }

    final current = bountyTarget;
    if (current == null) {
      _startNewBounty();
      return;
    }

    _bountyTimeLeft -= dt;
    if (_bountyTimeLeft <= 0) {
      current.score += frenzy ? 90 : 120;
      current.stamina = math.min(100, current.stamina + 18);
      _float(
        current.position,
        'SURVIVE +${frenzy ? 90 : 120}',
        const Color(0xffffd64c),
      );
      _startNewBounty();
    }
  }

  void _startNewBounty({bool initial = false}) {
    final candidates = players.where((player) => !player.isIt).toList();
    if (candidates.isEmpty) {
      _bountyTargetId = null;
      _bountyTimeLeft = 0;
      return;
    }

    candidates.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return a.id.compareTo(b.id);
    });
    final targetPool = candidates.take(math.min(3, candidates.length)).toList();
    final target = targetPool[_random.nextInt(targetPool.length)];
    _bountyTargetId = target.id;
    _bountyTimeLeft = frenzy ? 8.0 : 11.0;
    if (!initial) {
      _float(
        target.position.translate(0, -58),
        'BOUNTY!',
        const Color(0xffffd64c),
        ttl: 0.95,
      );
    }
  }

  void setPracticeBounty(PlayerState target, {double seconds = 30}) {
    if (!players.contains(target) || target.isIt) {
      return;
    }
    _bountyEnabled = true;
    _bountyTargetId = target.id;
    _bountyTimeLeft = seconds;
  }

  void setBountyEnabled(bool enabled) {
    _bountyEnabled = enabled;
    if (!enabled) {
      _bountyTargetId = null;
      _bountyTimeLeft = 0;
    }
  }

  PowerUp addPracticePowerUp(
    PowerUpKind kind,
    Offset position, {
    double ttl = 60,
  }) {
    final powerUp = PowerUp(
      id: _nextPowerUpId++,
      kind: kind,
      position: position,
      ttl: ttl,
    );
    powerUps.add(powerUp);
    return powerUp;
  }

  void _updatePowerUps(double dt) {
    for (final powerUp in powerUps) {
      powerUp.ttl -= dt;
    }
    powerUps.removeWhere((powerUp) => powerUp.ttl <= 0);

    _powerUpSpawnTimer -= dt;
    if (_powerUpSpawnTimer <= 0 && powerUps.length < _maxPowerUps) {
      _spawnPowerUp();
      _powerUpSpawnTimer = _nextPowerUpDelay();
    }
  }

  int get _maxPowerUps {
    return switch (mode) {
      BlitzMode.staminaChase => 3,
      BlitzMode.bellZone => 4,
      BlitzMode.shrinkingYard => 4,
      BlitzMode.tagFrenzy => 5,
    };
  }

  double _nextPowerUpDelay() {
    final base = switch (mode) {
      BlitzMode.staminaChase => 5.6,
      BlitzMode.bellZone => 5.1,
      BlitzMode.shrinkingYard => 4.7,
      BlitzMode.tagFrenzy => 3.4,
    };
    return base * (0.78 + _random.nextDouble() * 0.48);
  }

  void _spawnPowerUp() {
    final activeYard = yard.deflate(74);
    for (var attempt = 0; attempt < 18; attempt += 1) {
      final position = Offset(
        activeYard.left + _random.nextDouble() * activeYard.width,
        activeYard.top + _random.nextDouble() * activeYard.height,
      );
      if (_isPowerUpSpotClear(position)) {
        powerUps.add(
          PowerUp(
            id: _nextPowerUpId++,
            kind: _randomPowerUpKind(),
            position: position,
            ttl: frenzy ? 8.5 : 11.5,
          ),
        );
        return;
      }
    }
  }

  bool _isPowerUpSpotClear(Offset position) {
    for (final obstacle in obstacles) {
      if (obstacle.rect.inflate(54).contains(position)) {
        return false;
      }
    }
    for (final player in players) {
      if ((player.position - position).distance < 76) {
        return false;
      }
    }
    for (final powerUp in powerUps) {
      if ((powerUp.position - position).distance < 118) {
        return false;
      }
    }
    return true;
  }

  PowerUpKind _randomPowerUpKind() {
    final roll = _random.nextDouble();
    return switch (mode) {
      BlitzMode.staminaChase =>
        roll < 0.36
            ? PowerUpKind.stamina
            : roll < 0.68
            ? PowerUpKind.lightning
            : roll < 0.86
            ? PowerUpKind.shield
            : PowerUpKind.star,
      BlitzMode.bellZone =>
        roll < 0.34
            ? PowerUpKind.star
            : roll < 0.58
            ? PowerUpKind.shield
            : roll < 0.82
            ? PowerUpKind.lightning
            : PowerUpKind.stamina,
      BlitzMode.shrinkingYard =>
        roll < 0.34
            ? PowerUpKind.shield
            : roll < 0.62
            ? PowerUpKind.lightning
            : roll < 0.84
            ? PowerUpKind.stamina
            : PowerUpKind.star,
      BlitzMode.tagFrenzy =>
        roll < 0.42
            ? PowerUpKind.lightning
            : roll < 0.72
            ? PowerUpKind.star
            : roll < 0.88
            ? PowerUpKind.stamina
            : PowerUpKind.shield,
    };
  }

  void _collectPowerUps() {
    final collected = <PowerUp>[];
    for (final powerUp in powerUps) {
      for (final player in players) {
        if ((player.position - powerUp.position).distance <= 46) {
          _applyPowerUp(player, powerUp);
          collected.add(powerUp);
          break;
        }
      }
    }
    powerUps.removeWhere(collected.contains);
  }

  void _applyPowerUp(PlayerState player, PowerUp powerUp) {
    switch (powerUp.kind) {
      case PowerUpKind.lightning:
        player
          ..speedBoostTimer = math.max(player.speedBoostTimer, frenzy ? 4.2 : 5)
          ..stamina = math.min(100, player.stamina + 22)
          ..dashCooldown = math.max(0, player.dashCooldown - 1.1);
        _float(player.position, 'BOOST!', const Color(0xff66ecff));
      case PowerUpKind.shield:
        player.shieldTimer = math.max(player.shieldTimer, 6.2);
        _float(player.position, 'SHIELD!', const Color(0xff9dff73));
      case PowerUpKind.stamina:
        player
          ..stamina = 100
          ..dashCooldown = math.max(0, player.dashCooldown - 1.8)
          ..fakeOutCooldown = math.max(0, player.fakeOutCooldown - 1.2);
        _float(player.position, 'FULL!', const Color(0xffffe36a));
      case PowerUpKind.star:
        final bonus = bellMode
            ? 120
            : frenzy
            ? 110
            : 90;
        player.starTokens = math.min(starGoal, player.starTokens + 1);
        player.score += bonus;
        if (player.starTokens >= starGoal) {
          player
            ..starTokens = 0
            ..score += 180
            ..speedBoostTimer = math.max(player.speedBoostTimer, 4.8)
            ..shieldTimer = math.max(player.shieldTimer, 3.5);
          _float(player.position, 'BLITZ!', const Color(0xffff8a18), ttl: 1);
        } else {
          _float(
            player.position,
            'STAR ${player.starTokens}/$starGoal',
            const Color(0xffffd64c),
          );
        }
    }
  }

  void _float(Offset position, String text, Color color, {double ttl = 0.78}) {
    floatingTexts.add(
      FloatingText(position: position, text: text, color: color, ttl: ttl),
    );
  }

  void _updateDecoys(double dt) {
    for (final decoy in decoys) {
      decoy.ttl -= dt;
    }
    decoys.removeWhere((decoy) => decoy.ttl <= 0);
  }

  void _updateFloatingTexts(double dt) {
    for (final text in floatingTexts) {
      text.ttl -= dt;
      text.position = text.position.translate(0, -44 * dt);
    }
    floatingTexts.removeWhere((text) => text.ttl <= 0);
  }

  void _updatePlayers(double dt, GameInput input) {
    final activeYard = yard;
    for (final player in players) {
      player
        ..safety = math.max(0, player.safety - dt)
        ..shieldTimer = math.max(0, player.shieldTimer - dt)
        ..speedBoostTimer = math.max(0, player.speedBoostTimer - dt)
        ..comboTimer = math.max(0, player.comboTimer - dt)
        ..dashCooldown = math.max(0, player.dashCooldown - dt)
        ..fakeOutCooldown = math.max(0, player.fakeOutCooldown - dt)
        ..dashTimer = math.max(0, player.dashTimer - dt)
        ..fakeOutTimer = math.max(0, player.fakeOutTimer - dt);
      if (player.comboTimer <= 0) {
        player.comboCount = 0;
      }

      final intent = player.isHuman
          ? _humanIntent(player, input)
          : _botIntent(player);
      _applyMovement(player, intent, dt);

      player.position = Offset(
        player.position.dx.clamp(
          activeYard.left + playerRadius,
          activeYard.right - playerRadius,
        ),
        player.position.dy.clamp(
          activeYard.top + playerRadius,
          activeYard.bottom - playerRadius,
        ),
      );

      for (final obstacle in obstacles) {
        _resolveRectCollision(player, obstacle.rect);
      }
    }
  }

  MoveIntent _humanIntent(PlayerState player, GameInput input) {
    if (input.dashPressed && player.dashCooldown <= 0 && player.stamina >= 18) {
      player
        ..dashTimer = 0.24
        ..dashCooldown = 3.8
        ..stamina -= 18;
    }

    if (input.fakeOutPressed &&
        player.fakeOutCooldown <= 0 &&
        player.stamina >= 14) {
      player
        ..fakeOutTimer = 0.7
        ..fakeOutCooldown = 5.5
        ..stamina -= 14;
      decoys.add(
        Decoy(
          position: player.position - player.velocity * 0.12,
          color: player.color,
          name: player.name,
          ttl: 1.1,
        ),
      );
    }

    final direction = _normalized(input.move);
    return MoveIntent(
      direction,
      sprint: input.sprint && direction.distance > 0.1 && player.stamina > 0,
    );
  }

  MoveIntent _botIntent(PlayerState player) {
    final tagger = it;
    final toIt = tagger.position - player.position;
    final itDistance = toIt.distance;
    final crowdAvoidance = _crowdAvoidance(player);

    if (player.isIt) {
      final target = _pickTagTarget(player);
      if (player.dashCooldown <= 0 &&
          (target.position - player.position).distance < 150 &&
          player.stamina > 18) {
        player
          ..dashTimer = 0.2
          ..dashCooldown = 3.5 + _random.nextDouble() * 2
          ..stamina -= 14;
      }
      return MoveIntent(
        _normalized(
          _normalized(target.position - player.position) +
              crowdAvoidance * 0.18,
        ),
        sprint: true,
      );
    }

    final wantsBell =
        bellMode &&
        bellZone.active &&
        (bellZone.center - player.position).distance > 28 &&
        itDistance > (settings.difficulty == Difficulty.blitz ? 185 : 220);
    if (wantsBell) {
      return MoveIntent(
        _normalized(
          _normalized(bellZone.center - player.position) +
              crowdAvoidance * 0.34,
        ),
      );
    }

    if (itDistance < 250) {
      if (player.fakeOutCooldown <= 0 &&
          itDistance < 120 &&
          player.stamina > 16) {
        player
          ..fakeOutTimer = 0.65
          ..fakeOutCooldown = 5.8 + _random.nextDouble() * 2
          ..stamina -= 12;
        decoys.add(
          Decoy(
            position: player.position,
            color: player.color,
            name: player.name,
            ttl: 1,
          ),
        );
      }
      return MoveIntent(
        _normalized(
          _normalized(player.position - tagger.position) +
              crowdAvoidance * 0.46,
        ),
        sprint: itDistance < 190,
      );
    }

    const center = Offset(380, 600);
    final orbit = _normalized(
      Offset(center.dy - player.position.dy, -(center.dx - player.position.dx)),
    );
    final towardCenter = _normalized(center - player.position);
    return MoveIntent(
      _normalized(orbit * 0.62 + towardCenter * 0.2 + crowdAvoidance * 0.58),
    );
  }

  void _applyMovement(PlayerState player, MoveIntent intent, double dt) {
    final difficultySpeed = switch (settings.difficulty) {
      Difficulty.chill => 0.94,
      Difficulty.balanced => 1.0,
      Difficulty.blitz => 1.08,
    };
    final modeSpeed = switch (mode) {
      BlitzMode.staminaChase => 1.0,
      BlitzMode.bellZone => 1.02,
      BlitzMode.shrinkingYard => 1.06,
      BlitzMode.tagFrenzy => 1.12,
    };
    var speed = (player.isHuman ? 242.0 : 226.0) * difficultySpeed * modeSpeed;

    if (player.isIt) {
      speed *= frenzy ? 1.22 : 1.08;
      speed *= catchupBoost;
    }
    if (player.speedBoostTimer > 0) {
      speed *= player.isIt ? 1.16 : 1.26;
    }
    if (player.dashTimer > 0) {
      speed *= 2.15;
    }
    if (intent.sprint && player.stamina > 0) {
      speed *= player.isIt ? 1.08 : 1.18;
    }
    if (player.fakeOutTimer > 0) {
      speed *= 1.12;
    }
    if (player.stamina < 16) {
      speed *= 0.7;
    } else if (player.stamina < 35) {
      speed *= 0.86;
    }

    if (intent.direction.distance <= 0.1) {
      player.velocity *= 0.85;
      player.stamina = math.min(
        100,
        player.stamina + _restRecovery(player) * dt,
      );
    } else {
      player.velocity = intent.direction * speed;
      final baseDrain = player.dashTimer > 0
          ? 12
          : intent.sprint
          ? 24
          : player.isIt
          ? 4
          : 7;
      final drain = baseDrain * _staminaDrainFactor;
      player.stamina = math.max(0, player.stamina - drain * dt);
    }

    if (!player.isHuman || player.stamina < 100) {
      player.stamina = math.min(
        100,
        player.stamina + _moveRecovery(player) * dt,
      );
    }
    player.position += player.velocity * dt;
    if (player.velocity.distance > 24 && player.velocity.dx.abs() > 8) {
      player.facingRight = player.velocity.dx >= 0;
    }
  }

  Offset _crowdAvoidance(PlayerState player) {
    var push = Offset.zero;
    for (final other in players) {
      if (other.id == player.id) {
        continue;
      }
      final delta = player.position - other.position;
      final distance = delta.distance;
      if (distance <= 0 || distance > 128) {
        continue;
      }
      final strength = (128 - distance) / 128;
      push += delta / distance * strength;
    }
    return _normalized(push);
  }

  double get _staminaDrainFactor {
    return switch (mode) {
      BlitzMode.staminaChase => 1.42,
      BlitzMode.bellZone => 1.04,
      BlitzMode.shrinkingYard => 1.14,
      BlitzMode.tagFrenzy => 0.86,
    };
  }

  double _restRecovery(PlayerState player) {
    final base = player.isIt ? 18.0 : 22.0;
    return switch (mode) {
      BlitzMode.staminaChase => base * 0.72,
      BlitzMode.bellZone => base,
      BlitzMode.shrinkingYard => base * 0.92,
      BlitzMode.tagFrenzy => base * 1.24,
    };
  }

  double _moveRecovery(PlayerState player) {
    final base = player.isIt ? 9.0 : 7.0;
    return switch (mode) {
      BlitzMode.staminaChase => base * 0.45,
      BlitzMode.bellZone => base * 0.95,
      BlitzMode.shrinkingYard => base * 0.82,
      BlitzMode.tagFrenzy => base * 1.25,
    };
  }

  void _resolveTags() {
    final tagger = it;
    for (final target in players) {
      if (target.id == tagger.id ||
          target.safety > 0 ||
          tagger.safety > 0 ||
          target.fakeOutTimer > 0) {
        continue;
      }

      if ((tagger.position - target.position).distance <= tagRadius) {
        if (target.shieldTimer > 0) {
          _blockTag(tagger, target);
          break;
        }
        final multiplier = frenzy ? 2 : 1;
        final comboCount = tagger.comboTimer > 0 ? tagger.comboCount + 1 : 1;
        final comboBonus = math.max(0, comboCount - 1) * (frenzy ? 80 : 45);
        final bountyHit = target.id == _bountyTargetId && _bountyTimeLeft > 0;
        final bountyBonus = bountyHit ? (frenzy ? 220 : 260) : 0;
        tagger
          ..score +=
              (frenzy ? 125 : 100) * multiplier + comboBonus + bountyBonus
          ..tags += 1
          ..comboCount = comboCount
          ..comboTimer = frenzy ? 6.0 : 4.6
          ..speedBoostTimer = bountyHit
              ? math.max(tagger.speedBoostTimer, 3.5)
              : tagger.speedBoostTimer
          ..isIt = false
          ..safety = 1
          ..stamina = math.min(100, tagger.stamina + 22);
        target
          ..score = math.max(0, target.score - 20)
          ..isIt = true
          ..safety = 1.15
          ..comboCount = 0
          ..comboTimer = 0
          ..stamina = math.min(100, target.stamina + 16);
        _pushApartAfterTag(tagger, target);
        noTagTimer = 0;
        catchupBoost = 1;
        if (bountyHit) {
          _float(
            target.position.translate(0, -36),
            'BOUNTY +$bountyBonus',
            const Color(0xffffd64c),
            ttl: 0.98,
          );
          _startNewBounty();
        }
        _float(
          target.position,
          comboCount >= 2 ? 'x$comboCount COMBO!' : 'TAG!',
          comboCount >= 2 ? const Color(0xffff8a18) : const Color(0xfffff4a8),
          ttl: comboCount >= 2 ? 0.9 : 0.75,
        );
        break;
      }
    }

    final boostSecond = noTagTimer.floor();
    if (noTagTimer > 10 &&
        boostSecond % 6 == 0 &&
        boostSecond != _lastBoostSecond) {
      _lastBoostSecond = boostSecond;
      floatingTexts.add(
        FloatingText(
          position: it.position.translate(0, -42),
          text: 'CATCH-UP',
          color: const Color(0xffffffff),
          ttl: 0.8,
        ),
      );
    }
  }

  void _blockTag(PlayerState tagger, PlayerState target) {
    target
      ..shieldTimer = 0
      ..safety = 0.72
      ..stamina = math.min(100, target.stamina + 12);
    tagger
      ..safety = 0.38
      ..comboCount = 0
      ..comboTimer = 0;
    final direction = _separationDirection(tagger, target);
    tagger
      ..position -= direction * 38
      ..velocity = -direction * 230;
    target
      ..position += direction * 18
      ..velocity = direction * 95;
    _clampPlayerToYard(tagger, yard);
    _clampPlayerToYard(target, yard);
    _float(target.position, 'BLOCK!', const Color(0xff9dff73), ttl: 0.88);
  }

  void _pushApartAfterTag(PlayerState tagger, PlayerState target) {
    final direction = _separationDirection(tagger, target);
    tagger
      ..position -= direction * 24
      ..velocity = -direction * 135;
    target
      ..position += direction * 34
      ..velocity = direction * 165;
    _clampPlayerToYard(tagger, yard);
    _clampPlayerToYard(target, yard);
  }

  void _resolvePlayerSeparation(Rect activeYard) {
    for (var pass = 0; pass < 2; pass += 1) {
      for (var i = 0; i < players.length; i += 1) {
        for (var j = i + 1; j < players.length; j += 1) {
          final first = players[i];
          final second = players[j];
          final delta = second.position - first.position;
          final distance = delta.distance;
          if (distance >= playerSeparationRadius) {
            continue;
          }
          final direction = distance < 0.001
              ? _directionForPair(i, j)
              : delta / distance;
          final overlap = playerSeparationRadius - distance;
          final firstShare = first.isHuman
              ? 0.28
              : second.isHuman
              ? 0.72
              : 0.5;
          final secondShare = 1 - firstShare;

          first.position -= direction * overlap * firstShare;
          second.position += direction * overlap * secondShare;
          first.velocity -= direction * overlap * 3.2 * firstShare;
          second.velocity += direction * overlap * 3.2 * secondShare;
          _clampPlayerToYard(first, activeYard);
          _clampPlayerToYard(second, activeYard);
        }
      }
    }
  }

  Offset _separationDirection(PlayerState first, PlayerState second) {
    final delta = second.position - first.position;
    if (delta.distance >= 0.001) {
      return delta / delta.distance;
    }
    final firstIndex = players.indexOf(first);
    final secondIndex = players.indexOf(second);
    return _directionForPair(firstIndex, secondIndex);
  }

  Offset _directionForPair(int firstIndex, int secondIndex) {
    final angle = firstIndex * 2.399963 + secondIndex * 1.714291;
    return Offset(math.cos(angle), math.sin(angle));
  }

  void _clampPlayerToYard(PlayerState player, Rect activeYard) {
    player.position = Offset(
      player.position.dx.clamp(
        activeYard.left + playerRadius,
        activeYard.right - playerRadius,
      ),
      player.position.dy.clamp(
        activeYard.top + playerRadius,
        activeYard.bottom - playerRadius,
      ),
    );
  }

  void _scoreObjectives(double dt) {
    for (final player in players) {
      if (!player.isIt) {
        player.score += dt * _survivalRate;
      }

      if (player.id == _bountyTargetId && _bountyTimeLeft > 0 && !player.isIt) {
        player.score += dt * (frenzy ? 5.5 : 4.2);
      }

      if (bellMode &&
          bellZone.active &&
          (player.position - bellZone.center).distance <= bellZone.radius) {
        player.score += dt * (player.isIt ? 8 : 13);
      }

      if (shrinkingMode) {
        final activeYard = yard;
        final edgeMargin = [
          player.position.dx - activeYard.left,
          activeYard.right - player.position.dx,
          player.position.dy - activeYard.top,
          activeYard.bottom - player.position.dy,
        ].reduce(math.min);
        if (edgeMargin > 86) {
          player.score += dt * (player.isIt ? 1.2 : 3.2);
        } else if (edgeMargin < 34) {
          player.stamina = math.max(0, player.stamina - 12 * dt);
        }
      }
    }
  }

  double get _survivalRate {
    return switch (mode) {
      BlitzMode.staminaChase => 1.8,
      BlitzMode.bellZone => 0.8,
      BlitzMode.shrinkingYard => 1.1,
      BlitzMode.tagFrenzy => 0.35,
    };
  }

  PlayerState _pickTagTarget(PlayerState player) {
    if (decoys.isNotEmpty && _random.nextDouble() < 0.24) {
      final decoy = decoys[_random.nextInt(decoys.length)];
      return PlayerState(
        id: 'decoy',
        name: decoy.name,
        position: decoy.position,
        color: decoy.color,
        isHuman: false,
        isIt: false,
      );
    }

    var best = players.firstWhere((candidate) => !candidate.isIt);
    var bestScore = double.infinity;
    for (final candidate in players) {
      if (candidate.id == player.id || candidate.isIt) {
        continue;
      }
      final distanceScore = (candidate.position - player.position).distance;
      final bellRisk = bellMode && bellZone.active
          ? (candidate.position - bellZone.center).distance * 0.18
          : 0;
      final score = distanceScore + bellRisk - candidate.score * 0.03;
      if (score < bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    return best;
  }

  void _resolveRectCollision(PlayerState player, Rect obstacle) {
    if (!obstacle.inflate(playerRadius).contains(player.position)) {
      return;
    }

    final left = (player.position.dx - (obstacle.left - playerRadius)).abs();
    final right = (player.position.dx - (obstacle.right + playerRadius)).abs();
    final top = (player.position.dy - (obstacle.top - playerRadius)).abs();
    final bottom = (player.position.dy - (obstacle.bottom + playerRadius))
        .abs();
    final smallest = math.min(math.min(left, right), math.min(top, bottom));

    if (smallest == left) {
      player.position = Offset(
        obstacle.left - playerRadius,
        player.position.dy,
      );
    } else if (smallest == right) {
      player.position = Offset(
        obstacle.right + playerRadius,
        player.position.dy,
      );
    } else if (smallest == top) {
      player.position = Offset(player.position.dx, obstacle.top - playerRadius);
    } else {
      player.position = Offset(
        player.position.dx,
        obstacle.bottom + playerRadius,
      );
    }
    player.velocity *= 0.35;
  }
}

Offset _normalized(Offset value) {
  final length = value.distance;
  if (length < 0.001) {
    return Offset.zero;
  }
  return value / length;
}
