#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT DE CONFIGURACION DEL CLIENTE — Arch Linux
# ═══════════════════════════════════════════════════════════════════════════════
# Cliente   : Arch Linux
# Protocolo : Samba / SMB2+
#
# USO:
#   sudo bash setup_cliente_arch.sh
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
    echo "  Uso: sudo bash setup_cliente_arch.sh"
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
echo -e "${CYAN}${NEGRITA}   CONFIGURACION CLIENTE NAS — Arch Linux${RESET}"
echo -e "${CYAN}${NEGRITA}   Servidor: $IP_SERVIDOR | Usuario local: $USUARIO_REAL${RESET}"
echo -e "${CYAN}${NEGRITA}============================================================${RESET}"
echo ""

# ─── PASO 1: INSTALAR PAQUETES ───────────────────────────────────────────────
echo -e "${NEGRITA}[1/4] Instalando paquetes necesarios...${RESET}"
echo ""
# cifs-utils : permite montar shares SMB como directorios locales (mount.cifs)
# smbclient  : herramienta de terminal para explorar el servidor
# gvfs       : capa de abstraccion de sistemas de archivos virtuales para GTK
# gvfs-smb   : complemento de gvfs que permite acceder a shares SMB desde
#              el explorador de archivos Thunar (y otros gestores GTK)
pacman -S --needed --noconfirm cifs-utils smbclient gvfs gvfs-smb
echo -e "    ${VERDE}cifs-utils, smbclient, gvfs, gvfs-smb instalados.${RESET}"
echo ""

# ─── PASO 2: VERIFICAR CONECTIVIDAD ──────────────────────────────────────────
echo -e "${NEGRITA}[2/4] Verificando conectividad con el servidor ($IP_SERVIDOR)...${RESET}"
echo ""
if ping -c 3 -W 2 "$IP_SERVIDOR" &>/dev/null; then
    echo -e "    ${VERDE}El servidor responde al ping.${RESET}"
else
    echo -e "    ${AMARILLO}El servidor no responde al ping.${RESET}"
    echo "    Puede ser el firewall del servidor o que no esteis en la misma red."
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
echo -e "${NEGRITA}[3/4] Creando puntos de montaje en /mnt/nas/...${RESET}"
echo ""
mkdir -p /mnt/nas
echo -e "    ${VERDE}/mnt/nas/ listo como raiz de montajes.${RESET}"
echo ""

# ─── PASO 4: INSTRUCCIONES DE ACCESO ─────────────────────────────────────────
echo -e "${NEGRITA}[4/4] Como acceder al NAS${RESET}"
echo ""

echo -e "${CYAN}${NEGRITA}  OPCION A — Explorador de archivos Thunar (recomendado, sin comandos)${RESET}"
echo ""
echo "  1. Abre Thunar."
echo "  2. En la barra de ubicacion (atajo: Ctrl+L) escribe:"
echo -e "       ${NEGRITA}smb://$IP_SERVIDOR${RESET}"
echo "  3. Thunar pedira usuario y contrasena."
echo "     Ingresa las credenciales que te dio el administrador del servidor."
echo "  4. Navega las carpetas como si fueran locales."
echo ""
echo "  Si no ves la barra de ubicacion: Ve al menu Ver -> Mostrar barra de ubicacion"
echo ""

echo -e "${CYAN}${NEGRITA}  OPCION B — Terminal (montaje manual con mount.cifs)${RESET}"
echo ""
echo "  Montar la carpeta publica (lectura, con usuario invitado):"
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

echo -e "${CYAN}${NEGRITA}  OPCION C — Desconectarse / cambiar de usuario (IMPORTANTE)${RESET}"
echo ""
echo "  GVFS mantiene los shares SMB montados aunque presiones 'Atras' en Thunar."
echo "  Para que el servidor vuelva a pedir contrasena hay que desmontar el share"
echo "  explicitamente. Usa estos comandos en la terminal (no dentro de Thunar):"
echo ""
echo "  Ver todos los shares SMB montados actualmente:"
echo "    gio mount -l | grep smb://"
echo ""
echo "  Desmontar un share especifico (reemplaza CARPETA por el nombre real):"
echo -e "    ${NEGRITA}gio mount -u smb://$IP_SERVIDOR/CARPETA${RESET}"
echo ""
echo "  Desmontar TODOS los shares del servidor de una vez:"
echo "    gio mount -l | grep 'smb://$IP_SERVIDOR' | awk '{print \$NF}' | \\"
echo "      xargs -I{} gio mount -u {}"
echo ""
echo "  O ejecuta el script de limpieza (opcion 1 — solo sesion):"
echo "    sudo bash limpiar_cliente_arch.sh"
echo ""

echo -e "${VERDE}${NEGRITA}+============================================================+${RESET}"
echo -e "${VERDE}${NEGRITA}|  Cliente Arch Linux configurado.                            |${RESET}"
echo -e "${VERDE}${NEGRITA}|  Accede al NAS con Thunar: smb://$IP_SERVIDOR      |${RESET}"
echo -e "${VERDE}${NEGRITA}+============================================================+${RESET}"
echo ""
