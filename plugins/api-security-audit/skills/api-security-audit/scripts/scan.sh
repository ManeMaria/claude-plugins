#!/usr/bin/env bash
# Varredura estática rápida e agnóstica de linguagem.
# Produz CANDIDATOS, não achados. Cada bloco vira insumo do subagente do bloco.
#
#   uso: scan.sh [diretorio]   (padrão: diretório atual)
#
# Não altera nada. Somente leitura.

set -uo pipefail
ROOT="${1:-.}"
cd "$ROOT" || { echo "diretório inválido: $ROOT" >&2; exit 1; }

if command -v rg >/dev/null 2>&1; then
  SEARCH() {
    rg --no-heading --line-number --color never -i \
      --glob='!node_modules' --glob='!.git' --glob='!dist' --glob='!build' \
      --glob='!vendor' --glob='!*.min.*' --glob='!*.lock' \
      -e "$1" . 2>/dev/null
  }
else
  SEARCH() {
    grep -rEni --binary-files=without-match \
      --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist \
      --exclude-dir=build --exclude-dir=vendor --exclude-dir=__pycache__ \
      --exclude='*.min.*' --exclude='*.lock' \
      -e "$1" . 2>/dev/null
  }
fi

# Ruído estrutural: caminhos que nunca produzem achado real.
# Ajustar por projeto se necessário — ver references/patterns.md § Ruído conhecido.
denoise() {
  grep -vEi \
    -e '/(tests?|spec|__tests__|fixtures|migrations|examples?|locale)/' \
    -e '/(staticfiles|mediafiles|static|media|coverage|htmlcov)/' \
    -e '/(archived|leap_files|scaffold|templates?/skills)/' \
    -e '/\.(claude|github|vscode|idea)/' \
    -e '\.(md|rst|txt|lock|map|d\.ts|po|mo|svg)[:=]' \
    -e '\.(backup|bak|orig|example|sample|dist)[^:]*:' \
    -e '\.min\.(js|css)'
}

CAP=25   # linhas por bloco; o resto é ruído para leitura humana

hit() {
  local id="$1" desc="$2" pat="$3"
  local out
  out="$(SEARCH "$pat" | denoise | head -n "$CAP")"
  if [ -n "$out" ]; then
    printf '\n### %s — %s\n' "$id" "$desc"
    printf '%s\n' "$out"
  fi
}

absent() {
  local id="$1" desc="$2" pat="$3"
  if ! SEARCH "$pat" | denoise | grep -q .; then
    printf '\n### %s — %s\n' "$id" "$desc"
    printf '  AUSENTE: nenhuma ocorrência de /%s/ no projeto\n' "$pat"
  fi
}

echo "# Varredura estática — $(pwd)"
echo
echo "## Stack detectada"
for f in package.json requirements.txt pyproject.toml go.mod pom.xml build.gradle \
         Gemfile composer.json Cargo.toml *.csproj; do
  [ -e "$f" ] && echo "  - $f"
done
echo
echo "## Arquivo de trava de dependências (SUP.4)"
found_lock=0
for f in package-lock.json yarn.lock pnpm-lock.yaml poetry.lock Pipfile.lock \
         go.sum Gemfile.lock composer.lock Cargo.lock requirements/*.txt; do
  [ -e "$f" ] && { echo "  - $f"; found_lock=1; }
done
[ "$found_lock" -eq 0 ] && echo "  AUSENTE — SUP.4 é achado"
echo
echo "## Pipeline (SDLC.1-3)"
ls -d .github/workflows .gitlab-ci.yml Jenkinsfile .circleci bitbucket-pipelines.yml \
   azure-pipelines.yml 2>/dev/null | sed 's/^/  - /' || echo "  nenhum encontrado"

echo
echo "---"
echo "# CANDIDATOS"
echo
echo "> Cada linha abaixo é candidata. Confirmar alcançabilidade a partir de entrada"
echo "> externa antes de reportar. Ver references/patterns.md § Ruído conhecido."

hit CONF.1  "depuração ligada" \
  'DEBUG\s*[:=]\s*(True|true|1)\b|NODE_ENV\s*[:=]\s*.?development|APP_DEBUG\s*=\s*true|debug\s*=\s*True'

hit CONF.2  "hosts permitidos com curinga" \
  "ALLOWED_HOSTS\s*=\s*\[\s*['\"]\*|allowed_hosts.*\*"

hit CONF.3  "origem cruzada permissiva" \
  "CORS_ALLOW_ALL|CORS_ORIGIN_ALLOW_ALL|Access-Control-Allow-Origin.{0,4}\*|origin\s*:\s*['\"]\*"

hit CONF.7  "segredo literal" \
  "(SECRET_KEY|SECRET|PRIVATE_KEY|API_?KEY|ACCESS_KEY|PASSWORD|PASSWD|TOKEN)\s*[:=]\s*['\"][^'\"\$#{<]{8,}"

hit CONF.7b "credencial de provedor conhecido" \
  'AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[baprs]-[0-9A-Za-z-]{10,}|gh[pousr]_[0-9A-Za-z]{20,}'

hit AUTH.2  "hash fraco em senha" \
  '(md5|sha1|sha256)\s*\(.{0,40}(pass|senha|pwd|secret)|hashlib\.(md5|sha1)'

hit AUTH.4  "validação de token frouxa" \
  "verify\s*[:=]\s*(False|false)|verify_signature.{0,10}False|algorithms.{0,12}none"

hit SUP.2   "verificação de TLS desligada" \
  'verify\s*=\s*False|rejectUnauthorized\s*:\s*false|InsecureSkipVerify\s*:\s*true|SSL_VERIFYPEER.{0,8}(0|false)|NODE_TLS_REJECT_UNAUTHORIZED'

hit INJ.1   "consulta montada por concatenação" \
  "(execute|executemany|query|raw|createQuery)\s*\(\s*[\"'f].*(\+|%s|\.format|\\\$\{)|\.raw\s*\(|\.extra\s*\("

hit INJ.3   "execução de comando" \
  'os\.(system|popen)\s*\(|shell\s*=\s*True|child_process\.(exec|execSync)|Runtime\.getRuntime\(\)\.exec|shell_exec|passthru|\beval\s*\('

hit INJ.6   "desserialização insegura" \
  'pickle\.loads?|marshal\.loads|yaml\.load\s*\(|unserialize\s*\(|ObjectInputStream|readObject\s*\('

hit INJ.7   "analisador de XML" \
  'etree|minidom|ElementTree|SAXParser|DocumentBuilderFactory|simplexml_load'

hit PROP.1  "atribuição em massa" \
  "fields\s*=\s*['\"]__all__['\"]|exclude\s*=\s*[\[\(]|Object\.assign\s*\(\s*\w+\s*,\s*(req|request)\.body|\.\.\.(req|request)\.body|setattr\s*\(.{0,20}(request|req)"

hit FUNC.5  "papel ou identidade vindo do cliente" \
  "(headers?|body|query|params|GET|POST|data)\s*(\[|\.get\(|\.)\s*['\"]?(role|is_admin|is_staff|is_superuser|scope|tenant_id|owner_id|user_id)"

hit SSRF.1  "destino de saída controlado por variável" \
  '(requests\.(get|post|put|request)|urlopen|axios\.(get|post)|fetch|file_get_contents|curl_init|HttpClient)\s*\(\s*[a-zA-Z_$][a-zA-Z0-9_$.]*\s*[,)]'

hit SSRF.4  "campo de URL fornecido pelo usuário" \
  'webhook|callback_url|redirect_uri|image_url|import_url|source_url|target_url'

hit LOG.4   "detalhe interno na resposta ou falha silenciosa" \
  'traceback\.format_exc|str\(\s*e\s*\)|e\.message|getMessage\(\)|except\s+\w*\s*:?\s*pass|catch\s*\([^)]*\)\s*\{\s*\}'

hit LOG.2   "dado sensível em registro" \
  '(log|logger|console|print)\w*\.?\w*\(.{0,60}(password|senha|token|secret|authorization|cpf|card)'

hit SUP.6   "imagem base sem digest" \
  '^FROM\s+[^@]+$'

echo
echo "---"
echo "# AUSÊNCIAS (a ausência é o achado)"

absent RES.1  "nenhum mecanismo de limite de requisição" 'throttl|rate.?limit|ratelimit|limiter|leaky|bucket'
absent RES.3  "nenhuma paginação"                        'paginat|page_size|per_page|page\[size\]'
absent CONF.5 "nenhuma marcação segura em cookie"        'httponly|samesite|COOKIE_SECURE'
absent CONF.4 "nenhum cabeçalho de segurança"            'content-security-policy|x-content-type-options|strict-transport-security|helmet|secure_headers'
absent LOG.3  "nenhum identificador de correlação"       'correlation|request_id|trace_id|x-request-id'
absent FLOW.3 "nenhuma transação explícita"              'atomic|transaction|begin\(\)|select_for_update|FOR UPDATE'
absent SDLC.4 "nenhum teste de autorização entre usuários" 'test.{0,40}(403|forbidden|permission|unauthorized)'

echo
echo "---"
echo "# HISTÓRICO DE VERSIONAMENTO (CONF.7)"
if [ -d .git ]; then
  echo "  repositório git detectado — rodar varredura de segredo no histórico:"
  echo "    gitleaks detect --source . --no-banner"
  echo "    trufflehog git file://. --only-verified"
  echo
  echo "  arquivos sensíveis já rastreados alguma vez:"
  git log --all --pretty=format: --name-only --diff-filter=A 2>/dev/null \
    | sort -u | grep -Ei '\.(env|pem|key|p12|pfx|keystore)$|(^|/)(\.env|secrets?|credentials?)' \
    | head -20 | sed 's/^/    /' || echo "    nenhum"
else
  echo "  não é repositório git — varredura de histórico não aplicável"
fi

echo
echo "FIM. Nada aqui é achado até ser confirmado no código."
