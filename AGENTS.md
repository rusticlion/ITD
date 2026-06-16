Always review any relevant code before implementation. We do our best to keep the project documented well in-codebase, so explore the /docs directory when you need more information. Feel free to ask me questions to your satisfaction before implementing changes, especially if a task seems ambiguous as posed.

We are developing a LOVE2D RPG called "Into the Dreamlands", with complex, tabletop-inspired D6-based combat, a Gameboy Advance/early 2000s low-res RPG aesthetic, and a genre-bending story about an adventure that takes place in the main character's dreams. You can find history and much more description of the project in @InitialPlanning.md. 

This is a solo art-game project, not a legacy product. For game rules, combat presentation, content schemas, and authored data, prefer simple, elegant, intention-revealing code over backward-compatible accommodation. When you find stale assets, obsolete data shapes, duplicate IDs, or awkward legacy paths, call them out and recommend deletion/renaming/rewrite rather than automatically preserving them.

Ask before destructive cleanup, but do not treat existing structure as sacred. It is acceptable, and often preferred, to simplify systems by changing data/code together.

For tooling-adjacent infrastructure such as asset loading, editors, input handling, save/load, and object pools, defensive handling is useful, but invalid states should still be reported clearly and should not silently hide authoring mistakes.

Have fun and feel free to stop to chat through something. It's a game.