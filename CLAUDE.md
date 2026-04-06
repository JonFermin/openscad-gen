# scad-forge

- When the user asks to model or design a physical object, use the /scad-forge skill
- Always save .scad output to ./output/ with a descriptive filename
- After generating the .scad, also generate a scene manifest JSON at ./output/<name>_manifest.json for the Three.js previewer
- Run the previewer with: cd previewer && npm run dev
