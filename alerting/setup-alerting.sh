#!/bin/bash
# =============================================================
# setup-alerting.sh — Configura Alertmanager + Telegram no VPS
# Execute: bash setup-alerting.sh
# =============================================================

set -e

MONITORING_DIR="/opt/docker/monitoramento"
echo "=== Configurando sistema de alertas Telegram ==="

# 1. Criar estrutura de diretórios
mkdir -p "$MONITORING_DIR/alertmanager-config"
mkdir -p "$MONITORING_DIR/prometheus-rules"

# 2. Criar alertmanager.yml
cat > "$MONITORING_DIR/alertmanager-config/alertmanager.yml" << 'EOF'
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'name']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'telegram'
  routes:
    - match:
        severity: critical
      receiver: 'telegram'
      repeat_interval: 1h
    - match:
        severity: warning
      receiver: 'telegram'
      repeat_interval: 4h

receivers:
  - name: 'telegram'
    webhook_configs:
      - url: 'http://alertmanager-bot:8080'
        send_resolved: true

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'name']
EOF
echo "✅ alertmanager.yml criado"

# 3. Criar regras de alerta do Prometheus
cat > "$MONITORING_DIR/prometheus-rules/alert-rules.yml" << 'EOF'
groups:
  - name: containers
    interval: 60s
    rules:

      - alert: ContainerDown
        expr: (time() - container_last_seen{name!="", name!~".*POD.*", name!~".*pause.*"}) > 90
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "🔴 Container DOWN: {{ $labels.name }}"
          description: "Container {{ $labels.name }} não é visto há mais de 2 minutos."

      - alert: ContainerHighCPU
        expr: sum(rate(container_cpu_usage_seconds_total{name!="", name!~".*POD.*"}[5m])) by (name) * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "⚠️ CPU alta: {{ $labels.name }}"
          description: "Container {{ $labels.name }} usando {{ $value | printf \"%.1f\" }}% de CPU há 5 minutos."

      - alert: ContainerHighMemory
        expr: (container_memory_usage_bytes{name!="", name!~".*POD.*"} / container_spec_memory_limit_bytes{name!="", name!~".*POD.*"} > 0) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "⚠️ Memória alta: {{ $labels.name }}"
          description: "Container {{ $labels.name }} usando {{ $value | printf \"%.1f\" }}% da memória limite."

  - name: host
    interval: 60s
    rules:

      - alert: HostHighCPU
        expr: 100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "⚠️ CPU do VPS alta"
          description: "CPU do host em {{ $value | printf \"%.1f\" }}% há 5 minutos."

      - alert: HostLowMemory
        expr: (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 < 15
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "⚠️ RAM baixa no VPS"
          description: "Apenas {{ $value | printf \"%.1f\" }}% de RAM livre."

      - alert: HostLowDisk
        expr: (node_filesystem_avail_bytes{mountpoint="/", fstype!="tmpfs"} / node_filesystem_size_bytes{mountpoint="/", fstype!="tmpfs"}) * 100 < 15
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "⚠️ Disco baixo no VPS"
          description: "Apenas {{ $value | printf \"%.1f\" }}% de espaço livre."

      - alert: HostDown
        expr: up{job="node-exporter"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "🔴 VPS inacessível!"
          description: "Node Exporter não responde — host pode estar fora do ar."
EOF
echo "✅ alert-rules.yml criado"

# 4. Adicionar serviços ao docker-compose.yml
echo ""
echo "=== ATENÇÃO: Edite manualmente o docker-compose.yml ==="
echo ""
echo "4a. Adicionar na seção 'services:':"
cat << 'EOF'

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    volumes:
      - ./alertmanager-config/alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--log.level=warn'
    restart: unless-stopped
    networks:
      - monitor_internal

  alertmanager-bot:
    image: metalmatze/alertmanager-bot:0.4.3
    container_name: alertmanager-bot
    environment:
      - ALERTMANAGER_URL=http://alertmanager:9093
      - LISTEN_ADDR=0.0.0.0:8080
      - BOLT_PATH=/data/bot.db
      - STORE=bolt
      - TELEGRAM_ADMIN=8450507431
      - TELEGRAM_TOKEN=8529096444:AAEozgVqNfPCHtIPxFOtpBEMAE9slKyxvzE
    volumes:
      - alertmanager_bot_data:/data
    restart: unless-stopped
    networks:
      - monitor_internal
    depends_on:
      - alertmanager

EOF
echo "4b. Adicionar na seção 'volumes:':"
echo "  alertmanager_data:"
echo "  alertmanager_bot_data:"

echo ""
echo "4c. Adicionar volume de regras ao serviço 'prometheus':"
echo "      - ./prometheus-rules:/etc/prometheus/rules"

echo ""
echo "=== Adicionar ao prometheus.yml (antes de scrape_configs) ==="
cat << 'EOF'
rule_files:
  - /etc/prometheus/rules/*.yml

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
EOF

echo ""
echo "=== Quando terminar de editar, execute: ==="
echo "  cd $MONITORING_DIR"
echo "  docker compose up -d alertmanager alertmanager-bot"
echo "  docker compose restart prometheus"
echo ""
echo "=== Testar se o bot responde: ==="
echo "  No Telegram, envie /start para o seu bot"
echo "  O bot deve responder com seus comandos disponíveis"
