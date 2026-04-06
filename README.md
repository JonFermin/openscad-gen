# cadsmith

A Claude Code skill suite that generates parametric 3D models (build123d/CadQuery) and interactive Three.js previews from natural language descriptions of physical objects. Describe what you want to make, and cadsmith produces a print-ready model alongside a browser-based 3D preview you can orbit and inspect.

## Install

```bash
git clone git@github.com:JonFermin/cadsmith.git
cd cadsmith
```

The skills auto-load when Claude Code runs from this directory.

## Usage

From Claude Code:

```
/make-model a phone stand
/make-model design a bracket for my shelf
/make-model create a cable organizer with 6 slots
/edit-model street_intersection
/export-model bracket -f glb
```

Or just describe what you want in natural language — the CLAUDE.md hints Claude to use the skill when you mention modeling or designing physical objects.

## Skills

| Skill | Purpose |
|-------|---------|
| `/make-model` | Generate parametric build123d Python models + Three.js preview manifests |
| `/edit-model` | Review and fix existing models via reviewer/fixer agent team |
| `/export-model` | Export models to STL, OBJ, glTF, or GLB via Blender pipeline |

## Previewer

The repo includes a standalone Three.js previewer for inspecting generated models:

```bash
cd previewer
npm install
npm run dev
```

This opens a browser at http://localhost:3000. Load a `_manifest.json` file via the file picker, drag & drop, or URL parameter.

## How it works

1. You describe a physical object
2. cadsmith asks brief clarifying questions (1 round max, defaults aggressively)
3. Generates a parametric `.py` file (build123d) in `./output/` with `.step` and `.stl` exports
4. Generates a `_manifest.json` scene description for the previewer
5. Runs a reviewer/fixer agent loop to catch and correct issues
6. Opens the Three.js preview in your browser

The `.py` file is the source of truth. The Three.js preview is a fast visual approximation — difference() operations show as transparent red wireframes since true CSG isn't available in the browser.

## Project structure

```
cadsmith/
├── .claude/
│   ├── skills/
│   │   ├── make-model/           # Model generation skill
│   │   ├── edit-model/           # Review & fix skill
│   │   └── export-model/         # Export pipeline skill
│   └── agents/
│       ├── review-model.md       # Visual review agent
│       └── fix-model.md          # Targeted fix agent
├── previewer/                    # Three.js preview app (Vite)
├── pipeline/                     # Export pipeline (Blender)
├── output/                       # Generated models and manifests (gitignored)
├── CLAUDE.md                     # Project-level Claude instructions
└── README.md
```

## License

MIT
