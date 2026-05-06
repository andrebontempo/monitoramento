#!/bin/bash
# =============================================================================
# deploy_monitoramento.sh — Automatização de atualização do stack
# =============================================================================

# Configurações
REPO_DIR="/opt/docker/monitoramento"

# Cores para o terminal
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}>>> Iniciando Deploy do Monitoramento...${NC}"

# 1. Entrar no diretório
cd "$REPO_DIR" || { echo -e "${RED}Erro: Diretorio $REPO_DIR nao encontrado.${NC}"; exit 1; }

# 2. Puxar atualizações do GitHub
echo -e "${GREEN}1. Sincronizando com o GitHub...${NC}"
git pull origin main

# 3. Garantir permissões nos scripts
echo -e "${GREEN}2. Ajustando permissões...${NC}"
chmod +x trivy-scan.sh
chmod +x setup-alerting.sh
chmod +x deploy_monitoramento.sh

# 4. Atualizar Containers (Docker Compose)
# O '--remove-orphans' limpa containers antigos que saíram do arquivo compose
echo -e "${GREEN}3. Atualizando containers...${NC}"
docker compose up -d --remove-orphans

# 5. Recarregar Prometheus (para aplicar novas regras de alerta sem downtime)
echo -e "${GREEN}4. Aguardando Prometheus ficar pronto...${NC}"
for i in $(seq 1 12); do
  if docker exec prometheus wget -q --spider http://localhost:9090/-/ready 2>/dev/null; then
    break
  fi
  echo -e "   tentativa $i/12 — aguardando 5s..."
  sleep 5
done

echo -e "${GREEN}5. Recarregando regras do Prometheus...${NC}"
if docker exec prometheus wget -qO- --post-data='' http://localhost:9090/-/reload > /dev/null 2>&1; then
  echo -e "${GREEN}   Regras recarregadas com sucesso!${NC}"
else
  echo -e "${YELLOW}   Aviso: reload falhou — as regras serão aplicadas no próximo restart.${NC}"
fi

echo -e "=============================================="
echo -e "${GREEN}Deploy concluído com sucesso!${NC}"
echo -e "=============================================="
