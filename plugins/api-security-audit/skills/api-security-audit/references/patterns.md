# Padrões de busca — agnósticos de linguagem

Sinais para localizar candidatos. **Toda ocorrência é candidata, não achado.**
Achado exige leitura do trecho e confirmação de que o caminho é alcançável a partir
de entrada externa. Padrão que casa em teste, exemplo, documentação ou script local
não é achado — é ruído.

Sintaxe: expressão regular estendida, compatível com `grep -E` e `rg`.

---

## CONF.1 — depuração ligada

```
DEBUG\s*[:=]\s*(True|true|1)
NODE_ENV\s*[:=]\s*['"]?development
app\.(debug|run)\(.*debug\s*=\s*True
spring\.profiles\.active\s*=\s*dev
APP_DEBUG\s*=\s*true
```
Confirmar: o valor vale para ambiente exposto? Origem em variável de ambiente com
padrão seguro não é achado.

## CONF.2 / CONF.3 — hosts e origem cruzada

```
ALLOWED_HOSTS\s*=\s*\[\s*['"]\*
CORS_ALLOW_ALL(_ORIGINS)?\s*=\s*True
Access-Control-Allow-Origin['"]?\s*[:,]\s*['"]\*
origin\s*:\s*['"]\*['"]
cors\(\s*\)
credentials\s*:\s*true
```
`P0` quando curinga de origem aparece junto de credenciais.

## CONF.5 — cookie de sessão

Buscar **ausência**:
```
(SESSION|CSRF)_COOKIE_(SECURE|HTTPONLY|SAMESITE)
httpOnly|sameSite|secure\s*:\s*true
```
Nenhuma ocorrência em projeto que usa sessão por cookie é achado.

## CONF.7 — segredos

```
(SECRET_KEY|SECRET|PRIVATE_KEY|TOKEN|PASSWORD|PASSWD|API_KEY|APIKEY|ACCESS_KEY)\s*[:=]\s*['"][^'"$#{]{8,}
AKIA[0-9A-Z]{16}
-----BEGIN [A-Z ]*PRIVATE KEY-----
xox[baprs]-[0-9A-Za-z-]{10,}
gh[pousr]_[0-9A-Za-z]{20,}
eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.
```
Excluir: `os.environ`, `process.env`, `System.getenv`, `${...}`, `<placeholder>`.
**Rodar também no histórico do versionamento**, não só na árvore atual —
segredo removido em commit posterior continua recuperável.

## AUTH.2 — hash de senha

```
(md5|sha1|sha256|sha512)\s*\(.{0,40}(pass|senha|pwd|secret)
hashlib\.(md5|sha1|sha256)
MessageDigest\.getInstance\(\s*['"](MD5|SHA-1)
```
Esperado no lugar: `argon2`, `bcrypt`, `scrypt`, `pbkdf2`.

## AUTH.4 — validação de token

```
decode\(.*verify\s*[:=]\s*(False|false)
verify_signature\s*[:=]\s*False
algorithms\s*[:=]\s*\[?\s*['"]?none
jwt\.decode\([^,)]*\)
```
Última linha: decodificação sem chave nem algoritmo declarado.
Verificar também presença de checagem de emissor e audiência.

## SUP.2 — verificação de TLS desligada

```
verify\s*=\s*False
rejectUnauthorized\s*:\s*false
InsecureSkipVerify\s*:\s*true
CURLOPT_SSL_VERIFYPEER.{0,10}(0|false)
curl\s.*(-k|--insecure)
NODE_TLS_REJECT_UNAUTHORIZED\s*=\s*['"]?0
```
`P0` mesmo em homologação: normaliza o padrão e vaza para produção.

## INJ.1 — injeção em consulta

```
(execute|executemany|query|raw|createQuery)\s*\(\s*['"].*['"]\s*(\+|%|\.format|f['"])
(SELECT|INSERT|UPDATE|DELETE|WHERE|ORDER BY).{0,60}(\+\s*[a-zA-Z_]|\$\{|%s['"]\s*%|\{[a-z_]+\})
extra\s*\(\s*(where|select)
\.raw\s*\(
```
Consulta parametrizada com marcador de posição não é achado.
O sinal é o operador de concatenação **entre** a string e a variável.

## INJ.3 — execução de comando

```
os\.(system|popen)\s*\(
subprocess\.[a-z]+\(.*shell\s*=\s*True
child_process\.(exec|execSync)\s*\(
Runtime\.getRuntime\(\)\.exec\s*\(
shell_exec|passthru|proc_open|`.*\$
eval\s*\(|exec\s*\(
```

## INJ.4 — travessia de caminho

```
(open|readFile|sendFile|File|Path)\s*\(.{0,40}(request|req|params|query|body|input)
os\.path\.join\s*\(.{0,40}(request|req|params|input)
```
Confirmar se há resolução canônica e comparação com diretório base depois da junção.

## INJ.6 — desserialização

```
pickle\.loads?|marshal\.loads
yaml\.load\s*\((?!.*Safe)
unserialize\s*\(
ObjectInputStream|readObject\s*\(
JsonConvert.*TypeNameHandling
```

## INJ.7 — entidades externas em XML

```
(etree|minidom|ElementTree|SAXParser|DocumentBuilderFactory|simplexml_load)
```
Achado quando o analisador é usado sobre entrada externa **sem** desabilitar
entidades externas e expansão de DTD.

## INJ.9 — exportação para planilha

```
(csv|xlsx|writer|to_csv|WriteRecords)
```
Achado quando célula é escrita a partir de dado do usuário sem neutralizar
`=`, `+`, `-` e `@` no início do valor.

## SSRF.1 — destino controlado por entrada

```
(requests\.(get|post)|urlopen|fetch|axios\.(get|post)|http\.(Get|Post)|HttpClient|file_get_contents|curl_init)\s*\(\s*[a-zA-Z_$]
```
O sinal é a URL ser variável, não literal. Rastrear a origem da variável até
uma entrada externa antes de concluir.

Complementos:
```
allow_redirects\s*=\s*True|followRedirects|maxRedirects
webhook|callback_url|redirect_uri|image_url|import_url|source_url
```

## RES.1 / RES.4 — limites e tempo limite

Buscar **ausência**:
```
throttl|rate.?limit|limiter|bucket|quota
timeout|deadline|Timeout|timeoutMs
```
Toda chamada de saída sem tempo limite é `RES.4`.
Projeto de API sem nenhuma configuração de limite é `RES.1` direto.

## RES.3 — paginação

```
pagination|paginate|page_size|limit|per_page
```
Achado: tamanho de página lido do cliente sem teto máximo declarado.

## FUNC.2 — rota sem política

Estratégia genérica em dois passos:
1. Extrair a tabela de rotas do projeto (comando do framework, arquivo de rotas
   ou geração de esquema).
2. Para cada rota, procurar declaração de política no mesmo arquivo/classe:
```
permission|authorize|auth_required|requireAuth|@PreAuthorize|guard|policy|middleware
```
Rota sem nenhuma declaração e sem política padrão restritiva é `P0`.

## FUNC.5 — papel vindo do cliente

```
(headers?|body|query|params|data)\s*\[?\s*['"]?(role|is_admin|is_staff|scope|perm|tenant|user_id|owner)
```

## PROP.1 / PROP.2 — atribuição em massa

```
fields\s*=\s*['"]__all__['"]
exclude\s*=
Object\.assign\s*\(\s*[a-z]+\s*,\s*req\.body
\.\.\.req\.body|\.\.\.request\.body
setattr\s*\(.*request
new\s+\w+\(\s*(req\.body|request\.body)
```
`exclude` é sinal porque inverte a lógica: campo novo no modelo entra gravável
por padrão. Preferir lista fechada de campos.

## PROP.4 / LOG.2 — vazamento de dado sensível

```
(password|senha|token|secret|cpf|cnpj|card|hash|api_key)
```
Cruzar com: representação de saída e chamadas de registro.
Achado quando o termo aparece em serializador de saída ou em argumento de registro.

## LOG.4 / LOG.5 — tratamento de erro

```
except\s*(Exception|BaseException)?\s*:?\s*(pass|continue)
catch\s*\([^)]*\)\s*\{\s*\}
str\(e\)|e\.message|exception\.getMessage\(\)|traceback\.format_exc
```
Primeiros dois: falha silenciosa. Último: detalhe interno na resposta —
confirmar se o valor vai para o corpo devolvido ao cliente ou só para o registro.

## LOG.6 / FLOW.3 — atomicidade

```
transaction|atomic|BEGIN|commit|rollback|select_for_update|FOR UPDATE|idempotency
```
Achado: sequência de duas ou mais escritas relacionadas sem transação envolvendo.

## SUP.4 / SUP.6 — cadeia de suprimentos

Presença esperada de arquivo de trava do ecossistema.
```
^FROM\s+\S+:(latest|[0-9.]+)\s*$
```
Imagem base sem digest fixado é `SUP.6`.

## SDLC.1–3 — pipeline

Ler a configuração de integração contínua e procurar etapas de:
análise estática, varredura de segredos, auditoria de dependência.
Ausência de qualquer uma é achado do bloco 13.

---

## Ruído conhecido — não reportar

- Ocorrência em diretório de teste, exemplo, migração ou documentação, salvo quando
  o próprio item é sobre teste.
- Segredo em arquivo de exemplo com valor evidentemente falso.
- Depuração ligada em configuração exclusiva de desenvolvimento local que não é
  carregada em outro ambiente.
- Concatenação em consulta cujos componentes são todos literais do próprio código.
- Dependência de desenvolvimento em auditoria de dependência.
