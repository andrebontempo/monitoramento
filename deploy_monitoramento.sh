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
echo -e "${GREEN}4. Recarregando regras do Prometheus...${NC}"
docker exec prometheus wget -qO- --post-data='' http://localhost:9090/-/reload > /dev/null

echo -e "=============================================="
echo -e "${GREEN}Deploy concluído com sucesso!${NC}"
echo -e "=============================================="
