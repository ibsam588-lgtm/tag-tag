import Phaser from 'phaser';
import {
  type GameSettings,
  type GameSnapshot,
  type InputActions,
  type PlayerState,
  PlaygroundBlitzSimulation,
  WORLD,
} from './simulation';

interface PlayerView {
  container: Phaser.GameObjects.Container;
  aura: Phaser.GameObjects.Arc;
  body: Phaser.GameObjects.Arc;
  face: Phaser.GameObjects.Arc;
  label: Phaser.GameObjects.Text;
  arrow: Phaser.GameObjects.Triangle;
}

interface DecoyView {
  container: Phaser.GameObjects.Container;
  ttl: number;
}

type CursorKeys = Record<'up' | 'down' | 'left' | 'right' | 'w' | 'a' | 's' | 'd' | 'shift' | 'space' | 'f', Phaser.Input.Keyboard.Key>;

const UI_EVENT = 'tagtag:update';
const COMPLETE_EVENT = 'tagtag:complete';

export class PlaygroundBlitzScene extends Phaser.Scene {
  private readonly settings: GameSettings;
  private simulation!: PlaygroundBlitzSimulation;
  private players = new Map<string, PlayerView>();
  private decoys = new Map<string, DecoyView>();
  private staticLayer!: Phaser.GameObjects.Graphics;
  private yardLayer!: Phaser.GameObjects.Graphics;
  private bellLayer!: Phaser.GameObjects.Graphics;
  private tagRing!: Phaser.GameObjects.Arc;
  private cursors!: CursorKeys;
  private lastHudUpdate = 0;
  private completed = false;

  constructor(settings: GameSettings) {
    super('PlaygroundBlitzScene');
    this.settings = settings;
  }

  create(): void {
    this.simulation = new PlaygroundBlitzSimulation(this.settings);
    this.cameras.main.setBackgroundColor('#52cfe4');
    this.cameras.main.setBounds(0, 0, WORLD.width, WORLD.height);

    this.staticLayer = this.add.graphics();
    this.yardLayer = this.add.graphics();
    this.bellLayer = this.add.graphics();
    this.drawPlayground();

    this.tagRing = this.add.circle(0, 0, WORLD.tagRadius, 0xff395b, 0.12).setStrokeStyle(3, 0xff395b, 0.72);
    this.tagRing.setDepth(15);

    for (const player of this.simulation.players) {
      this.players.set(player.id, this.createPlayerView(player));
    }

    this.cursors = this.input.keyboard!.addKeys({
      up: Phaser.Input.Keyboard.KeyCodes.UP,
      down: Phaser.Input.Keyboard.KeyCodes.DOWN,
      left: Phaser.Input.Keyboard.KeyCodes.LEFT,
      right: Phaser.Input.Keyboard.KeyCodes.RIGHT,
      w: Phaser.Input.Keyboard.KeyCodes.W,
      a: Phaser.Input.Keyboard.KeyCodes.A,
      s: Phaser.Input.Keyboard.KeyCodes.S,
      d: Phaser.Input.Keyboard.KeyCodes.D,
      shift: Phaser.Input.Keyboard.KeyCodes.SHIFT,
      space: Phaser.Input.Keyboard.KeyCodes.SPACE,
      f: Phaser.Input.Keyboard.KeyCodes.F,
    }) as CursorKeys;

    this.input.keyboard?.on('keydown-SPACE', (event: KeyboardEvent) => event.preventDefault());
    this.dispatchSnapshot();
  }

  update(_time: number, deltaMs: number): void {
    const actions = this.readActions();
    this.simulation.update(deltaMs / 1000, actions);

    const snapshot = this.simulation.getSnapshot();
    this.drawDynamicLayers(snapshot);
    this.syncPlayers(snapshot);
    this.syncDecoys(snapshot);
    this.playEvents();

    if (_time - this.lastHudUpdate > 80 || snapshot.roundOver) {
      this.lastHudUpdate = _time;
      this.dispatchSnapshot(snapshot);
    }

    if (snapshot.roundOver && !this.completed) {
      this.completed = true;
      window.dispatchEvent(new CustomEvent(COMPLETE_EVENT, { detail: snapshot }));
    }
  }

  private readActions(): InputActions {
    const keyboardX = Number(this.cursors.right.isDown || this.cursors.d.isDown) - Number(this.cursors.left.isDown || this.cursors.a.isDown);
    const keyboardY = Number(this.cursors.down.isDown || this.cursors.s.isDown) - Number(this.cursors.up.isDown || this.cursors.w.isDown);
    const virtual = window.tagTagInput ?? { moveX: 0, moveY: 0, dash: false, fakeOut: false };
    const move = new Phaser.Math.Vector2(keyboardX + virtual.moveX, keyboardY + virtual.moveY);

    if (move.length() > 1) {
      move.normalize();
    }

    const dash = Phaser.Input.Keyboard.JustDown(this.cursors.space) || virtual.dash;
    const fakeOut = Phaser.Input.Keyboard.JustDown(this.cursors.f) || virtual.fakeOut;

    if (window.tagTagInput) {
      window.tagTagInput.dash = false;
      window.tagTagInput.fakeOut = false;
    }

    return {
      moveX: move.x,
      moveY: move.y,
      sprint: this.cursors.shift.isDown,
      dash,
      fakeOut,
    };
  }

  private drawPlayground(): void {
    const g = this.staticLayer;
    g.clear();

    g.fillStyle(0x32b866, 1);
    g.fillRect(0, 0, WORLD.width, WORLD.height);

    g.fillStyle(0x4fd4e6, 1);
    g.fillRoundedRect(64, 64, 1072, 632, 24);
    g.lineStyle(8, 0xffffff, 0.7);
    g.strokeRoundedRect(78, 78, 1044, 604, 18);

    g.lineStyle(4, 0xf9f1ca, 0.7);
    g.strokeCircle(600, 380, 118);
    g.strokeLineShape(new Phaser.Geom.Line(600, 82, 600, 678));
    g.strokeLineShape(new Phaser.Geom.Line(82, 380, 1118, 380));

    this.drawSlide(g, 170, 145);
    this.drawMonkeyBars(g, 508, 126);
    this.drawBench(g, 128, 500);
    this.drawBench(g, 887, 508);
    this.drawHopscotch(g, 520, 500);
    this.drawConeRow(g, 780, 220);
    this.drawChalkMarks(g);
  }

  private drawDynamicLayers(snapshot: GameSnapshot): void {
    this.drawYard(snapshot);
    this.drawBell(snapshot);

    this.tagRing.setVisible(true);
    this.tagRing.setPosition(snapshot.it.x, snapshot.it.y);
    this.tagRing.setRadius(WORLD.tagRadius + Math.sin(this.time.now / 120) * 3);
  }

  private drawYard(snapshot: GameSnapshot): void {
    const yard = snapshot.yard;
    const g = this.yardLayer;
    g.clear();
    g.setDepth(4);

    const shrinkAlpha = Phaser.Math.Clamp(snapshot.elapsed / snapshot.roundLength, 0.06, 0.42);
    g.fillStyle(0xff315d, shrinkAlpha);
    g.fillRect(0, 0, WORLD.width, yard.y);
    g.fillRect(0, yard.y + yard.h, WORLD.width, WORLD.height - yard.y - yard.h);
    g.fillRect(0, yard.y, yard.x, yard.h);
    g.fillRect(yard.x + yard.w, yard.y, WORLD.width - yard.x - yard.w, yard.h);

    g.lineStyle(snapshot.frenzy ? 7 : 5, snapshot.frenzy ? 0xffe45b : 0xffffff, snapshot.frenzy ? 0.95 : 0.75);
    g.strokeRoundedRect(yard.x, yard.y, yard.w, yard.h, 18);

    g.lineStyle(2, 0x273248, 0.16);
    for (let i = 0; i < 8; i += 1) {
      g.strokeCircle(yard.x + 18 + i * 36, yard.y + yard.h + 18, 9);
      g.strokeCircle(yard.x + yard.w - 18 - i * 36, yard.y - 18, 9);
    }
  }

  private drawBell(snapshot: GameSnapshot): void {
    const bell = snapshot.bellZone;
    const g = this.bellLayer;
    g.clear();
    g.setDepth(6);

    if (!bell.active) return;

    const pulse = 0.5 + Math.sin(this.time.now / 140) * 0.12;
    g.fillStyle(0xffdf54, 0.2 + pulse * 0.16);
    g.fillCircle(bell.x, bell.y, bell.radius);
    g.lineStyle(5, 0xffdf54, 0.95);
    g.strokeCircle(bell.x, bell.y, bell.radius + Math.sin(this.time.now / 90) * 5);
    g.lineStyle(2, 0xffffff, 0.7);
    g.strokeCircle(bell.x, bell.y, bell.radius * 0.55);
  }

  private syncPlayers(snapshot: GameSnapshot): void {
    for (const player of snapshot.players) {
      let view = this.players.get(player.id);
      if (!view) {
        view = this.createPlayerView(player);
        this.players.set(player.id, view);
      }

      view.container.setPosition(player.x, player.y);
      view.container.setDepth(player.isIt ? 30 : 20);
      view.aura.setVisible(player.isIt || player.safety > 0 || player.fakeOutTimer > 0);
      view.aura.setFillStyle(player.isIt ? 0xff315d : player.fakeOutTimer > 0 ? 0xffffff : 0x65f5ff, player.isIt ? 0.28 : 0.18);
      view.aura.setStrokeStyle(player.isIt ? 4 : 2, player.isIt ? 0xff315d : 0xffffff, player.isIt ? 0.8 : 0.38);
      view.aura.setScale(player.isIt ? 1.3 + Math.sin(this.time.now / 90) * 0.08 : 1.04);
      view.body.setFillStyle(Phaser.Display.Color.HexStringToColor(player.color).color, player.stamina < 14 ? 0.68 : 1);
      view.body.setStrokeStyle(player.isHuman ? 4 : 2, player.isHuman ? 0xffffff : 0x263044, player.isHuman ? 0.9 : 0.45);
      view.face.setFillStyle(player.isIt ? 0xfff3b0 : 0x263044, 1);
      view.arrow.setVisible(player.isIt);
      view.label.setText(player.name);
    }
  }

  private syncDecoys(snapshot: GameSnapshot): void {
    const activeIds = new Set(snapshot.decoys.map((decoy) => decoy.id));

    for (const [id, view] of this.decoys) {
      if (!activeIds.has(id)) {
        view.container.destroy(true);
        this.decoys.delete(id);
      }
    }

    for (const decoy of snapshot.decoys) {
      let view = this.decoys.get(decoy.id);
      if (!view) {
        const color = Phaser.Display.Color.HexStringToColor(decoy.color).color;
        const body = this.add.circle(0, 0, 18, color, 0.28).setStrokeStyle(2, 0xffffff, 0.4);
        const label = this.add.text(0, 28, decoy.name, {
          fontFamily: 'Arial, sans-serif',
          fontSize: '13px',
          fontStyle: '700',
          color: '#ffffff',
          stroke: '#263044',
          strokeThickness: 3,
        }).setOrigin(0.5);
        const container = this.add.container(decoy.x, decoy.y, [body, label]).setDepth(18);
        view = { container, ttl: decoy.ttl };
        this.decoys.set(decoy.id, view);
      }

      view.ttl = decoy.ttl;
      view.container.setPosition(decoy.x, decoy.y);
      view.container.setAlpha(Phaser.Math.Clamp(decoy.ttl, 0, 1) * 0.62);
      view.container.setScale(1 + (1 - Phaser.Math.Clamp(decoy.ttl, 0, 1)) * 0.2);
    }
  }

  private playEvents(): void {
    for (const event of this.simulation.popEvents()) {
      const color = event.type === 'tag' ? '#fff4a8' : event.type === 'frenzy' ? '#ff315d' : '#ffffff';
      const text = this.add.text(event.x, event.y - 18, event.text, {
        fontFamily: 'Arial Black, Arial, sans-serif',
        fontSize: event.type === 'frenzy' ? '54px' : '34px',
        color,
        stroke: '#263044',
        strokeThickness: 7,
      }).setOrigin(0.5).setDepth(100);

      this.tweens.add({
        targets: text,
        y: text.y - 56,
        scale: event.type === 'tag' ? 1.35 : 1.12,
        alpha: 0,
        duration: event.type === 'tag' ? 720 : 950,
        ease: 'Back.easeOut',
        onComplete: () => text.destroy(),
      });

      if (event.type === 'tag') {
        this.cameras.main.shake(120, 0.004);
      }
    }
  }

  private createPlayerView(player: PlayerState): PlayerView {
    const color = Phaser.Display.Color.HexStringToColor(player.color).color;
    const aura = this.add.circle(0, 0, 25, 0xff315d, 0.24);
    const body = this.add.circle(0, 0, 18, color, 1).setStrokeStyle(2, 0x263044, 0.45);
    const face = this.add.circle(6, -5, 4, 0x263044, 1);
    const arrow = this.add.triangle(0, -32, 0, 0, 11, 16, -11, 16, 0xff315d, 1).setStrokeStyle(2, 0xffffff, 0.8);
    const label = this.add.text(0, 28, player.name, {
      fontFamily: 'Arial, sans-serif',
      fontSize: '13px',
      fontStyle: '700',
      color: '#ffffff',
      stroke: '#263044',
      strokeThickness: 3,
    }).setOrigin(0.5);

    const container = this.add.container(player.x, player.y, [aura, body, face, arrow, label]).setDepth(player.isIt ? 30 : 20);
    return { container, aura, body, face, arrow, label };
  }

  private dispatchSnapshot(snapshot = this.simulation.getSnapshot()): void {
    window.dispatchEvent(new CustomEvent(UI_EVENT, { detail: snapshot }));
  }

  private drawSlide(g: Phaser.GameObjects.Graphics, x: number, y: number): void {
    g.fillStyle(0xffc743, 1);
    g.fillRoundedRect(x, y, 130, 78, 14);
    g.fillStyle(0xff6c54, 1);
    g.fillRoundedRect(x + 18, y + 14, 46, 52, 12);
    g.lineStyle(6, 0xffffff, 0.55);
    g.strokeLineShape(new Phaser.Geom.Line(x + 78, y + 18, x + 116, y + 62));
  }

  private drawMonkeyBars(g: Phaser.GameObjects.Graphics, x: number, y: number): void {
    g.lineStyle(8, 0x6e6a95, 1);
    g.strokeRoundedRect(x, y, 156, 58, 12);
    g.lineStyle(4, 0xfff4a8, 0.9);
    for (let i = 18; i < 148; i += 22) {
      g.strokeLineShape(new Phaser.Geom.Line(x + i, y + 7, x + i, y + 51));
    }
  }

  private drawBench(g: Phaser.GameObjects.Graphics, x: number, y: number): void {
    g.fillStyle(0x7a5245, 1);
    g.fillRoundedRect(x, y, 150, 38, 8);
    g.fillStyle(0xffd58b, 1);
    g.fillRoundedRect(x + 8, y + 7, 134, 8, 5);
    g.fillRoundedRect(x + 8, y + 23, 134, 8, 5);
  }

  private drawHopscotch(g: Phaser.GameObjects.Graphics, x: number, y: number): void {
    g.lineStyle(3, 0xffffff, 0.8);
    for (let row = 0; row < 4; row += 1) {
      const offset = row % 2 === 0 ? 24 : 0;
      g.strokeRoundedRect(x + offset, y + row * 28, 44, 26, 4);
      if (row % 2 === 1) {
        g.strokeRoundedRect(x + 54, y + row * 28, 44, 26, 4);
      }
    }
  }

  private drawConeRow(g: Phaser.GameObjects.Graphics, x: number, y: number): void {
    for (let i = 0; i < 6; i += 1) {
      const coneY = y + i * 42;
      g.fillStyle(0xff7a3d, 1);
      g.fillTriangle(x + 28, coneY, x + 6, coneY + 34, x + 50, coneY + 34);
      g.fillStyle(0xffffff, 0.75);
      g.fillRect(x + 17, coneY + 20, 22, 5);
    }
  }

  private drawChalkMarks(g: Phaser.GameObjects.Graphics): void {
    g.lineStyle(3, 0xffffff, 0.38);
    g.strokeCircle(340, 252, 38);
    g.strokeCircle(376, 252, 38);
    g.strokeCircle(358, 292, 38);
    g.strokeRoundedRect(842, 118, 124, 66, 12);
    g.strokeRoundedRect(286, 610, 118, 44, 12);
  }
}

declare global {
  interface Window {
    tagTagInput?: {
      moveX: number;
      moveY: number;
      dash: boolean;
      fakeOut: boolean;
    };
  }
}
