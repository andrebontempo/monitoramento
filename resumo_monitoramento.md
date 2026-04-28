# Resumo da Implementação: Observabilidade e Alertas VPS

Este documento detalha o stack de monitoramento e alertas configurado para a VPS, garantindo visibilidade total sobre saúde dos containers, recursos do sistema e segurança.

## 1. Stack de Tecnologias
- **Métricas:** Prometheus + Node Exporter + cAdvisor.
- **Logs:** Loki + Promtail.
- **Visualização:** Grafana.
- **Segurança:** Trivy (Scan de CVEs).
- **Alertas:** Alertmanager + Telegram (Receiver nativo).

---

## 2. Configuração de Alertas (Telegram)
O sistema utiliza o receiver nativo do **Alertmanager** com um template HTML customizado para mensagens claras e profissionais.

### Detalhes do Bot:
- **Bot:** `@VPS_Monitor_Bot`
- **Fuso Horário:** America/Sao_Paulo (BRT -3).
- **Formatação:** HTML rico com emojis e separadores.

### Regras Ativas:
1. **ContainerDown:** Alerta crítico se um container ficar offline por > 2 min.
2. **ContainerHighMemory:** Aviso se o uso de RAM do container for > 85% (ignora containers sem limite definido).
3. **ContainerHighCPU:** Aviso se o uso de CPU do container for > 80%.
4. **HostHighCPU:** Aviso se a CPU da VPS estiver > 85%.
5. **HostLowDisk:** Alerta se o disco livre for < 15%.
6. **HostDown:** Alerta crítico se a VPS parar de enviar métricas (Node Exporter).

---

## 3. Segurança (Trivy CVE Scan)
Implementamos um sistema de scan semanal automatizado.
- **Script:** `/opt/docker/monitoramento/trivy-scan.sh`
- **Fluxo:** O script varre todas as imagens Docker locais, converte as vulnerabilidades em logs e envia para o **Loki**.
- **Visualização:** Dashboard "Segurança - CVEs por Imagem Detalhado" no Grafana.

---

## 4. Caminhos de Arquivos no VPS
- **Configs Prometheus:** `/opt/docker/monitoramento/prometheus.yml`
- **Regras de Alerta:** `/opt/docker/monitoramento/prometheus-rules/alert-rules.yml`
- **Config Alertmanager:** `/opt/docker/monitoramento/alertmanager-config/alertmanager.yml`
- **Script Trivy:** `/opt/docker/monitoramento/trivy-scan.sh`

---

## 5. Comandos Úteis de Manutenção

### Recarregar regras do Prometheus (sem restart):
```bash
docker exec prometheus wget -qO- --post-data='' http://localhost:9090/-/reload
```

### Reiniciar todo o stack:
```bash
cd /opt/docker/monitoramento
docker compose down && docker compose up -d
```

### Verificar alertas ativos via CLI:
```bash
docker exec prometheus wget -qO- 'http://localhost:9090/api/v1/alerts' | python3 -m json.tool
```

---
**Data da última atualização:** 28/04/2026
**Responsável:** André Bontempo
