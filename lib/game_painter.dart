import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game_simulation.dart';

class PlaygroundPainter extends CustomPainter {
  PlaygroundPainter({required this.simulation, required this.animationTime});

  final PlaygroundBlitzSimulation simulation;
  final double animationTime;

  static const _ink = Color(0xff111820);
  static const _asphalt = Color(0xff756f64);
  static const _asphaltLight = Color(0xff90877b);
  static const _grass = Color(0xff2c8d4b);
  static const _grassDark = Color(0xff155f32);
  static const _chalk = Color(0xfffff4de);
  static const _red = Color(0xffff405f);
  static const _yellow = Color(0xffffd64c);
  static const _purple = Color(0xffb34cff);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / PlaygroundBlitzSimulation.worldSize.width,
      size.height / PlaygroundBlitzSimulation.worldSize.height,
    );
    final worldSize = PlaygroundBlitzSimulation.worldSize * scale;
    final offset = Offset(
      (size.width - worldSize.width) / 2,
      (size.height - worldSize.height) / 2,
    );

    _drawScreenBackdrop(canvas, size);
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    _drawWorld(canvas);
    canvas.restore();
  }

  void _drawScreenBackdrop(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff17331f), Color(0xff244b35), Color(0xff182632)],
        ).createShader(rect),
    );
  }

  void _drawWorld(Canvas canvas) {
    final world = Offset.zero & PlaygroundBlitzSimulation.worldSize;
    canvas.drawRect(
      world,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_grassDark, _grass, Color(0xff1d6f4a)],
        ).createShader(world),
    );

    _drawFoliage(canvas);
    _drawFence(canvas);
    _drawArena(canvas);
    _drawAsphaltTexture(canvas);
    _drawCourtLines(canvas);
    _drawPlaygroundCorners(canvas);
    _drawObstacles(canvas);
    _drawYardPressure(canvas);
    _drawBellZone(canvas);
    _drawDecoys(canvas);
    _drawTagRing(canvas);
    _drawPlayers(canvas);
    _drawFloatingTexts(canvas);
    _drawWorldVignette(canvas);
  }

  void _drawArena(Canvas canvas) {
    final court = RRect.fromRectAndRadius(
      PlaygroundBlitzSimulation.startYard,
      const Radius.circular(26),
    );
    canvas.drawRRect(
      court.shift(const Offset(0, 12)),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
    canvas.drawRRect(
      court,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_asphaltLight, _asphalt, Color(0xff5e594f)],
        ).createShader(PlaygroundBlitzSimulation.startYard),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        PlaygroundBlitzSimulation.startYard.deflate(15),
        const Radius.circular(20),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = _chalk.withValues(alpha: 0.46),
    );
  }

  void _drawFoliage(Canvas canvas) {
    final leafColors = [
      const Color(0xff1f7837),
      const Color(0xff37a84c),
      const Color(0xff79b944),
      const Color(0xff0f542c),
    ];
    for (var i = 0; i < 70; i += 1) {
      final x = (i * 37 % 1200).toDouble();
      final wobble = math.sin(i * 1.7) * 13;
      final radius = 17 + (i % 5) * 3.0;
      final paint = Paint()..color = leafColors[i % leafColors.length];
      canvas.drawCircle(Offset(x, 14 + wobble), radius, paint);
      canvas.drawCircle(Offset(x + 18, 746 - wobble), radius * 0.9, paint);
    }
    for (var i = 0; i < 34; i += 1) {
      final y = 80 + i * 19.0;
      final radius = 14 + (i % 4) * 3.0;
      canvas.drawCircle(
        Offset(18 + math.sin(i) * 9, y),
        radius,
        Paint()..color = leafColors[(i + 1) % leafColors.length],
      );
      canvas.drawCircle(
        Offset(1183 + math.cos(i) * 9, y),
        radius,
        Paint()..color = leafColors[(i + 2) % leafColors.length],
      );
    }
  }

  void _drawFence(Canvas canvas) {
    final rail = Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xff33404a);
    final post = Paint()..color = const Color(0xff465562);
    for (final y in [48.0, 712.0]) {
      canvas.drawLine(Offset(40, y), Offset(1160, y), rail);
      canvas.drawLine(Offset(40, y + 18), Offset(1160, y + 18), rail);
      for (var x = 50.0; x <= 1150; x += 48) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, y + 8), width: 9, height: 46),
            const Radius.circular(4),
          ),
          post,
        );
      }
    }
    for (final x in [42.0, 1158.0]) {
      canvas.drawLine(Offset(x, 80), Offset(x, 680), rail);
      canvas.drawLine(
        Offset(x + (x < 600 ? 18 : -18), 80),
        Offset(x + (x < 600 ? 18 : -18), 680),
        rail,
      );
      for (var y = 92.0; y <= 668; y += 48) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, y), width: 40, height: 9),
            const Radius.circular(4),
          ),
          post,
        );
      }
    }
  }

  void _drawAsphaltTexture(Canvas canvas) {
    final yard = PlaygroundBlitzSimulation.startYard.deflate(18);
    for (var i = 0; i < 210; i += 1) {
      final x = yard.left + (i * 73 % yard.width.toInt()).toDouble();
      final y = yard.top + (i * 41 % yard.height.toInt()).toDouble();
      final color = i.isEven
          ? Colors.white.withValues(alpha: 0.055)
          : _ink.withValues(alpha: 0.08);
      canvas.drawCircle(
        Offset(x, y),
        0.7 + (i % 5) * 0.32,
        Paint()..color = color,
      );
    }

    final crackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = _ink.withValues(alpha: 0.12);
    for (var i = 0; i < 8; i += 1) {
      final start = Offset(180 + i * 116.0, 145 + (i * 61 % 420).toDouble());
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..relativeLineTo(22, -8 + (i % 3) * 7)
        ..relativeLineTo(18, 13)
        ..relativeLineTo(28, -9);
      canvas.drawPath(path, crackPaint);
    }
  }

  void _drawCourtLines(Canvas canvas) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = _chalk.withValues(alpha: 0.46);
    _drawDashedCircle(canvas, const Offset(600, 380), 128, line, 54);
    _drawDashedCircle(canvas, const Offset(600, 380), 62, line, 42);

    final softLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = _chalk.withValues(alpha: 0.34);
    _drawStar(canvas, const Offset(382, 600), 42, softLine);
    _drawStar(canvas, const Offset(760, 585), 36, softLine);
    _drawRainbow(canvas, const Offset(930, 606));
    _drawFlowerChalk(canvas, const Offset(395, 286));
    _drawSmallText(
      canvas,
      '08',
      const Offset(590, 420),
      52,
      _chalk.withValues(alpha: 0.24),
    );
  }

  void _drawPlaygroundCorners(Canvas canvas) {
    _drawTireStack(canvas, const Offset(948, 132));
    _drawTireStack(canvas, const Offset(1022, 138));
    _drawCone(canvas, const Offset(160, 318), 0.86);
    _drawCone(canvas, const Offset(980, 592), 0.92);
    _drawCone(canvas, const Offset(1042, 610), 0.84);
    _drawCone(canvas, const Offset(905, 256), 0.74);
    _drawSideSlide(canvas, const Rect.fromLTWH(980, 150, 148, 112));
    _drawSideSlide(
      canvas,
      const Rect.fromLTWH(970, 505, 160, 126),
      flipped: true,
    );
    _drawBench(canvas, const Rect.fromLTWH(82, 615, 154, 42));
  }

  void _drawObstacles(Canvas canvas) {
    for (final obstacle in PlaygroundBlitzSimulation.obstacles) {
      switch (obstacle.kind) {
        case ObstacleKind.slide:
          _drawSlide(canvas, obstacle.rect);
        case ObstacleKind.fence:
          _drawMonkeyBars(canvas, obstacle.rect);
        case ObstacleKind.bench:
          _drawBench(canvas, obstacle.rect);
        case ObstacleKind.chalk:
          _drawHopscotch(canvas, obstacle.rect);
        case ObstacleKind.cones:
          _drawConeRow(canvas, obstacle.rect);
      }
    }
  }

  void _drawYardPressure(Canvas canvas) {
    final yard = simulation.yard;
    final pressureAlpha = (0.08 + simulation.shrinkProgress * 0.34)
        .clamp(0.08, 0.42)
        .toDouble();
    final outer = Path()
      ..addRect(Offset.zero & PlaygroundBlitzSimulation.worldSize);
    final inner = Path()
      ..addRRect(RRect.fromRectAndRadius(yard, const Radius.circular(18)));
    final dangerPath = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(
      dangerPath,
      Paint()..color = _red.withValues(alpha: pressureAlpha),
    );

    if (simulation.frenzy) {
      canvas.drawPath(
        dangerPath,
        Paint()..color = const Color(0xffff8a1e).withValues(alpha: 0.14),
      );
    }

    final boundary = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = simulation.frenzy ? 7 : 5
      ..strokeCap = StrokeCap.round
      ..color = (simulation.frenzy ? _yellow : _chalk).withValues(alpha: 0.82);
    canvas.drawRRect(
      RRect.fromRectAndRadius(yard, const Radius.circular(18)),
      boundary,
    );

    if (simulation.shrinkProgress > 0.24) {
      final dashPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = _red.withValues(alpha: 0.86);
      _drawDashedRect(canvas, yard, dashPaint);
      for (var i = 0; i < 10; i += 1) {
        final t = i / 9;
        _drawCone(
          canvas,
          Offset(lerpDouble(yard.left, yard.right, t), yard.top - 22),
          0.72,
        );
        _drawCone(
          canvas,
          Offset(lerpDouble(yard.left, yard.right, t), yard.bottom + 18),
          0.72,
        );
      }
    }
  }

  void _drawBellZone(Canvas canvas) {
    final bell = simulation.bellZone;
    if (!bell.active) {
      return;
    }
    final pulse = math.sin(animationTime * 7) * 6;
    final glow = Paint()
      ..color = _purple.withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(bell.center, bell.radius + 16, glow);
    canvas.drawCircle(
      bell.center,
      bell.radius,
      Paint()..color = _purple.withValues(alpha: 0.13),
    );
    canvas.drawCircle(
      bell.center,
      bell.radius + pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = const Color(0xffd27cff).withValues(alpha: 0.96),
    );
    _drawStarburstChalk(canvas, bell.center, bell.radius * 0.6);
    _drawBell(canvas, bell.center);
  }

  void _drawDecoys(Canvas canvas) {
    for (final decoy in simulation.decoys) {
      final alpha = decoy.ttl.clamp(0.0, 1.0).toDouble() * 0.52;
      canvas.drawCircle(
        decoy.position,
        24 + (1 - alpha) * 8,
        Paint()..color = decoy.color.withValues(alpha: alpha * 0.42),
      );
      canvas.drawCircle(
        decoy.position,
        15,
        Paint()..color = decoy.color.withValues(alpha: alpha),
      );
    }
  }

  void _drawTagRing(Canvas canvas) {
    final tagger = simulation.it;
    final pulse = math.sin(animationTime * 10) * 5;
    canvas.drawCircle(
      tagger.position,
      PlaygroundBlitzSimulation.tagRadius + 18,
      Paint()
        ..color = _red.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(
      tagger.position,
      PlaygroundBlitzSimulation.tagRadius + pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _red.withValues(alpha: 0.92),
    );
    canvas.drawCircle(
      tagger.position,
      PlaygroundBlitzSimulation.tagRadius,
      Paint()..color = _red.withValues(alpha: 0.14),
    );
    for (var i = 0; i < 3; i += 1) {
      final angle = animationTime * 1.8 + i * math.pi * 2 / 3;
      final tip =
          tagger.position + Offset(math.cos(angle), math.sin(angle)) * 52;
      final left =
          tagger.position +
          Offset(math.cos(angle + 0.18), math.sin(angle + 0.18)) * 38;
      final right =
          tagger.position +
          Offset(math.cos(angle - 0.18), math.sin(angle - 0.18)) * 38;
      final arrow = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close();
      canvas.drawPath(arrow, Paint()..color = _red.withValues(alpha: 0.72));
    }
  }

  void _drawPlayers(Canvas canvas) {
    final sortedPlayers = [...simulation.players]
      ..sort(
        (a, b) => a.isIt == b.isIt
            ? 0
            : a.isIt
            ? 1
            : -1,
      );
    for (final player in sortedPlayers) {
      _drawMotionTrail(canvas, player);
    }
    for (final player in sortedPlayers) {
      _drawRunner(canvas, player);
      _drawPlayerMarker(canvas, player);
    }
  }

  void _drawMotionTrail(Canvas canvas, PlayerState player) {
    final speed = player.velocity.distance;
    if (speed < 55) {
      return;
    }
    final direction = player.velocity / speed;
    final trailColor = player.isIt
        ? _red
        : player.isHuman
        ? const Color(0xff39caff)
        : _yellow;
    final paint = Paint()
      ..strokeWidth = player.dashTimer > 0 ? 6 : 3
      ..strokeCap = StrokeCap.round
      ..color = trailColor.withValues(
        alpha: player.dashTimer > 0 ? 0.65 : 0.36,
      );
    for (var i = 0; i < 3; i += 1) {
      final side = Offset(-direction.dy, direction.dx) * (i - 1) * 5.0;
      canvas.drawLine(
        player.position - direction * (22 + i * 9.0) + side,
        player.position - direction * (46 + i * 10.0) + side,
        paint,
      );
    }
  }

  void _drawRunner(Canvas canvas, PlayerState player) {
    final speed = player.velocity.distance;
    final angle = speed > 8
        ? math.atan2(player.velocity.dy, player.velocity.dx)
        : -math.pi / 2;
    final bodyColor = player.isIt ? _red : player.color;
    final skin = const Color(0xffffbd82);
    final phase = math.sin(animationTime * (speed > 20 ? 14 : 6));

    if (player.isIt || player.safety > 0 || player.fakeOutTimer > 0) {
      canvas.drawCircle(
        player.position,
        player.isIt ? 31 + math.sin(animationTime * 9) * 2 : 24,
        Paint()
          ..color = (player.isIt ? _red : Colors.white).withValues(
            alpha: player.isIt ? 0.26 : 0.15,
          ),
      );
    }

    canvas.save();
    canvas.translate(player.position.dx, player.position.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      const Rect.fromLTWH(-20, -12, 42, 26).shift(const Offset(4, 12)),
      Paint()..color = Colors.black.withValues(alpha: 0.24),
    );

    final limbPaint = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xff242938);
    canvas.drawLine(
      Offset(-8, -7 + phase * 2),
      Offset(-24, -16 - phase * 5),
      limbPaint,
    );
    canvas.drawLine(
      Offset(-8, 7 - phase * 2),
      Offset(-24, 16 + phase * 5),
      limbPaint,
    );
    canvas.drawLine(Offset(1, -10), Offset(-13, -22 + phase * 4), limbPaint);
    canvas.drawLine(Offset(2, 10), Offset(-12, 22 - phase * 4), limbPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-13, -13, 27, 26),
        const Radius.circular(9),
      ),
      Paint()
        ..color = bodyColor.withValues(alpha: player.stamina < 14 ? 0.7 : 1),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-13, -13, 27, 26),
        const Radius.circular(9),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = player.isHuman ? 3 : 2
        ..color = Colors.white.withValues(alpha: player.isHuman ? 0.9 : 0.38),
    );

    canvas.drawCircle(const Offset(12, 0), 11, Paint()..color = skin);
    canvas.drawArc(
      const Rect.fromLTWH(2, -11, 20, 18),
      math.pi,
      math.pi,
      false,
      Paint()
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = _hairColor(player),
    );
    canvas.drawCircle(const Offset(16, -3), 1.7, Paint()..color = _ink);
    canvas.drawCircle(const Offset(16, 4), 1.7, Paint()..color = _ink);
    canvas.restore();
  }

  Color _hairColor(PlayerState player) {
    if (player.color == const Color(0xffffcb45)) {
      return const Color(0xffffd35e);
    }
    if (player.color == const Color(0xffb99cff)) {
      return const Color(0xff7942c9);
    }
    return const Color(0xff1a1a22);
  }

  void _drawPlayerMarker(Canvas canvas, PlayerState player) {
    final markerColor = player.isIt
        ? _red
        : player.isHuman
        ? const Color(0xff37caff)
        : _yellow;
    final top = player.position.translate(0, -44);
    final path = Path()
      ..moveTo(top.dx, top.dy + math.sin(animationTime * 6) * 2)
      ..lineTo(top.dx - 9, top.dy - 16)
      ..lineTo(top.dx + 9, top.dy - 16)
      ..close();
    canvas.drawPath(
      path.shift(const Offset(1, 3)),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
    canvas.drawPath(path, Paint()..color = markerColor);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _ink.withValues(alpha: 0.58),
    );
  }

  void _drawFloatingTexts(Canvas canvas) {
    for (final text in simulation.floatingTexts) {
      final progress = (text.ttl / text.maxTtl).clamp(0.0, 1.0).toDouble();
      final scale = 1 + (1 - progress) * 0.28;
      canvas.save();
      canvas.translate(text.position.dx, text.position.dy);
      canvas.scale(scale);
      if (text.text == 'TAG!') {
        _drawComicBurst(canvas, progress);
      }
      final painter = TextPainter(
        text: TextSpan(
          text: text.text,
          style: TextStyle(
            fontSize: text.text == 'FRENZY!' ? 52 : 34,
            fontWeight: FontWeight.w900,
            color: text.color.withValues(alpha: progress),
            shadows: [
              Shadow(
                color: _ink.withValues(alpha: progress),
                blurRadius: 0,
                offset: const Offset(3, 3),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }
  }

  void _drawSlide(Canvas canvas, Rect rect) {
    _drawSoftShadow(canvas, rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left, rect.top, 58, rect.height),
        const Radius.circular(12),
      ),
      Paint()..color = const Color(0xff327bc3),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left + 44,
          rect.top + 8,
          rect.width - 42,
          rect.height - 14,
        ),
        const Radius.circular(16),
      ),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xffffdc55), Color(0xffffa82e)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 12, rect.top + 10, 38, rect.height - 20),
        const Radius.circular(7),
      ),
      Paint()..color = const Color(0xffef4f43),
    );
    final rail = Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.5);
    canvas.drawLine(
      Offset(rect.left + 61, rect.top + 16),
      Offset(rect.right - 7, rect.top + 22),
      rail,
    );
    canvas.drawLine(
      Offset(rect.left + 61, rect.bottom - 16),
      Offset(rect.right - 7, rect.bottom - 22),
      rail,
    );
  }

  void _drawSideSlide(Canvas canvas, Rect rect, {bool flipped = false}) {
    _drawSoftShadow(canvas, rect);
    final platform = flipped
        ? Rect.fromLTWH(rect.right - 54, rect.top + 10, 54, rect.height - 20)
        : Rect.fromLTWH(rect.left, rect.top + 10, 54, rect.height - 20);
    final chute = flipped
        ? Rect.fromLTWH(
            rect.left,
            rect.top + 20,
            rect.width - 44,
            rect.height - 34,
          )
        : Rect.fromLTWH(
            rect.left + 42,
            rect.top + 20,
            rect.width - 44,
            rect.height - 34,
          );
    canvas.drawRRect(
      RRect.fromRectAndRadius(platform, const Radius.circular(11)),
      Paint()..color = const Color(0xff1d9ec2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(chute, const Radius.circular(16)),
      Paint()
        ..color = flipped ? const Color(0xffef4f43) : const Color(0xffffb735),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(platform.deflate(10), const Radius.circular(8)),
      Paint()
        ..color = flipped ? const Color(0xfff5c747) : const Color(0xffef4f43),
    );
  }

  void _drawMonkeyBars(Canvas canvas, Rect rect) {
    _drawSoftShadow(canvas, rect.inflate(4));
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xff305d9f);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      frame,
    );
    final rail = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xffffd35e);
    for (var x = rect.left + 18; x < rect.right - 8; x += 22) {
      canvas.drawLine(
        Offset(x, rect.top + 8),
        Offset(x, rect.bottom - 8),
        rail,
      );
    }
  }

  void _drawBench(Canvas canvas, Rect rect) {
    _drawSoftShadow(canvas, rect);
    final frame = Paint()..color = const Color(0xff573a2d);
    final slat = Paint()..color = const Color(0xffc8874d);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      frame,
    );
    for (var i = 0; i < 3; i += 1) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left + 9,
            rect.top + 6 + i * 12,
            rect.width - 18,
            7,
          ),
          const Radius.circular(4),
        ),
        slat,
      );
    }
  }

  void _drawHopscotch(Canvas canvas, Rect rect) {
    final chalk = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.66);
    for (var row = 0; row < 4; row += 1) {
      final offset = row.isEven ? 24.0 : 0.0;
      final box = Rect.fromLTWH(
        rect.left + offset,
        rect.top + row * 28,
        44,
        26,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(4)),
        chalk,
      );
      _drawSmallText(
        canvas,
        '${row + 1}',
        box.center.translate(0, -1),
        14,
        Colors.white.withValues(alpha: 0.54),
      );
      if (row.isOdd) {
        final pair = Rect.fromLTWH(rect.left + 54, rect.top + row * 28, 44, 26);
        canvas.drawRRect(
          RRect.fromRectAndRadius(pair, const Radius.circular(4)),
          chalk,
        );
        _drawSmallText(
          canvas,
          '${row + 5}',
          pair.center.translate(0, -1),
          14,
          Colors.white.withValues(alpha: 0.54),
        );
      }
    }
  }

  void _drawConeRow(Canvas canvas, Rect rect) {
    for (var i = 0; i < 6; i += 1) {
      _drawCone(canvas, Offset(rect.left + 28, rect.top + i * 42), 0.82);
    }
  }

  void _drawCone(Canvas canvas, Offset top, double scale) {
    canvas.save();
    canvas.translate(top.dx, top.dy);
    canvas.scale(scale);
    canvas.drawOval(
      const Rect.fromLTWH(-23, 28, 46, 12),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    final cone = Path()
      ..moveTo(0, 0)
      ..lineTo(-20, 34)
      ..lineTo(20, 34)
      ..close();
    canvas.drawPath(cone, Paint()..color = const Color(0xffff762e));
    canvas.drawRect(
      const Rect.fromLTWH(-12, 20, 24, 5),
      Paint()..color = Colors.white.withValues(alpha: 0.78),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-24, 32, 48, 8),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xffc94c20),
    );
    canvas.restore();
  }

  void _drawTireStack(Canvas canvas, Offset center) {
    for (var i = 0; i < 3; i += 1) {
      final c = center.translate(i * 10.0, i * 12.0);
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(3, 4), width: 54, height: 34),
        Paint()..color = Colors.black.withValues(alpha: 0.24),
      );
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 54, height: 34),
        Paint()..color = const Color(0xff25252a),
      );
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 30, height: 17),
        Paint()..color = _asphalt.withValues(alpha: 0.82),
      );
    }
  }

  void _drawBell(Canvas canvas, Offset center) {
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 30), width: 88, height: 28),
      Paint()..color = Colors.black.withValues(alpha: 0.24),
    );
    canvas.drawCircle(
      center.translate(0, 25),
      36,
      Paint()..color = const Color(0xff5d5050),
    );
    canvas.drawCircle(
      center.translate(0, 21),
      28,
      Paint()..color = const Color(0xff786868),
    );
    final bellBody = Path()
      ..moveTo(center.dx - 35, center.dy + 16)
      ..quadraticBezierTo(
        center.dx - 26,
        center.dy - 22,
        center.dx,
        center.dy - 30,
      )
      ..quadraticBezierTo(
        center.dx + 26,
        center.dy - 22,
        center.dx + 35,
        center.dy + 16,
      )
      ..quadraticBezierTo(
        center.dx + 22,
        center.dy + 28,
        center.dx - 22,
        center.dy + 28,
      )
      ..close();
    canvas.drawPath(
      bellBody,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xfffff08d), Color(0xffffc233), Color(0xffbf7f10)],
        ).createShader(Rect.fromCircle(center: center, radius: 44)),
    );
    canvas.drawCircle(
      center.translate(0, -34),
      8,
      Paint()..color = const Color(0xffffe36a),
    );
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 26), width: 70, height: 15),
      Paint()..color = const Color(0xffd59626),
    );
  }

  void _drawComicBurst(Canvas canvas, double alpha) {
    final burst = Path();
    for (var i = 0; i < 18; i += 1) {
      final radius = i.isEven ? 62.0 : 42.0;
      final angle = -math.pi / 2 + i * math.pi * 2 / 18;
      final point = Offset(math.cos(angle), math.sin(angle)) * radius;
      if (i == 0) {
        burst.moveTo(point.dx, point.dy);
      } else {
        burst.lineTo(point.dx, point.dy);
      }
    }
    burst.close();
    canvas.drawPath(
      burst,
      Paint()..color = _red.withValues(alpha: alpha * 0.86),
    );
    canvas.drawPath(
      burst,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white.withValues(alpha: alpha),
    );
  }

  void _drawStarburstChalk(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = _chalk.withValues(alpha: 0.42);
    final path = Path();
    for (var i = 0; i < 24; i += 1) {
      final r = i.isEven ? radius : radius * 0.72;
      final angle = -math.pi / 2 + i * math.pi * 2 / 24;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawFlowerChalk(Canvas canvas, Offset center) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.28);
    for (var i = 0; i < 5; i += 1) {
      final angle = i * math.pi * 2 / 5;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * 21,
        18,
        paint,
      );
    }
    canvas.drawCircle(center, 12, paint);
  }

  void _drawRainbow(Canvas canvas, Offset center) {
    final colors = [
      const Color(0xffff6464),
      const Color(0xffffd64c),
      const Color(0xff57d989),
      const Color(0xff57b6ff),
    ];
    for (var i = 0; i < colors.length; i += 1) {
      canvas.drawArc(
        Rect.fromCenter(
          center: center,
          width: 104 - i * 18,
          height: 78 - i * 14,
        ),
        math.pi,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = colors[i].withValues(alpha: 0.52),
      );
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i += 1) {
      final r = i.isEven ? radius : radius * 0.43;
      final angle = -math.pi / 2 + i * math.pi * 2 / 10;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
    int segments,
  ) {
    for (var i = 0; i < segments; i += 2) {
      final start = i * math.pi * 2 / segments;
      final sweep = math.pi * 2 / segments;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    const dash = 28.0;
    const gap = 16.0;
    for (var x = rect.left; x < rect.right; x += dash + gap) {
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(math.min(x + dash, rect.right), rect.top),
        paint,
      );
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(math.min(x + dash, rect.right), rect.bottom),
        paint,
      );
    }
    for (var y = rect.top; y < rect.bottom; y += dash + gap) {
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.left, math.min(y + dash, rect.bottom)),
        paint,
      );
      canvas.drawLine(
        Offset(rect.right, y),
        Offset(rect.right, math.min(y + dash, rect.bottom)),
        paint,
      );
    }
  }

  double lerpDouble(double a, double b, double t) => a + (b - a) * t;

  void _drawSmallText(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _drawSoftShadow(Canvas canvas, Rect rect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.shift(const Offset(5, 8)),
        const Radius.circular(16),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );
  }

  void _drawWorldVignette(Canvas canvas) {
    final rect = Offset.zero & PlaygroundBlitzSimulation.worldSize;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.22)],
          stops: const [0.68, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant PlaygroundPainter oldDelegate) {
    return true;
  }
}
