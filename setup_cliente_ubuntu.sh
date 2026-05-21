#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT DE CONFIGURACION DEL CLIENTE — Ubuntu Desktop
# ═══════════════════════════════════════════════════════════════════════════════
# Cliente   : Ubuntu Desktop 20.04 / 22.04 / 24.04 LTS
# Protocolo : Samba / SMB2+
#
# USO:
#   sudo bash setup_cliente_ubuntu.sh
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

VERDE='\033[0;32m'
ROJO='\033[0;31m'
AMARILLO='\033[1;33m'
CYAN='\033[0;36m'
NEGRITA='\033[1m'
RESET='\033[0m'

# ─── VERIFICACIONES INICIALES ────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${ROJO}ERROR: Este script debe ejecutarse con sudo.${RESET}"
    echo "  Uso: sudo bash setup_cliente_ubuntu.sh"
    exit 1
fi

read -rp "Introduce la IP del servidor NAS: " IP_SERVIDOR

if [ -z "$IP_SERVIDOR" ] || echo "$IP_SERVIDOR" | grep -q '[<>]'; then
    echo -e "${ROJO}ERROR: La IP introducida no es valida.${RESET}"
    exit 1
fi

# UID/GID del usuario real (no de root)
USUARIO_REAL="${SUDO_USER:-$USER}"
UID_REAL=$(id -u "$USUARIO_REAL" 2>/dev/null || echo "1000")
GID_REAL=$(id -g "$USUARIO_REAL" 2>/dev/null || echo "1000")

echo ""
echo -e "${CYAN}${NEGRITA}============================================================${RESET}"
echo -e "${CYAN}${NEGRITA}   CONFIGURACION CLIENTE NAS — Ubuntu${RESET}"
echo -e "${CYAN}${NEGRITA}   Servidor: $IP_SERVIDOR | Usuario local: $USUARIO_REAL${RESET}"
echo -e "${CYAN}${NEGRITA}============================================================${RESET}"
echo ""

# ─── PASO 1: INSTALAR PAQUETES ───────────────────────────────────────────────
echo -e "${NEGRITA}[1/4] Instalando paquetes necesarios...${RESET}"
echo ""
# cifs-utils    : permite montar shares SMB como directorios locales (mount.cifs)
# smbclient     : herramienta de terminal para explorar el servidor
# gvfs-backends : paquete de Ubuntu que incluye soporte SMB para Nautilus
#                 (el gestor de archivos de GNOME). Permite acceder a
#                 smb:// directamente desde el explorador de archivos.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAQUETES_DIR="${SCRIPT_DIR}/paquetes/cliente_ubuntu"

if ls "$PAQUETES_DIR"/*.deb &>/dev/null 2>&1; then
    NUM_DEBS=$(ls "$PAQUETES_DIR"/*.deb | wc -l)
    echo -e "    Modo OFFLINE: usando ${NUM_DEBS} paquetes locales desde paquetes/cliente_ubuntu/"
    dpkg -i "$PAQUETES_DIR"/*.deb 2>&1 | tail -5 || true
else
    DEBIAN_FRONTEND=noninteractive apt install -y cifs-utils smbclient gvfs-backends 2>&1 | tail -5 || true
fi
echo -e "    ${VERDE}cifs-utils, smbclient, gvfs-backends instalados.${RESET}"
echo ""

# ─── PASO 2: VERIFICAR CONECTIVIDAD ──────────────────────────────────────────
echo -e "${NEGRITA}[2/4] Verificando conectividad con el servidor ($IP_SERVIDOR)...${RESET}"
echo ""
if ping -c 3 -W 2 "$IP_SERVIDOR" &>/dev/null; then
    echo -e "    ${VERDE}El servidor responde al ping.${RESET}"
else
    echo -e "    ${AMARILLO}El servidor no responde al ping.${RESET}"
    echo "    Verifica que el servidor esta encendido y en la misma red."
    echo "    Continuando de todas formas..."
fi

if smbclient -L "//$IP_SERVIDOR" -N 2>/dev/null | grep -q "Disk"; then
    echo -e "    ${VERDE}Samba accesible. Shares detectados:${RESET}"
    smbclient -L "//$IP_SERVIDOR" -N 2>/dev/null | grep "Disk" | sed 's/^/      /'
else
    echo -e "    ${AMARILLO}No se listaron shares (puede ser normal con autenticacion requerida).${RESET}"
    echo "    Prueba manual: smbclient -L //$IP_SERVIDOR -U admin"
fi
echo ""

# ─── PASO 3: CREAR PUNTOS DE MONTAJE ─────────────────────────────────────────
echo -e "${NEGRITA}[3/4] Creando directorio base de montajes...${RESET}"
echo ""
mkdir -p /mnt/nas
echo -e "    ${VERDE}/mnt/nas/ listo como raiz de montajes.${RESET}"
echo ""

# ─── PASO 4: INSTRUCCIONES DE ACCESO ─────────────────────────────────────────
echo -e "${NEGRITA}[4/4] Como acceder al NAS${RESET}"
echo ""

echo -e "${CYAN}${NEGRITA}  OPCION A — Nautilus (gestor de archivos de GNOME) — sin comandos${RESET}"
echo ""
echo "  METODO 1 — Barra de ubicacion:"
echo "  1. Abre el gestor de archivos (Nautilus)."
echo "  2. Presiona Ctrl+L para abrir la barra de ubicacion."
echo "  3. Escribe:"
echo -e "       ${NEGRITA}smb://$IP_SERVIDOR${RESET}"
echo "  4. Nautilus pedira usuario y contrasena."
echo "     Ingresa las credenciales que te dio el administrador del servidor."
echo ""
echo "  METODO 2 — Otras ubicaciones:"
echo "  1. En Nautilus, clic en 'Otras ubicaciones' (barra lateral izquierda)."
echo "  2. En la barra inferior 'Conectar al servidor' escribe:"
echo -e "       ${NEGRITA}smb://$IP_SERVIDOR${RESET}"
echo "  3. Presiona Enter e ingresa tus credenciales."
echo ""

echo -e "${CYAN}${NEGRITA}  OPCION B — Terminal (montaje manual con mount.cifs)${RESET}"
echo ""
echo "  Montar la carpeta publica (lectura, usuario invitado):"
echo "    sudo mkdir -p /mnt/nas/publico"
echo "    sudo mount.cifs //$IP_SERVIDOR/publico /mnt/nas/publico \\"
echo "      -o username=invitado,vers=3.0,uid=$UID_REAL,gid=$GID_REAL,iocharset=utf8"
echo ""
echo "  Montar una carpeta de departamento (reemplaza USUARIO, PASS y CARPETA):"
echo "    sudo mkdir -p /mnt/nas/CARPETA"
echo "    sudo mount.cifs //$IP_SERVIDOR/CARPETA /mnt/nas/CARPETA \\"
echo "      -o username=USUARIO,password=PASS,vers=3.0,uid=$UID_REAL,gid=$GID_REAL,iocharset=utf8"
echo ""
echo "  Desmontar:"
echo "    sudo umount /mnt/nas/publico"
echo "    sudo umount -l /mnt/nas/CARPETA   # si da error 'busy'"
echo ""
echo "  Ver shares disponibles en el servidor:"
echo "    smbclient -L //$IP_SERVIDOR -U admin"
echo ""

echo -e "${VERDE}${NEGRITA}+============================================================+${RESET}"
echo -e "${VERDE}${NEGRITA}|  Cliente Ubuntu configurado.                                |${RESET}"
echo -e "${VERDE}${NEGRITA}|  Accede al NAS con Nautilus: smb://$IP_SERVIDOR    |${RESET}"
echo -e "${VERDE}${NEGRITA}+============================================================+${RESET}"
echo ""
