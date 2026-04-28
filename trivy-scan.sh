#!/bin/bash
# =============================================================================
# trivy-scan.sh — Scanner de CVEs via Trivy → Loki
# Requer: docker, jq, curl
# Uso: bash trivy-scan.sh
# Cron: 0 3 * * 1 /opt/docker/monitoramento/trivy-scan.sh >> /var/log/trivy-scan.log 2>&1
# =============================================================================

LOKI_URL="http://172.19.0.2:3100/loki/api/v1/push"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=============================================="
echo " Trivy CVE Scanner — $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================="

# Verificar dependência jq
if ! command -v jq &>/dev/null; then
  echo "jq não encontrado. Instalando..."
  apt-get install -y jq -q 2>/dev/null || { echo "Erro: instale jq manualmente (apt install jq)"; exit 1; }
fi

# -----------------------------------------------------------------------
# Função: enviar linha ao Loki
# Uso: push_loki <job> <image> <severity> <log_line>
# -----------------------------------------------------------------------
push_loki() {
  local JOB="$1"
  local IMAGE="$2"
  local SEVERITY="$3"
  local LOG_LINE="$4"
  local TS
  TS=$(date +%s%N)

  # Escapar aspas duplas na log_line para JSON válido
  local SAFE_LOG
  SAFE_LOG=$(echo "$LOG_LINE" | sed 's/"/\\"/g')

  curl -sf -X POST "$LOKI_URL" \
    -H "Content-Type: application/json" \
    -d "{
      \"streams\": [{
        \"stream\": {\"job\":\"$JOB\",\"image\":\"$IMAGE\",\"severity\":\"$SEVERITY\"},
        \"values\": [[\"$TS\", \"$SAFE_LOG\"]]
      }]
    }" > /dev/null
}

# Pegar todas as imagens dos containers em execução
IMAGES=$(docker ps --format '{{.Image}}' | sort -u)
TOTAL=$(echo "$IMAGES" | wc -l)
COUNT=0

for IMAGE in $IMAGES; do
  COUNT=$((COUNT + 1))
  echo ""
  echo -e "${YELLOW}[$COUNT/$TOTAL]${NC} Escaneando: $IMAGE"

  # Executar Trivy — saída JSON, stderr descartado
  RESULT=$(docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v trivy_cache:/root/.cache/trivy \
    aquasec/trivy:latest image \
    --format json \
    --quiet \
    --no-progress \
    --scanners vuln \
    "$IMAGE" 2>/dev/null)

  # Validar se a saída é JSON válido e não vazio
  if [ -z "$RESULT" ]; then
    echo -e "  ${YELLOW}⚠️  Saída vazia — imagem pode não ser escaneável${NC}"
    push_loki "trivy" "$IMAGE" "none" \
      "image=\"$IMAGE\" critical=0 high=0 medium=0 low=0 total=0 status=skipped"
    continue
  fi

  if ! echo "$RESULT" | jq empty 2>/dev/null; then
    echo -e "  ${RED}❌ JSON inválido recebido do Trivy para $IMAGE${NC}"
    continue
  fi

  # ---- Contar CVEs por severidade usando jq ----
  CRITICAL=$(echo "$RESULT" | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' 2>/dev/null || echo "0")
  HIGH=$(echo "$RESULT"     | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")]     | length' 2>/dev/null || echo "0")
  MEDIUM=$(echo "$RESULT"   | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="MEDIUM")]   | length' 2>/dev/null || echo "0")
  LOW=$(echo "$RESULT"      | jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="LOW")]      | length' 2>/dev/null || echo "0")
  TOTAL_VULNS=$(( CRITICAL + HIGH + MEDIUM + LOW ))

  # ---- Enviar resumo ao Loki (job=trivy) ----
  push_loki "trivy" "$IMAGE" "summary" \
    "image=\"$IMAGE\" critical=$CRITICAL high=$HIGH medium=$MEDIUM low=$LOW total=$TOTAL_VULNS status=scanned"

  # ---- Enviar CVEs individuais ao Loki (job=trivy-vuln) ----
  DETAIL_COUNT=0

  while IFS= read -r LINE; do
    [ -z "$LINE" ] && continue
    SEV=$(echo "$LINE" | grep -oP 'severity=\K\S+')
    push_loki "trivy-vuln" "$IMAGE" "${SEV:-UNKNOWN}" "$LINE"
    DETAIL_COUNT=$((DETAIL_COUNT + 1))
    # Pequena pausa para não sobrecarregar o Loki
    sleep 0.02
  done < <(
    echo "$RESULT" | jq -r --arg img "$IMAGE" '
      .Results[]?.Vulnerabilities[]? |
      [
        "severity=" + (.Severity // "UNKNOWN"),
        "cveid="    + (.VulnerabilityID // "N/A"),
        "package="  + (.PkgName // "N/A" | gsub(" "; "_")),
        "installed="+ (.InstalledVersion // "N/A" | gsub(" "; "_")),
        "fixed="    + (if .FixedVersion and .FixedVersion != "" then (.FixedVersion | gsub(" "; "_")) else "no_fix" end),
        "has_fix="  + (if .FixedVersion and .FixedVersion != "" then "yes" else "no" end),
        "title="    + (.Title // "" | gsub("[\\\" ]"; "_") | .[0:80]),
        "status=vuln"
      ] | join(" ")
    ' 2>/dev/null
  )

  # ---- Exibir resultado no terminal ----
  if [ "${CRITICAL:-0}" -gt 0 ]; then
    echo -e "  ${RED}💀 CRITICAL=$CRITICAL  HIGH=$HIGH  MEDIUM=$MEDIUM  LOW=$LOW  ($DETAIL_COUNT CVEs enviados)${NC}"
  elif [ "${HIGH:-0}" -gt 0 ]; then
    echo -e "  ${YELLOW}🔴 CRITICAL=$CRITICAL  HIGH=$HIGH  MEDIUM=$MEDIUM  LOW=$LOW  ($DETAIL_COUNT CVEs enviados)${NC}"
  else
    echo -e "  ${GREEN}✅ CRITICAL=$CRITICAL  HIGH=$HIGH  MEDIUM=$MEDIUM  LOW=$LOW  ($DETAIL_COUNT CVEs enviados)${NC}"
  fi

done

echo ""
echo "=============================================="
echo -e "${GREEN} Scan concluído! $COUNT imagens processadas.${NC}"
echo " Resultados visíveis no Grafana → Dashboard Trivy"
echo "=============================================="
