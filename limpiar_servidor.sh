#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT DE LIMPIEZA DEL SERVIDOR NAS
# ═══════════════════════════════════════════════════════════════════════════════
# Servidor  : Ubuntu Server 22.04.5 LTS o superior
#
# USO:
#   sudo bash limpiar_servidor.sh
#
# DESCRIPCION:
#   Revierte COMPLETAMENTE la configuracion del servidor NAS:
#   detiene Samba, elimina usuarios, grupos, datos en /srv/datacorp,
#   desinstala paquetes y limpia la configuracion.
#
#   ADVERTENCIA: Esta operacion es IRREVERSIBLE. Los datos en /srv/datacorp
#   se perderan permanentemente.
# ═══════════════════════════════════════════════════════════════════════════════

VERDE='\033[0;32m'
ROJO='\033[0;31m'
AMARILLO='\033[1;33m'
CYAN='\033[0;36m'
NEGRITA='\033[1m'
RESET='\033[0m'

ok()     { echo -e "    ${VERDE}OK${RESET}  $*"; }
info()   { echo -e "    ${AMARILLO}--${RESET}  $*"; }
err()    { echo -e "    ${ROJO}ERR${RESET} $*"; }
header() {
    echo ""
    echo -e "${CYAN}${NEGRITA}============================================================${RESET}"
    echo -e "${CYAN}${NEGRITA}   $*${RESET}"
    echo -e "${CYAN}${NEGRITA}============================================================${RESET}"
    echo ""
}

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${ROJO}ERROR: Este script debe ejecutarse con sudo.${RESET}"
    echo "  Uso: sudo bash limpiar_servidor.sh"
    exit 1
fi

header "LIMPIEZA DEL SERVIDOR NAS"

echo -e "  ${ROJO}${NEGRITA}ADVERTENCIA — Esta operacion eliminara PERMANENTEMENTE:${RESET}"
echo ""
echo "    - Todos los datos en /srv/datacorp/ (archivos de los usuarios)"
echo "    - Todos los usuarios y grupos del NAS"
echo "    - Los paquetes de Samba, acl y attr"
echo "    - La configuracion /etc/samba/smb.conf"
echo ""
echo -e "  ${ROJO}Esta accion NO se puede deshacer.${RESET}"
echo ""
read -rp "  Para confirmar, escribe exactamente CONFIRMAR: " CONF
echo ""

if [ "$CONF" != "CONFIRMAR" ]; then
    echo "  Operacion cancelada. No se cambio nada."
    exit 0
fi

# ─── PASO 1: DETENER SAMBA ───────────────────────────────────────────────────
header "1/8 — Detener Samba"

systemctl stop smbd  2>/dev/null  && ok "smbd detenido."   || info "smbd no estaba corriendo."
systemctl stop nmbd  2>/dev/null  && ok "nmbd detenido."   || info "nmbd no estaba corriendo."
systemctl disable smbd 2>/dev/null && ok "smbd deshabilitado del arranque." || true
systemctl disable nmbd 2>/dev/null && ok "nmbd deshabilitado del arranque." || true

# ─── PASO 2: DESREGISTRAR USUARIOS DE SAMBA ─────────────────────────────────
header "2/8 — Desregistrar usuarios de Samba"

if command -v pdbedit &>/dev/null; then
    SMB_USERS=$(pdbedit -L 2>/dev/null | cut -d: -f1)
    if [ -z "$SMB_USERS" ]; then
        info "No hay usuarios registrados en Samba."
    else
        while IFS= read -r USR; do
            [ -z "$USR" ] && continue
            pdbedit --delete -u "$USR" 2>/dev/null \
                && ok "Desregistrado de Samba: $USR" \
                || info "No se pudo desregistrar: $USR"
        done <<< "$SMB_USERS"
    fi
else
    info "pdbedit no encontrado, omitiendo."
fi

# ─── PASO 3: ELIMINAR USUARIOS DEL SISTEMA ──────────────────────────────────
header "3/8 — Eliminar usuarios del sistema"

USERS_TO_DELETE=()
for GRUPO in administradores invitados usuarios; do
    MIEMBROS=$(getent group "$GRUPO" 2>/dev/null | cut -d: -f4)
    if [ -n "$MIEMBROS" ]; then
        IFS=',' read -ra LISTA <<< "$MIEMBROS"
        for U in "${LISTA[@]}"; do
            [ -n "$U" ] && USERS_TO_DELETE+=("$U")
        done
    fi
done

# Eliminar duplicados
if [ ${#USERS_TO_DELETE[@]} -gt 0 ]; then
    mapfile -t USERS_TO_DELETE < <(printf '%s\n' "${USERS_TO_DELETE[@]}" | sort -u)
    for U in "${USERS_TO_DELETE[@]}"; do
        userdel "$U" 2>/dev/null \
            && ok "Usuario eliminado: $U" \
            || info "No se pudo eliminar usuario '$U' (puede no existir)."
    done
else
    info "No se encontraron usuarios NAS para eliminar."
fi

# ─── PASO 4: ELIMINAR GRUPOS ────────────────────────────────────────────────
header "4/8 — Eliminar grupos"

# Detectar grupos de departamento desde los subdirectorios del NAS
GRUPOS_DEPT=()
if [ -d "/srv/datacorp/departamentos" ]; then
    while IFS= read -r -d '' DIR; do
        GRUPOS_DEPT+=("$(basename "$DIR")")
    done < <(find /srv/datacorp/departamentos -mindepth 1 -maxdepth 1 -type d -print0)
fi

TODOS_GRUPOS=("administradores" "invitados" "usuarios" "${GRUPOS_DEPT[@]}")
for G in "${TODOS_GRUPOS[@]}"; do
    groupdel "$G" 2>/dev/null \
        && ok "Grupo eliminado: $G" \
        || info "No se pudo eliminar grupo '$G' (puede no existir o tener dependencias)."
done

# ─── PASO 5: DESINSTALAR PAQUETES ───────────────────────────────────────────
header "5/8 — Desinstalar paquetes de Samba"

apt-get remove --purge -y samba samba-common samba-common-bin samba-libs acl attr 2>/dev/null \
    && ok "Paquetes de Samba desinstalados." \
    || info "Algunos paquetes no estaban instalados."
apt-get autoremove -y 2>/dev/null && ok "Dependencias huerfanas eliminadas." || true

# ─── PASO 6: ELIMINAR DATOS DEL NAS ─────────────────────────────────────────
header "6/8 — Eliminar datos del NAS"

if [ -d "/srv/datacorp" ]; then
    rm -rf /srv/datacorp \
        && ok "/srv/datacorp eliminado." \
        || err "No se pudo eliminar /srv/datacorp."
else
    info "/srv/datacorp no existe, omitiendo."
fi

# ─── PASO 7: ELIMINAR CONFIGURACION ─────────────────────────────────────────
header "7/8 — Eliminar configuracion de Samba"

[ -f "/etc/samba/smb.conf" ] \
    && rm -f /etc/samba/smb.conf \
    && ok "/etc/samba/smb.conf eliminado." \
    || info "/etc/samba/smb.conf no existe, omitiendo."

rm -f /etc/samba/smb.conf.backup.* 2>/dev/null \
    && ok "Backups de smb.conf eliminados." || true

# ─── PASO 8: FIREWALL ───────────────────────────────────────────────────────
header "8/8 — Limpiar reglas de firewall"

if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "active"; then
    ufw delete allow samba 2>/dev/null \
        && ok "Regla de Samba eliminada del UFW." \
        || info "No habia regla de Samba en UFW."
else
    info "UFW no esta activo, omitiendo."
fi

echo ""
echo -e "${VERDE}${NEGRITA}+======================================================+${RESET}"
echo -e "${VERDE}${NEGRITA}|         LIMPIEZA COMPLETADA                          |${RESET}"
echo -e "${VERDE}${NEGRITA}+======================================================+${RESET}"
echo ""
echo "  El servidor NAS ha sido completamente desconfigurado."
echo "  Para volver a configurarlo desde cero:"
echo "    sudo bash setup_servidor.sh"
echo ""
