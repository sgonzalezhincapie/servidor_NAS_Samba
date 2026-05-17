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
echo "  Selecciona el modo de limpieza:"
echo ""
echo "    1) Solo limpiar sesion SMB  — Desmonta los shares GVFS activos y"
echo "       limpia la cache de credenciales. Util para cambiar de usuario"
echo "       durante el laboratorio. No desinstala paquetes."
echo ""
echo "    2) Desinstalar todo         — Elimina paquetes, puntos de montaje"
echo "       y sesiones SMB activas. Revierte completamente el cliente NAS."
echo ""
read -rp "  Opcion [1/2]: " MODO
MODO="${MODO:-1}"
if [[ ! "$MODO" =~ ^[12]$ ]]; then
    echo "  Operacion cancelada."
    exit 0
fi
echo ""

if [ "$MODO" = "2" ]; then
    echo -e "  ${AMARILLO}Este script eliminara:${RESET}"
    echo "    - Paquetes: cifs-utils, smbclient, gvfs, gvfs-smb"
    echo "    - Punto de montaje: /mnt/nas/"
    echo "    - Sesiones SMB activas y cache de GVFS"
    echo ""
    read -rp "  Confirmar desinstalacion completa? [s/N]: " CONF
    CONF="${CONF:-N}"
    if [[ ! "$CONF" =~ ^[Ss]$ ]]; then
        echo "  Operacion cancelada."
        exit 0
    fi
    echo ""
fi

# ─── [SOLO MODO 2] PASO 1: DESMONTAR /mnt/nas ────────────────────────────────
if [ "$MODO" = "2" ]; then
    echo -e "${NEGRITA}[1/3] Desmontando unidades NAS (/mnt/nas)...${RESET}"
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
fi

# ─── PASO [1 o 2]: LIMPIAR SESION SMB EN GVFS ────────────────────────────────
LABEL_PASO="[1/2]"
[ "$MODO" = "2" ] && LABEL_PASO="[2/3]"
echo -e "${NEGRITA}${LABEL_PASO} Limpiando sesion SMB en GVFS (Thunar)...${RESET}"
echo ""

if [ -n "$SUDO_USER" ]; then
    UID_REAL=$(id -u "$SUDO_USER" 2>/dev/null || echo "1000")
    DBUS_ADDR="unix:path=/run/user/${UID_REAL}/bus"

    # Desmontar ordenadamente todos los shares SMB activos antes de matar el daemon
    MOUNTS_SMB=$(su -c "DBUS_SESSION_BUS_ADDRESS='$DBUS_ADDR' gio mount -l 2>/dev/null | grep 'smb://' | awk '{print \$NF}'" "$SUDO_USER" 2>/dev/null || true)

    if [ -n "$MOUNTS_SMB" ]; then
        ok "Shares SMB activos detectados:"
        echo "$MOUNTS_SMB" | sed 's/^/      /'
        echo ""
        while IFS= read -r MOUNT_URI; do
            [ -z "$MOUNT_URI" ] && continue
            su -c "DBUS_SESSION_BUS_ADDRESS='$DBUS_ADDR' gio mount -u '$MOUNT_URI' 2>/dev/null" "$SUDO_USER" 2>/dev/null \
                && ok "Desmontado: $MOUNT_URI" \
                || info "No se pudo desmontar: $MOUNT_URI (puede que ya este cerrado)"
        done <<< "$MOUNTS_SMB"
        echo ""
    else
        info "No hay shares SMB activos montados por GVFS."
    fi

    # Matar el daemon gvfs-smb para forzar que olvide las sesiones en memoria
    su -c "pkill -u \"\$USER\" gvfsd-smb 2>/dev/null; pkill -u \"\$USER\" gvfsd-smb-browse 2>/dev/null; true" "$SUDO_USER" 2>/dev/null \
        && ok "Daemons gvfs-smb detenidos para el usuario $SUDO_USER." \
        || info "gvfs-smb no estaba corriendo (normal si Thunar estaba cerrado)."

    # Limpiar cache de metadata de GVFS del usuario real
    GVFS_CACHE="/home/${SUDO_USER}/.cache/gvfs"
    if [ -d "$GVFS_CACHE" ]; then
        rm -rf "$GVFS_CACHE"
        ok "Cache de GVFS eliminada: $GVFS_CACHE"
    else
        info "No se encontro cache de GVFS en $GVFS_CACHE."
    fi
else
    info "No se detecto SUDO_USER; omitiendo limpieza de sesion GVFS."
fi
echo ""

# ─── [SOLO MODO 2] PASO 3: DESINSTALAR PAQUETES ──────────────────────────────
if [ "$MODO" = "2" ]; then
    echo -e "${NEGRITA}[3/3] Desinstalando paquetes...${RESET}"
    echo ""

    pacman -Rns --noconfirm cifs-utils smbclient gvfs gvfs-smb 2>/dev/null \
        && ok "Paquetes desinstalados: cifs-utils, smbclient, gvfs, gvfs-smb" \
        || info "Algunos paquetes no estaban instalados (normal si nunca se instalaron)."
    echo ""
fi

# ─── RESUMEN ──────────────────────────────────────────────────────────────────
echo -e "${NEGRITA}Limpieza completada.${RESET}"
echo ""
if [ "$MODO" = "1" ]; then
    echo -e "${VERDE}  Sesion SMB cerrada. Abre Thunar para conectarte con otro usuario.${RESET}"
    echo ""
    echo "  En Thunar (Ctrl+L): smb://IP_DEL_SERVIDOR"
    echo "  El servidor pedira usuario y contrasena de nuevo."
else
    echo -e "${VERDE}  Tu equipo ya no tiene configuracion de cliente NAS.${RESET}"
    echo "  Para volver a configurar el acceso:"
    echo "    sudo bash setup_cliente_arch.sh"
fi
echo ""
