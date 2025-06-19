#!/bin/bash

### ===============================
### Script para integrar Debian/Ubuntu ao Active Directory
### Autor: ChatGPT + Amaro
### ===============================

# ====== VARIÁVEIS (EDITE AQUI) ======
DOMINIO="empresa.local"             # Nome do domínio (exemplo.local)
DOMINIO_REALM="EMPRESA.LOCAL"       # Mesma coisa, mas em MAIÚSCULO
USUARIO_AD="Administrador"          # Usuário com permissão de JOIN no AD
IP_SERVIDOR_AD="192.168.1.10"       # IP do servidor AD para sincronizar horário
NOME_HOST="maquina01"               # Nome da máquina no domínio
GRUPO_AD="TI"                       # Grupo do AD autorizado a logar (opcional)

# ========== VERIFICAÇÕES ==========
if [[ "$EUID" -ne 0 ]]; then
  echo "🚫 Execute este script como root (sudo)!"
  exit 1
fi

# Detectar sistema
if [[ -f /etc/debian_version ]]; then
    echo "📦 Sistema detectado: Debian/Ubuntu"
else
    echo "🚫 Este script é apenas para Debian/Ubuntu"
    exit 1
fi

# ========== INSTALAÇÃO DE PACOTES ==========
echo "📦 Instalando pacotes necessários..."
apt update && apt install -y \
  realmd sssd sssd-tools libnss-sss libpam-sss \
  adcli oddjob oddjob-mkhomedir \
  samba-common-bin krb5-user packagekit chrony

# ========== CONFIGURAÇÃO ==========
echo "🖥️ Definindo nome do host como: $NOME_HOST"
hostnamectl set-hostname "$NOME_HOST"

# -------- CONFIGURAR NTP (CHRONY) --------
echo "⏰ Configurando sincronização de horário com AD ($IP_SERVIDOR_AD)..."
sed -i '/^pool /d' /etc/chrony/chrony.conf
echo "server $IP_SERVIDOR_AD iburst" >> /etc/chrony/chrony.conf
systemctl enable chrony
systemctl restart chrony

# -------- DESCOBRIR E JUNTAR-SE AO DOMÍNIO --------
echo "🔍 Descobrindo o domínio..."
realm discover "$DOMINIO"

echo "🔐 Iniciando junção ao domínio..."
realm join --user="$USUARIO_AD" "$DOMINIO"
if [ $? -ne 0 ]; then
  echo "🚫 Falha ao entrar no domínio. Verifique o domínio, IP e credenciais."
  exit 1
fi

# -------- HABILITAR CRIAÇÃO AUTOMÁTICA DO HOME --------
echo "📁 Habilitando criação automática da pasta home..."
pam-auth-update --enable mkhomedir

# -------- AJUSTAR CONFIGURAÇÃO DO SSSD --------
echo "⚙️ Configurando nomes de usuário simples no SSSD..."
SSSD_CONF="/etc/sssd/sssd.conf"

if ! grep -q "use_fully_qualified_names" "$SSSD_CONF"; then
  echo -e "\nuse_fully_qualified_names = False\nfallback_homedir = /home/%u" >> "$SSSD_CONF"
else
  sed -i 's/use_fully_qualified_names.*/use_fully_qualified_names = False/' "$SSSD_CONF"
  sed -i 's/fallback_homedir.*/fallback_homedir = \/home\/%u/' "$SSSD_CONF"
fi

chmod 600 "$SSSD_CONF"
systemctl restart sssd

# -------- RESTRIÇÃO OPCIONAL AO GRUPO DO AD --------
if [ -n "$GRUPO_AD" ]; then
  echo "🔐 Restringindo login ao grupo '$GRUPO_AD' do AD..."
  realm permit --groups "$GRUPO_AD"
fi

# ========== TESTES ==========
echo "🧪 Teste com: id usuario@$DOMINIO ou login direto na máquina."

# ========== FIM ==========
echo "✅ Integração concluída com sucesso!"
echo "👉 Agora você pode logar com usuários do domínio: $DOMINIO"
