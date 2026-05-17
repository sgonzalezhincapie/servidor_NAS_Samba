#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT DE CONFIGURACIÓN DEL SERVIDOR NAS
# ═══════════════════════════════════════════════════════════════════════════════
# Servidor  : Ubuntu Server 22.04.5 LTS (Jammy Jellyfish) o superior
# Protocolo : Samba / SMB2+
#
# USO:
#   sudo bash setup_servidor.sh
#
# DESCRIPCIÓN:
#   Configura desde cero un servidor NAS con Samba. El script es interactivo:
#   pregunta los grupos de departamento, usuarios y contraseñas antes de aplicar
#   ningún cambio. Crea estructura de carpetas, permisos POSIX + ACLs, instala y
#   arranca Samba con el firewall abierto.
# ═══════════════════════════════════════════════════════════════════════════════

set -e

VERDE='\033[0;32m'
ROJO='\033[0;31m'
AMARILLO='\033[1;33m'
CYAN='\033[0;36m'
NEGRITA='\033[1m'
RESET='\033[0m'

ok()     { echo -e "    ${VERDE}checkmark${RESET} $*"; }
err()    { echo -e "    ${ROJO}x ERROR:${RESET} $*"; }
info()   { echo -e "    ${AMARILLO}i${RESET} $*"; }
header() {
    echo ""
    echo -e "${CYAN}${NEGRITA}============================================================${RESET}"
    echo -e "${CYAN}${NEGRITA}   $*${RESET}"
    echo -e "${CYAN}${NEGRITA}============================================================${RESET}"
    echo ""
}

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${ROJO}ERROR: Este script debe ejecutarse con sudo.${RESET}"
    echo "  Uso: sudo bash setup_servidor.sh"
    exit 1
fi

header "CONFIGURACION DEL SERVIDOR NAS"
echo "  Este script te preguntara los grupos, usuarios y contrasenas"
echo "  antes de configurar nada. Puedes cancelar con Ctrl+C en cualquier momento."
echo ""

leer_password() {
    local VAR_NAME="$1"
    local PROMPT="$2"
    local PASS="" PASS2=""
    while true; do
        read -rsp "    ${PROMPT}: " PASS; echo ""
        read -rsp "    Confirmar contrasena: " PASS2; echo ""
        if [ "$PASS" != "$PASS2" ]; then
            echo -e "    ${ROJO}Las contrasenas no coinciden.${RESET}"
        elif [ -z "$PASS" ]; then
            echo -e "    ${ROJO}La contrasena no puede estar vacia.${RESET}"
        else
            printf -v "$VAR_NAME" '%s' "$PASS"
            break
        fi
    done
}

# ─── BLOQUE A: GRUPOS ────────────────────────────────────────────────────────
echo -e "${NEGRITA}[A] GRUPOS DE DEPARTAMENTO (uno por VLAN/departamento)${RESET}"
echo ""
echo "  Grupos por defecto:"
GRUPOS_DEFAULT=("Financiera" "Produccion" "Design" "RH")
for i in "${!GRUPOS_DEFAULT[@]}"; do
    echo "    $((i+1)). ${GRUPOS_DEFAULT[$i]}"
done
echo ""
read -rp "  Deseas usar estos grupos? [S/n]: " RESP_GRUPOS
RESP_GRUPOS="${RESP_GRUPOS:-S}"

GRUPOS=()
if [[ "$RESP_GRUPOS" =~ ^[Ss]$ ]]; then
    GRUPOS=("${GRUPOS_DEFAULT[@]}")
    echo -e "    ${VERDE}Grupos por defecto seleccionados.${RESET}"
else
    while true; do
        read -rp "  Cuantos grupos quieres crear? (minimo 1): " NUM_GRUPOS
        [[ "$NUM_GRUPOS" =~ ^[1-9][0-9]*$ ]] && break
        echo -e "    ${ROJO}Ingresa un numero valido mayor a 0.${RESET}"
    done
    echo "  Ingresa el nombre de cada grupo (sin espacios ni acentos):"
    for ((i=1; i<=NUM_GRUPOS; i++)); do
        while true; do
            read -rp "    Grupo $i: " NOMBRE_GRUPO
            if [[ "$NOMBRE_GRUPO" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                GRUPOS+=("$NOMBRE_GRUPO"); break
            else
                echo -e "    ${ROJO}Solo letras, numeros, guiones y guion bajo.${RESET}"
            fi
        done
    done
fi
echo ""

# ─── BLOQUE B: CONTRASENAS ADMIN E INVITADO ──────────────────────────────────
echo -e "${NEGRITA}[B] CONTRASENAS DE USUARIOS PREDETERMINADOS${RESET}"
echo ""
echo "  Siempre se crean:"
echo "  admin    => acceso total al NAS"
echo "  invitado => solo lectura en la carpeta publica"
echo ""
leer_password PASS_ADMIN    "  Contrasena para admin"
leer_password PASS_INVITADO "  Contrasena para invitado"
echo ""

# ─── BLOQUE C: USUARIOS ADICIONALES ──────────────────────────────────────────
echo -e "${NEGRITA}[C] USUARIOS ADICIONALES${RESET}"
echo ""
read -rp "  Quieres agregar usuarios de departamento ahora? [S/n]: " RESP_USERS
RESP_USERS="${RESP_USERS:-S}"

NOMBRES_USERS=()
PASSES_USERS=()
GRUPOS_USERS=()

if [[ "$RESP_USERS" =~ ^[Ss]$ ]]; then
    while true; do
        read -rp "  Cuantos usuarios (ademas de admin e invitado)?: " NUM_USERS
        [[ "$NUM_USERS" =~ ^[0-9]+$ ]] && break
        echo -e "    ${ROJO}Ingresa un numero valido (0 o mas).${RESET}"
    done

    if [ "$NUM_USERS" -gt 0 ]; then
        echo ""
        echo "  Grupos disponibles:"
        for i in "${!GRUPOS[@]}"; do
            echo "    $((i+1)). ${GRUPOS[$i]}"
        done
        echo ""
        for ((i=1; i<=NUM_USERS; i++)); do
            echo -e "  ${NEGRITA}--- Usuario $i de $NUM_USERS ---${RESET}"
            while true; do
                read -rp "    Nombre de usuario (minusculas): " UNAME
                [[ "$UNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] && break
                echo -e "    ${ROJO}Solo minusculas, numeros, guiones. Debe empezar con letra.${RESET}"
            done
            leer_password UPASS "    Contrasena para $UNAME"
            while true; do
                read -rp "    A que grupo pertenece? (numero 1-${#GRUPOS[@]}): " GNUM
                if [[ "$GNUM" =~ ^[0-9]+$ ]] && [ "$GNUM" -ge 1 ] && [ "$GNUM" -le "${#GRUPOS[@]}" ]; then
                    UGRUPO="${GRUPOS[$((GNUM-1))]}"; break
                fi
                echo -e "    ${ROJO}Elige un numero entre 1 y ${#GRUPOS[@]}.${RESET}"
            done
            NOMBRES_USERS+=("$UNAME")
            PASSES_USERS+=("$UPASS")
            GRUPOS_USERS+=("$UGRUPO")
            echo -e "    ${VERDE}${UNAME} -> grupo ${UGRUPO}${RESET}"
            echo ""
        done
    fi
fi

# ─── RESUMEN ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${NEGRITA}+==================================================+${RESET}"
echo -e "${NEGRITA}|       RESUMEN — SE VA A CONFIGURAR               |${RESET}"
echo -e "${NEGRITA}+==================================================+${RESET}"
echo ""
echo "  Grupos de departamento:"
for g in "${GRUPOS[@]}"; do echo "    * $g"; done
echo ""
echo "  Usuarios:"
echo "    * admin    (acceso total)"
echo "    * invitado (solo lectura publica)"
for i in "${!NOMBRES_USERS[@]}"; do
    echo "    * ${NOMBRES_USERS[$i]}  -> grupo ${GRUPOS_USERS[$i]}"
done
echo ""
read -rp "  Confirmas la instalacion? [S/n]: " CONFIRMAR
CONFIRMAR="${CONFIRMAR:-S}"
if [[ ! "$CONFIRMAR" =~ ^[Ss]$ ]]; then
    echo "  Operacion cancelada."
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════════
# INSTALACION
# ═══════════════════════════════════════════════════════════════════════════════

header "1/10 — Actualizar lista de paquetes"
apt update -y 2>&1 | tail -1 || true
echo -e "    ${VERDE}Lista actualizada.${RESET}"

header "2/10 — Instalar Samba y herramientas"
DEBIAN_FRONTEND=noninteractive apt install -y samba samba-common smbclient acl attr 2>&1 | tail -5 || true
if ! command -v smbd &>/dev/null; then
    echo -e "    ${ROJO}ERROR: Samba no se instalo correctamente. Intenta: sudo apt install -y samba${RESET}"
    exit 1
fi
echo -e "    ${VERDE}Samba instalado: $(smbd --version)${RESET}"

header "3/10 — Detectar interfaz de red"
INTERFAZ=$(ip -4 route show default 2>/dev/null | awk '{print $5}' | head -1)
if [ -z "$INTERFAZ" ]; then
    echo ""
    echo "  No se detecto interfaz automaticamente. Interfaces disponibles:"
    ip -4 addr show | grep -E '^[0-9]+:' | awk -F': ' '{print "    *", $2}'
    echo ""
    read -rp "  Ingresa el nombre de la interfaz de red (ej: eth0, ens3): " INTERFAZ
fi
echo -e "    ${VERDE}Interfaz de red: ${INTERFAZ}${RESET}"

header "4/10 — Crear estructura de directorios"
mkdir -p /srv/datacorp/publico /srv/datacorp/privado /srv/datacorp/admin
for g in "${GRUPOS[@]}"; do
    GLOW=$(echo "$g" | tr '[:upper:]' '[:lower:]')
    mkdir -p "/srv/datacorp/departamentos/${GLOW}"
    echo -e "    ${VERDE}Creado: /srv/datacorp/departamentos/${GLOW}${RESET}"
done
echo -e "    ${VERDE}Carpetas base: publico, privado, admin${RESET}"

header "5/10 — Crear grupos del sistema"
groupadd administradores 2>/dev/null || true
groupadd invitados       2>/dev/null || true
groupadd usuarios        2>/dev/null || true
for g in "${GRUPOS[@]}"; do
    GLOW=$(echo "$g" | tr '[:upper:]' '[:lower:]')
    groupadd "$GLOW" 2>/dev/null || true
    echo -e "    ${VERDE}Grupo: $GLOW${RESET}"
done

header "6/10 — Crear usuarios y asignar grupos"
id admin    &>/dev/null || useradd --no-create-home --shell /usr/sbin/nologin admin
id invitado &>/dev/null || useradd --no-create-home --shell /usr/sbin/nologin invitado
usermod -aG administradores admin
usermod -aG invitados invitado
echo -e "    ${VERDE}admin -> administradores${RESET}"
echo -e "    ${VERDE}invitado -> invitados${RESET}"

for i in "${!NOMBRES_USERS[@]}"; do
    UNAME="${NOMBRES_USERS[$i]}"
    UGRUPO="${GRUPOS_USERS[$i]}"
    UGLOW=$(echo "$UGRUPO" | tr '[:upper:]' '[:lower:]')
    id "$UNAME" &>/dev/null || useradd --no-create-home --shell /usr/sbin/nologin "$UNAME"
    usermod -aG usuarios "$UNAME"
    usermod -aG "$UGLOW" "$UNAME"
    echo -e "    ${VERDE}${UNAME} -> usuarios, ${UGLOW}${RESET}"
done

header "7/10 — Permisos POSIX"
chown root:administradores /srv/datacorp && chmod 755 /srv/datacorp
chown root:administradores /srv/datacorp/publico && chmod 775 /srv/datacorp/publico
echo -e "    ${VERDE}/publico -> 775${RESET}"
chown root:usuarios /srv/datacorp/departamentos && chmod 750 /srv/datacorp/departamentos
setfacl -m g:administradores:r-x /srv/datacorp/departamentos
echo -e "    ${VERDE}/departamentos -> 750 + ACL admin=r-x${RESET}"
for g in "${GRUPOS[@]}"; do
    GLOW=$(echo "$g" | tr '[:upper:]' '[:lower:]')
    chown root:"$GLOW" "/srv/datacorp/departamentos/${GLOW}"
    chmod 2770 "/srv/datacorp/departamentos/${GLOW}"
    echo -e "    ${VERDE}/departamentos/${GLOW} -> 2770 SGID${RESET}"
done
chown root:administradores /srv/datacorp/privado && chmod 770 /srv/datacorp/privado
chown root:administradores /srv/datacorp/admin   && chmod 770 /srv/datacorp/admin
echo -e "    ${VERDE}/privado y /admin -> 770${RESET}"

header "8/10 — Aplicar ACLs"
setfacl -R -b /srv/datacorp/publico
setfacl -R -m g:administradores:rwx /srv/datacorp/publico
setfacl -R -m g:usuarios:r-x /srv/datacorp/publico
setfacl -R -m g:invitados:r-x /srv/datacorp/publico
setfacl -d -m g:administradores:rwx /srv/datacorp/publico
setfacl -d -m g:usuarios:r-x /srv/datacorp/publico
setfacl -d -m g:invitados:r-x /srv/datacorp/publico
echo -e "    ${VERDE}/publico -> admin=rwx, usuarios=r-x, invitados=r-x${RESET}"

for g in "${GRUPOS[@]}"; do
    GLOW=$(echo "$g" | tr '[:upper:]' '[:lower:]')
    DPATH="/srv/datacorp/departamentos/${GLOW}"
    setfacl -R -b "$DPATH"
    setfacl -R -m g:administradores:rwx "$DPATH"
    setfacl -R -m "g:${GLOW}:rwx" "$DPATH"
    setfacl -d -m g:administradores:rwx "$DPATH"
    setfacl -d -m "g:${GLOW}:rwx" "$DPATH"
    echo -e "    ${VERDE}/departamentos/${GLOW} -> admin=rwx, ${GLOW}=rwx${RESET}"
done

setfacl -R -b /srv/datacorp/privado && setfacl -R -m g:administradores:rwx /srv/datacorp/privado
setfacl -d -m g:administradores:rwx /srv/datacorp/privado
setfacl -R -b /srv/datacorp/admin   && setfacl -R -m g:administradores:rwx /srv/datacorp/admin
setfacl -d -m g:administradores:rwx /srv/datacorp/admin
echo -e "    ${VERDE}/privado y /admin -> admin=rwx${RESET}"

header "9/10 — Registrar usuarios en Samba"
(echo "$PASS_ADMIN";    echo "$PASS_ADMIN")    | smbpasswd -s -a admin;    smbpasswd -e admin
echo -e "    ${VERDE}admin registrado.${RESET}"
(echo "$PASS_INVITADO"; echo "$PASS_INVITADO") | smbpasswd -s -a invitado; smbpasswd -e invitado
echo -e "    ${VERDE}invitado registrado.${RESET}"
for i in "${!NOMBRES_USERS[@]}"; do
    UNAME="${NOMBRES_USERS[$i]}"; UPASS="${PASSES_USERS[$i]}"
    (echo "$UPASS"; echo "$UPASS") | smbpasswd -s -a "$UNAME"; smbpasswd -e "$UNAME"
    echo -e "    ${VERDE}${UNAME} registrado.${RESET}"
done

header "10/10 — Instalar smb.conf y arrancar Samba"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/smb.conf" ]; then
    echo -e "    ${ROJO}ERROR: No se encontro smb.conf en $SCRIPT_DIR${RESET}"
    exit 1
fi
[ -f /etc/samba/smb.conf ] && cp /etc/samba/smb.conf "/etc/samba/smb.conf.backup.$(date +%Y%m%d_%H%M%S)"

# Inyectar la interfaz detectada
sed "s|<INTERFAZ_RED>|${INTERFAZ}|g" "$SCRIPT_DIR/smb.conf" > /etc/samba/smb.conf
echo -e "    ${VERDE}smb.conf instalado con interfaz '${INTERFAZ}'.${RESET}"

# Agregar shares de departamento generados dinamicamente
cat >> /etc/samba/smb.conf << 'SHARES_MARK'

# === SHARES DE DEPARTAMENTOS (generados por setup_servidor.sh) ===
SHARES_MARK

for g in "${GRUPOS[@]}"; do
    GLOW=$(echo "$g" | tr '[:upper:]' '[:lower:]')
    printf '\n[%s]\n   comment = Departamento %s\n   path = /srv/datacorp/departamentos/%s\n   browseable = yes\n   writable = yes\n   guest ok = no\n   valid users = @%s @administradores\n   write list = @%s @administradores\n   force group = %s\n   create mask = 0660\n   directory mask = 0770\n' \
        "$GLOW" "$g" "$GLOW" "$GLOW" "$GLOW" "$GLOW" >> /etc/samba/smb.conf
    echo -e "    ${VERDE}Share [${GLOW}] generado.${RESET}"
done

testparm -s &>/dev/null && echo -e "    ${VERDE}smb.conf validado sin errores.${RESET}" || \
    echo -e "    ${AMARILLO}Advertencia en testparm. Verifica con: sudo testparm -s${RESET}"

if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "active"; then
    ufw allow samba
    echo -e "    ${VERDE}UFW: puertos de Samba abiertos.${RESET}"
else
    echo -e "    ${AMARILLO}UFW no esta activo. Si usas otro firewall, abre los puertos 139/TCP y 445/TCP.${RESET}"
fi

systemctl enable smbd nmbd &>/dev/null
systemctl restart smbd && echo -e "    ${VERDE}smbd activo.${RESET}"
systemctl restart nmbd 2>/dev/null && echo -e "    ${VERDE}nmbd activo.${RESET}" || \
    echo -e "    ${AMARILLO}nmbd no pudo iniciarse (no afecta el servicio; los clientes se conectan por IP).${RESET}"

IP_ACTUAL=$(ip -4 addr show "$INTERFAZ" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)

echo ""
echo -e "${VERDE}${NEGRITA}+======================================================+${RESET}"
echo -e "${VERDE}${NEGRITA}|         SERVIDOR NAS LISTO                           |${RESET}"
echo -e "${VERDE}${NEGRITA}+======================================================+${RESET}"
echo ""
echo "  IP del servidor: ${IP_ACTUAL:-'ejecuta: ip -4 addr show'}"
echo ""
echo "  Comparte esta IP con los clientes:"
echo "    Windows     -> abrir Explorador y escribir:  \\\\${IP_ACTUAL:-IP_SERVIDOR}"
echo "    Arch/Ubuntu -> abrir gestor de archivos y escribir: smb://${IP_ACTUAL:-IP_SERVIDOR}"
echo ""
echo "  Comandos utiles de administracion:"
echo "  - Agregar usuario:"
echo "      sudo useradd --no-create-home --shell /usr/sbin/nologin NOMBRE"
echo "      sudo usermod -aG usuarios NOMBRE && sudo usermod -aG GRUPO NOMBRE"
echo "      sudo smbpasswd -a NOMBRE"
echo "  - Cambiar contrasena:  sudo smbpasswd NOMBRE"
echo "  - Ver usuarios Samba:  sudo pdbedit -L"
echo "  - Verificar permisos:  sudo bash verificacion_permisos.sh"
echo ""
