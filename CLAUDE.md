# cadsmith

- When the user asks to model or design a physical object, use the /make-model skill (CadQuery/build123d)
- Always save output to ./output/ with a descriptive filename
- After generating the model, also generate a scene manifest JSON at ./output/<name>_manifest.json for the Three.js previewer
- Run the previewer with: cd previewer && npm run dev
- After generating files, the skill captures a screenshot of the preview using Playwright and self-evaluates before presenting to the user
- Screenshots are saved to ./output/<name>_preview.png
- To review and fix an existing model, use the /edit-model skill — it runs the reviewer/fixer agent loop on both the source file and manifest
- To export a model, use the /export-model skill or run directly: `./pipeline/scad-to-godot.sh output/<name>.stl -f glb`
- Pipeline accepts .stl, .step, or .py input and supports stl, obj, glb, gltf output formats
- Use `-d 0.5` to decimate mesh, `-u` for UV maps, `-b` to force Blender processing
