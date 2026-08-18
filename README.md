# claude-plugins

Marketplace interno de plugins para o Claude Code.

Repositório privado: quem tem acesso a ele instala os plugins; quem não tem, não.
É esse o controle de acesso — não existe restrição por domínio de e-mail no Claude Code.

## Instalação

Dentro do Claude Code, uma vez por máquina:

```
/plugin marketplace add ManeMaria/claude-plugins
```

Depois, instale o que quiser:

```
/plugin install api-security-audit@claude-plugins
```

Se a instalação pedir, rode `/reload-plugins` para ativar.

Para receber atualizações:

```
/plugin marketplace update claude-plugins
```

## Plugins

### `api-security-audit`

Auditoria de postura de segurança de APIs backend, agnóstica de linguagem e framework.
Baseada no OWASP API Security Top 10 (2023) e no OWASP Top 10 (2025).

```
/api-security-audit:api-security-audit
```

O que faz:

1. Roda uma varredura estática determinística sobre o repositório e levanta candidatos.
2. Distribui os blocos do checklist entre subagentes em paralelo, que confirmam ou
   descartam cada candidato lendo o código.
3. Consolida em relatório com achados por severidade, cada um com `arquivo:linha` e o
   caminho pelo qual é alcançável a partir de entrada externa.
4. Gera o roteiro dos testes que **não** dão para verificar lendo código.

O ponto que diferencia esta auditoria: cada um dos ~90 itens é classificado em `AUTO`,
`MANUAL` ou `RUNTIME`. Item `RUNTIME` — BOLA, enumeração de usuário, limite de requisição,
SSRF, condição de corrida — nunca é marcado como conforme por análise estática. Ele vira
roteiro de teste com dois usuários e a API no ar.

Sem essa separação, uma auditoria automatizada varre, não acha nada e reporta "tudo certo"
em item que exige teste dinâmico. Isso é pior do que não auditar: o time entra no pentest
achando que está coberto.

**Quando usar:** antes de uma janela de pentest, antes de expor serviço novo à internet,
ou como auditoria trimestral.

**Quando não usar:** para revisar um diff. Aí é `/security-review`. Esta skill varre o
repositório inteiro e é cara.

**Escopo:** o que o time de backend controla — código, configuração e pipeline.
Rede, WAF gerenciado e infraestrutura de terceiros ficam de fora.

Checklist navegável, com marcação de progresso:
https://claude.ai/code/artifact/3f6ddb1d-5d21-4d9f-b2b9-fec4b51299ce

## Como adicionar um plugin novo

1. Crie `plugins/<nome>/.claude-plugin/plugin.json` com pelo menos o campo `name`.
2. Coloque as skills em `plugins/<nome>/skills/<skill>/SKILL.md`.
3. Adicione a entrada em `.claude-plugin/marketplace.json`.
4. Suba `version` no `plugin.json` a cada release — sem isso ninguém recebe a atualização.

Referência: https://code.claude.com/docs/en/plugin-marketplaces
