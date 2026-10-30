# Regras do Projeto (AGENTS.md)

Consulte também [GEMINI.md](project-trace/GEMINI.md) para as regras principais deste workspace.
Leia [JOGO.md](project-trace/JOGO.md) para entender o jogo e a historia.

# Godot Project Guidelines

- Use Godot 4.x and GDScript unless explicitly requested otherwise.
- Follow Godot's node-based scene architecture.
- Prefer small, reusable scripts and scenes.
- Use typed GDScript where it improves clarity.
- Never invent node paths; inspect the existing scenes first.
- Preserve existing project settings and input actions.
- Do not overwrite assets or scenes without checking their current contents.
- After making changes, run Godot validation when possible.
- Fix parser errors and runtime errors before declaring a task complete.
- Explain which files changed and how to test the result.
- Keep gameplay logic separate from UI and presentation.
