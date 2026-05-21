#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT DE DESCARGA DE PAQUETES PARA INSTALACION OFFLINE
# ═══════════════════════════════════════════════════════════════════════════════
# Uso       : sudo bash descargar_paquetes.sh
# Requisito : Ejecutar UNA VEZ con conexion a internet.
#
# DESCRIPCION:
#   Descarga todos los paquetes .deb (con sus dependencias) necesarios para
#   setup_servidor.sh y setup_cliente_ubuntu.sh, y los paquetes .pkg.tar.*
#   para setup_cliente_arch.sh, en las carpetas:
#
#     paquetes/servidor/         → samba, samba-common, smbclient, acl, attr
#     paquetes/cliente_ubuntu/   → cifs-utils, smbclient, gvfs-backends
#     paquetes/cliente_arch/     → cifs-utils, smbclient, gvfs, gvfs-smb
#
#   Una vez descargados, los scripts de setup los detectan automaticamente
#   y los instalan con dpkg / pacman -U sin necesitar internet.
# ═══════════════════════════════════════════════════════════════════════════════

set -e

VERDE='\033[0;32m'
ROJO='\033[0;31m'
AMARILLO='\033[1;33m'
CYAN='\033[0;36m'
NEGRITA='\033[1m'
RESET='\033[0m'

ok()     { echo -e "    ${VERDE}OK${RESET}  $*"; }
err()    { echo -e "    ${ROJO}ERR${RESET} $*"; }
info()   { echo -e "    ${AMARILLO}--${RESET}  $*"; }
header() {
    echo ""
    echo -e "${CYAN}${NEGRITA}============================================================${RESET}"
    echo -e "${CYAN}${NEGRITA}   $*${RESET}"
    echo -e "${CYAN}${NEGRITA}============================================================${RESET}"
    echo ""
}

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${ROJO}ERROR: Este script debe ejecutarse con sudo.${RESET}"
    echo "  Uso: sudo bash descargar_paquetes.sh"
    exit 1
fi

# Verificar conexion a internet
if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null && ! ping -c 1 -W 3 1.1.1.1 &>/dev/null; then
    echo -e "${ROJO}ERROR: No hay conexion a internet.${RESET}"
    echo "  Este script necesita internet para descargar los paquetes."
    echo "  Ejecutalo en una maquina con acceso a internet."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── FUNCION: descargar paquetes apt con dependencias ────────────────────────
# Usa apt-cache depends --recurse para obtener TODOS los paquetes transitivos
# y apt-get download para guardarlos en el directorio indicado.
descargar_apt() {
    local DESTINO="$1"
    shift
    local PAQUETES=("$@")

    mkdir -p "$DESTINO"

    echo "  Resolviendo dependencias de: ${PAQUETES[*]}"
    # Obtener lista completa de paquetes (principales + dependencias transitivas)
    local LISTA
    LISTA=$(apt-cache depends --recurse \
        --no-recommends --no-suggests \
        --no-conflicts --no-breaks \
        --no-replaces --no-enhances \
        "${PAQUETES[@]}" 2>/dev/null \
        | grep "^\w" | sort -u)

    if [ -z "$LISTA" ]; then
        err "No se pudieron resolver las dependencias. Verifica los nombres de los paquetes."
        return 1
    fi

    local TOTAL
    TOTAL=$(echo "$LISTA" | wc -l)
    echo "  Total de paquetes a descargar (incluye dependencias): ${TOTAL}"
    echo ""

    local DESCARGADOS=0
    local OMITIDOS=0

    # Cambiar al directorio destino para que apt-get download guarde ahi
    pushd "$DESTINO" > /dev/null

    while IFS= read -r PKG; do
        [ -z "$PKG" ] && continue
        # Verificar si ya existe una version de este paquete descargada
        if ls "${PKG}_"*.deb &>/dev/null 2>&1; then
            ((OMITIDOS++)) || true
            continue
        fi
        if apt-get download "$PKG" &>/dev/null 2>&1; then
            ((DESCARGADOS++)) || true
        else
            info "No se pudo descargar: $PKG (puede ser virtual o de arquitectura)"
        fi
    done <<< "$LISTA"

    popd > /dev/null

    ok "Descargados: ${DESCARGADOS} | Ya existian: ${OMITIDOS}"
    local NUM_DEBS
    NUM_DEBS=$(ls "$DESTINO"/*.deb 2>/dev/null | wc -l)
    ok "Total .deb en ${DESTINO}: ${NUM_DEBS}"
}

# ─── ACTUALIZACION DE LISTA ──────────────────────────────────────────────────
header "Actualizando lista de paquetes"
apt-get update -y 2>&1 | tail -3
echo -e "    ${VERDE}Lista actualizada.${RESET}"

# ─── SERVIDOR (Ubuntu Server) ────────────────────────────────────────────────
header "Descargando paquetes del SERVIDOR (samba, acl, attr...)"
DEST_SRV="${SCRIPT_DIR}/paquetes/servidor"
descargar_apt "$DEST_SRV" samba samba-common smbclient acl attr
echo ""
echo -e "  ${VERDE}Guardados en:${RESET} ${DEST_SRV}/"

# ─── CLIENTE UBUNTU ──────────────────────────────────────────────────────────
header "Descargando paquetes del CLIENTE Ubuntu (cifs-utils, gvfs-backends...)"
DEST_CLI_UBU="${SCRIPT_DIR}/paquetes/cliente_ubuntu"
descargar_apt "$DEST_CLI_UBU" cifs-utils smbclient gvfs-backends
echo ""
echo -e "  ${VERDE}Guardados en:${RESET} ${DEST_CLI_UBU}/"

# ─── CLIENTE ARCH ────────────────────────────────────────────────────────────
header "Descargando paquetes del CLIENTE Arch Linux"
DEST_CLI_ARCH="${SCRIPT_DIR}/paquetes/cliente_arch"
mkdir -p "$DEST_CLI_ARCH"

if command -v pacman &>/dev/null; then
    # Si estamos en Arch, podemos descargar directamente con pacman
    pacman -Sw --cachedir "$DEST_CLI_ARCH" --noconfirm \
        cifs-utils smbclient gvfs gvfs-smb 2>&1 | tail -5 || true
    NUM_PKG=$(ls "$DEST_CLI_ARCH"/*.pkg.tar.* 2>/dev/null | wc -l)
    ok "Total paquetes Arch en ${DEST_CLI_ARCH}: ${NUM_PKG}"
else
    echo -e "  ${AMARILLO}AVISO: Este no es un sistema Arch.${RESET}"
    echo "  Los paquetes para el cliente Arch deben descargarse desde"
    echo "  una maquina con Arch Linux con el comando:"
    echo ""
    echo "    sudo pacman -Sw --cachedir ./paquetes/cliente_arch/ --noconfirm \\"
    echo "      cifs-utils smbclient gvfs gvfs-smb"
    echo ""
    echo "  Luego copia la carpeta paquetes/cliente_arch/ al proyecto."
fi
echo ""
echo -e "  ${VERDE}Guardados en:${RESET} ${DEST_CLI_ARCH}/"

# ─── RESUMEN ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${VERDE}${NEGRITA}+============================================================+${RESET}"
echo -e "${VERDE}${NEGRITA}|  Descarga completada.                                      |${RESET}"
echo -e "${VERDE}${NEGRITA}|                                                            |${RESET}"
echo -e "${VERDE}${NEGRITA}|  Los scripts de setup detectaran automaticamente           |${RESET}"
echo -e "${VERDE}${NEGRITA}|  estos paquetes e instalaran sin internet.                 |${RESET}"
echo -e "${VERDE}${NEGRITA}+============================================================+${RESET}"
echo ""
echo "  Estructura generada:"
echo "    paquetes/"
echo "    ├── servidor/        → para setup_servidor.sh"
echo "    ├── cliente_ubuntu/  → para setup_cliente_ubuntu.sh"
echo "    └── cliente_arch/    → para setup_cliente_arch.sh"
echo ""
