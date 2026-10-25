# Formas e Estratégias de Testar no Godot 4

Este documento reúne os métodos, frameworks e comandos para execução de testes no Godot.

---

## 1. Verificação Estática e Checagem de Erros (Headless)

Antes de rodar testes unitários, você pode verificar sintaxe e compilação de scripts via CLI em modo headless:

```bash
# Checar integridade do projeto sem abrir interface gráfica
/Arquivos/Salvar_Dados/Godot_v4.7.2-stable_linux.x86_64 --headless --path /home/aluno/project-trace --check-only
```

Executar um script de teste rápido ou runner customizado diretamente pelo terminal:
```bash
/Arquivos/Salvar_Dados/Godot_v4.7.2-stable_linux.x86_64 --headless --path /home/aluno/project-trace -s res://path/to/test_script.gd
```

---

## 2. Frameworks de Teste Recomendados

### Opção A: GUT (Godot Unit Test) - Padrão Comunitário
O GUT é o framework de testes unitários e de integração mais popular do ecossistema Godot.

1. **Instalação via AssetLib / Addon**:
   * Baixar o plugin GUT na pasta `res://addons/gut/`.
   * Ativar o plugin em `Project Settings -> Plugins`.

2. **Estrutura de Teste GUT (`res://tests/test_player.gd`)**:
   ```gdscript
   extends GutTest

   var player_scene = preload("res://scenes/level_debug.tscn")
   var player = null

   func before_each():
       player = player_scene.instantiate()
       add_child_autofree(player)

   func test_initial_position():
       assert_not_null(player, "O jogador deve ser instanciado")
       assert_eq(player.position.x, 200.0, "Posição inicial esperada em X")

   func test_damage_reduces_health():
       # Exemplo de teste com componentes
       if player.has_node("HealthComponent"):
           var health_comp = player.get_node("HealthComponent")
           health_comp.damage(10)
           assert_eq(health_comp.current_health, 90)
   ```

3. **Execução Headless do GUT (via Terminal / CI)**:
   ```bash
   /Arquivos/Salvar_Dados/Godot_v4.7.2-stable_linux.x86_64 --headless --path /home/aluno/project-trace -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
   ```

---

### Opção B: GdUnit4 - Focado em TDD Avançado e Mocking
GdUnit4 oferece suporte nativo a asserções fluentes, simulação de sinais, testes assíncronos e testes de cena complexos.

1. **Instalação**: Addon `gdUnit4` em `res://addons/gdUnit4/`.
2. **Execução via CLI**:
   ```bash
   /Arquivos/Salvar_Dados/Godot_v4.7.2-stable_linux.x86_64 --headless --path /home/aluno/project-trace -s res://addons/gdUnit4/runtest.gd --test-dir=res://tests
   ```

---

## 3. Tipos de Teste no Godot

1. **Testes Unitários Puros**:
   * Testam lógica matemática, algoritmos, cálculos de dano, inventário e recursos (`Resource`).
   * Não precisam instanciar árvores de cena pesadas.
2. **Testes de Integração de Nós**:
   * Instanciam nós (`.instantiate()`) e testam sinais emitidos e interação física rápida (`await get_tree().physics_frame`).
3. **Smoke Tests / Validação de Cenas**:
   * Carregam as cenas principais (`scenes/*.tscn`) para garantir que nenhuma dependência está ausente ou quebrada:
   ```gdscript
   extends SceneTree

   func _init():
       var scene = load("res://scenes/level_debug.tscn")
       assert(scene != null, "Falha ao carregar level_debug.tscn")
       print("Cena carregada com sucesso!")
       quit(0)
   ```
