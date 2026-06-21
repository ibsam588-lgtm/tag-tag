import Phaser from 'phaser';
import './styles.css';
import { PlaygroundBlitzScene } from './game/PlaygroundBlitzScene';
import type { Difficulty, GameSettings, GameSnapshot } from './game/simulation';
import { WORLD } from './game/simulation';

const setupForm = document.querySelector<HTMLFormElement>('#setup-form');
const feedbackForm = document.querySelector<HTMLFormElement>('#feedback-form');
const menuScreen = document.querySelector<HTMLElement>('#menu-screen');
const hud = document.querySelector<HTMLElement>('#hud');
const resultsModal = document.querySelector<HTMLElement>('#results-modal');
const winnerText = document.querySelector<HTMLElement>('#winner-text');
const resultsText = document.querySelector<HTMLElement>('#results-text');
const playAgainButton = document.querySelector<HTMLButtonElement>('#play-again-button');
const botCountInput = document.querySelector<HTMLInputElement>('#bot-count');
const botCountValue = document.querySelector<HTMLElement>('#bot-count-value');
const ideaStatus = document.querySelector<HTMLElement>('#idea-status');
const joystick = document.querySelector<HTMLElement>('#joystick');
const joystickStick = document.querySelector<HTMLElement>('#joystick-stick');
const dashButton = document.querySelector<HTMLButtonElement>('#dash-button');
const fakeButton = document.querySelector<HTMLButtonElement>('#fake-button');

const timerText = document.querySelector<HTMLElement>('#timer-text');
const itText = document.querySelector<HTMLElement>('#it-text');
const scoreText = document.querySelector<HTMLElement>('#score-text');
const staminaValue = document.querySelector<HTMLElement>('#stamina-value');
const staminaFill = document.querySelector<HTMLElement>('#stamina-fill');
const objectiveText = document.querySelector<HTMLElement>('#objective-text');
const yardText = document.querySelector<HTMLElement>('#yard-text');
const dashCooldown = document.querySelector<HTMLElement>('#dash-cooldown');
const fakeCooldown = document.querySelector<HTMLElement>('#fake-cooldown');

let game: Phaser.Game | null = null;

window.tagTagInput = {
  moveX: 0,
  moveY: 0,
  dash: false,
  fakeOut: false,
};

function requireElement<T>(element: T | null, name: string): T {
  if (!element) {
    throw new Error(`Missing element: ${name}`);
  }
  return element;
}

const elements = {
  setupForm: requireElement(setupForm, 'setup-form'),
  feedbackForm: requireElement(feedbackForm, 'feedback-form'),
  menuScreen: requireElement(menuScreen, 'menu-screen'),
  hud: requireElement(hud, 'hud'),
  resultsModal: requireElement(resultsModal, 'results-modal'),
  winnerText: requireElement(winnerText, 'winner-text'),
  resultsText: requireElement(resultsText, 'results-text'),
  playAgainButton: requireElement(playAgainButton, 'play-again-button'),
  botCountInput: requireElement(botCountInput, 'bot-count'),
  botCountValue: requireElement(botCountValue, 'bot-count-value'),
  ideaStatus: requireElement(ideaStatus, 'idea-status'),
  joystick: requireElement(joystick, 'joystick'),
  joystickStick: requireElement(joystickStick, 'joystick-stick'),
  dashButton: requireElement(dashButton, 'dash-button'),
  fakeButton: requireElement(fakeButton, 'fake-button'),
  timerText: requireElement(timerText, 'timer-text'),
  itText: requireElement(itText, 'it-text'),
  scoreText: requireElement(scoreText, 'score-text'),
  staminaValue: requireElement(staminaValue, 'stamina-value'),
  staminaFill: requireElement(staminaFill, 'stamina-fill'),
  objectiveText: requireElement(objectiveText, 'objective-text'),
  yardText: requireElement(yardText, 'yard-text'),
  dashCooldown: requireElement(dashCooldown, 'dash-cooldown'),
  fakeCooldown: requireElement(fakeCooldown, 'fake-cooldown'),
};

elements.botCountInput.addEventListener('input', () => {
  elements.botCountValue.textContent = `${elements.botCountInput.value} bots`;
});

elements.setupForm.addEventListener('submit', (event) => {
  event.preventDefault();
  const formData = new FormData(elements.setupForm);
  const difficulty = String(formData.get('difficulty') ?? 'balanced') as Difficulty;
  const settings: GameSettings = {
    playerName: String(formData.get('playerName') ?? 'Player').trim().slice(0, 16) || 'Player',
    botCount: Number(formData.get('botCount') ?? 5),
    roundLength: Number(formData.get('roundLength') ?? 90),
    difficulty,
  };

  startGame(settings);
});

elements.feedbackForm.addEventListener('submit', (event) => {
  event.preventDefault();
  const ideaInput = document.querySelector<HTMLTextAreaElement>('#idea-text');
  const idea = ideaInput?.value.trim();
  if (!idea) {
    elements.ideaStatus.textContent = 'Add an idea first.';
    return;
  }

  const saved = JSON.parse(localStorage.getItem('tagtag:ideas') ?? '[]') as string[];
  saved.unshift(idea);
  localStorage.setItem('tagtag:ideas', JSON.stringify(saved.slice(0, 8)));
  elements.ideaStatus.textContent = `Saved ${saved.length > 1 ? 'another idea' : 'your first idea'}.`;
  if (ideaInput) ideaInput.value = '';
});

elements.playAgainButton.addEventListener('click', () => {
  elements.resultsModal.classList.add('hidden');
  elements.menuScreen.classList.remove('menu-hidden');
  elements.hud.classList.add('hud-hidden');
});

elements.dashButton.addEventListener('pointerdown', () => {
  if (window.tagTagInput) window.tagTagInput.dash = true;
});

elements.fakeButton.addEventListener('pointerdown', () => {
  if (window.tagTagInput) window.tagTagInput.fakeOut = true;
});

setupJoystick();

window.addEventListener('tagtag:update', (event) => {
  const snapshot = (event as CustomEvent<GameSnapshot>).detail;
  updateHud(snapshot);
});

window.addEventListener('tagtag:complete', (event) => {
  const snapshot = (event as CustomEvent<GameSnapshot>).detail;
  showResults(snapshot);
});

function startGame(settings: GameSettings): void {
  game?.destroy(true);
  elements.menuScreen.classList.add('menu-hidden');
  elements.resultsModal.classList.add('hidden');
  elements.hud.classList.remove('hud-hidden');

  game = new Phaser.Game({
    type: Phaser.AUTO,
    parent: 'game-root',
    width: WORLD.width,
    height: WORLD.height,
    backgroundColor: '#52cfe4',
    scale: {
      mode: Phaser.Scale.FIT,
      autoCenter: Phaser.Scale.CENTER_BOTH,
      width: WORLD.width,
      height: WORLD.height,
    },
    render: {
      antialias: true,
      pixelArt: false,
    },
    scene: [new PlaygroundBlitzScene(settings)],
  });
}

function updateHud(snapshot: GameSnapshot): void {
  const human = snapshot.human;
  const seconds = Math.ceil(snapshot.timer);
  elements.timerText.textContent = `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
  elements.itText.textContent = snapshot.it.isHuman ? 'You' : snapshot.it.name;
  elements.scoreText.textContent = Math.round(human.score).toLocaleString();
  elements.staminaValue.textContent = String(Math.round(human.stamina));
  elements.staminaFill.style.width = `${Math.round(human.stamina)}%`;
  elements.staminaFill.dataset.state = human.stamina < 18 ? 'low' : human.stamina < 42 ? 'mid' : 'full';

  if (snapshot.frenzy) {
    elements.objectiveText.textContent = `Frenzy ${Math.ceil(snapshot.timer)}s`;
    elements.objectiveText.dataset.state = 'frenzy';
  } else if (snapshot.bellZone.active) {
    elements.objectiveText.textContent = `Bell Zone ${Math.ceil(snapshot.bellZone.timeLeft)}s`;
    elements.objectiveText.dataset.state = 'bell';
  } else {
    elements.objectiveText.textContent = `Bell Zone in ${Math.ceil(snapshot.bellZone.nextIn)}s`;
    elements.objectiveText.dataset.state = 'calm';
  }

  const shrinkPercent = Math.round(Math.max(0, Math.min(1, (snapshot.elapsed - 15) / Math.max(18, snapshot.roundLength - 32))) * 100);
  elements.yardText.textContent = snapshot.frenzy ? 'Final Yard' : shrinkPercent > 0 ? `Yard Closing ${shrinkPercent}%` : 'Yard Open';
  elements.yardText.dataset.state = snapshot.frenzy ? 'frenzy' : shrinkPercent > 45 ? 'warning' : 'calm';
  elements.dashCooldown.textContent = human.dashCooldown <= 0 ? 'Ready' : `${human.dashCooldown.toFixed(1)}s`;
  elements.fakeCooldown.textContent = human.fakeOutCooldown <= 0 ? 'Ready' : `${human.fakeOutCooldown.toFixed(1)}s`;
  elements.dashButton.disabled = human.dashCooldown > 0 || human.stamina < 18;
  elements.fakeButton.disabled = human.fakeOutCooldown > 0 || human.stamina < 14;
}

function showResults(snapshot: GameSnapshot): void {
  const winner = snapshot.winner;
  const human = snapshot.human;
  elements.winnerText.textContent = winner.isHuman ? 'You won the yard' : `${winner.name} won the yard`;
  elements.resultsText.textContent = `You scored ${Math.round(human.score).toLocaleString()} with ${human.tags} tag${human.tags === 1 ? '' : 's'}. ${winner.name} led with ${Math.round(winner.score).toLocaleString()} points.`;
  elements.resultsModal.classList.remove('hidden');
}

function setupJoystick(): void {
  let activePointerId: number | null = null;
  const maxDistance = 44;

  elements.joystick.addEventListener('pointerdown', (event) => {
    activePointerId = event.pointerId;
    elements.joystick.setPointerCapture(event.pointerId);
    updateStick(event);
  });

  elements.joystick.addEventListener('pointermove', (event) => {
    if (activePointerId !== event.pointerId) return;
    updateStick(event);
  });

  const release = (event: PointerEvent) => {
    if (activePointerId !== event.pointerId) return;
    activePointerId = null;
    if (window.tagTagInput) {
      window.tagTagInput.moveX = 0;
      window.tagTagInput.moveY = 0;
    }
    elements.joystickStick.style.transform = 'translate(-50%, -50%)';
  };

  elements.joystick.addEventListener('pointerup', release);
  elements.joystick.addEventListener('pointercancel', release);

  function updateStick(event: PointerEvent): void {
    const rect = elements.joystick.getBoundingClientRect();
    const centerX = rect.left + rect.width / 2;
    const centerY = rect.top + rect.height / 2;
    const rawX = event.clientX - centerX;
    const rawY = event.clientY - centerY;
    const length = Math.hypot(rawX, rawY);
    const scale = length > maxDistance ? maxDistance / length : 1;
    const x = rawX * scale;
    const y = rawY * scale;

    elements.joystickStick.style.transform = `translate(calc(-50% + ${x}px), calc(-50% + ${y}px))`;

    if (window.tagTagInput) {
      window.tagTagInput.moveX = x / maxDistance;
      window.tagTagInput.moveY = y / maxDistance;
    }
  }
}
