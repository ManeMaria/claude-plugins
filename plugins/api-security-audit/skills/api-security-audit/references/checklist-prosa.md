# Checklist de Segurança para APIs — Backend (agnóstico de linguagem)

>**Base:** OWASP API Security Top 10 (2023), cruzado com OWASP Top 10:2025,
> OWASP ASVS 5.0.0 (mai/2025) e OWASP WSTG.
> **Escopo:** o que o dev backend controla no código, na config e no pipeline.
> Não cobre rede, WAF gerenciado nem infra de terceiros.

## Como usar

- Cada item tem **o que fazer** e **como verificar** (teste manual rápido, sem ferramenta paga).
- Prioridade: `P0` = bloqueia release · `P1` = corrigir no ciclo · `P2` = melhoria contínua.
- Marque o item só depois de **executar a verificação**, não depois de ler o código.
- Rode o bloco inteiro antes de expor endpoint novo à internet.

---

## 1. Autorização em nível de objeto — BOLA (API1:2023) · `P0`

O achado nº1 em pentest de API. Endpoint autentica, mas não checa se **aquele** usuário
pode acessar **aquele** registro.

- [ ] Toda query que recebe ID vindo do cliente filtra também pelo dono/tenant do recurso
      (`WHERE id = ? AND owner_id = <usuário da sessão>`), não só pelo ID.
- [ ] A checagem de dono vive na camada de dados/serviço, não só no controller — para não
      ser esquecida em um segundo endpoint que reusa o mesmo serviço.
- [ ] Não existe endpoint que confie em ID enviado no body/query para decidir permissão
      (`?user_id=123` define o dono → falha).
- [ ] IDs sequenciais expostos foram avaliados: se o recurso é sensível, use UUID/ULID.
      **UUID não é controle de acesso** — é só redução de enumeração.
- [ ] Rotas de escrita (`PUT`/`PATCH`/`DELETE`) têm a mesma checagem das de leitura.
- [ ] Endpoints de listagem retornam só o escopo do usuário (sem `GET /orders` global).

**Verificar:** com dois usuários comuns (A e B), pegue um ID de recurso de A e chame todos os
endpoints autenticado como B — leitura, escrita e delete. Esperado: `403`/`404` em todos.
Este é exatamente o primeiro teste que um pentest de API executa.

---

## 2. Autenticação (API2:2023 · A07:2025) · `P0`

- [ ] Credenciais e tokens trafegam **só** sobre TLS. HTTP redireciona para HTTPS e não aceita
      body em texto claro.
- [ ] Sem credenciais padrão/hardcoded em nenhum ambiente (inclusive homologação).
- [ ] Senhas com hash lento e com salt (Argon2id, scrypt ou bcrypt). Nunca MD5/SHA1/SHA256 puro.
- [ ] Rate limit + backoff em `login`, `refresh`, `reset de senha` e envio de OTP.
- [ ] Sem **user enumeration**: mensagem e tempo de resposta iguais para "usuário não existe" e
      "senha errada". Vale também para cadastro e recuperação de senha.
- [ ] JWT: valida **assinatura**, `exp`, `iss`, `aud` e o algoritmo esperado.
      Rejeita `alg: none` e rejeita troca de algoritmo (`RS256` → `HS256`).
- [ ] Access token curto (minutos) + refresh token com rotação e revogação.
- [ ] Logout / troca de senha / revogação de acesso **invalida** sessões e refresh tokens ativos.
- [ ] Segredo de assinatura vem de variável de ambiente/secret manager, com chave distinta por ambiente.
- [ ] MFA disponível ao menos para papéis administrativos.

**Verificar:** decodifique um token seu, altere o payload (`sub`, `role`), reenvie — deve dar `401`.
Reenvie um token expirado — `401`. Faça logout e reutilize o token antigo — `401`.

---

## 3. Autorização em nível de propriedade — mass assignment / vazamento de campo (API3:2023) · `P0`

- [ ] Entrada usa **allowlist** de campos graváveis. Nunca bind direto do body no model/entidade.
- [ ] Campos sensíveis (`role`, `is_admin`, `status`, `owner_id`, `price`, `balance`) são
      ignorados quando vêm do cliente, mesmo que existam no model.
- [ ] Saída usa serializer/DTO explícito. Nada de `return objeto_do_banco` cru.
- [ ] Nenhuma resposta carrega hash de senha, token, segredo, dado interno ou PII além do necessário.
- [ ] Erro de validação não devolve stack trace, query SQL nem caminho de arquivo.

**Verificar:** envie no `PATCH` um campo que não deveria ser editável (`{"role":"admin"}`) e
confira no banco se mudou. Compare o JSON de resposta campo a campo com o que a tela realmente usa.

---

## 4. Consumo de recursos (API4:2023) · `P1`

- [ ] Rate limit por identidade **e** por IP, com resposta `429` + `Retry-After`.
- [ ] Limite máximo de tamanho de body e de upload, validado antes de processar.
- [ ] Paginação obrigatória com teto (`?limit=` não pode virar 100000).
- [ ] Timeout em toda chamada externa (HTTP, banco, fila) e em toda transação longa.
- [ ] Custo de operação pesada (relatório, export, e-mail em massa) é assíncrono ou limitado.
- [ ] Regex de validação sem backtracking catastrófico (ReDoS).
- [ ] Se houver GraphQL: limite de profundidade e complexidade de query.

**Verificar:** dispare 200 requisições em loop no endpoint mais caro. Deve haver `429` antes de
degradar. Envie um arquivo acima do limite — rejeitar sem consumir memória.

---

## 5. Autorização em nível de função (API5:2023 · A01:2025) · `P0`

- [ ] Permissão é **negada por padrão**; endpoint só abre com decorator/middleware explícito.
- [ ] Rotas administrativas exigem papel administrativo — verificado no servidor, nunca só na UI.
- [ ] Todo método HTTP da rota é protegido (`GET` protegido e `DELETE` esquecido é falha comum).
- [ ] Papel/permissão vem do servidor (sessão/token validado), nunca de header ou body do cliente.
- [ ] Existe teste automatizado que percorre a lista de rotas e falha se alguma estiver sem
      classe de permissão declarada.

**Verificar:** liste todas as rotas do projeto e chame cada uma como usuário comum. Toda rota
administrativa deve retornar `403`. Repita trocando o método HTTP.

---

## 6. Fluxos de negócio sensíveis (API6:2023) · `P1`

Aqui não há bug técnico — o atacante usa a API exatamente como projetada, só que em escala.

- [ ] Fluxos abusáveis mapeados: cadastro, cupom, voto, convite, reserva, compra, envio de e-mail/SMS.
- [ ] Cada um tem limite por usuário/período no **servidor** e regra de negócio antifraude
      (ex.: 1 voto por ideia por usuário, validado no banco com constraint única).
- [ ] Operações críticas são idempotentes ou protegidas contra duplo envio/corrida
      (chave de idempotência ou `SELECT ... FOR UPDATE` / transação).
- [ ] Existe alerta para pico anômalo nesses fluxos.

**Verificar:** dispare a mesma operação crítica 20x em paralelo com o mesmo payload.
Deve resultar em 1 efeito, não 20.

---

## 7. SSRF (API7:2023) · `P1`

- [ ] Nenhum endpoint busca URL fornecida pelo cliente sem allowlist de domínio/esquema.
- [ ] Bloqueio de IP interno e metadata (`127.0.0.0/8`, `10.x`, `172.16-31.x`, `192.168.x`,
      `169.254.169.254`, `::1`), validado **após** resolver DNS.
- [ ] Redirect não é seguido automaticamente em fetch de URL do usuário (ou é revalidado a cada salto).
- [ ] Webhook cadastrado por usuário passa pela mesma validação.
- [ ] Timeout curto e resposta do fetch nunca é devolvida crua ao cliente.

**Verificar:** tente cadastrar `http://169.254.169.254/latest/meta-data/` e `http://localhost:8000/admin`
em qualquer campo de URL/webhook/importação de imagem.

---

## 8. Configuração e transporte (API8:2023 · A02:2025 · A04:2025) · `P0`

- [ ] `DEBUG=false` em qualquer ambiente exposto. Página de erro genérica, sem stack trace.
- [ ] TLS 1.2+ obrigatório, HSTS ativo, sem cipher suite obsoleta.
- [ ] CORS com origem explícita. **Nunca** `*` junto com credenciais.
- [ ] Headers de resposta: `X-Content-Type-Options: nosniff`, `X-Frame-Options`/`frame-ancestors`,
      `Content-Security-Policy`, `Referrer-Policy`.
- [ ] Headers que vazam versão de framework/servidor removidos.
- [ ] Cookie de sessão com `Secure`, `HttpOnly`, `SameSite`.
- [ ] Métodos HTTP não usados desabilitados (`TRACE`, `OPTIONS` amplo, `PUT` em arquivo estático).
- [ ] Nenhum bucket/pasta de upload público por padrão.
- [ ] Segredos fora do repositório e fora da imagem — em secret manager ou variável de ambiente.
      Histórico do Git auditado; segredo já commitado é segredo **rotacionado**, não só removido.
- [ ] Dados em repouso: PII e credenciais de terceiros criptografadas; chave gerenciada, não hardcoded.

**Verificar:** `curl -I https://sua-api/` e leia os headers. Force um erro `500` e veja o que volta.
Rode um scanner de segredos (gitleaks/trufflehog) no histórico completo.

---

## 9. Inventário e documentação (API9:2023) · `P1`

- [ ] Existe inventário de todos os endpoints, ambientes e versões expostos.
- [ ] Documentação OpenAPI/Swagger gerada a partir do código e **atualizada** — o pentest de API
      exige ela como insumo.
- [ ] Documentação exposta com autenticação, ou publicada só para o time/pentester —
      não vinculada ao flag de debug.
- [ ] Versões antigas de API desligadas, não apenas "não divulgadas".
- [ ] Ambientes de teste/homologação não usam dados reais de produção; se usarem, são mascarados.
- [ ] Nenhum endpoint de depuração, health detalhado ou console (`/debug`, `/actuator`, `/admin`)
      acessível sem autenticação.

**Verificar:** compare a lista de rotas do código com a documentação publicada. Toda rota não
documentada é uma rota que ninguém está testando.

---

## 10. Consumo de APIs de terceiros (API10:2023 · A03:2025) · `P1`

- [ ] Resposta de API externa é validada com o mesmo rigor da entrada do usuário
      (schema, tipo, tamanho) antes de persistir ou repassar.
- [ ] Certificado TLS do terceiro é validado (nunca `verify=false`).
- [ ] Timeout, retry com limite e circuit breaker em toda integração.
- [ ] Redirect de integração não é seguido cegamente para outro host.
- [ ] Dependências: lockfile commitado, `audit` no CI, atualização periódica, SBOM gerado.
- [ ] Build usa imagem base fixada por digest, não por tag móvel.

**Verificar:** rode o audit de dependências do ecossistema e trate tudo que for crítico/alto.
Simule timeout do terceiro e confira que a API não trava nem vaza erro interno.

---

## 11. Injeção e tratamento de entrada (A05:2025) · `P0`

- [ ] SQL/NoSQL sempre por query parametrizada ou ORM. Nenhuma concatenação de string com input.
- [ ] `ORDER BY`, nome de tabela/coluna dinâmicos vêm de allowlist, nunca do cliente.
- [ ] Comando de SO: sem shell interpolado com input. Se inevitável, allowlist + argumentos separados.
- [ ] Caminho de arquivo validado contra path traversal (`../`), com resolução canônica.
- [ ] Upload: valida tipo real (magic bytes, não só extensão nem `Content-Type`), renomeia o arquivo,
      grava fora da raiz web e nunca executa.
- [ ] Desserialização de formato inseguro desabilitada (pickle/YAML full-load/objeto binário de input).
- [ ] Parser XML com entidades externas desabilitadas (XXE).
- [ ] Template engine não renderiza string vinda do usuário (SSTI).
- [ ] Saída para outro contexto é escapada nesse contexto (HTML, e-mail, CSV — cuidado com
      CSV injection em export).
- [ ] Validação de entrada por schema, com tipo, faixa, tamanho e formato — no servidor.

**Verificar:** em cada parâmetro, teste `'`, `" OR 1=1--`, `../../etc/passwd`, `{{7*7}}` e um payload
XML com DOCTYPE. Nenhuma deve alterar o comportamento nem vazar erro de banco.

---

## 12. Logging, alerta e tratamento de erro (A09:2025 · A10:2025) · `P1`

- [ ] Eventos de segurança logados: login ok/falha, mudança de senha e permissão, acesso negado,
      operação administrativa, alteração de dado sensível — com quem, o quê, quando, de onde.
- [ ] Log **nunca** grava senha, token, cartão, PII completa ou body inteiro de request sensível.
- [ ] Log tem correlation ID por requisição e é centralizado, com retenção definida.
- [ ] Log é somente-append para quem opera a aplicação (atacante não apaga o próprio rastro).
- [ ] Alerta configurado para pico de `401`/`403`, `429` e `5xx`.
- [ ] Todo caminho de erro é tratado: falha de dependência não vira `500` com stack trace,
      nem deixa transação/estado parcial gravado.
- [ ] Falha de checagem de segurança resulta em **negar**, nunca em seguir adiante (fail closed).

**Verificar:** provoque falha de banco, de terceiro e de disco. A resposta ao cliente deve ser
genérica, o log interno deve ter o detalhe e o estado no banco deve estar consistente.

---

## 13. Ciclo de desenvolvimento (A06:2025 · A08:2025) · `P2`

- [ ] Modelagem de ameaça leve em feature nova que toca dado sensível, dinheiro ou permissão.
- [ ] Code review com olhar de segurança em: autorização, entrada do usuário, segredo, dependência nova.
- [ ] SAST + scanner de segredos + audit de dependência rodando no CI, com build quebrando em crítico.
- [ ] Teste automatizado de autorização (usuário A não acessa recurso de B) no conjunto de testes.
- [ ] Migração/deploy com rollback testado e backup verificado antes de janela de risco.
- [ ] Artefato de build assinado ou verificado por hash; pipeline não puxa script remoto sem pin.

---

## Pré-pentest — o que preparar antes da janela

Insumos que praticamente todo escopo de teste em API exige:

- [ ] Swagger/OpenAPI atualizado e acessível ao testador (ou 2 chaves de API).
- [ ] **2 usuários** com a permissão mais comum da aplicação, ativos e validados.
- [ ] URL do ambiente definida e confirmada com o time de segurança.
- [ ] Rate limit ajustado para a janela (senão o teste morre no `429`) — com data de reversão marcada.
- [ ] Backup e massa de teste preparados; ambiente com dado sintético, não PII real.
- [ ] Log e monitoramento ligados durante a janela, para diferenciar pentest de ataque real.
- [ ] Canal de contato aberto com o time de segurança durante o teste.
- [ ] Plano de remediação combinado: severidade Crítica/Alta entra no ciclo seguinte, com prazo.

---

## Referências

- OWASP API Security Top 10 — 2023: https://owasp.org/API-Security/editions/2023/en/0x11-t10/
- OWASP Top 10:2025: https://owasp.org/Top10/2025/
- OWASP ASVS 5.0.0: https://github.com/OWASP/ASVS
- OWASP Web Security Testing Guide (WSTG): https://owasp.org/www-project-web-security-testing-guide/
- OWASP Cheat Sheet Series: https://cheatsheetseries.owasp.org/
- NIST SP 800-115 (metodologia de teste): https://csrc.nist.gov/pubs/sp/800/115/final
- PTES: http://www.pentest-standard.org/
