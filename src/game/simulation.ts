export type Difficulty = 'chill' | 'balanced' | 'blitz';

export interface GameSettings {
  playerName: string;
  botCount: number;
  roundLength: number;
  difficulty: Difficulty;
}

export interface InputActions {
  moveX: number;
  moveY: number;
  sprint: boolean;
  dash: boolean;
  fakeOut: boolean;
}

export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface Obstacle extends Rect {
  id: string;
  kind: 'slide' | 'bench' | 'fence' | 'chalk' | 'cones';
}

export interface PlayerState {
  id: string;
  name: string;
  x: number;
  y: number;
  vx: number;
  vy: number;
  color: string;
  isHuman: boolean;
  isIt: boolean;
  score: number;
  stamina: number;
  safety: number;
  dashCooldown: number;
  dashTimer: number;
  fakeOutCooldown: number;
  fakeOutTimer: number;
  tags: number;
}

export interface BellZone {
  x: number;
  y: number;
  radius: number;
  active: boolean;
  timeLeft: number;
  nextIn: number;
}

export interface Decoy {
  id: string;
  x: number;
  y: number;
  ttl: number;
  color: string;
  name: string;
}

export interface GameEvent {
  id: number;
  type: 'tag' | 'bell' | 'frenzy' | 'boost';
  x: number;
  y: number;
  text: string;
}

interface MoveIntent {
  x: number;
  y: number;
  sprint: boolean;
}

export interface GameSnapshot {
  players: PlayerState[];
  decoys: Decoy[];
  bellZone: BellZone;
  yard: Rect;
  obstacles: Obstacle[];
  timer: number;
  roundLength: number;
  elapsed: number;
  noTagTimer: number;
  frenzy: boolean;
  catchupBoost: number;
  roundOver: boolean;
  winner: PlayerState;
  human: PlayerState;
  it: PlayerState;
}

const WORLD_WIDTH = 1200;
const WORLD_HEIGHT = 760;
const START_YARD: Rect = { x: 64, y: 64, w: 1072, h: 632 };
const FINAL_YARD: Rect = { x: 188, y: 132, w: 824, h: 496 };
const PLAYER_RADIUS = 18;
const TAG_RADIUS = 42;

export const WORLD = {
  width: WORLD_WIDTH,
  height: WORLD_HEIGHT,
  startYard: START_YARD,
  finalYard: FINAL_YARD,
  playerRadius: PLAYER_RADIUS,
  tagRadius: TAG_RADIUS,
};

export const OBSTACLES: Obstacle[] = [
  { id: 'slide', kind: 'slide', x: 170, y: 145, w: 130, h: 78 },
  { id: 'monkey-bars', kind: 'fence', x: 508, y: 126, w: 156, h: 58 },
  { id: 'bench-left', kind: 'bench', x: 128, y: 500, w: 150, h: 38 },
  { id: 'bench-right', kind: 'bench', x: 887, y: 508, w: 148, h: 38 },
  { id: 'hopscotch', kind: 'chalk', x: 520, y: 500, w: 116, h: 112 },
  { id: 'cone-row', kind: 'cones', x: 780, y: 220, w: 54, h: 236 },
];

const BOT_NAMES = ['Zay', 'Mina', 'Rafi', 'June', 'Niko', 'Paz', 'Lena'];
const COLORS = ['#36d6ff', '#ffcb45', '#8df96f', '#ff7ca8', '#b99cff', '#ff985f', '#5ef0bf', '#7aa8ff'];

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function distance(a: { x: number; y: number }, b: { x: number; y: number }): number {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

function normalize(x: number, y: number): { x: number; y: number; length: number } {
  const length = Math.hypot(x, y);
  if (length < 0.001) {
    return { x: 0, y: 0, length: 0 };
  }
  return { x: x / length, y: y / length, length };
}

function interpolateRect(a: Rect, b: Rect, t: number): Rect {
  return {
    x: a.x + (b.x - a.x) * t,
    y: a.y + (b.y - a.y) * t,
    w: a.w + (b.w - a.w) * t,
    h: a.h + (b.h - a.h) * t,
  };
}

function pointInRect(x: number, y: number, rect: Rect, padding = 0): boolean {
  return x > rect.x - padding && x < rect.x + rect.w + padding && y > rect.y - padding && y < rect.y + rect.h + padding;
}

function resolveRectCollision(player: PlayerState, obstacle: Rect): void {
  if (!pointInRect(player.x, player.y, obstacle, PLAYER_RADIUS)) {
    return;
  }

  const left = Math.abs(player.x - (obstacle.x - PLAYER_RADIUS));
  const right = Math.abs(player.x - (obstacle.x + obstacle.w + PLAYER_RADIUS));
  const top = Math.abs(player.y - (obstacle.y - PLAYER_RADIUS));
  const bottom = Math.abs(player.y - (obstacle.y + obstacle.h + PLAYER_RADIUS));
  const min = Math.min(left, right, top, bottom);

  if (min === left) player.x = obstacle.x - PLAYER_RADIUS;
  if (min === right) player.x = obstacle.x + obstacle.w + PLAYER_RADIUS;
  if (min === top) player.y = obstacle.y - PLAYER_RADIUS;
  if (min === bottom) player.y = obstacle.y + obstacle.h + PLAYER_RADIUS;

  player.vx *= 0.35;
  player.vy *= 0.35;
}

export class PlaygroundBlitzSimulation {
  readonly settings: GameSettings;
  readonly players: PlayerState[];
  readonly obstacles = OBSTACLES;
  readonly decoys: Decoy[] = [];
  readonly bellZone: BellZone = { x: 620, y: 390, radius: 92, active: false, timeLeft: 0, nextIn: 5 };

  timer: number;
  elapsed = 0;
  noTagTimer = 0;
  catchupBoost = 1;
  roundOver = false;

  private eventId = 0;
  private events: GameEvent[] = [];
  private bellCelebrated = false;
  private frenzyCelebrated = false;
  private lastBoostSecond = -1;

  constructor(settings: GameSettings) {
    this.settings = settings;
    this.timer = settings.roundLength;
    this.players = this.createPlayers(settings);
  }

  update(deltaSeconds: number, input: InputActions): void {
    if (this.roundOver) return;

    const dt = Math.min(deltaSeconds, 0.05);
    this.elapsed += dt;
    this.timer = Math.max(0, this.timer - dt);
    this.noTagTimer += dt;
    this.catchupBoost = this.noTagTimer > 10 ? clamp(1 + (this.noTagTimer - 10) * 0.035, 1, this.isFrenzy() ? 1.45 : 1.28) : 1;

    if (this.isFrenzy() && !this.frenzyCelebrated) {
      this.frenzyCelebrated = true;
      this.events.push({ id: this.eventId++, type: 'frenzy', x: WORLD_WIDTH / 2, y: 140, text: 'FRENZY!' });
    }

    this.updateBellZone(dt);
    this.updateDecoys(dt);
    this.updatePlayers(dt, input);
    this.resolveTags();
    this.scoreObjectives(dt);

    if (this.timer <= 0) {
      this.roundOver = true;
    }
  }

  popEvents(): GameEvent[] {
    const next = this.events;
    this.events = [];
    return next;
  }

  getSnapshot(): GameSnapshot {
    const human = this.players.find((player) => player.isHuman) ?? this.players[0];
    const it = this.getIt();
    return {
      players: this.players.map((player) => ({ ...player })),
      decoys: this.decoys.map((decoy) => ({ ...decoy })),
      bellZone: { ...this.bellZone },
      yard: this.getYard(),
      obstacles: this.obstacles,
      timer: this.timer,
      roundLength: this.settings.roundLength,
      elapsed: this.elapsed,
      noTagTimer: this.noTagTimer,
      frenzy: this.isFrenzy(),
      catchupBoost: this.catchupBoost,
      roundOver: this.roundOver,
      winner: { ...this.getWinner() },
      human: { ...human },
      it: { ...it },
    };
  }

  private createPlayers(settings: GameSettings): PlayerState[] {
    const starts = [
      { x: 380, y: 360 },
      { x: 780, y: 360 },
      { x: 310, y: 570 },
      { x: 900, y: 560 },
      { x: 276, y: 268 },
      { x: 920, y: 260 },
      { x: 585, y: 612 },
      { x: 612, y: 210 },
    ];

    const players: PlayerState[] = [
      {
        id: 'human',
        name: settings.playerName.trim() || 'Player',
        x: starts[0].x,
        y: starts[0].y,
        vx: 0,
        vy: 0,
        color: COLORS[0],
        isHuman: true,
        isIt: false,
        score: 0,
        stamina: 100,
        safety: 1.5,
        dashCooldown: 0,
        dashTimer: 0,
        fakeOutCooldown: 0,
        fakeOutTimer: 0,
        tags: 0,
      },
    ];

    for (let i = 0; i < settings.botCount; i += 1) {
      players.push({
        id: `bot-${i}`,
        name: BOT_NAMES[i] ?? `Bot ${i + 1}`,
        x: starts[i + 1].x,
        y: starts[i + 1].y,
        vx: 0,
        vy: 0,
        color: COLORS[i + 1],
        isHuman: false,
        isIt: i === 0,
        score: 0,
        stamina: 82 + Math.random() * 18,
        safety: i === 0 ? 0 : 1.5,
        dashCooldown: 1 + Math.random() * 3,
        dashTimer: 0,
        fakeOutCooldown: 2 + Math.random() * 4,
        fakeOutTimer: 0,
        tags: 0,
      });
    }

    return players;
  }

  private updateBellZone(dt: number): void {
    if (this.bellZone.active) {
      this.bellZone.timeLeft -= dt;
      if (!this.bellCelebrated) {
        this.bellCelebrated = true;
        this.events.push({ id: this.eventId++, type: 'bell', x: this.bellZone.x, y: this.bellZone.y, text: 'BELL ZONE!' });
      }
      if (this.bellZone.timeLeft <= 0) {
        this.bellZone.active = false;
        this.bellZone.nextIn = 12;
        this.bellCelebrated = false;
      }
      return;
    }

    this.bellZone.nextIn -= dt;
    if (this.bellZone.nextIn <= 0) {
      const yard = this.getYard();
      this.bellZone.x = yard.x + 160 + Math.random() * Math.max(120, yard.w - 320);
      this.bellZone.y = yard.y + 130 + Math.random() * Math.max(120, yard.h - 260);
      this.bellZone.active = true;
      this.bellZone.timeLeft = this.settings.difficulty === 'blitz' ? 7 : 8.5;
    }
  }

  private updateDecoys(dt: number): void {
    for (const decoy of this.decoys) {
      decoy.ttl -= dt;
    }

    for (let index = this.decoys.length - 1; index >= 0; index -= 1) {
      if (this.decoys[index].ttl <= 0) {
        this.decoys.splice(index, 1);
      }
    }
  }

  private updatePlayers(dt: number, input: InputActions): void {
    const yard = this.getYard();

    for (const player of this.players) {
      player.safety = Math.max(0, player.safety - dt);
      player.dashCooldown = Math.max(0, player.dashCooldown - dt);
      player.fakeOutCooldown = Math.max(0, player.fakeOutCooldown - dt);
      player.dashTimer = Math.max(0, player.dashTimer - dt);
      player.fakeOutTimer = Math.max(0, player.fakeOutTimer - dt);

      const intent = player.isHuman ? this.getHumanIntent(player, input) : this.getBotIntent(player);
      this.applyMovement(player, intent.x, intent.y, intent.sprint, dt);

      player.x = clamp(player.x, yard.x + PLAYER_RADIUS, yard.x + yard.w - PLAYER_RADIUS);
      player.y = clamp(player.y, yard.y + PLAYER_RADIUS, yard.y + yard.h - PLAYER_RADIUS);

      for (const obstacle of this.obstacles) {
        resolveRectCollision(player, obstacle);
      }
    }
  }

  private getHumanIntent(player: PlayerState, input: InputActions): MoveIntent {
    if (input.dash && player.dashCooldown <= 0 && player.stamina >= 18) {
      player.dashTimer = 0.24;
      player.dashCooldown = 3.8;
      player.stamina -= 18;
    }

    if (input.fakeOut && player.fakeOutCooldown <= 0 && player.stamina >= 14) {
      player.fakeOutTimer = 0.7;
      player.fakeOutCooldown = 5.5;
      player.stamina -= 14;
      this.decoys.push({
        id: `decoy-${this.eventId++}`,
        x: player.x - player.vx * 0.12,
        y: player.y - player.vy * 0.12,
        ttl: 1.1,
        color: player.color,
        name: player.name,
      });
    }

    const intent = normalize(input.moveX, input.moveY);
    return { x: intent.x, y: intent.y, sprint: input.sprint && intent.length > 0.1 && player.stamina > 0 };
  }

  private getBotIntent(player: PlayerState): MoveIntent {
    const it = this.getIt();
    const toIt = { x: it.x - player.x, y: it.y - player.y };
    const itDistance = Math.hypot(toIt.x, toIt.y);

    if (player.isIt) {
      const target = this.pickTagTarget(player);
      const desired = normalize(target.x - player.x, target.y - player.y);
      if (player.dashCooldown <= 0 && distance(player, target) < 150 && player.stamina > 18) {
        player.dashTimer = 0.2;
        player.dashCooldown = 3.5 + Math.random() * 2;
        player.stamina -= 14;
      }
      return { ...desired, sprint: true };
    }

    const wantsBell = this.bellZone.active && distance(player, this.bellZone) > 28 && itDistance > (this.settings.difficulty === 'blitz' ? 185 : 220);
    if (wantsBell) {
      return { ...normalize(this.bellZone.x - player.x, this.bellZone.y - player.y), sprint: false };
    }

    if (itDistance < 250) {
      if (player.fakeOutCooldown <= 0 && itDistance < 120 && player.stamina > 16) {
        player.fakeOutTimer = 0.65;
        player.fakeOutCooldown = 5.8 + Math.random() * 2;
        player.stamina -= 12;
        this.decoys.push({
          id: `decoy-${this.eventId++}`,
          x: player.x,
          y: player.y,
          ttl: 1,
          color: player.color,
          name: player.name,
        });
      }
      return { ...normalize(player.x - it.x, player.y - it.y), sprint: itDistance < 190 };
    }

    const center = { x: WORLD_WIDTH / 2, y: WORLD_HEIGHT / 2 };
    const orbit = normalize(center.y - player.y, -(center.x - player.x));
    const towardCenter = normalize(center.x - player.x, center.y - player.y);
    return { ...normalize(orbit.x * 0.75 + towardCenter.x * 0.25, orbit.y * 0.75 + towardCenter.y * 0.25), sprint: false };
  }

  private applyMovement(player: PlayerState, inputX: number, inputY: number, sprint: boolean, dt: number): void {
    const difficultySpeed = this.settings.difficulty === 'chill' ? 0.94 : this.settings.difficulty === 'blitz' ? 1.08 : 1;
    let speed = (player.isHuman ? 242 : 226) * difficultySpeed;

    if (player.isIt) {
      speed *= this.isFrenzy() ? 1.22 : 1.08;
      speed *= this.catchupBoost;
    }

    if (player.dashTimer > 0) {
      speed *= 2.15;
    }

    if (sprint && player.stamina > 0) {
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

    const hasIntent = Math.hypot(inputX, inputY) > 0.1;
    if (!hasIntent) {
      player.vx *= 0.85;
      player.vy *= 0.85;
      player.stamina = Math.min(100, player.stamina + 17 * dt);
    } else {
      player.vx = inputX * speed;
      player.vy = inputY * speed;
      const drain = player.dashTimer > 0 ? 12 : sprint ? 24 : player.isIt ? 4 : 7;
      player.stamina = Math.max(0, player.stamina - drain * dt);
    }

    if (!player.isHuman || player.stamina < 100) {
      player.stamina = Math.min(100, player.stamina + (player.isIt ? 13 : 10) * dt);
    }

    player.x += player.vx * dt;
    player.y += player.vy * dt;
  }

  private resolveTags(): void {
    const it = this.getIt();
    for (const target of this.players) {
      if (target.id === it.id || target.safety > 0 || it.safety > 0 || target.fakeOutTimer > 0) {
        continue;
      }

      if (distance(it, target) <= TAG_RADIUS) {
        const multiplier = this.isFrenzy() ? 2 : 1;
        it.score += 100 * multiplier;
        it.tags += 1;
        target.score = Math.max(0, target.score - 20);
        it.isIt = false;
        target.isIt = true;
        it.safety = 1;
        target.safety = 1.15;
        it.stamina = Math.min(100, it.stamina + 22);
        target.stamina = Math.min(100, target.stamina + 16);
        this.noTagTimer = 0;
        this.catchupBoost = 1;
        this.events.push({ id: this.eventId++, type: 'tag', x: target.x, y: target.y, text: 'TAG!' });
        break;
      }
    }

    const boostSecond = Math.floor(this.noTagTimer);
    if (this.noTagTimer > 10 && boostSecond % 6 === 0 && boostSecond !== this.lastBoostSecond) {
      const boostEventExists = this.events.some((event) => event.type === 'boost');
      if (!boostEventExists) {
        this.lastBoostSecond = boostSecond;
        this.events.push({ id: this.eventId++, type: 'boost', x: it.x, y: it.y - 42, text: 'CATCH-UP' });
      }
    }
  }

  private scoreObjectives(dt: number): void {
    for (const player of this.players) {
      if (!player.isIt) {
        player.score += dt * 1.4;
      }

      if (this.bellZone.active && distance(player, this.bellZone) <= this.bellZone.radius) {
        player.score += dt * (player.isIt ? 8 : 13);
      }
    }
  }

  private pickTagTarget(player: PlayerState): { x: number; y: number } {
    if (this.decoys.length > 0 && Math.random() < 0.24) {
      return this.decoys[Math.floor(Math.random() * this.decoys.length)];
    }

    let best = this.players.find((candidate) => !candidate.isIt) ?? this.players[0];
    let bestScore = Number.POSITIVE_INFINITY;

    for (const candidate of this.players) {
      if (candidate.id === player.id || candidate.isIt) continue;
      const distanceScore = distance(player, candidate);
      const bellRisk = this.bellZone.active ? distance(candidate, this.bellZone) * 0.18 : 0;
      const score = distanceScore + bellRisk - candidate.score * 0.03;
      if (score < bestScore) {
        best = candidate;
        bestScore = score;
      }
    }

    return best;
  }

  private getIt(): PlayerState {
    return this.players.find((player) => player.isIt) ?? this.players[0];
  }

  private getWinner(): PlayerState {
    return [...this.players].sort((a, b) => b.score - a.score)[0];
  }

  private getYard(): Rect {
    const shrinkStart = 15;
    const shrinkDuration = Math.max(18, this.settings.roundLength - 32);
    const progress = clamp((this.elapsed - shrinkStart) / shrinkDuration, 0, 1);
    return interpolateRect(START_YARD, FINAL_YARD, progress);
  }

  private isFrenzy(): boolean {
    return this.timer <= 15;
  }
}
