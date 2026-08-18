# Roteiro dos itens RUNTIME

Itens que **nenhuma leitura de código resolve**. Exigem a API no ar e duas contas
de usuário comum, chamadas aqui de **A** e **B**, criadas no mesmo papel — o mesmo
insumo que um pentest de API pede.

O agente não executa nada disto sozinho. Ele **gera o roteiro preenchido** com as
rotas reais do projeto e entrega para execução humana ou para um passo explícito
de execução autorizado pelo usuário.

## Regras de execução

Só rodar contra ambiente de desenvolvimento ou homologação, com dado sintético.
Contra produção, só com autorização escrita e janela combinada. Nenhum teste desta
lista é destrutivo por natureza, mas vários escrevem dado.

Preparação:
1. Base do ambiente: `BASE`
2. Token de A: `TOKEN_A` · Token de B: `TOKEN_B`
3. Um recurso de cada tipo pertencente a A, com o ID anotado

---

## § BOLA — BOLA.7 · `P0`

Para cada recurso identificável por ID, executar com o token de **B** contra um ID de **A**:

| Passo | Chamada | Esperado |
|---|---|---|
| Leitura | `GET {BASE}/{recurso}/{id_de_A}` | `403` ou `404` |
| Alteração | `PATCH {BASE}/{recurso}/{id_de_A}` com corpo válido | `403` ou `404` |
| Substituição | `PUT {BASE}/{recurso}/{id_de_A}` | `403` ou `404` |
| Remoção | `DELETE {BASE}/{recurso}/{id_de_A}` | `403` ou `404` |
| Listagem | `GET {BASE}/{recurso}` como B | Nenhum item de A no corpo |
| Aninhado | `GET {BASE}/{pai}/{id_de_A}/{filho}` | `403` ou `404` |
| Ação | `POST {BASE}/{recurso}/{id_de_A}/{ação}` | `403` ou `404` |

`200` em qualquer linha é achado `P0`. `500` também conta: indica que a checagem
não existe e a falha veio de outro lugar.

Variantes que costumam escapar: recurso alcançado por rota de exportação,
de relatório, de anexo e de comentário.

## § FUNC — FUNC.7 · `P0`

1. Extrair a lista completa de rotas do projeto.
2. Classificar quais são administrativas.
3. Chamar cada uma com `TOKEN_A` (usuário comum), variando o método.

Esperado: `403` em todas. `200`, `201` ou `500` é achado `P0`.

Repetir sem token nenhum: esperado `401` em toda rota não pública.

## § AUTH — AUTH.8 e AUTH.9 · `P0`

**Enumeração de usuário (AUTH.8)**
Comparar corpo, código e **tempo** de resposta entre:
- login com usuário inexistente e senha qualquer
- login com usuário existente e senha errada

Diferença consistente em qualquer um dos três é achado.
Repetir no fluxo de cadastro e no de recuperação de senha.

**Ciclo de vida do token (AUTH.9)**
| Passo | Esperado |
|---|---|
| Token com carga alterada, assinatura original | `401` |
| Token com algoritmo trocado para nenhum | `401` |
| Token com algoritmo assimétrico trocado por simétrico, assinado com a chave pública | `401` |
| Token expirado | `401` |
| Token de acesso após logout | `401` |
| Refresh reutilizado depois de rotacionado | `401` |
| Token após troca de senha | `401` |

**Força bruta**
Trinta tentativas de login erradas seguidas devem produzir bloqueio ou atraso
crescente. Repetir variando a origem para checar se o limite é só por origem.

## § RES — RES.7 · `P1`

| Teste | Esperado |
|---|---|
| 200 requisições em laço no endpoint mais caro | `429` antes de degradar |
| Corpo acima do limite declarado | Rejeição sem consumir memória proporcional |
| `?limit=100000` na listagem maior | Teto aplicado, não a base inteira |
| Upload acima do limite | Rejeição antes de gravar |

Medir o tempo de resposta do endpoint durante a carga: degradação sem `429`
é achado.

## § FLOW — FLOW.5 · `P1`

Para cada fluxo crítico identificado (voto, cupom, reserva, compra, convite):

Disparar 20 requisições **em paralelo** com o mesmo conteúdo e o mesmo token.
Esperado: um efeito no banco. N efeitos é achado `P1` — condição de corrida.

Repetir com o mesmo teste depois de um envio duplo com atraso de milissegundos,
que é o caso real de duplo clique.

## § SSRF — SSRF.6 · `P1`

Em todo campo que aceite URL — webhook, importação, avatar por link, integração:

| Carga | Esperado |
|---|---|
| `http://169.254.169.254/latest/meta-data/` | Recusa |
| `http://metadata.google.internal/` | Recusa |
| `http://127.0.0.1:8000/` e `http://localhost:8000/admin` | Recusa |
| `http://[::1]:8000/` | Recusa |
| `http://10.0.0.1/` e demais faixas internas | Recusa |
| Domínio externo que responde com redirecionamento para `127.0.0.1` | Recusa |
| `file:///etc/passwd` e `gopher://` | Recusa por esquema |

Observar também o **tempo** de resposta: diferença entre destino que existe e
destino que não existe entrega varredura de porta interna mesmo com a resposta
bloqueada.

## § INJ — INJ.11 · `P0`

Em cada parâmetro de entrada, incluindo cabeçalhos e campos de filtro:

| Carga | Sinal de achado |
|---|---|
| `'` e `"` | Erro de banco na resposta |
| `" OR 1=1--` em campo de filtro | Volume de resultado diferente do esperado |
| `1' AND SLEEP(3)--` | Resposta demora três segundos a mais |
| `../../etc/passwd` em campo de caminho ou nome de arquivo | Conteúdo de fora do diretório base |
| `{{7*7}}` e `${7*7}` | `49` na resposta |
| `;id` e `\|id` em campo usado por comando | Saída de comando na resposta |
| XML com `DOCTYPE` e entidade externa | Conteúdo de arquivo local ou requisição de saída |
| `=1+1` em campo exportado para planilha | Fórmula ativa no arquivo gerado |

## Como reportar

Cada linha executada vira uma das três conclusões:

- `CONFORME` — executado, resultado esperado. Registrar a chamada e o código de resposta.
- `ACHADO` — executado, resultado divergente. Registrar chamada, resposta e severidade.
- `NÃO EXECUTADO` — falta insumo (ambiente, segundo usuário, autorização).
  **Nunca** converter em conforme.
