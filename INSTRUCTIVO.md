# Laboratorio NAS con Samba — DataCorp

**Proyecto**: Comunicaciones III — Tema 3  
**Integrantes**: Manuela Marín Rojo, Daniel Trujillo F, Santiago González  
**Fecha de entrega**: Viernes 17 de abril de 2026  

---

## Tabla de Contenidos

1. [Introducción](#1-introducción-qué-es-este-laboratorio-y-qué-demuestra)
2. [Requisitos previos](#2-requisitos-previos)
3. [Datos del entorno (completar antes de empezar)](#3-datos-del-entorno-completar-antes-de-empezar)
4. [Diagrama del entorno](#4-diagrama-del-entorno)
5. [Marco teórico: ¿Qué es un NAS y qué es Samba?](#5-marco-teórico-qué-es-un-nas-y-qué-es-samba)
6. [PARTE A — Configuración del Servidor (Ubuntu 24.04)](#parte-a--configuración-del-servidor-ubuntu-2404)
7. [PARTE B — Configuración del Cliente (Arch Linux)](#parte-b--configuración-del-cliente-arch-linux)
8. [Pruebas de Verificación de Perfiles](#pruebas-de-verificación-de-perfiles)
9. [Solución de Problemas](#solución-de-problemas)
10. [Preguntas Frecuentes para la Exposición](#preguntas-frecuentes-para-la-exposición)

---

## 1. Introducción: Qué es este laboratorio y qué demuestra

Este laboratorio implementa un **servidor NAS (Network Attached Storage)** usando **Samba** en un entorno real con dos computadores conectados a la misma red local.

### ¿Qué es un NAS?

Imagina que en la empresa **DataCorp** hay un cuarto de archivos. Ese cuarto tiene varios estantes:
- Uno con documentos **públicos** que cualquiera puede leer (como el tablón de anuncios).
- Uno con los archivos del **departamento de contabilidad** (solo entra quien tiene la llave).
- Uno con los archivos del **departamento de sistemas** (igual, llave propia).
- Una **caja fuerte** donde solo el jefe puede entrar.

Un **NAS** es exactamente eso, pero digital: un servidor que comparte carpetas en la red, y cada persona tiene acceso solo a lo que le corresponde según su rol y departamento.

### ¿Qué es Samba?

**Samba** es un software libre que implementa el protocolo **SMB/CIFS** (Server Message Block / Common Internet File System). Este protocolo es el estándar que usan Windows, Linux y macOS para compartir archivos en red. Gracias a Samba, un servidor Linux puede compartir carpetas que cualquier sistema operativo puede acceder como si fueran directorios locales.

### ¿Qué demuestra este laboratorio?

1. **Compartir archivos en red** entre un servidor Linux y un cliente Linux.
2. **Control de acceso basado en roles (RBAC)**: diferentes usuarios tienen diferentes permisos.
3. **Seguridad en capas**: permisos POSIX + ACLs + directivas de Samba.
4. **Configuración real**: no usamos máquinas virtuales sino computadores reales.

---

## 2. Requisitos previos

### Hardware
- **2 computadores** conectados a la misma red local (LAN), ya sea por cable Ethernet o WiFi.
- **Conexión a internet** (solo para instalar paquetes; el NAS funciona sin internet).

### Software — Servidor
- **Ubuntu 24.04 LTS** (Noble Numbat) instalado y con acceso a terminal.
- Acceso como **root** (o usuario con `sudo`).

### Software — Cliente
- **Arch Linux** (rolling release, actualizado).
- Acceso como **root** (o usuario con `sudo`).

### Conocimientos asumidos
- Saber abrir una terminal.
- Saber escribir y ejecutar comandos básicos (`cd`, `ls`, `sudo`).
- *No se requiere experiencia con Samba, NFS ni redes avanzadas.*

---

## 3. Datos del entorno (completar antes de empezar)

**Antes de comenzar, identifica y anota estos datos. Los necesitarás en múltiples pasos.**

| Variable                  | Valor a completar         | Cómo encontrarlo                                           |
|---------------------------|---------------------------|------------------------------------------------------------|
| IP del servidor           | ______________________    | En el servidor: `ip -4 addr show \| grep inet`             |
| Interfaz de red (servidor)| ______________________    | En el servidor: `ip a \| grep -E '^[0-9]+:'`               |
| IP del cliente            | ______________________    | En el cliente: `ip -4 addr show \| grep inet`              |
| Nombre del grupo de trabajo| DATACORP                 | Ya definido en este laboratorio                            |
| Subred                    | ______________________    | Normalmente `192.168.x.0/24` o similar                     |
| Gateway (puerta de enlace)| ______________________    | `ip route \| grep default`                                 |

### ¿Cómo identificar la interfaz de red?

En el **servidor** Ubuntu, ejecuta:

```bash
ip a | grep -E '^[0-9]+:'
```

Verás algo como:

```
1: lo: <LOOPBACK,UP,LOWER_UP> ...
2: enp3s0: <BROADCAST,MULTICAST,UP,LOWER_UP> ...
```

- `lo` es la interfaz **loopback** (localhost) — **ignórala**.
- `enp3s0` (o `eth0`, `ens33`, `enp0s3`, `eno1`, etc.) es tu interfaz de red real — **esa es la que necesitas**.

> **Nombres comunes de interfaces en Ubuntu 24.04:**
> - `eth0` — nombre clásico
> - `ens33` — común en VMware
> - `enp3s0` — nombre por posición PCI (PCI bus 3, slot 0)
> - `enp0s3` — común en VirtualBox
> - `eno1` — nombre embebido en la placa base
> - `wlp2s0` — interfaz WiFi

---

## 4. Diagrama del entorno

```
    ┌──────────────────────────────┐          ┌──────────────────────────────┐
    │       SERVIDOR NAS           │          │         CLIENTE              │
    │    Ubuntu 24.04 LTS          │          │       Arch Linux             │
    │                              │          │                              │
    │  Samba (smbd + nmbd)         │          │  cifs-utils + smbclient      │
    │  ┌────────────────────────┐  │          │                              │
    │  │  /srv/datacorp/        │  │          │  Puntos de montaje:          │
    │  │  ├── publico/          │  │          │  /mnt/datacorp/              │
    │  │  ├── departamentos/    │  │          │  ├── publico/                │
    │  │  │   ├── contabilidad/ │  │          │  ├── contabilidad/           │
    │  │  │   └── sistemas/     │  │          │  ├── sistemas/               │
    │  │  ├── privado/          │  │          │  ├── privado/                │
    │  │  └── admin/            │  │          │  └── admin/                  │
    │  └────────────────────────┘  │          │                              │
    │                              │          │                              │
    │  IP: <IP_SERVIDOR>           │          │  IP: (automática o fija)     │
    │  Interfaz: <INTERFAZ_RED>    │          │                              │
    └──────────────┬───────────────┘          └──────────────┬───────────────┘
                   │                                          │
                   │         Red Local (LAN)                  │
                   │    ┌──────────────────────┐              │
                   └────┤   Switch / Router     ├─────────────┘
                        │  192.168.x.0/24      │
                        └──────────────────────┘
                        
    Protocolo: SMB3 (puerto 445/TCP)
    Autenticación: Usuario/Contraseña (Samba local)
```

### Flujo de comunicación

```
    Cliente                                    Servidor
    ┌──────┐    1. Solicitud SMB (puerto 445)  ┌──────┐
    │ Arch │ ────────────────────────────────→ │Ubuntu│
    │Linux │    2. Autenticación (user/pass)    │24.04 │
    │      │ ────────────────────────────────→ │      │
    │      │    3. Samba verifica credenciales  │      │
    │      │    4. Samba verifica permisos      │      │
    │      │       (smb.conf + POSIX + ACL)    │      │
    │      │    5. Acceso concedido/denegado    │      │
    │      │ ←──────────────────────────────── │      │
    │      │    6. Transferencia de archivos    │      │
    │      │ ←────────────────────────────────→│      │
    └──────┘                                    └──────┘
```

---

## 5. Marco teórico: ¿Qué es un NAS y qué es Samba?

### NAS vs SAN vs DAS

| Tipo | Significado | Protocolo | Analogía |
|------|------------|-----------|----------|
| **DAS** | Direct Attached Storage | USB, SATA | Un disco duro conectado directamente a tu PC |
| **NAS** | Network Attached Storage | SMB, NFS | Un cuarto de archivos compartido por red (lo que hacemos hoy) |
| **SAN** | Storage Area Network | iSCSI, Fibre Channel | Un disco entero dedicado a servidores de alto rendimiento |

### Protocolo SMB/CIFS

- **SMB** (Server Message Block) es el protocolo para compartir archivos en red.
- **CIFS** (Common Internet File System) es una versión antigua de SMB (prácticamente sinónimos).
- Versiones: SMB1 (obsoleto, inseguro), **SMB2** (mejorado), **SMB3** (cifrado, actual).
- Puerto: **445/TCP** (principal) y 139/TCP (legacy, NetBIOS).

### RBAC (Control de Acceso Basado en Roles)

En vez de asignar permisos a cada usuario individualmente, **RBAC** los agrupa en **roles**:

| Rol | Grupo Linux | Permisos |
|-----|-------------|----------|
| Administrador | `administradores` | Acceso total a todo |
| Usuario estándar | `usuarios` | Acceso a su departamento |
| Invitado | `invitados` | Solo lectura pública |

### Capas de seguridad en nuestro NAS

Nuestro sistema tiene **tres capas de seguridad** que trabajan juntas:

```
    ┌─────────────────────────────────────┐
    │  Capa 3: Directivas de Samba        │  ← smb.conf (valid users, write list)
    │  (¿Quién puede conectarse al share?)│
    ├─────────────────────────────────────┤
    │  Capa 2: ACLs (setfacl/getfacl)     │  ← Control granular por grupo
    │  (¿Qué operaciones puede hacer?)    │
    ├─────────────────────────────────────┤
    │  Capa 1: Permisos POSIX             │  ← chmod/chown (rwxrwxrwx)
    │  (Permisos básicos del sistema)     │
    └─────────────────────────────────────┘
```

**Las tres deben permitir el acceso** para que funcione. Si cualquiera de las tres dice "no", el acceso se deniega.

### Matriz de permisos — DataCorp

| Carpeta                 | administradores | usuarios | invitados |
|-------------------------|:-:|:-:|:-:|
| `/publico`              | R+W | R | R |
| `/departamentos/contabilidad` | R+W | R+W* | Sin acceso |
| `/departamentos/sistemas`     | R+W | R+W* | Sin acceso |
| `/privado`              | R+W | Sin acceso | Sin acceso |
| `/admin`                | R+W | Sin acceso | Sin acceso |

(*) Solo los usuarios que pertenecen al grupo de ese departamento específico.

---

## PARTE A — Configuración del Servidor (Ubuntu 24.04)

### Paso 1: Configurar IP fija con Netplan

**¿Por qué IP fija?** Si el servidor cambia de IP cada vez que reinicia (DHCP), los clientes no sabrán dónde encontrarlo. Una IP fija garantiza que la dirección del servidor sea siempre la misma.

#### 1.1. Identificar la interfaz de red y configuración actual

```bash
# Ver todas las interfaces de red
ip a | grep -E '^[0-9]+:'

# Ver la IP actual del servidor
ip -4 addr show

# Ver la puerta de enlace (gateway) actual
ip route | grep default
```

Ejemplo de salida:

```
1: lo: <LOOPBACK,UP,LOWER_UP>
2: enp3s0: <BROADCAST,MULTICAST,UP,LOWER_UP>

inet 192.168.1.105/24 brd 192.168.1.255 scope global dynamic enp3s0

default via 192.168.1.1 dev enp3s0
```

De aquí extraemos:
- **Interfaz**: `enp3s0`
- **IP actual**: `192.168.1.105`
- **Máscara**: `/24` (equivale a `255.255.255.0`)
- **Gateway**: `192.168.1.1`

#### 1.2. Identificar el servidor DNS

```bash
# Ver el servidor DNS actual
resolvectl status | grep "DNS Servers"
# O alternativamente:
cat /etc/resolv.conf | grep nameserver
```

#### 1.3. Crear el archivo de configuración Netplan

> **NOTA sobre Ubuntu 24.04 vs 22.04:** Ubuntu 24.04 usa **Netplan** como gestor de red por defecto. El archivo YAML puede llamarse `01-netcfg.yaml`, `50-cloud-init.yaml` o similar. Verifica qué archivo existe primero.

```bash
# Ver qué archivos de Netplan ya existen
ls /etc/netplan/
```

Edita (o crea) el archivo de configuración. **Reemplaza los valores** `<INTERFAZ_RED>`, `<IP_SERVIDOR>`, `<GATEWAY>` y `<DNS>` con tus datos reales:

```bash
sudo nano /etc/netplan/01-datacorp-static.yaml
```

Contenido del archivo:

```yaml
# Configuración de red estática para el servidor NAS DataCorp
# IMPORTANTE: Usa espacios, NO tabulaciones. YAML es sensible a la indentación.
network:
  version: 2
  renderer: networkd
  ethernets:
    <INTERFAZ_RED>:         # Reemplazar por tu interfaz (ej: enp3s0)
      dhcp4: no             # Desactivar DHCP (queremos IP fija)
      addresses:
        - <IP_SERVIDOR>/24  # Tu IP fija (ej: 192.168.1.100/24)
      routes:
        - to: default
          via: <GATEWAY>    # Tu puerta de enlace (ej: 192.168.1.1)
      nameservers:
        addresses:
          - 8.8.8.8         # DNS de Google (público y confiable)
          - 8.8.4.4         # DNS secundario de Google
```

**Ejemplo concreto** (si tu interfaz es `enp3s0` y quieres la IP `192.168.1.100`):

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp3s0:
      dhcp4: no
      addresses:
        - 192.168.1.100/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
```

#### 1.4. Aplicar la configuración

```bash
# Validar que el YAML está bien escrito (detecta errores de sintaxis)
sudo netplan generate

# Aplicar la nueva configuración de red
sudo netplan apply

# Verificar que la IP fija se asignó correctamente
ip -4 addr show <INTERFAZ_RED>
```

> **⚠ CUIDADO:** Si estás conectado por SSH, al cambiar la IP puedes perder la conexión. Tendrás que reconectarte usando la nueva IP.

#### 1.5. Verificar conectividad

```bash
# Verificar que tienes internet (para instalar paquetes)
ping -c 3 8.8.8.8

# Verificar resolución de nombres
ping -c 3 google.com
```

---

### Paso 2: Ejecutar setup_servidor.sh

#### 2.1. Copiar los archivos al servidor

Transfiere los archivos `setup_servidor.sh` y `smb.conf` al servidor. Puedes usar USB, SCP, o simplemente copiar el contenido:

**Opción A — Con SCP desde el cliente:**

```bash
# Desde el cliente Arch Linux:
scp setup_servidor.sh smb.conf usuario@<IP_SERVIDOR>:~/
```

**Opción B — Copiar y pegar directamente en el servidor:**

```bash
# En el servidor, crear los archivos:
nano ~/setup_servidor.sh
# (pegar el contenido del archivo)

nano ~/smb.conf
# (pegar el contenido del archivo)
```

#### 2.2. Editar smb.conf con tus datos

Antes de ejecutar el script, edita `smb.conf` para reemplazar `<INTERFAZ_RED>`:

```bash
nano ~/smb.conf
```

Busca la línea:
```
   interfaces = lo <INTERFAZ_RED>
```

Reemplaza `<INTERFAZ_RED>` por tu interfaz real (ej: `enp3s0`):
```
   interfaces = lo enp3s0
```

#### 2.3. Ejecutar el script

```bash
# Hacer el script ejecutable
chmod +x ~/setup_servidor.sh

# Ejecutar como root
sudo bash ~/setup_servidor.sh
```

El script mostrará el progreso paso a paso. Si hay algún error, se detendrá inmediatamente y mostrará qué falló.

#### 2.4. Verificar la ejecución

Al final del script, verás un resumen. Verifica que todos los ítems tengan ✓.

---

### Paso 3: Verificar que Samba está corriendo

Después de ejecutar el script, verifica manualmente:

```bash
# Verificar que el servicio smbd está activo
sudo systemctl status smbd
```

Deberías ver: `Active: active (running)`

```bash
# Verificar que el servicio nmbd está activo
sudo systemctl status nmbd
```

Deberías ver: `Active: active (running)`

```bash
# Verificar que Samba escucha en el puerto 445
sudo ss -tlnp | grep 445
```

Deberías ver algo como: `LISTEN 0 50 0.0.0.0:445 0.0.0.0:*`

```bash
# Validar la configuración de Samba
testparm -s
```

Este comando muestra la configuración efectiva de Samba. Revisa que los shares `[publico]`, `[contabilidad]`, `[sistemas]`, `[privado]` y `[admin]` aparezcan.

```bash
# Verificar que los shares son accesibles
smbclient -L localhost -U admin
```

Ingresa la contraseña de admin (`Admin2026`) cuando la solicite. Deberías ver la lista de shares.

---

### Paso 4: Verificar permisos con getfacl

```bash
# Verificar ACLs de cada directorio

echo "=== /publico ==="
getfacl /srv/datacorp/publico

echo "=== /departamentos/contabilidad ==="
getfacl /srv/datacorp/departamentos/contabilidad

echo "=== /departamentos/sistemas ==="
getfacl /srv/datacorp/departamentos/sistemas

echo "=== /privado ==="
getfacl /srv/datacorp/privado

echo "=== /admin ==="
getfacl /srv/datacorp/admin
```

**¿Qué buscar en la salida de getfacl?**

Para `/publico` deberías ver:
```
# file: srv/datacorp/publico
# owner: root
# group: administradores
user::rwx
group::rwx
group:administradores:rwx
group:usuarios:r-x
group:invitados:r-x
mask::rwx
other::r-x
```

Esto significa:
- `group:administradores:rwx` → los administradores pueden leer, escribir y acceder.
- `group:usuarios:r-x` → los usuarios pueden leer y acceder, pero NO escribir.
- `group:invitados:r-x` → los invitados pueden leer y acceder, pero NO escribir.

```bash
# Verificar la pertenencia de usuarios a grupos
groups admin
groups juan
groups maria
groups invitado
```

Salida esperada:
```
admin : admin administradores
juan : juan usuarios contabilidad
maria : maria usuarios sistemas
invitado : invitado invitados
```

---

## PARTE B — Configuración del Cliente (Arch Linux)

### Paso 1: Instalar herramientas necesarias

```bash
# Actualizar la base de datos de paquetes
sudo pacman -Sy

# Instalar cifs-utils (para mount.cifs) y smbclient (para pruebas)
# --needed evita reinstalar paquetes que ya están instalados
sudo pacman -S --needed cifs-utils smbclient
```

**¿Qué instala cada paquete?**
- `cifs-utils`: proporciona el comando `mount.cifs` que permite montar carpetas compartidas SMB como si fueran directorios locales.
- `smbclient`: herramienta de línea de comandos para explorar servidores SMB. Funciona como un "mini explorador de archivos" en terminal.

**Verificar la instalación:**

```bash
# Verificar que mount.cifs existe
which mount.cifs

# Verificar versiones
smbclient --version
```

---

### Paso 2: Verificar conectividad con el servidor

```bash
# Paso 2.1: Verificar que hay conexión de red (ping)
ping -c 3 <IP_SERVIDOR>
```

Si responde, hay conexión de red. Si no:
- Verifica que ambos equipos están en la misma red.
- Verifica que el cable/WiFi está conectado.
- Verifica que el firewall del servidor permite Samba.

```bash
# Paso 2.2: Verificar que Samba está accesible (listar shares)
smbclient -L //<IP_SERVIDOR> -N
```

> **Nota:** `-N` significa "sin contraseña" (conexión anónima). Puede que no muestre todos los shares si `map to guest = bad user` está activo. Para ver todos:

```bash
# Listar shares autenticándose como admin
smbclient -L //<IP_SERVIDOR> -U admin
# Contraseña: Admin2026
```

Deberías ver algo como:
```
Sharename       Type      Comment
---------       ----      -------
publico         Disk      Carpeta publica de DataCorp - Solo lectura para todos
contabilidad    Disk      Departamento de Contabilidad - Acceso restringido
sistemas        Disk      Departamento de Sistemas - Acceso restringido
privado         Disk      Carpeta privada - Solo administradores
```

> **Nota:** `[admin]` no aparece porque tiene `browseable = no` (es un share oculto).

---

### Paso 3: Montar los recursos compartidos

#### 3.1. Crear puntos de montaje

```bash
sudo mkdir -p /mnt/datacorp/{publico,contabilidad,sistemas,privado,admin}
```

#### 3.2. Montar como invitado (/publico)

```bash
sudo mount.cifs //<IP_SERVIDOR>/publico /mnt/datacorp/publico \
  -o guest,vers=3.0,uid=$(id -u),gid=$(id -g),iocharset=utf8
```

**Explicación de cada opción:**
| Opción | Significado |
|--------|-------------|
| `guest` | Conectarse sin usuario/contraseña |
| `vers=3.0` | Usar SMB versión 3.0 (seguro y compatible) |
| `uid=$(id -u)` | Los archivos montados se ven como del usuario actual |
| `gid=$(id -g)` | Los archivos montados se ven con el grupo actual |
| `iocharset=utf8` | Soporte para caracteres especiales (ñ, acentos) |

Verificar:
```bash
ls -la /mnt/datacorp/publico
```

#### 3.3. Montar como juan (/contabilidad)

```bash
# NOTA: Cambiar contraseña en producción
sudo mount.cifs //<IP_SERVIDOR>/contabilidad /mnt/datacorp/contabilidad \
  -o username=juan,password=Juan2026,vers=3.0,uid=$(id -u),gid=$(id -g),iocharset=utf8
```

> **Alternativa más segura** (pide la contraseña interactivamente):
> ```bash
> sudo mount.cifs //<IP_SERVIDOR>/contabilidad /mnt/datacorp/contabilidad \
>   -o username=juan,vers=3.0,uid=$(id -u),gid=$(id -g),iocharset=utf8
> # Te pedirá: Password for juan@//<IP_SERVIDOR>/contabilidad:
> ```

#### 3.4. Montar como maria (/sistemas)

```bash
# NOTA: Cambiar contraseña en producción
sudo mount.cifs //<IP_SERVIDOR>/sistemas /mnt/datacorp/sistemas \
  -o username=maria,password=Maria2026,vers=3.0,uid=$(id -u),gid=$(id -g),iocharset=utf8
```

#### 3.5. Montar como admin (/privado y /admin)

```bash
# Montar /privado
# NOTA: Cambiar contraseña en producción
sudo mount.cifs //<IP_SERVIDOR>/privado /mnt/datacorp/privado \
  -o username=admin,password=Admin2026,vers=3.0,uid=$(id -u),gid=$(id -g),iocharset=utf8

# Montar /admin (share oculto — hay que conocer la ruta exacta)
sudo mount.cifs //<IP_SERVIDOR>/admin /mnt/datacorp/admin \
  -o username=admin,password=Admin2026,vers=3.0,uid=$(id -u),gid=$(id -g),iocharset=utf8
```

#### 3.6. Verificar los montajes

```bash
# Ver todos los shares montados
mount | grep cifs

# Ver la versión de SMB negociada
cat /proc/fs/cifs/DebugData 2>/dev/null | head -20
```

#### 3.7. Desmontar correctamente

```bash
# Desmontar un share específico
sudo umount /mnt/datacorp/publico

# Si da error "device is busy" (algún proceso está usando el directorio)
sudo umount -l /mnt/datacorp/publico
# -l = lazy unmount (desmontaje perezoso): desmonta en cuanto nadie lo use

# Desmontar todos
sudo umount /mnt/datacorp/publico 2>/dev/null
sudo umount /mnt/datacorp/contabilidad 2>/dev/null
sudo umount /mnt/datacorp/sistemas 2>/dev/null
sudo umount /mnt/datacorp/privado 2>/dev/null
sudo umount /mnt/datacorp/admin 2>/dev/null
```

---

### Paso 4: Probar acceso con diferentes usuarios

Se puede probar el acceso directamente desde `smbclient` sin necesidad de montar:

```bash
# Conectarse como juan al share de contabilidad
smbclient //<IP_SERVIDOR>/contabilidad -U juan
# Contraseña: Juan2026
# Dentro de smbclient, puedes usar:
#   ls           → listar archivos
#   put archivo  → subir un archivo
#   get archivo  → descargar un archivo
#   mkdir carpeta → crear una carpeta
#   exit         → salir
```

```bash
# Conectarse como maria al share de sistemas
smbclient //<IP_SERVIDOR>/sistemas -U maria
# Contraseña: Maria2026
```

```bash
# Intentar conectarse como juan al share privado (debería fallar)
smbclient //<IP_SERVIDOR>/privado -U juan
# Contraseña: Juan2026
# Resultado esperado: NT_STATUS_ACCESS_DENIED
```

---

## Pruebas de Verificación de Perfiles

Estas pruebas demuestran que el modelo RBAC funciona correctamente. Ejecútalas desde el **cliente** (Arch Linux).

### Prueba 1: Invitado puede leer `/publico` ✓

```bash
# Primero, desde el servidor, crea un archivo de prueba:
# (en el servidor) sudo bash -c 'echo "Documento público de DataCorp" > /srv/datacorp/publico/bienvenida.txt'

# Desde el cliente, montar como invitado y leer:
sudo mount.cifs //<IP_SERVIDOR>/publico /mnt/datacorp/publico -o guest,vers=3.0
cat /mnt/datacorp/publico/bienvenida.txt
# Resultado esperado: "Documento público de DataCorp" ✓
```

### Prueba 2: Invitado NO puede escribir en `/publico` ✗

```bash
# Intentar crear un archivo como invitado:
touch /mnt/datacorp/publico/intruso.txt
# Resultado esperado: "Permission denied" ✗ (¡correcto! no debería poder)
```

### Prueba 3: Juan puede escribir en `/contabilidad` ✓

```bash
# Montar contabilidad como juan:
sudo mount.cifs //<IP_SERVIDOR>/contabilidad /mnt/datacorp/contabilidad \
  -o username=juan,password=Juan2026,vers=3.0,uid=$(id -u),gid=$(id -g)

# Crear un archivo:
echo "Informe financiero Q1 2026" > /mnt/datacorp/contabilidad/informe_q1.txt
cat /mnt/datacorp/contabilidad/informe_q1.txt
# Resultado esperado: "Informe financiero Q1 2026" ✓
```

### Prueba 4: Juan NO puede acceder a `/privado` ✗

```bash
# Intentar montar /privado como juan:
sudo mount.cifs //<IP_SERVIDOR>/privado /mnt/datacorp/privado \
  -o username=juan,password=Juan2026,vers=3.0
# Resultado esperado: mount error(13): Permission denied ✗ (¡correcto!)
```

### Prueba 5: Admin puede acceder a todo ✓

```bash
# Montar /privado como admin:
sudo mount.cifs //<IP_SERVIDOR>/privado /mnt/datacorp/privado \
  -o username=admin,password=Admin2026,vers=3.0,uid=$(id -u),gid=$(id -g)

# Crear un archivo en /privado:
echo "Documento confidencial" > /mnt/datacorp/privado/confidencial.txt
cat /mnt/datacorp/privado/confidencial.txt
# Resultado esperado: "Documento confidencial" ✓

# Montar /admin (share oculto) como admin:
sudo mount.cifs //<IP_SERVIDOR>/admin /mnt/datacorp/admin \
  -o username=admin,password=Admin2026,vers=3.0,uid=$(id -u),gid=$(id -g)

# Crear un archivo en /admin:
echo "Configuración del sistema" > /mnt/datacorp/admin/config_backup.txt
# Resultado esperado: archivo creado sin error ✓
```

### Prueba 6: Juan NO puede acceder a `/sistemas` (no es su departamento)

```bash
# Intentar montar /sistemas como juan:
sudo mount.cifs //<IP_SERVIDOR>/sistemas /mnt/datacorp/sistemas \
  -o username=juan,password=Juan2026,vers=3.0
# Resultado esperado: mount error(13): Permission denied ✗ (¡correcto!)
# Juan pertenece a "contabilidad", no a "sistemas"
```

### Prueba 7: Maria puede escribir en `/sistemas` pero NO en `/contabilidad`

```bash
# Maria puede acceder a /sistemas:
sudo mount.cifs //<IP_SERVIDOR>/sistemas /mnt/datacorp/sistemas \
  -o username=maria,password=Maria2026,vers=3.0,uid=$(id -u),gid=$(id -g)
echo "Reporte de red" > /mnt/datacorp/sistemas/reporte_red.txt
# Resultado esperado: archivo creado ✓

# Maria NO puede acceder a /contabilidad:
sudo mount.cifs //<IP_SERVIDOR>/contabilidad /mnt/datacorp/contabilidad \
  -o username=maria,password=Maria2026,vers=3.0
# Resultado esperado: mount error(13): Permission denied ✗ (¡correcto!)
```

### Resumen de pruebas

| # | Prueba | Esperado | Resultado |
|---|--------|----------|-----------|
| 1 | Invitado lee `/publico` | ✓ Puede | |
| 2 | Invitado escribe `/publico` | ✗ No puede | |
| 3 | Juan escribe `/contabilidad` | ✓ Puede | |
| 4 | Juan accede `/privado` | ✗ No puede | |
| 5 | Admin accede a todo | ✓ Puede | |
| 6 | Juan accede `/sistemas` | ✗ No puede | |
| 7 | Maria escribe `/sistemas`, no `/contabilidad` | ✓/✗ | |

> **Llena la columna "Resultado" durante la exposición para demostrar en vivo.**

---

## Solución de Problemas

### Error 1: `NT_STATUS_ACCESS_DENIED`

**Síntoma:** Al intentar conectarse con smbclient o montar un share, aparece:
```
tree connect failed: NT_STATUS_ACCESS_DENIED
```

**Causas y soluciones:**

1. **El usuario no existe en Samba** (aunque exista en Linux):
   ```bash
   # En el servidor, verificar usuarios de Samba:
   sudo pdbedit -L
   # Si el usuario no aparece, agregarlo:
   sudo smbpasswd -a <usuario>
   ```

2. **El usuario no está en el grupo correcto**:
   ```bash
   # Verificar grupos del usuario:
   groups <usuario>
   # Agregar al grupo si falta:
   sudo usermod -aG <grupo> <usuario>
   ```

3. **Permisos del sistema de archivos** (POSIX o ACL bloquean el acceso):
   ```bash
   # Verificar permisos POSIX:
   ls -la /srv/datacorp/<directorio>
   # Verificar ACLs:
   getfacl /srv/datacorp/<directorio>
   ```

4. **Directiva `valid users` en smb.conf no incluye al usuario/grupo**:
   ```bash
   # Revisar la configuración del share:
   testparm -s 2>/dev/null | grep -A10 "\[nombre_del_share\]"
   ```

---

### Error 2: `mount error(112): Host is down`

**Síntoma:** Al montar con mount.cifs:
```
mount error(112): Host is down
```

**Causa:** Incompatibilidad de versión de SMB. El cliente intenta una versión que el servidor no acepta.

**Solución:** Especificar la versión de SMB explícitamente:
```bash
# Probar con SMB 3.0:
sudo mount.cifs //<IP_SERVIDOR>/publico /mnt/datacorp/publico -o vers=3.0,guest

# Si no funciona, probar con SMB 2.1:
sudo mount.cifs //<IP_SERVIDOR>/publico /mnt/datacorp/publico -o vers=2.1,guest

# Si nada funciona, verificar en el servidor:
testparm -s 2>/dev/null | grep protocol
```

---

### Error 3: `Connection refused` / No se puede conectar

**Síntoma:** smbclient o mount.cifs no pueden conectar con el servidor.

**Posibles causas:**

1. **Samba no está corriendo**:
   ```bash
   # En el servidor:
   sudo systemctl status smbd
   sudo systemctl start smbd
   ```

2. **Firewall bloqueando**:
   ```bash
   # En el servidor, verificar reglas del firewall:
   sudo ufw status
   # Abrir puertos de Samba:
   sudo ufw allow samba
   # O manualmente:
   sudo ufw allow 445/tcp
   sudo ufw allow 139/tcp
   ```

3. **No están en la misma red**:
   ```bash
   # Verificar IPs:
   # En el servidor:
   ip -4 addr show
   # En el cliente:
   ip -4 addr show
   # Ambos deben estar en la misma subred (ej: 192.168.1.x)
   ```

---

### Error 4: `Permission denied` al escribir archivos

**Síntoma:** Puedes conectarte y listar archivos, pero no puedes crear ni modificar.

**Causa:** Los permisos POSIX o ACLs del directorio no permiten escritura.

**Solución:**
```bash
# En el servidor, verificar permisos:
ls -la /srv/datacorp/<directorio>
getfacl /srv/datacorp/<directorio>

# Si los permisos están mal, corregir:
sudo chmod 2770 /srv/datacorp/departamentos/<departamento>
sudo setfacl -R -m g:<grupo>:rwx /srv/datacorp/departamentos/<departamento>

# Reiniciar Samba después de cambios:
sudo systemctl restart smbd
```

---

### Error 5: `Unable to find suitable address` / Problemas de nombre

**Síntoma:** No se puede resolver el nombre del servidor.

**Solución:** Usar la IP directamente en vez del nombre:
```bash
# En vez de:
smbclient -L //miservidor/publico
# Usar:
smbclient -L //192.168.1.100/publico
```

O agregar el servidor a `/etc/hosts` del cliente:
```bash
echo "<IP_SERVIDOR>  servidor-datacorp" | sudo tee -a /etc/hosts
```

---

### Nota sobre Ubuntu 24.04 vs 22.04

| Aspecto | Ubuntu 22.04 | Ubuntu 24.04 |
|---------|-------------|-------------|
| Samba versión | 4.15.x | 4.19.x+ |
| Netplan | Disponible | Por defecto (renderer: networkd) |
| SMB1 | Deshabilitado por defecto | Deshabilitado por defecto |
| Protocolo mín. | SMB2_02 | SMB2_02 |
| UFW | Activo si se instaló | Puede estar activo |
| systemd-resolved | Activo | Activo (puede interferir con DNS) |

**Diferencia importante:** En Ubuntu 24.04, `systemd-resolved` gestiona el DNS. Si tienes problemas de resolución de nombres, verifica con `resolvectl status`.

---

## Preguntas Frecuentes para la Exposición

### P: ¿Por qué usamos Samba y no NFS?

**R:** NFS (Network File System) es de origen Unix/Linux y funciona muy bien entre sistemas Linux. Sin embargo, Samba implementa el protocolo SMB que es compatible con **todos los sistemas operativos**: Windows, macOS y Linux. En un entorno empresarial mixto como DataCorp, Samba es la opción más versátil. Además, Samba proporciona autenticación de usuario integrada, mientras que NFS clásico (v3) confía en las IPs.

### P: ¿Qué es RBAC y por qué lo usamos?

**R:** RBAC es "Role-Based Access Control" (Control de Acceso Basado en Roles). En vez de dar permisos individuales a cada usuario (lo cual es un caos con 100 empleados), agrupamos los permisos por **rol** (administrador, usuario, invitado). Cuando llega un nuevo empleado al departamento de contabilidad, simplemente lo agregamos al grupo `contabilidad` y automáticamente hereda todos los permisos. Es más fácil de mantener y auditar.

### P: ¿Qué son las ACLs y por qué no basta con chmod?

**R:** Los permisos POSIX (chmod) solo permiten asignar permisos a **un propietario** y **un grupo**. ¿Pero qué pasa si un directorio necesita dar escritura al grupo `contabilidad` Y al grupo `administradores`? Con chmod no se puede (solo admite un grupo). Las ACLs (Access Control Lists) permiten **múltiples entradas de permisos** para diferentes usuarios y grupos en el mismo archivo o directorio.

### P: ¿Qué versión de SMB estamos usando y por qué importa?

**R:** Usamos **SMB3** (con mínimo SMB2). SMB1 (el original de los años 90) tiene vulnerabilidades graves — el ransomware WannaCry (2017) lo explotó para propagarse. SMB2 mejoró el rendimiento y la seguridad. SMB3 añade **cifrado** de datos en tránsito, protegiendo contra espionaje en la red. Nuestro `smb.conf` prohíbe explícitamente SMB1 con `min protocol = SMB2`.

### P: ¿Qué es el SGID bit (chmod 2770)?

**R:** El bit SGID (Set Group ID) en un directorio hace que todos los archivos creados dentro **hereden automáticamente el grupo del directorio**, no el grupo principal del usuario que los crea. Ejemplo: si juan crea un archivo en `/departamentos/contabilidad/` (que tiene SGID y grupo `contabilidad`), el archivo pertenecerá al grupo `contabilidad`, no al grupo personal de juan. Esto es esencial para que todos los del departamento puedan acceder a los archivos de los demás.

### P: ¿Qué pasa si el servidor se apaga?

**R:** Los clientes que tienen shares montados verán errores de "stale file handle" o "host is down" al intentar acceder a los archivos. La solución es desmontar (`umount -l`) y volver a montar cuando el servidor esté disponible. Si usamos `/etc/fstab` con la opción `nofail`, el cliente arrancará normalmente aunque el servidor esté apagado.

### P: ¿Es seguro este sistema para producción?

**R:** Para un laboratorio es adecuado, pero en producción se necesitaría:
1. **LDAP o Active Directory** en vez de usuarios locales (para centralizar la autenticación).
2. **Cifrado obligatorio** (`smb encrypt = required`).
3. **VPN** si se accede desde fuera de la LAN.
4. **Contraseñas fuertes** (no las de ejemplo).
5. **Respaldo (backup)** automático de los datos.
6. **Monitoreo** de logs y alertas de seguridad.

### P: ¿Cuál es la diferencia entre `smbd` y `nmbd`?

**R:** 
- **smbd** (Samba Daemon) es el servicio principal. Maneja la autenticación, el acceso a archivos y las transferencias. Usa el puerto **445/TCP**.
- **nmbd** (NetBIOS Name Service Daemon) se encarga de la **resolución de nombres** en la red. Permite que otros equipos encuentren el servidor por nombre. Usa los puertos **137/UDP** y **138/UDP**. Es opcional si siempre usas IP directa.

### P: ¿Se puede acceder desde Windows?

**R:** ¡Sí! Windows soporta SMB nativamente. Desde cualquier PC con Windows:
1. Presiona `Win + R`.
2. Escribe `\\<IP_SERVIDOR>\publico` y presiona Enter.
3. Ingresa usuario y contraseña cuando lo solicite.
Los mismos permisos aplicarán porque Samba es compatible con todos los sistemas operativos.
