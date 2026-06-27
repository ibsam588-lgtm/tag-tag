import 'package:flutter_test/flutter_test.dart';
import 'package:tag_tag_playground_blitz/game_simulation.dart';

void main() {
  const settings = GameSettings(
    playerName: 'Tester',
    botCount: 5,
    roundLength: 90,
    difficulty: Difficulty.balanced,
  );

  test('modes start with distinct rule states', () {
    final stamina = PlaygroundBlitzSimulation(
      settings,
      mode: BlitzMode.staminaChase,
    );
    final bell = PlaygroundBlitzSimulation(settings, mode: BlitzMode.bellZone);
    final shrinking = PlaygroundBlitzSimulation(
      settings,
      mode: BlitzMode.shrinkingYard,
    );
    final frenzy = PlaygroundBlitzSimulation(
      settings,
      mode: BlitzMode.tagFrenzy,
    );

    expect(stamina.bellZone.active, isFalse);
    expect(stamina.shrinkProgress, 0);
    expect(stamina.tagTarget, 15);

    expect(bell.bellZone.active, isTrue);
    expect(bell.shrinkProgress, 0);
    expect(bell.tagTarget, 15);

    expect(shrinking.bellZone.active, isFalse);
    expect(shrinking.roundLength, lessThan(settings.roundLength));
    expect(shrinking.tagTarget, 15);

    expect(frenzy.frenzy, isTrue);
    expect(frenzy.bellZone.active, isFalse);
    expect(frenzy.tagTarget, 12);
  });

  test('shrinking yard changes only in shrinking mode', () {
    final input = GameInput();
    final stamina = PlaygroundBlitzSimulation(
      settings,
      mode: BlitzMode.staminaChase,
    );
    final shrinking = PlaygroundBlitzSimulation(
      settings,
      mode: BlitzMode.shrinkingYard,
    );

    for (var i = 0; i < 1200; i += 1) {
      stamina.update(1 / 30, input);
      shrinking.update(1 / 30, input);
    }

    expect(stamina.yard, PlaygroundBlitzSimulation.startYard);
    expect(shrinking.shrinkProgress, greaterThan(0));
    expect(
      shrinking.yard.width,
      lessThan(PlaygroundBlitzSimulation.startYard.width),
    );
  });

  test('overlapping players separate instead of jittering in place', () {
    final simulation = PlaygroundBlitzSimulation(
      settings,
      mode: BlitzMode.tagFrenzy,
    );
    const stackedSpot = Offset(380, 520);
    for (final player in simulation.players.take(4)) {
      player
        ..position = stackedSpot
        ..velocity = Offset.zero
        ..safety = 2;
    }

    simulation.update(1 / 30, GameInput());

    var smallestDistance = double.infinity;
    final checkedPlayers = simulation.players.take(4).toList();
    for (var i = 0; i < checkedPlayers.length; i += 1) {
      for (var j = i + 1; j < checkedPlayers.length; j += 1) {
        final distance =
            (checkedPlayers[i].position - checkedPlayers[j].position).distance;
        if (distance < smallestDistance) {
          smallestDistance = distance;
        }
      }
    }

    expect(smallestDistance, greaterThan(18));
  });

  test('power ups spawn and can be collected', () {
    final simulation = PlaygroundBlitzSimulation(
      settings,
      mode: BlitzMode.tagFrenzy,
    );
    expect(simulation.powerUps, isNotEmpty);

    final human = simulation.human
      ..stamina = 20
      ..dashCooldown = 2;
    final pickup = simulation.powerUps.first..position = human.position;
    final startingScore = human.score;

    simulation.update(1 / 30, GameInput());

    expect(
      simulation.powerUps.any((powerUp) => powerUp.id == pickup.id),
      isFalse,
    );
    switch (pickup.kind) {
      case PowerUpKind.lightning:
        expect(human.speedBoostTimer, greaterThan(0));
      case PowerUpKind.shield:
        expect(human.shieldTimer, greaterThan(0));
      case PowerUpKind.stamina:
        expect(human.stamina, 100);
      case PowerUpKind.star:
        expect(human.score, greaterThan(startingScore));
    }
  });

  test('bounty target creates a timed scoring goal', () {
    final simulation = PlaygroundBlitzSimulation(
      settings,
      mode: BlitzMode.staminaChase,
    );
    final target = simulation.players.firstWhere((player) => !player.isIt);
    simulation.setPracticeBounty(target, seconds: 0.05);
    final startingScore = target.score;

    simulation.update(0.04, GameInput());
    expect(simulation.bountyTargetId, target.id);

    simulation.update(0.04, GameInput());
    expect(target.score, greaterThan(startingScore));
    expect(simulation.bountyTargetId, isNotNull);
  });

  test('tagging the bounty gives a larger score bonus', () {
    final simulation = PlaygroundBlitzSimulation(
      settings,
      mode: BlitzMode.staminaChase,
    );
    final tagger = simulation.it;
    final target = simulation.players.firstWhere((player) => !player.isIt);
    target
      ..position = tagger.position
      ..safety = 0
      ..shieldTimer = 0;
    tagger.safety = 0;
    simulation.setPracticeBounty(target, seconds: 10);

    simulation.update(1 / 30, GameInput());

    expect(tagger.tags, 1);
    expect(tagger.score, greaterThanOrEqualTo(360));
  });
}
