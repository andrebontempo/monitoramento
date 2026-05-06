# 🔍 Análise da Stack de Monitoramento

> Gerado em: 2026-05-06 | Stack: Prometheus + Grafana + Loki + Alertmanager + Telegram

---

## Arquitetura dos Serviços

```
Prometheus ──► Alertmanager ──► alertmanager-bot ──► 📱 Telegram
    ▲               
    ├── Node Exporter  (métricas do host via 172.17.0.1:9100)
    └── cAdvisor       (métricas dos containers via DNS interno)

Promtail ──► Loki ──► Grafana
  (logs Docker)         (dashboards)
```

---

## ✅ O que está correto

| Componente | Avaliação |
|---|---|
| **Prometheus** | ✅ Retenção de 7d; `--web.enable-lifecycle` presente; regras mapeadas |
| **Node Exporter** | ✅ `network_mode: host` + `pid: host` corretos para leitura do kernel |
| **cAdvisor** | ✅ `privileged: true` + `/dev/kmsg` necessários; porta interna correta |
| **Loki** | ✅ Dados persistidos em volume (não mais em `/tmp`); schema `v13` + tsdb |
| **Promtail** | ✅ Posições persistidas; filtro `drop older_than: 24h` evita reenvio |
| **Alertmanager** | ✅ Rotas `critical/warning`; `inhibit_rules` evita spam de alertas |
| **alertmanager-bot** | ✅ Integração Telegram funcional; formatação HTML em horário BRT |
| **Alert Rules** | ✅ Cobre CPU, RAM, Disco, ContainerDown e HostDown |

---

## ⚠️ Problemas Identificados e Status

### 🔴 CRÍTICO — Credenciais expostas ✅ CORRIGIDO

Token do Telegram e chat_id estavam em texto puro em múltiplos arquivos.

**Solução aplicada:**
- Criado `.env` na raiz com as credenciais reais (ignorado pelo git)
- Criado `.env.example` como modelo seguro para o repositório
- `docker-compose.yml` agora usa `${TELEGRAM_TOKEN}` e `${TELEGRAM_ADMIN}`
- `alerting/.env.alerting` removido do tracking do git (`git rm --cached`)
- Todos os arquivos históricos sanitizados com placeholders

> ⚠️ **Atenção:** Como o token já esteve em commits anteriores, considere revogá-lo
> no @BotFather e gerar um novo token.

---

### 🟡 IMPORTANTE — `image: latest` em serviços críticos

Prometheus, Grafana, Loki e Promtail usam a tag `latest`.

**Risco:** Atualização automática pode quebrar a stack silenciosamente.

**Correção recomendada:**
```yaml
prometheus:  image: prom/prometheus:v2.51.2
grafana:     image: grafana/grafana:11.0.0
loki:        image: grafana/loki:3.0.0
promtail:    image: grafana/promtail:3.0.0
```

---

### 🟡 IMPORTANTE — Senha do Grafana fraca

A senha do Grafana estava hardcoded como `admin` no `docker-compose.yml`.

**Solução aplicada:** Migrada para variáveis `${GF_SECURITY_ADMIN_USER}` e
`${GF_SECURITY_ADMIN_PASSWORD}` lidas do `.env`.

**Pendente:** Alterar o valor no `.env` da VPS para uma senha forte.

---

### 🟡 IMPORTANTE — `restart: unless-stopped` faltando no Loki

O serviço `loki` não tinha política de reinício. Se o processo morrer, os logs
param de ser coletados silenciosamente.

**Correção recomendada:**
```yaml
loki:
  restart: unless-stopped  # ← adicionar
```

---

### 🟡 IMPORTANTE — Node Exporter via IP fixo `172.17.0.1`

O target no `prometheus.yml` usa o IP do gateway da bridge padrão do Docker.

**Risco:** Se o Docker for reinstalado, esse IP pode mudar.

**Alternativa:** Usar o IP privado fixo da VPS Hostinger, ou `host-gateway`:
```yaml
# No serviço prometheus (docker-compose.yml)
extra_hosts:
  - "host-gateway:host-gateway"
```
```yaml
# No prometheus.yml
- targets: ['host-gateway:9100']
```

---

### 🟢 SUGESTÃO — Alertas adicionais recomendados

| Alerta | Por quê adicionar |
|---|---|
| `ContainerRestarting` | Detecta loop de crash |
| `HostHighDiskIO` | Disco lento antes de ficar cheio |
| `HostHighLoad` | Load average além do número de cores |
| `LokiDown` | Alerta se Loki parar de receber logs |

---

### 🟢 SUGESTÃO — `alertmanager-bot` desatualizado

A imagem `metalmatze/alertmanager-bot:0.4.3` (2019) tem pouca manutenção ativa.

---

## 📋 Resumo Geral

| Prioridade | Problema | Status |
|---|---|---|
| 🔴 Crítico | Token Telegram exposto | ✅ Corrigido |
| 🟡 Importante | Tags `latest` em produção | ⏳ Pendente |
| 🟡 Importante | Senha Grafana fraca | ✅ Migrada para .env (alterar valor) |
| 🟡 Importante | `restart` faltando no Loki | ⏳ Pendente |
| 🟡 Importante | IP fixo `172.17.0.1` frágil | ⏳ Pendente |
| 🟢 Sugestão | Alertas adicionais | ⏳ Opcional |
| 🟢 Sugestão | alertmanager-bot desatualizado | ⏳ Opcional |

---

## 🚀 Deploy na VPS

Após qualquer alteração local:

```bash
# 1. Enviar código para o GitHub
git add .
git commit -m "descrição da mudança"
git push

# 2. Na VPS — atualizar e reiniciar
cd /opt/docker/monitoramento
git pull
docker compose up -d
```

### Primeiro deploy (ou após trocar credenciais)

```bash
# Copiar o .env manualmente (único arquivo fora do git)
scp /home/dedee/GitHub/monitoramento/.env usuario@IP_DA_VPS:/opt/docker/monitoramento/.env
```
