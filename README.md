# Tag Tag: Playground Blitz

Top-down browser prototype for a playground tag game where the rules force action instead of letting runners kite forever.

## Game Rules

- One player is **It**.
- Tagging another player gives points and transfers **It**.
- Sprinting and dashing drain stamina, so nonstop running becomes slower.
- Bell Zone events award points only to players who risk entering the highlighted zone.
- The yard shrinks during the round to push everyone closer.
- If no tag happens for too long, **It** gets a catch-up boost.
- The last 15 seconds become Frenzy Mode with faster tags and score multipliers.

## Local Development

```bash
npm install
npm run dev
```

## Build

```bash
npm run build
```

## Deploy

This repo includes a GitHub Pages workflow in `.github/workflows/deploy.yml`. Pushing to `main` builds the app and deploys the `dist` folder through GitHub Pages.
