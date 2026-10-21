# Guia: Como Usar a Godot em MCP e Integrar Skills do skills.sh

Este documento detalha o funcionamento do **Model Context Protocol (MCP)** com a Godot Engine e como gerenciar skills do **skills.sh**.

---

## 1. O que é Godot MCP?

O **MCP (Model Context Protocol)** permite que o agente de IA (como o Antigravity) interaja diretamente com a Godot Engine em execução, em vez de apenas ler e editar arquivos estáticos.

### O que o agente pode fazer via MCP:
* **Inspeção de Cenas em Tempo Real**: Ler a árvore de nós de uma cena aberta (`SceneTree`), tipos de nós e propriedades.
* **Manipulação de Nós e Propriedades**: Adicionar, mover, duplicar ou deletar nós; conectar sinais e alterar valores de propriedades.
* **Execução e Playtest**: Iniciar a execução do projeto ou de uma cena específica e capturar saídas de console e stack traces de erro diretamente na conversa.
* **Recursos e Física**: Consultar CollisionShapes, Raycasts, TileMaps e shaders diretamente.

---

## 2. Arquitetura da Conexão MCP com a Godot

O fluxo de comunicação funciona em 3 camadas:

```text
[ Antigravity Agent ]
         │ (Comunicação Stdio)
         ▼
[ MCP Server (Node.js / npx godot-mcp) ]
         │ (WebSocket / TCP local - ex: porta 9090)
         ▼
[ Godot Editor Plugin (res://addons/godot_mcp) ]
         │
[ Godot Engine / Projeto Ativo ]
```

---

## 3. Configuração do MCP no Projeto

O Antigravity permite configurar servidores MCP diretamente no projeto através do arquivo:
`res://.agents/mcp_config.json`

### Exemplo de Configuração (`.agents/mcp_config.json`):
```json
{
  "mcpServers": {
    "godot": {
      "command": "npx",
      "args": ["-y", "godot-mcp"],
      "env": {
        "GODOT_PATH": "/Arquivos/Salvar_Dados/Godot_v4.7.2-stable_linux.x86_64",
        "GODOT_PROJECT_PATH": "/home/aluno/project-trace",
        "GODOT_PORT": "9090"
      }
    }
  }
}
```

### Passos para Ativar:
1. Instalar o plugin correspondente na pasta `res://addons/` (ex: `addons/godot_mcp`).
2. Abrir o Godot Editor e habilitar o plugin em:
   * **Project -> Project Settings -> Plugins -> Enable**.
3. O plugin abre um socket WebSocket local (por padrão em `ws://127.0.0.1:9090`).
4. Quando o Antigravity inicia a conexão MCP, o servidor conecta ao editor aberto e disponibiliza ferramentas automáticas para o agente.

---

## 4. Skills do skills.sh para Godot

O **skills.sh** é o ecossistema aberto de habilidades para agentes de IA. Neste projeto, as skills são salvas em:
`res://.agents/skills/`

### Skills Já Instaladas no Projeto:
* **`godot-testing`**: Padrões de teste com GUT e GdUnit4, TDD, mocks e execução headless.
* **`gdscript-patterns`**: Melhores práticas de GDScript, tipagem forte, lambdas, corrotinas `await`, annotations (`@export`, `@onready`).
* **`scene-organization`**: Arquitetura de nós, padrões de composição vs herança e acoplamento fraco.
* **`godot-debugging`**: Estratégias de depuração, breakpoints remotos, rastreamento de sinais e stack traces.

### Como Gerenciar Skills via Terminal:
Para buscar ou instalar novas skills do `skills.sh`, utilize o CLI:

```bash
# 1. Buscar skills disponíveis para Godot
npx -y skills find godot

# 2. Listar todas as skills em um repositório
npx -y skills add jame581/godotprompter --list

# 3. Instalar uma nova skill no projeto
npx -y skills add jame581/godotprompter --skill player-controller -y

# 4. Listar as skills instaladas no projeto atual
npx -y skills list
```
As novas skills são adicionadas diretamente na pasta `.agents/skills/` do projeto e ficam automaticamente disponíveis para o Antigravity.
