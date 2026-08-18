# Checklist de auditoria — itens verificáveis

Tabela de trabalho dos subagentes. Versão em prosa, para humano: `checklist-prosa.md`,
nesta mesma pasta.

## Classes de verificabilidade

| Classe | Significa | O agente pode concluir sozinho? |
|---|---|---|
| `AUTO` | Decidível lendo código/config | **Sim** — com `arquivo:linha` como prova |
| `MANUAL` | Exige conhecimento de processo, contrato ou infra fora do repositório | **Não** — pergunta ao humano |
| `RUNTIME` | Exige requisição real, dois usuários ou carga | **Não** — vira roteiro em `runtime-tests.md` |

Regra dura: item `RUNTIME` **nunca** é marcado como conforme por leitura de código.
O máximo que a análise estática entrega é "existe um mecanismo plausível" — o que é
hipótese, não verificação.

---

## Bloco 1 — BOLA · autorização de objeto (API1:2023) · P0

| ID | Classe | Regra | Onde procurar |
|---|---|---|---|
| BOLA.1 | `AUTO` | Consulta por ID vindo do cliente filtra também por dono/tenant | Camada de dados: busca por ID sem cláusula de dono no mesmo escopo |
| BOLA.2 | `AUTO` | Checagem de dono na camada de serviço/dados, não só no controller | Serviço que recebe ID e não recebe identidade do chamador |
| BOLA.3 | `AUTO` | Dono nunca vem de parâmetro do cliente | Leitura de `owner_id`/`user_id`/`tenant_id` a partir de corpo ou query |
| BOLA.4 | `MANUAL` | ID sequencial exposto foi avaliado quanto a sensibilidade | Tipo da chave primária dos modelos expostos |
| BOLA.5 | `AUTO` | Rotas de escrita têm a mesma checagem das de leitura | Comparar escopo de consulta entre métodos do mesmo recurso |
| BOLA.6 | `AUTO` | Listagem devolve só o escopo do usuário | Listagem sem filtro por identidade |
| BOLA.7 | `RUNTIME` | Usuário B não alcança recurso de A em nenhum método | `runtime-tests.md` § BOLA |

## Bloco 2 — Autenticação (API2:2023) · P0

| ID | Classe | Regra | Onde procurar |
|---|---|---|---|
| AUTH.1 | `AUTO` | Sem credencial padrão ou fixa no código, em nenhum ambiente | Literais de senha/chave em config e seed |
| AUTH.2 | `AUTO` | Hash de senha lento e com salt | Uso de MD5/SHA-1/SHA-256 puro para senha |
| AUTH.3 | `AUTO` | Segredo de assinatura vem de ambiente/cofre, distinto por ambiente | Segredo literal em config |
| AUTH.4 | `AUTO` | Token valida assinatura, expiração, emissor, audiência e algoritmo | Decodificação sem verificação; `alg` aceito do próprio token |
| AUTH.5 | `AUTO` | Tempo de vida do token de acesso é curto | Configuração de expiração |
| AUTH.6 | `AUTO` | Revogação existe: logout/troca de senha invalida token ativo | Lista de bloqueio, rotação de refresh, versão de sessão |
| AUTH.7 | `AUTO` | Rate limit em login, refresh, recuperação e código de uso único | Política de limite nas rotas de autenticação |
| AUTH.8 | `RUNTIME` | Sem enumeração de usuário — mensagem e tempo iguais | `runtime-tests.md` § AUTH |
| AUTH.9 | `RUNTIME` | Token adulterado, expirado e pós-logout são rejeitados | `runtime-tests.md` § AUTH |
| AUTH.10 | `MANUAL` | Segundo fator disponível para papéis administrativos | Política da organização |

## Bloco 3 — Propriedade do objeto (API3:2023) · P0

| ID | Classe | Regra | Onde procurar |
|---|---|---|---|
| PROP.1 | `AUTO` | Entrada usa lista fechada de campos graváveis | Vínculo direto do corpo na entidade; campo curinga no serializador |
| PROP.2 | `AUTO` | Campo sensível ignorado quando vem do cliente | `role`, `is_admin`, `status`, `owner`, `price`, `balance` graváveis |
| PROP.3 | `AUTO` | Saída passa por serializador/DTO explícito | Retorno do registro cru |
| PROP.4 | `AUTO` | Resposta não carrega hash, token, segredo ou dado pessoal excedente | Campos sensíveis na representação de saída |
| PROP.5 | `AUTO` | Erro não devolve rastro de pilha, SQL nem caminho de arquivo | Manipulador de exceção que serializa a exceção |

## Bloco 4 — Autorização de função (API5:2023) · P0

| ID | Classe | Regra | Onde procurar |
|---|---|---|---|
| FUNC.1 | `AUTO` | Negado por padrão; política global exige autenticação | Configuração de política padrão do framework |
| FUNC.2 | `AUTO` | Toda rota declara política explícita | Rota sem declaração de permissão |
| FUNC.3 | `AUTO` | Rota administrativa exige papel administrativo no servidor | Ação sensível com política de usuário comum |
| FUNC.4 | `AUTO` | Todo método da rota está protegido | Método adicional sem política própria |
| FUNC.5 | `AUTO` | Papel vem do servidor, nunca de cabeçalho ou corpo | Leitura de papel a partir da requisição |
| FUNC.6 | `AUTO` | Existe teste que falha se rota ficar sem política | Suíte de testes |
| FUNC.7 | `RUNTIME` | Usuário comum recebe negação em toda rota administrativa | `runtime-tests.md` § FUNC |

## Bloco 5 — Consumo de recursos (API4:2023) · P1

| ID | Classe | Regra | Onde procurar |
|---|---|---|---|
| RES.1 | `AUTO` | Rate limit por identidade e por origem, com resposta padronizada | Configuração global de limite |
| RES.2 | `AUTO` | Limite de tamanho de corpo e de arquivo aplicado antes de processar | Configuração de upload e de corpo |
| RES.3 | `AUTO` | Paginação com teto rígido | Paginação ausente ou com tamanho controlado pelo cliente sem teto |
| RES.4 | `AUTO` | Tempo limite em toda chamada externa | Chamada HTTP/cliente externo sem tempo limite |
| RES.5 | `AUTO` | Operação cara é assíncrona ou tem cota | Geração de relatório/exportação em ciclo de requisição |
| RES.6 | `AUTO` | Expressão regular sem retrocesso catastrófico | Quantificador aninhado em validação |
| RES.7 | `RUNTIME` | Carga real produz limitação antes de degradar | `runtime-tests.md` § RES |

## Bloco 6 — Fluxos de negócio (API6:2023) · P1

| ID | Classe | Regra | Onde procurar |
|---|---|---|---|
| FLOW.1 | `MANUAL` | Fluxos abusáveis mapeados | Requer conhecimento do produto |
| FLOW.2 | `AUTO` | Unicidade garantida no banco, não só na aplicação | Restrição única ausente onde a regra exige "um por usuário" |
| FLOW.3 | `AUTO` | Operação crítica é idempotente ou usa bloqueio transacional | Escrita crítica sem transação nem chave de idempotência |
| FLOW.4 | `MANUAL` | Alerta para volume anômalo nesses fluxos | Configuração de observabilidade |
| FLOW.5 | `RUNTIME` | Envio paralelo produz um efeito, não N | `runtime-tests.md` § FLOW |

## Bloco 7 — Injeção e entrada (A05:2025) · P0

| ID | Classe | Regra | Onde procurar |
|---|---|---|---|
| INJ.1 | `AUTO` | Sem concatenação de entrada em SQL/NoSQL | Consulta crua montada por string |
| INJ.2 | `AUTO` | Ordenação e nome de coluna dinâmicos vêm de lista fechada | Campo de ordenação repassado direto |
| INJ.3 | `AUTO` | Sem shell interpolado com entrada | Execução de comando com shell habilitado |
| INJ.4 | `AUTO` | Caminho de arquivo validado contra travessia | Junção de caminho com entrada sem resolução canônica |
| INJ.5 | `AUTO` | Upload valida tipo real pelos bytes, renomeia e grava fora da raiz web | Validação apenas por extensão ou por tipo declarado |
| INJ.6 | `AUTO` | Desserialização insegura desligada para dado externo | Desserializador binário sobre entrada |
| INJ.7 | `AUTO` | Leitor de XML sem entidades externas | Analisador de XML com configuração padrão |
| INJ.8 | `AUTO` | Template nunca renderiza string do usuário | Template montado em tempo de execução com entrada |
| INJ.9 | `AUTO` | Saída escapada no contexto de destino, incluindo exportação para planilha | Exportação sem neutralizar fórmula |
| INJ.10 | `AUTO` | Validação por esquema no servidor com tipo, faixa e tamanho | Campo aceito sem validação |
| INJ.11 | `RUNTIME` | Cargas clássicas não alteram comportamento | `runtime-tests.md` § INJ |

## Bloco 8 — SSRF (API7:2023) · P1

| ID | Classe | Regra | Onde procurar |
|---|---|---|---|
| SSRF.1 | `AUTO` | URL do cliente só é buscada sob lista fechada de domínio e esquema | Requisição de saída com destino controlado por entrada |
| SSRF.2 | `AUTO` | Faixas internas e endpoint de metadados bloqueados após resolver DNS | Validação por string antes da resolução |
| SSRF.3 | `AUTO` | Redirecionamento não seguido cegamente | Cliente HTTP com redirecionamento automático em fluxo de URL do usuário |
| SSRF.4 | `AUTO` | Webhook do usuário passa pela mesma validação | Cadastro de webhook sem validação de destino |
| SSRF.5 | `AUTO` | Resposta do fetch não volta crua ao cliente | Repasse do corpo da resposta externa |
| SSRF.6 | `RUNTIME` | Destino interno é recusado na prática | `runtime-tests.md` § SSRF |

## Bloco 9 — Terceiros e cadeia de suprimentos (API10:2023 · A03:2025) · P1

| ID | Classe | Regra | Onde procurar |
|---|---|---|---|
| SUP.1 | `AUTO` | Resposta externa validada por esquema antes de persistir | Persistência direta do corpo recebido |
| SUP.2 | `AUTO` | Verificação de certificado TLS nunca desligada | Verificação desabilitada em cliente HTTP |
| SUP.3 | `AUTO` | Tempo limite, retentativa com teto e disjuntor nas integrações | Integração sem tempo limite |
| SUP.4 | `AUTO` | Arquivo de trava de dependências versionado | Ausência de arquivo de trava |
| SUP.5 | `AUTO` | Auditoria de dependência na integração contínua | Configuração do pipeline |
| SUP.6 | `AUTO` | Imagem base fixada por digest | Tag móvel no arquivo de build |

## Bloco 10 — Configuração, transporte e segredos (API8:2023 · A02/A04:2025) · P0

| ID | Classe | Regra | Onde procurar |
|---|---|---|---|
| CONF.1 | `AUTO` | Depuração desligada em ambiente exposto | Sinalizador de depuração ligado fora de desenvolvimento |
| CONF.2 | `AUTO` | Hosts permitidos restritos | Curinga na lista de hosts |
| CONF.3 | `AUTO` | CORS com origem explícita, sem curinga com credenciais | Configuração de origem cruzada |
| CONF.4 | `AUTO` | Cabeçalhos de segurança presentes na resposta | Configuração de middleware de cabeçalhos |
| CONF.5 | `AUTO` | Cookie de sessão com marcações seguras | Configuração de cookie |
| CONF.6 | `AUTO` | TLS obrigatório e redirecionamento ativo | Configuração de transporte |
| CONF.7 | `AUTO` | Nenhum segredo no repositório nem na imagem | Varredura de segredos na árvore **e no histórico** |
| CONF.8 | `AUTO` | Diretório de upload não é público por padrão | Configuração de armazenamento |
| CONF.9 | `MANUAL` | Segredo já commitado foi rotacionado, não só removido | Só o time sabe |
| CONF.10 | `MANUAL` | Dado sensível cifrado em repouso, com chave gerenciada fora do código | Depende da infraestrutura |

## Bloco 11 — Inventário e documentação (API9:2023) · P1

| ID | Classe | Regra | Onde procurar |
|---|---|---|---|
| INV.1 | `AUTO` | Especificação da API gerada do código | Geração de esquema no projeto |
| INV.2 | `AUTO` | Documentação não depende do sinalizador de depuração para existir | Rota de documentação condicionada à depuração |
| INV.3 | `AUTO` | Documentação exposta sob autenticação | Rota de documentação pública |
| INV.4 | `AUTO` | Nenhuma rota de depuração, console ou saúde detalhada sem autenticação | Rotas administrativas e de diagnóstico |
| INV.5 | `AUTO` | Toda rota do código aparece na documentação | Diferença entre tabela de rotas e esquema |
| INV.6 | `MANUAL` | Versões antigas desligadas de fato | Depende do ambiente |
| INV.7 | `MANUAL` | Ambiente de teste sem dado real de produção | Depende do processo |

## Bloco 12 — Registro, alerta e falha (A09/A10:2025) · P1

| ID | Classe | Regra | Onde procurar |
|---|---|---|---|
| LOG.1 | `AUTO` | Eventos de segurança registrados com autor, ação, momento e origem | Registro nas rotas de autenticação e administrativas |
| LOG.2 | `AUTO` | Registro nunca grava senha, token, cartão ou corpo sensível inteiro | Registro de corpo ou de cabeçalho de autorização |
| LOG.3 | `AUTO` | Identificador de correlação por requisição | Middleware de correlação |
| LOG.4 | `AUTO` | Erro genérico ao cliente, detalhe só no registro interno | Manipulador de exceção |
| LOG.5 | `AUTO` | Falha em checagem de segurança nega o acesso | Bloco que captura exceção e segue adiante |
| LOG.6 | `AUTO` | Escrita crítica é transacional; falha não deixa estado parcial | Sequência de escritas sem transação |
| LOG.7 | `MANUAL` | Registro centralizado, somente-adição, com retenção e alerta | Depende da infraestrutura |

## Bloco 13 — Ciclo de desenvolvimento (A06/A08:2025) · P2

| ID | Classe | Regra | Onde procurar |
|---|---|---|---|
| SDLC.1 | `AUTO` | Análise estática no pipeline | Configuração da integração contínua |
| SDLC.2 | `AUTO` | Verificador de segredos no pipeline | Configuração da integração contínua |
| SDLC.3 | `AUTO` | Auditoria de dependência quebrando o build em severidade crítica | Configuração da integração contínua |
| SDLC.4 | `AUTO` | Existe teste automatizado de autorização entre usuários | Suíte de testes |
| SDLC.5 | `MANUAL` | Modelagem de ameaça em funcionalidade sensível | Processo |
| SDLC.6 | `MANUAL` | Backup verificado e retorno testado antes de janela de risco | Processo |

## Bloco 14 — Preparação de pentest · P1

Todos `MANUAL`. Verificar com o time antes da janela; não há sinal no código.
Lista em `checklist-prosa.md` § Pré-pentest.
