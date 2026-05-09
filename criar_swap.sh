#!/bin/bash

# ==========================================
# Script para criar 2GB de SWAP em arquivo
# ==========================================

SWAPFILE="/swapfile"

echo "Criando arquivo de swap de 2GB..."

# Cria arquivo de 2GB
sudo fallocate -l 2G $SWAPFILE

# Caso fallocate não funcione, use:
# sudo dd if=/dev/zero of=$SWAPFILE bs=1M count=2048 status=progress

echo "Definindo permissões..."
sudo chmod 600 $SWAPFILE

echo "Formatando como swap..."
sudo mkswap $SWAPFILE

echo "Ativando swap..."
sudo swapon $SWAPFILE

echo "Adicionando ao /etc/fstab..."
if ! grep -q "$SWAPFILE" /etc/fstab; then
    echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab
fi

echo
echo "=================================="
echo "SWAP criada com sucesso!"
echo "=================================="

echo
echo "Resumo:"
free -h

echo
echo "Swap ativa:"
swapon --show
