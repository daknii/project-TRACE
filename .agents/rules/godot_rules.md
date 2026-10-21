# Regras e Diretrizes para Godot 4 (Project TRACE)

Este documento estabelece as regras e padrões arquiteturais para desenvolvimento neste projeto Godot.

---

## 1. Ambiente e Execução
* **Versão do Godot**: Godot 4.7.x (Linux x86_64)
* **Caminho do Binário Local**:
  ```bash
  /Arquivos/Salvar_Dados/Godot_v4.7.2-stable_linux.x86_64
  ```
* **Caminho do Projeto**: `/home/aluno/project-trace` (`res://`)

---

## 2. Estrutura de Diretórios
* `res://scenes/`: Cenas do jogo (`.tscn`), organizadas por contexto (ex: `scenes/levels/`, `scenes/ui/`, `scenes/characters/`).
* `res://scripts/`: Scripts controladores (`.gd`), espelhando as responsabilidades das cenas.
* `res://components/`: Componentes reutilizáveis desacoplados (ex: `HealthComponent.gd`, `HitboxComponent.gd`, `MovementComponent.gd`).
* `res://assets/`: Texturas, áudios, fontes, shaders e modelos.
* `res://tests/`: Testes automatizados (GUT / GdUnit4).

---

## 3. Padrões de GDScript (Strict & Clean)
1. **Tipagem Estática Obrigatória**:
   Sempre use tipagem estática em variáveis, argumentos e retornos:
   ```gdscript
   var speed: float = 200.0
   var velocity: Vector2 = Vector2.ZERO

   func apply_damage(amount: int) -> void:
       current_health -= amount
   ```

2. **Nomenclatura**:
   * **Classes e Nós**: `PascalCase` (ex: `PlayerController`, `HealthComponent`).
   * **Funções e Variáveis**: `snake_case` (ex: `move_and_slide()`, `current_speed`).
   * **Constantes e Enums**: `SCREAMING_SNAKE_CASE` (ex: `MAX_SPEED`, `State.IDLE`).
   * **Sinais**: `snake_case` no passado ou indicando evento ocorrido (ex: `health_changed(new_health: int)`, `died`).
   * **Arquivos de Script**: `PascalCase.gd` para classes nomeadas ou `snake_case.gd` para utilitários.

3. **Ordem de Elementos no Script**:
   1. `class_name` e `extends`
   2. `@tool` (se aplicável)
   3. Sinais (`signal`)
   4. Enums e Constantes
   5. Variáveis `@export`
   6. Variáveis públicas
   7. Variáveis privadas (`_var_name`)
   8. Variáveis `@onready`
   9. Métodos de ciclo de vida (`_init()`, `_ready()`, `_process()`, `_physics_process()`)
   10. Métodos públicos
   11. Métodos privados (`_method_name`)

---

## 4. Arquitetura de Nós e Comunicação
* **Regra de Ouro**: *"Signal Up, Call Down"*:
  * Nós-pais chamam funções diretamente em seus nós-filhos (`$ChildNode.do_something()`).
  * Nós-filhos **NUNCA** devem chamar diretamente nós-pais via caminhos relativos rígidos (como `get_parent().get_parent()`). Em vez disso, os filhos emitem sinais (`emit_signal()` ou `signal_name.emit()`).
* **Event Bus (Autoload)**:
  * Para nós que estão distantes na árvore de cenas e precisam se comunicar sem acoplamento direto, utilize um singleton / Autoload de eventos centralizado.
* **Component-Based Design**:
  * Priorize composição sobre herança. Adicione componentes sob a pasta `res://components/` para funcionalidades como vida, dano, interação e física.
* **Destruição Segura**:
  * Sempre use `node.queue_free()`, nunca `node.free()`, para garantir que o nó seja removido no final do frame sem causar crashes de ponteiro nulo.
