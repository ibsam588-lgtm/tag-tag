import 'dart:math' as math;
import 'dart:ui';

enum Difficulty { chill, balanced, blitz }

enum ObstacleKind { slide, bench, fence, chalk, cones }

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
  double score = 0;
  double stamina = 100;
  double safety = 1.2;
  double dashCooldown = 0;
  double dashTimer = 0;
  double fakeOutCooldown = 0;
  double fakeOutTimer = 0;
  int tags = 0;
}

class BellZone {
  Offset center = const Offset(620, 390);
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
  PlaygroundBlitzSimulation(this.settings)
    : timer = settings.roundLength,
      players = _createPlayers(settings);

  static const Size worldSize = Size(1200, 760);
  static const Rect startYard = Rect.fromLTWH(64, 64, 1072, 632);
  static const Rect finalYard = Rect.fromLTWH(188, 132, 824, 496);
  static const double playerRadius = 18;
  static const double tagRadius = 42;

  static const List<ArenaObstacle> obstacles = [
    ArenaObstacle(
      'slide',
      ObstacleKind.slide,
      Rect.fromLTWH(170, 145, 130, 78),
    ),
    ArenaObstacle(
      'monkey-bars',
      ObstacleKind.fence,
      Rect.fromLTWH(508, 126, 156, 58),
    ),
    ArenaObstacle(
      'bench-left',
      ObstacleKind.bench,
      Rect.fromLTWH(128, 500, 150, 38),
    ),
    ArenaObstacle(
      'bench-right',
      ObstacleKind.bench,
      Rect.fromLTWH(887, 508, 148, 38),
    ),
    ArenaObstacle(
      'hopscotch',
      ObstacleKind.chalk,
      Rect.fromLTWH(520, 500, 116, 112),
    ),
    ArenaObstacle(
      'cone-row',
      ObstacleKind.cones,
      Rect.fromLTWH(780, 220, 54, 236),
    ),
  ];

  final GameSettings settings;
  final List<PlayerState> players;
  final BellZone bellZone = BellZone();
  final List<Decoy> decoys = [];
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

  PlayerState get human => players.firstWhere((player) => player.isHuman);
  PlayerState get it =>
      players.firstWhere((player) => player.isIt, orElse: () => players.first);
  bool get frenzy => timer <= 15;

  PlayerState get winner {
    final sorted = [...players]..sort((a, b) => b.score.compareTo(a.score));
    return sorted.first;
  }

  Rect get yard {
    const shrinkStart = 15.0;
    final shrinkDuration = math.max(18.0, settings.roundLength - 32);
    final t = ((elapsed - shrinkStart) / shrinkDuration).clamp(0.0, 1.0);
    return Rect.lerp(startYard, finalYard, t)!;
  }

  double get shrinkProgress {
    const shrinkStart = 15.0;
    final shrinkDuration = math.max(18.0, settings.roundLength - 32);
    return ((elapsed - shrinkStart) / shrinkDuration).clamp(0.0, 1.0);
  }

  void reset() {
    final fresh = PlaygroundBlitzSimulation(settings);
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
    floatingTexts.clear();
    timer = settings.roundLength;
    elapsed = 0;
    noTagTimer = 0;
    catchupBoost = 1;
    roundOver = false;
    _bellCelebrated = false;
    _frenzyCelebrated = false;
    _lastBoostSecond = -1;
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
          position: const Offset(600, 145),
          text: 'FRENZY!',
          color: const Color(0xffff3f68),
          ttl: 1.05,
        ),
      );
    }

    _updateBellZone(dt);
    _updateDecoys(dt);
    _updatePlayers(dt, input);
    _resolveTags();
    _scoreObjectives(dt);

    if (timer <= 0) {
      roundOver = true;
    }
  }

  static List<PlayerState> _createPlayers(GameSettings settings) {
    const starts = [
      Offset(380, 360),
      Offset(780, 360),
      Offset(310, 570),
      Offset(900, 560),
      Offset(276, 268),
      Offset(920, 260),
      Offset(585, 612),
      Offset(612, 210),
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
        bellZone.nextIn = 12;
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
      bellZone.timeLeft = settings.difficulty == Difficulty.blitz ? 7 : 8.5;
    }
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
        ..dashCooldown = math.max(0, player.dashCooldown - dt)
        ..fakeOutCooldown = math.max(0, player.fakeOutCooldown - dt)
        ..dashTimer = math.max(0, player.dashTimer - dt)
        ..fakeOutTimer = math.max(0, player.fakeOutTimer - dt);

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
        _normalized(target.position - player.position),
        sprint: true,
      );
    }

    final wantsBell =
        bellZone.active &&
        (bellZone.center - player.position).distance > 28 &&
        itDistance > (settings.difficulty == Difficulty.blitz ? 185 : 220);
    if (wantsBell) {
      return MoveIntent(_normalized(bellZone.center - player.position));
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
        _normalized(player.position - tagger.position),
        sprint: itDistance < 190,
      );
    }

    const center = Offset(600, 380);
    final orbit = _normalized(
      Offset(center.dy - player.position.dy, -(center.dx - player.position.dx)),
    );
    final towardCenter = _normalized(center - player.position);
    return MoveIntent(_normalized(orbit * 0.75 + towardCenter * 0.25));
  }

  void _applyMovement(PlayerState player, MoveIntent intent, double dt) {
    final difficultySpeed = switch (settings.difficulty) {
      Difficulty.chill => 0.94,
      Difficulty.balanced => 1.0,
      Difficulty.blitz => 1.08,
    };
    var speed = (player.isHuman ? 242.0 : 226.0) * difficultySpeed;

    if (player.isIt) {
      speed *= frenzy ? 1.22 : 1.08;
      speed *= catchupBoost;
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
      player.stamina = math.min(100, player.stamina + 17 * dt);
    } else {
      player.velocity = intent.direction * speed;
      final drain = player.dashTimer > 0
          ? 12
          : intent.sprint
          ? 24
          : player.isIt
          ? 4
          : 7;
      player.stamina = math.max(0, player.stamina - drain * dt);
    }

    if (!player.isHuman || player.stamina < 100) {
      player.stamina = math.min(
        100,
        player.stamina + (player.isIt ? 13 : 10) * dt,
      );
    }
    player.position += player.velocity * dt;
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
        final multiplier = frenzy ? 2 : 1;
        tagger
          ..score += 100 * multiplier
          ..tags += 1
          ..isIt = false
          ..safety = 1
          ..stamina = math.min(100, tagger.stamina + 22);
        target
          ..score = math.max(0, target.score - 20)
          ..isIt = true
          ..safety = 1.15
          ..stamina = math.min(100, target.stamina + 16);
        noTagTimer = 0;
        catchupBoost = 1;
        floatingTexts.add(
          FloatingText(
            position: target.position,
            text: 'TAG!',
            color: const Color(0xfffff4a8),
            ttl: 0.75,
          ),
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

  void _scoreObjectives(double dt) {
    for (final player in players) {
      if (!player.isIt) {
        player.score += dt * 1.4;
      }

      if (bellZone.active &&
          (player.position - bellZone.center).distance <= bellZone.radius) {
        player.score += dt * (player.isIt ? 8 : 13);
      }
    }
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
      final bellRisk = bellZone.active
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
