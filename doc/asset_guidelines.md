# Asset Guidelines

## Placeholder Art Structure

Temporary placeholder textures are stored under `res://art/placeholders`. Use the following naming conventions when adding or replacing art so exported resources can reference them consistently:

### Forge Assets

- Blueprint icons: `res://art/placeholders/forge/blueprint_<blueprint_id>.png`
  - Example: `res://art/placeholders/forge/blueprint_sword_basic.png`
  - Provide `blueprint_default.png` when a generic fallback is required.
- Material icons: `res://art/placeholders/forge/material_<material_id>.png`
  - Provide `material_default.png` as a safe fallback.
- Trial backgrounds: `res://art/placeholders/forge/background_<variant>.png`
  - Use `background_default.png` until bespoke art is available.

### Dungeon Assets

- Trial backgrounds: `res://art/placeholders/dungeon/background_<variant>.png`
  - Use `background_default.png` for the standard dungeon encounter backdrop.

When replacing placeholders with final art, keep the file names intact or update the relevant resources (`BlueprintResource.icon`, `TrialResource.background`) so scenes keep loading the correct textures.
