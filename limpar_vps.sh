#!/bin/bash

echo "==========================================="
echo "🧹 Iniciando Limpeza Segura do Servidor VPS"
echo "==========================================="

# Mostrar o espaço antes
echo ""
echo "Espaço atual no disco:"
df -h / | grep '/'

echo ""
echo "[1/4] Limpando pacotes antigos do Ubuntu..."
sudo apt-get autoremove -y > /dev/null 2>&1
sudo apt-get clean > /dev/null 2>&1
echo "Pacotes limpos!"

echo ""
echo "[2/4] Limpando logs de sistema antigos (mantendo 3 dias)..."
sudo journalctl --vacuum-time=3d

echo ""
echo "[3/4] Limpando imagens Docker não utilizadas e caches de build..."
sudo docker image prune -a -f
sudo docker builder prune -f
sudo docker network prune -f

echo ""
echo "[4/4] Buscando logs de containers maiores que 500MB (Apenas para visualização):"
sudo find /var/lib/docker/containers/ -type f -name "*.log" -size +500M -exec du -sh {} + | sort -h

echo ""
echo "==========================================="
echo "✅ Limpeza concluída com sucesso!"
echo "Espaço livre após a limpeza:"
df -h / | grep '/'
echo "==========================================="
