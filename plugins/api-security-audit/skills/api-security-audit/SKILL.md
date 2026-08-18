---
name: api-security-audit
description: Audita a postura de segurança de uma API backend contra o checklist derivado do OWASP API Security Top 10 2023 e do OWASP Top 10 2025. Varre o repositório inteiro (não o diff), separa o que é verificável estaticamente do que exige teste em runtime, e produz relatório com achados por severidade. Usar antes de pentest, antes de expor endpoint novo à internet, ou como auditoria periódica.
---

# api-security-audit

Auditoria de postura de segurança de API. Agnóstica de linguagem e framework.

## Quando usar

- Antes de uma janela de pentest contratada
- Antes de expor um serviço novo à internet
- Auditoria periódica, uma vez por trimestre
- Quando o time herda uma base de código sem histórico de revisão de segurança

## Quando **não** usar

- Revisão de mudança pontual → usar `/security-review` ou a skill de revisão do
  próprio projeto, que olham o diff. Esta varre o repositório inteiro e é cara.
- Análise de dependência isolada → rodar a auditoria do gerenciador de pacotes direto.

---

## Regra de ouro

> **Item da classe `RUNTIME` nunca é marcado como conforme por leitura de código.**

Ler o código diz que existe um mecanismo. Não diz que o mecanismo funciona, nem que
cobre todos os caminhos. BOLA, enumeração de usuário, limite de requisição e SSRF só
são verificados com requisição real e dois usuários.

O modo de falha desta skill é gerar confiança falsa: varrer, não achar nada, e reportar
"tudo certo" em item que exige teste dinâmico. Isso é pior que não auditar — o time entra
no pentest achando que está coberto.

Toda conclusão é uma de três: `CONFORME`, `ACHADO` ou `NÃO VERIFICADO`.
Não existe quarta opção, e `NÃO VERIFICADO` nunca vira `CONFORME` por falta de evidência
contrária.

---

## Procedimento

### 1. Delimitar o alvo

Pergunte ao usuário, se não estiver claro:
- Qual diretório é a API? (repositório único, ou um serviço dentro de um monorepo)
- O escopo é o repositório inteiro ou um subconjunto de módulos?

### 2. Varredura estática determinística

```bash
bash "${CLAUDE_PLUGIN_ROOT}"/skills/api-security-audit/scripts/scan.sh <diretorio-da-api>
```

Fora de um plugin, o script fica ao lado deste arquivo, em `scripts/scan.sh`.

Produz candidatos por identificador de item, mais o inventário de stack, arquivo de
trava de dependências e pipeline. **Nada ali é achado ainda.**

Se o resultado vier com muito ruído estrutural específico do projeto, ajustar a função
`denoise()` do script — o filtro é editável de propósito.

### 3. Confirmação em paralelo

Distribuir os blocos entre subagentes. Um agente por grupo, executados em paralelo
numa única mensagem:

| Grupo | Blocos | Foco |
|---|---|---|
| `autorizacao` | 1, 3, 4 | BOLA, propriedade do objeto, função |
| `autenticacao` | 2 | Credencial, token, sessão, revogação |
| `entrada` | 7, 8 | Injeção, upload, travessia, SSRF |
| `config` | 10, 11 | Configuração, transporte, segredo, inventário |
| `operacao` | 5, 6, 9, 12, 13 | Recursos, fluxo de negócio, terceiros, registro, pipeline |

Cada subagente recebe:
- os itens do seu grupo, de `references/checklist.md`
- os padrões correspondentes, de `references/patterns.md`
- a saída bruta do passo 2 filtrada para os identificadores dele
- o caminho da API

E devolve **apenas** achados confirmados, no formato abaixo. Subagente que não
confirma nada devolve lista vazia — nunca preenche com suposição.

O bloco 14 é integralmente `MANUAL`: não gera subagente, vira pergunta ao usuário
no relatório final.

### 4. Consolidação

Na thread principal:
- Remover duplicata: mesmo arquivo, mesma linha, itens diferentes viram um achado
  com os dois identificadores.
- Ordenar por severidade, depois por bloco.
- Contrastar com a lista de itens: todo item sem achado e sem confirmação explícita
  entra como `NÃO VERIFICADO`, com o motivo.

### 5. Relatório

Formato em **Formato de saída**, abaixo. Oferecer ao usuário, ao final:
- gerar o roteiro de runtime preenchido com as rotas reais do projeto
  (`references/runtime-tests.md` com os endereços substituídos)
- abrir issues para os achados `P0`

---

## Formato de achado

Todo achado confirmado por subagente segue exatamente esta estrutura:

```
[P0] BOLA.1 · apps/pedidos/services.py:88
Consulta busca o pedido só por identificador, sem filtrar pelo dono.
Alcançável por: GET /api/pedidos/{id}/ e PATCH /api/pedidos/{id}/
Correção: adicionar filtro por dono no mesmo escopo da consulta.
```

Quatro campos obrigatórios: severidade e identificador, local, o que está errado,
por onde é alcançável a partir de entrada externa.

**Sem `arquivo:linha` não é achado.** Sem caminho alcançável a partir de entrada
externa, também não — é observação, e vai para uma seção separada do relatório.

Severidade herda a do bloco em `references/checklist.md`, com dois ajustes:
- sobe um nível se o caminho é alcançável sem autenticação
- desce um nível se depende de outra falha para ser explorado

---

## Formato de saída

```markdown
# Auditoria de segurança — <alvo> — <data>

## Resumo
<N> achados: <n> P0, <n> P1, <n> P2.
<N> itens não verificáveis estaticamente — roteiro de runtime na seção final.

## Achados

### P0 — bloqueia release
<achados no formato acima>

### P1 — corrigir no ciclo
### P2 — melhoria contínua

## Observações
Padrões arriscados sem caminho externo confirmado. Não são achados; são dívida.

## Não verificado
| Item | Classe | Por quê | Como resolver |
|---|---|---|---|
| BOLA.7 | RUNTIME | Exige dois usuários e ambiente no ar | Roteiro § BOLA |
| CONF.9 | MANUAL | Só o time sabe se a chave foi rotacionada | Perguntar ao responsável |

## Perguntas ao time
<os itens MANUAL que precisam de resposta humana>
```

---

## O que esta skill não faz

- **Não corrige nada.** Auditoria é leitura. Correção é outra conversa, item a item,
  com o usuário decidindo o que entra no ciclo.
- **Não executa teste dinâmico** por conta própria. Gera o roteiro; a execução exige
  ambiente, credenciais e autorização explícita — e nunca contra produção sem janela
  combinada por escrito.
- **Não cobre rede, WAF, infraestrutura nem provedor gerenciado.** Escopo é o que o
  time de backend controla: código, configuração e pipeline.
- **Não substitui pentest.** Cobre a preparação. Um testador humano encontra o que
  nenhum padrão de busca prevê.

## Arquivos

| Arquivo | Conteúdo |
|---|---|
| `references/checklist.md` | Itens com identificador, classe de verificabilidade e severidade |
| `references/patterns.md` | Padrões de busca agnósticos, por item, com seção de ruído conhecido |
| `references/runtime-tests.md` | Roteiro dos itens que exigem API no ar e dois usuários |
| `references/checklist-prosa.md` | Versão em prosa, para humano ler e para colar em revisão |
| `scripts/scan.sh` | Varredura estática determinística, somente leitura |

Versão navegável do checklist, com marcação de progresso:
https://claude.ai/code/artifact/3f6ddb1d-5d21-4d9f-b2b9-fec4b51299ce
