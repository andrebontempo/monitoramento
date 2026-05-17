# Instruções para o Gemini (Antigravity) - Stack de Monitoramento

Este arquivo consolida o contexto, arquitetura e diretrizes de boas práticas para a IA ao trabalhar neste repositório.

## 🎯 Escopo e Arquitetura do Projeto
- **Objetivo:** Repositório dedicado à stack de observabilidade, alertas e segurança para instâncias VPS. O gerenciamento dos serviços é feito via **Docker Compose**.
- **Componentes Principais:**
  - **Métricas:** Prometheus, Node Exporter, cAdvisor
  - **Logs:** Loki, Promtail
  - **Dashboards:** Grafana
  - **Alertas:** Alertmanager (integrado ao Telegram)
  - **Segurança (CVE):** Trivy
- **Caminho de Deploy:** Em produção, esta stack costuma residir no diretório `/opt/docker/monitoramento` da VPS alvo.

## 📝 Diretrizes para Manutenção e Desenvolvimento

1. **Gestão de Arquivos YAML (.yml / .yaml):**
   - Tenha extremo cuidado com a indentação, pois os serviços do Prometheus, Alertmanager e Docker Compose dependem dessa formatação correta.
   - Novas regras de alertas devem ser inseridas no diretório `prometheus-rules/` e mapeadas no arquivo principal do Prometheus.

2. **Dashboards do Grafana (JSON):**
   - Os arquivos `.json` exportados do Grafana estão versionados neste repositório. Edições diretas nestes arquivos via IA devem ser evitadas para não corromper o layout. Se necessário alterar painéis complexos, prefira orientar o usuário a exportar o JSON atualizado novamente.

3. **Scripts de Automação (.sh):**
   - Mantenha scripts como `deploy_monitoramento.sh`, `trivy-scan.sh` e `setup-alerting.sh` limpos, eficientes e preferencialmente no formato POSIX compatível ou Bash padrão para distribuições Debian/Ubuntu.
   - Todo novo script ou comando executável deve possuir tratamento básico de erros (ex: `set -e`).

4. **Documentação:**
   - O repositório conta com os arquivos `resumo_monitoramento.md` e `analise_stack.md`. 
   - **Regra de Ouro:** Se você adicionar/remover um serviço do `docker-compose.yml` ou incluir novas regras de alertas, lembre-se de atualizar os resumos arquiteturais do projeto.

5. **Linguagem e Idioma:**
   - Mantenha toda a documentação, os comentários no código e a formatação das mensagens do Alertmanager em **Português do Brasil (pt-BR)**.
   - O tom do repositório é puramente técnico, focado em operações (DevOps) e estabilidade da infraestrutura.
