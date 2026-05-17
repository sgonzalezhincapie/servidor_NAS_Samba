#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT DE LIMPIEZA DEL CLIENTE NAS — Arch Linux
# ═══════════════════════════════════════════════════════════════════════════════
#
# USO:
#   sudo bash limpiar_cliente_arch.sh
#
# DESCRIPCION:
#   Revierte la configuracion de cliente NAS en Arch Linux:
#   desmonta unidades NAS, elimina el punto de montaje y
#   desinstala los paquetes instalados por setup_cliente_arch.sh.
# ═══════════════════════════════════════════════════════════════════════════════

VERDE='\033[0;32m'
ROJO='\033[0;31m'
AMARILLO='\033[1;33m'
CYAN='\033[0;36m'
NEGRITA='\033[1m'
RESET='\033[0m'

ok()   { echo -e "    ${VERDE}OK${RESET}  $*"; }
info() { echo -e "    ${AMARILLO}--${RESET}  $*"; }

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${ROJO}ERROR: Este script debe ejecutarse con sudo.${RESET}"
    echo "  Uso: sudo bash limpiar_cliente_arch.sh"
    exit 1
fi

echo ""
echo -e "${CYAN}${NEGRITA}============================================================${RESET}"
echo -e "${CYAN}${NEGRITA}   LIMPIEZA CLIENTE NAS — Arch Linux${RESET}"
echo -e "${CYAN}${NEGRITA}============================================================${RESET}"
echo ""
echo "  Este script eliminara:"
echo "    - Paquetes: cifs-utils, smbclient, gvfs, gvfs-smb"
echo "    - Punto de montaje: /mnt/nas/"
echo ""
read -rp "  Continuar? [s/N]: " CONF
CONF="${CONF:-N}"
if [[ ! "$CONF" =~ ^[Ss]$ ]]; then
    echo "  Operacion cancelada."
    exit 0
fi
echo ""

# ─── PASO 1: DESMONTAR ───────────────────────────────────────────────────────
echo -e "${NEGRITA}[1/4] Desmontando unidades NAS...${RESET}"
echo ""

if mount | grep -q "/mnt/nas"; then
    umount -l /mnt/nas 2>/dev/null \
        && ok "/mnt/nas desmontado." \
        || info "No se pudo desmontar /mnt/nas (puede estar en uso)."
else
    info "No hay unidades montadas en /mnt/nas."
fi

rm -rf /mnt/nas 2>/dev/null \
    && ok "Directorio /mnt/nas eliminado." \
    || info "/mnt/nas no existia."
echo ""

# ─── PASO 2: LIMPIAR CACHÉ GVFS (Thunar/SMB) ────────────────────────────────
echo -e "${NEGRITA}[2/4] Limpiando cache de GVFS (Thunar)...${RESET}"
echo ""

# Matar el daemon gvfs-smb del usuario real para forzar que olvide los shares cacheados
if [ -n "$SUDO_USER" ]; then
    su -c "pkill -u \"\$USER\" gvfsd-smb 2>/dev/null; pkill -u \"\$USER\" gvfsd-smb-browse 2>/dev/null; true" "$SUDO_USER" 2>/dev/null \
        && ok "Daemons gvfs-smb detenidos para el usuario $SUDO_USER." \
        || info "gvfs-smb no estaba corriendo (normal si Thunar estaba cerrado)."

    # Eliminar cache de bookmarks y metadata de GVFS del usuario real
    GVFS_CACHE="/home/${SUDO_USER}/.cache/gvfs"
    if [ -d "$GVFS_CACHE" ]; then
        rm -rf "$GVFS_CACHE"
        ok "Cache de GVFS eliminado: $GVFS_CACHE"
    else
        info "No se encontro cache de GVFS en $GVFS_CACHE."
    fi
else
    info "No se detecto SUDO_USER; omitiendo limpieza de cache de GVFS."
fi
echo ""

# ─── PASO 3: DESINSTALAR PAQUETES ───────────────────────────────────────────
echo -e "${NEGRITA}[3/4] Desinstalando paquetes...${RESET}"
echo ""

pacman -Rns --noconfirm cifs-utils smbclient gvfs gvfs-smb 2>/dev/null \
    && ok "Paquetes desinstalados: cifs-utils, smbclient, gvfs, gvfs-smb" \
    || info "Algunos paquetes no estaban instalados (normal si nunca se instalaron)."
echo ""

# ─── PASO 4: RESUMEN ────────────────────────────────────────────────────────
echo -e "${NEGRITA}[4/4] Limpieza completada.${RESET}"
echo ""
echo -e "${VERDE}  Tu equipo ya no tiene configuracion de cliente NAS.${RESET}"
echo "  Para volver a configurar el acceso:"
echo "    sudo bash setup_cliente_arch.sh"
echo ""
