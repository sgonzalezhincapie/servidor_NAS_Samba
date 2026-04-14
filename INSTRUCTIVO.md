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
7. [PARTE B — Configuración del Cliente Linux (Arch Linux)](#parte-b--configuración-del-cliente-linux-arch-linux)
8. [PARTE C — Configuración del Cliente Windows (Windows 10/11)](#parte-c--configuración-del-cliente-windows-windows-1011)
9. [Pruebas de Verificación de Perfiles](#pruebas-de-verificación-de-perfiles)
10. [Gestión de Permisos desde el Administrador](#gestión-de-permisos-desde-el-administrador-servidor)
11. [Solución de Problemas](#solución-de-problemas)
12. [Preguntas Frecuentes para la Exposición](#preguntas-frecuentes-para-la-exposición)

---

## 1. Introducción: Qué es este laboratorio y qué demuestra

Este laboratorio implementa un **servidor NAS (Network Attached Storage)** usando **Samba** en un entorno real con **tres computadores** conectados a la misma red local.

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

1. **Compartir archivos en red** entre un servidor Linux y clientes Linux y Windows.
2. **Entorno multiplataforma**: el mismo servidor Samba atiende clientes de diferentes sistemas operativos.
3. **Control de acceso basado en roles (RBAC)**: diferentes usuarios tienen diferentes permisos.
4. **Seguridad en capas**: permisos POSIX + ACLs + directivas de Samba.
5. **Configuración real**: no usamos máquinas virtuales sino computadores reales.

---

## 2. Requisitos previos

### Hardware
- **3 computadores** conectados a la misma red local (LAN), ya sea por cable Ethernet o WiFi.
- **Conexión a internet** (solo para instalar paquetes; el NAS funciona sin internet).

### Software — Servidor (equipo de Manuela)
- **Ubuntu 24.04 LTS** (Noble Numbat) instalado y con acceso a terminal.
- Acceso como **root** (o usuario con `sudo`).

### Software — Cliente Linux (equipo de Santiago)
- **Arch Linux** (rolling release, actualizado).
- Acceso como **root** (o usuario con `sudo`).

### Software — Cliente Windows (equipo de Daniel)
- **Windows 10 u 11** (cualquier edición: Home, Pro, Education).
- Acceso como **Administrador** (para ejecutar scripts de PowerShell).
- SMB viene habilitado por defecto en Windows; no se necesita instalar nada adicional.

### Conocimientos asumidos
- Saber abrir una terminal (Linux) o PowerShell (Windows).
- Saber escribir y ejecutar comandos básicos (`cd`, `ls`, `sudo` en Linux; `dir`, `cd` en Windows).
- *No se requiere experiencia con Samba, NFS ni redes avanzadas.*

---

## 3. Datos del entorno (completar antes de empezar)

**Antes de comenzar, identifica y anota estos datos. Los necesitarás en múltiples pasos.**

> **NOTA IMPORTANTE — IP dinámica (DHCP):** En este laboratorio **no configuramos IP estática** porque estamos en un entorno universitario donde no tenemos control de la infraestructura de red. Los tres equipos obtendrán su IP automáticamente por DHCP. Esto significa que la IP del servidor **puede cambiar** al reiniciar. Antes de conectar los clientes, siempre verifica la IP actual del servidor con `ip -4 addr show` (Linux) o `ipconfig` (Windows).

| Variable                  | Valor a completar         | Cómo encontrarlo                                           |
|---------------------------|---------------------------|------------------------------------------------------------|
| IP del servidor (DHCP)    | ______________________    | En el servidor: `ip -4 addr show \| grep inet`             |
| Interfaz de red (servidor)| ______________________    | En el servidor: `ip a \| grep -E '^[0-9]+:'`               |
| IP del cliente Linux      | ______________________    | En Arch: `ip -4 addr show \| grep inet`                    |
| IP del cliente Windows    | ______________________    | En Windows: `ipconfig` en CMD/PowerShell                   |
| Nombre del grupo de trabajo| DATACORP                 | Ya definido en este laboratorio                            |

### ¿Quién hace qué? — Roles del equipo

Cada integrante opera **un equipo** con un sistema operativo diferente. Estos son los roles y responsabilidades:

| Integrante | Equipo | Sistema Operativo | Rol en el lab | Qué debe hacer |
|------------|--------|-------------------|---------------|----------------|
| **Manuela** | Servidor | Ubuntu 24.04 LTS | Administradora del servidor | Ejecuta `setup_servidor.sh`, configura Samba, gestiona usuarios y permisos |
| **Santiago** | Cliente Linux | Arch Linux | Cliente Linux | Ejecuta `setup_cliente_arch.sh`, monta shares, prueba acceso con diferentes usuarios |
| **Daniel** | Cliente Windows | Windows 10/11 | Cliente Windows | Ejecuta `setup_cliente_windows.ps1`, mapea unidades de red, prueba acceso |

### Usuarios Samba y sus permisos

El servidor crea estos **usuarios Samba** (no confundir con los integrantes del equipo). Estos usuarios son las "llaves" con las que los clientes se conectan:

| Usuario Samba | Contraseña | Grupos | Acceso a shares |
|---------------|------------|--------|-----------------|
| `admin` | `Admin2026` | `administradores` | **Todo**: publico (R+W), contabilidad (R+W), sistemas (R+W), privado (R+W), admin (R+W) |
| `dani` | `Dani2026` | `usuarios`, `contabilidad` | publico (R), contabilidad (R+W). **Sin acceso** a: sistemas, privado, admin |
| `santi` | `Santi2026` | `usuarios`, `sistemas` | publico (R), sistemas (R+W). **Sin acceso** a: contabilidad, privado, admin |
| `invitado` | *(sin contraseña)* | `invitados` | publico (R). **Sin acceso** a todo lo demás |

**R** = solo lectura | **R+W** = lectura y escritura

> **Cualquier integrante puede usar cualquier usuario** desde su equipo. Por ejemplo, Daniel (Windows) puede probar conectándose como `dani`, `santi` o `admin` para verificar que los permisos funcionan. Lo mismo Santiago desde Arch Linux.

### Orden de ejecución recomendado

1. **Manuela primero** → Configura el servidor ejecutando `setup_servidor.sh` en Ubuntu
2. **Manuela comparte la IP** → Revisa la IP del servidor (`ip -4 addr show`) y se la comunica a Santiago y Daniel
3. **Santiago y Daniel** → Configuran la IP en sus scripts y los ejecutan desde sus respectivos equipos

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
    ┌──────────────────────────────┐
    │       SERVIDOR NAS           │
    │    Ubuntu 24.04 LTS          │
    │  (equipo de Manuela)         │
    │                              │
    │  Samba (smbd + nmbd)         │
    │  ┌────────────────────────┐  │
    │  │  /srv/datacorp/        │  │
    │  │  ├── publico/          │  │
    │  │  ├── departamentos/    │  │
    │  │  │   ├── contabilidad/ │  │
    │  │  │   └── sistemas/     │  │
    │  │  ├── privado/          │  │
    │  │  └── admin/            │  │
    │  └────────────────────────┘  │
    │                              │
    │  IP: (DHCP — verificar con   │
    │       ip -4 addr show)       │
    │  Interfaz: <INTERFAZ_RED>    │
    └──────────────┬───────────────┘
                   │
                   │         Red Local (LAN)
                   │    ┌──────────────────────┐
                   ├────┤   Switch / Router     ├────────┬────────────────────┐
                   │    │  192.168.x.0/24      │        │                    │
                   │    └──────────────────────┘        │                    │
                   │                                     │                    │
    ┌──────────────┴───────────────┐     ┌──────────────┴──────────────┐    ┌┴─────────────────────────────┐
    │      CLIENTE LINUX           │     │     CLIENTE WINDOWS         │    │                              │
    │      Arch Linux              │     │     Windows 10/11           │    │    Otros dispositivos...     │
    │  (equipo de Santiago)        │     │  (equipo de Daniel)         │    │    (pueden conectarse con    │
    │                              │     │                              │    │     cualquier SO con SMB)    │
    │  cifs-utils + smbclient      │     │  SMB nativo (sin instalar)  │    └──────────────────────────────┘
    │                              │     │                              │
    │  Puntos de montaje:          │     │  Unidades de red mapeadas:  │
    │  /mnt/datacorp/              │     │  P: = \\servidor\publico    │
    │  ├── publico/                │     │  K: = \\servidor\contabilid.│
    │  ├── contabilidad/           │     │  S: = \\servidor\sistemas   │
    │  ├── sistemas/               │     │  V: = \\servidor\privado    │
    │  ├── privado/                │     │  A: = \\servidor\admin      │
    │  └── admin/                  │     │                              │
    └──────────────────────────────┘     └──────────────────────────────┘
                        
    Protocolo: SMB3 (puerto 445/TCP)
    Autenticación: Usuario/Contraseña (Samba local)
```

### Flujo de comunicación

```
    Cliente (Linux o Windows)              Servidor (Ubuntu)
    ┌──────┐    1. Solicitud SMB (puerto 445)  ┌──────┐
    │ Arch │    (mount.cifs / net use /         │Ubuntu│
    │Linux │     Explorador de archivos)        │24.04 │
    │  o   │ ────────────────────────────────→ │      │
    │ Win  │    2. Autenticación (user/pass)    │      │
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

### Paso 1: Identificar la IP del servidor (DHCP)

> **Nota:** No configuramos IP estática porque estamos en un entorno universitario sin control de la infraestructura de red. Usamos la IP que el DHCP de la universidad asigna automáticamente. **Antes de cada sesión de laboratorio**, Manuela debe verificar la IP actual y comunicársela a Santiago y Daniel.

#### 1.1. Identificar la interfaz de red

```bash
# Ver todas las interfaces de red
ip a | grep -E '^[0-9]+:'
```

Verás algo como:

```
1: lo: <LOOPBACK,UP,LOWER_UP>
2: enp3s0: <BROADCAST,MULTICAST,UP,LOWER_UP>
```

- `lo` es la interfaz **loopback** (localhost) — **ignórala**.
- `enp3s0` (o `eth0`, `ens33`, `wlp2s0`, etc.) es tu interfaz de red real — **anótala**, la necesitas para `smb.conf`.

#### 1.2. Verificar la IP actual asignada por DHCP

```bash
# Ver la IP actual del servidor
ip -4 addr show
```

Ejemplo de salida:

```
2: enp3s0: <BROADCAST,MULTICAST,UP,LOWER_UP>
    inet 192.168.1.105/24 brd 192.168.1.255 scope global dynamic enp3s0
```

De aquí extraemos:
- **Interfaz**: `enp3s0` → Necesaria para `smb.conf`
- **IP actual**: `192.168.1.105` → Esta es la IP que Santiago y Daniel deben usar en sus scripts

> **⚠ IMPORTANTE:** La palabra `dynamic` confirma que la IP fue asignada por DHCP. Esta IP puede cambiar si el servidor se reinicia o si pasa mucho tiempo. Siempre verifícala antes de empezar.

#### 1.3. Comunicar la IP a los compañeros

Una vez identificada la IP del servidor, Manuela debe comunicarla a:
- **Santiago** (Arch Linux) → Para que la ponga en `setup_cliente_arch.sh` (variable `IP_SERVIDOR`)
- **Daniel** (Windows) → Para que la ponga en `setup_cliente_windows.ps1` (variable `$IP_SERVIDOR`)

#### 1.4. Verificar conectividad

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
groups dani
groups santi
groups invitado
```

Salida esperada:
```
admin : admin administradores
dani : dani usuarios contabilidad
santi : santi usuarios sistemas
invitado : invitado invitados
```

---

## PARTE B — Configuración del Cliente Linux (Arch Linux)

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
  -o username=invitado,password=Invitado2026,vers=3.0,uid=$(id -u),gid=$(id -g),iocharset=utf8
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

#### 3.3. Montar como dani (/contabilidad)

```bash
# NOTA: Cambiar contraseña en producción
sudo mount.cifs //<IP_SERVIDOR>/contabilidad /mnt/datacorp/contabilidad \
  -o username=dani,password=Dani2026,vers=3.0,uid=$(id -u),gid=$(id -g),iocharset=utf8
```

> **Alternativa más segura** (pide la contraseña interactivamente):
> ```bash
> sudo mount.cifs //<IP_SERVIDOR>/contabilidad /mnt/datacorp/contabilidad \
>   -o username=dani,vers=3.0,uid=$(id -u),gid=$(id -g),iocharset=utf8
> # Te pedirá: Password for dani@//<IP_SERVIDOR>/contabilidad:
> ```

#### 3.4. Montar como santi (/sistemas)

```bash
# NOTA: Cambiar contraseña en producción
sudo mount.cifs //<IP_SERVIDOR>/sistemas /mnt/datacorp/sistemas \
  -o username=santi,password=Santi2026,vers=3.0,uid=$(id -u),gid=$(id -g),iocharset=utf8
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
# Conectarse como dani al share de contabilidad
smbclient //<IP_SERVIDOR>/contabilidad -U dani
# Contraseña: Dani2026
# Dentro de smbclient, puedes usar:
#   ls           → listar archivos
#   put archivo  → subir un archivo
#   get archivo  → descargar un archivo
#   mkdir carpeta → crear una carpeta
#   exit         → salir
```

```bash
# Conectarse como santi al share de sistemas
smbclient //<IP_SERVIDOR>/sistemas -U santi
# Contraseña: Santi2026
```

```bash
# Intentar conectarse como dani al share privado (debería fallar)
smbclient //<IP_SERVIDOR>/privado -U dani
# Contraseña: Dani2026
# Resultado esperado: NT_STATUS_ACCESS_DENIED
```

---

## PARTE C — Configuración del Cliente Windows (Windows 10/11)

> **¿Por qué Windows no necesita instalar nada?** SMB es un protocolo inventado por Microsoft. Windows lo soporta de forma nativa desde hace décadas. No necesitas instalar paquetes como en Linux; el Explorador de archivos ya sabe "hablar" SMB.

### Paso 1: Verificar conectividad con el servidor

Abre **PowerShell** o **CMD** (no necesita ser como Administrador para esto):

```powershell
# Verificar que hay conexión de red con el servidor
ping <IP_SERVIDOR>
```

Si responde, hay conexión. Si no, verifica que ambos equipos estén en la misma red.

```powershell
# Verificar que el puerto SMB (445) está abierto
Test-NetConnection -ComputerName <IP_SERVIDOR> -Port 445
```

Si `TcpTestSucceeded` dice `True`, Samba está accesible.

### Paso 2: Acceder a los shares desde el Explorador de archivos (método GUI)

Este es el método más sencillo y visual:

1. Presiona **Win + R** (abrir "Ejecutar").
2. Escribe `\\<IP_SERVIDOR>` y presiona Enter.
3. Windows mostrará un cuadro de diálogo pidiendo **usuario y contraseña**.
4. Ingresa las credenciales del usuario que deseas probar:
   - Usuario: `dani` / Contraseña: `Dani2026`
   - Usuario: `santi` / Contraseña: `Santi2026`
   - Usuario: `admin` / Contraseña: `Admin2026`
5. Se abrirá una ventana mostrando los shares disponibles (`publico`, `contabilidad`, `sistemas`, `privado`).
6. Haz doble clic en la carpeta que deseas abrir.

> **Nota:** El share `[admin]` NO aparecerá en la lista porque tiene `browseable = no`. Para acceder, escribe la ruta completa: `\\<IP_SERVIDOR>\admin`

> **Nota:** Si Windows sigue usando credenciales antiguas, primero desconecta con:
> ```cmd
> net use * /delete /yes
> ```

### Paso 3: Mapear unidades de red (método CMD/PowerShell)

Abre **PowerShell como Administrador** (clic derecho → "Ejecutar como administrador").

#### 3.1. Mapear `/publico` como invitado

```powershell
# net use <LETRA>: \\<SERVIDOR>\<SHARE> /user:<USUARIO> <CONTRASEÑA>
net use P: \\<IP_SERVIDOR>\publico /user:guest ""
```

Verificar:
```powershell
dir P:\
```

#### 3.2. Mapear `/contabilidad` como dani

```powershell
# NOTA: Cambiar contraseña en producción
net use K: \\<IP_SERVIDOR>\contabilidad /user:dani Dani2026
```

Probar escritura:
```powershell
echo "Informe de Dani desde Windows" > K:\informe_windows.txt
type K:\informe_windows.txt
```

#### 3.3. Mapear `/sistemas` como santi

```powershell
# NOTA: Cambiar contraseña en producción
net use S: \\<IP_SERVIDOR>\sistemas /user:santi Santi2026
```

#### 3.4. Mapear `/privado` y `/admin` como admin

```powershell
# NOTA: Cambiar contraseña en producción
net use V: \\<IP_SERVIDOR>\privado /user:admin Admin2026
net use A: \\<IP_SERVIDOR>\admin /user:admin Admin2026
```

#### Letras de unidad asignadas

| Letra | Share | Mnemotecnia |
|-------|-------|-------------|
| P: | publico | **P**úblico |
| K: | contabilidad | **K**ontabilidad |
| S: | sistemas | **S**istemas |
| V: | privado | pri**V**ado |
| A: | admin | **A**dmin |

### Paso 4: Verificar la versión de SMB negociada

```powershell
# Después de conectarte a un share, ejecuta (como Administrador):
Get-SmbConnection | Format-Table ServerName, ShareName, Dialect
```

La columna **Dialect** mostrará la versión de SMB. Debería ser `3.x.x` (SMB 3.0 o superior).

### Paso 5: Desconectar unidades

```powershell
# Desconectar una unidad específica
net use P: /delete

# Desconectar TODAS las unidades de red
net use * /delete /yes

# Ver unidades mapeadas actualmente
net use
```

### Paso 6: Mapeo persistente (opcional — sobrevive al reinicio)

Para que las unidades se reconecten automáticamente al iniciar sesión:

```powershell
# Agregar /persistent:yes al final del comando
net use P: \\<IP_SERVIDOR>\publico /user:guest "" /persistent:yes
net use K: \\<IP_SERVIDOR>\contabilidad /user:dani Dani2026 /persistent:yes
```

Windows guardará las credenciales en el **Administrador de credenciales** y reconectará las unidades automáticamente.

### Paso 7: Ejecutar el script automatizado (opcional)

Si prefieres automatizar todo, usa el script PowerShell incluido:

```powershell
# 1. Abrir PowerShell como Administrador
# 2. Habilitar ejecución de scripts (solo la primera vez):
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 3. Editar el script y cambiar <IP_SERVIDOR>:
notepad .\setup_cliente_windows.ps1

# 4. Ejecutar:
.\setup_cliente_windows.ps1
```

---

## Pruebas de Verificación de Perfiles

Estas pruebas demuestran que el modelo RBAC funciona correctamente. Ejecútalas desde **cualquiera de los clientes** (Arch Linux o Windows).

> **Nota:** Los comandos de abajo usan `mount.cifs` (Arch Linux). Para hacer las mismas pruebas desde **Windows**, consulta la columna equivalente: en vez de `mount.cifs` usa `net use`, y en vez de `cat`/`echo`/`touch` usa `type`/`echo`/`copy nul`.

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

### Prueba 3: Dani puede escribir en `/contabilidad` ✓

```bash
# Montar contabilidad como dani:
sudo mount.cifs //<IP_SERVIDOR>/contabilidad /mnt/datacorp/contabilidad \
  -o username=dani,password=Dani2026,vers=3.0,uid=$(id -u),gid=$(id -g)

# Crear un archivo:
echo "Informe financiero Q1 2026" > /mnt/datacorp/contabilidad/informe_q1.txt
cat /mnt/datacorp/contabilidad/informe_q1.txt
# Resultado esperado: "Informe financiero Q1 2026" ✓
```

### Prueba 4: Dani NO puede acceder a `/privado` ✗

```bash
# Intentar montar /privado como dani:
sudo mount.cifs //<IP_SERVIDOR>/privado /mnt/datacorp/privado \
  -o username=dani,password=Dani2026,vers=3.0
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

### Prueba 6: Dani NO puede acceder a `/sistemas` (no es su departamento)

```bash
# Intentar montar /sistemas como dani:
sudo mount.cifs //<IP_SERVIDOR>/sistemas /mnt/datacorp/sistemas \
  -o username=dani,password=Dani2026,vers=3.0
# Resultado esperado: mount error(13): Permission denied ✗ (¡correcto!)
# Dani pertenece a "contabilidad", no a "sistemas"
```

### Prueba 7: Santi puede escribir en `/sistemas` pero NO en `/contabilidad`

```bash
# Santi puede acceder a /sistemas:
sudo mount.cifs //<IP_SERVIDOR>/sistemas /mnt/datacorp/sistemas \
  -o username=santi,password=Santi2026,vers=3.0,uid=$(id -u),gid=$(id -g)
echo "Reporte de red" > /mnt/datacorp/sistemas/reporte_red.txt
# Resultado esperado: archivo creado ✓

# Santi NO puede acceder a /contabilidad:
sudo mount.cifs //<IP_SERVIDOR>/contabilidad /mnt/datacorp/contabilidad \
  -o username=santi,password=Santi2026,vers=3.0
# Resultado esperado: mount error(13): Permission denied ✗ (¡correcto!)
```

### Resumen de pruebas

| # | Prueba | Esperado | Resultado |
|---|--------|----------|-----------|
| 1 | Invitado lee `/publico` | ✓ Puede | |
| 2 | Invitado escribe `/publico` | ✗ No puede | |
| 3 | Dani escribe `/contabilidad` | ✓ Puede | |
| 4 | Dani accede `/privado` | ✗ No puede | |
| 5 | Admin accede a todo | ✓ Puede | |
| 6 | Dani accede `/sistemas` | ✗ No puede | |
| 7 | Santi escribe `/sistemas`, no `/contabilidad` | ✓/✗ | |

> **Llena la columna "Resultado" durante la exposición para demostrar en vivo.**

---

## Gestión de Permisos desde el Administrador (Servidor)

Esta sección explica cómo **Manuela (administradora del servidor Ubuntu)** puede modificar los permisos y accesos de los otros dos dispositivos en tiempo real. Todos estos comandos se ejecutan **en el servidor Ubuntu**.

### Ver el estado actual de usuarios y grupos

```bash
# Ver todos los usuarios de Samba registrados
sudo pdbedit -L

# Ver a qué grupos pertenece cada usuario
groups admin dani santi invitado

# Ver las ACLs actuales de cada carpeta
getfacl /srv/datacorp/publico
getfacl /srv/datacorp/departamentos/contabilidad
getfacl /srv/datacorp/departamentos/sistemas
getfacl /srv/datacorp/privado
getfacl /srv/datacorp/admin
```

### Caso 1: Dar acceso a un usuario a un departamento que no le corresponde

Ejemplo: Permitir que **dani** (contabilidad) también acceda a **sistemas**.

```bash
# 1. Agregar a dani al grupo "sistemas" en Linux
sudo usermod -aG sistemas dani

# 2. Agregar a dani en la directiva "valid users" de [sistemas] en smb.conf
sudo nano /etc/samba/smb.conf
# Busca la sección [sistemas] y cambia:
#   valid users = @sistemas @administradores
# por:
#   valid users = @sistemas @administradores dani

# 3. Reiniciar Samba para que tome los cambios
sudo systemctl restart smbd

# 4. Verificar que dani ahora está en el grupo
groups dani
# Salida esperada: dani : dani usuarios contabilidad sistemas
```

**Desde Arch Linux (Santiago)** — Para probar el cambio:
```bash
# Desmontar si ya estaba montado
sudo umount /mnt/datacorp/sistemas 2>/dev/null
# Montar como dani (ahora debería funcionar)
sudo mount.cifs //<IP_SERVIDOR>/sistemas /mnt/datacorp/sistemas \
  -o username=dani,password=Dani2026,vers=3.0,uid=$(id -u),gid=$(id -g)
ls /mnt/datacorp/sistemas
```

**Desde Windows (Daniel)** — Para probar el cambio:
```powershell
# Limpiar conexiones anteriores
net use S: /delete 2>$null
# Reconectar como dani
net use S: \\<IP_SERVIDOR>\sistemas /user:dani Dani2026
dir S:\
```

### Caso 2: Quitar acceso a un usuario

Ejemplo: Revocar el acceso de **dani** a **contabilidad**.

```bash
# 1. Quitar a dani del grupo "contabilidad" en Linux
sudo gpasswd -d dani contabilidad

# 2. (Opcional) También quitarlo del valid users en smb.conf si estaba explícito
sudo nano /etc/samba/smb.conf

# 3. Reiniciar Samba
sudo systemctl restart smbd

# 4. Verificar
groups dani
# dani ya no aparece en el grupo "contabilidad"
```

Desde los clientes: al intentar acceder a `/contabilidad` como dani, ahora recibirán `NT_STATUS_ACCESS_DENIED` o `Permission denied`.

### Caso 3: Crear un usuario nuevo

Ejemplo: llega un empleado nuevo llamado **pedro** al departamento de contabilidad.

```bash
# 1. Crear el usuario en Linux (sin acceso por consola, solo para Samba)
sudo useradd -M -s /usr/sbin/nologin pedro

# 2. Agregar a los grupos correspondientes
sudo usermod -aG usuarios pedro
sudo usermod -aG contabilidad pedro

# 3. Crear la contraseña de Samba (se le pedirá ingresarla dos veces)
sudo smbpasswd -a pedro

# 4. Habilitar el usuario en Samba
sudo smbpasswd -e pedro

# 5. Reiniciar Samba
sudo systemctl restart smbd

# 6. Verificar
sudo pdbedit -L | grep pedro
groups pedro
# Salida: pedro : pedro usuarios contabilidad
```

Ahora los clientes pueden conectarse como `pedro` con la contraseña que se configuró.

### Caso 4: Cambiar permisos de una carpeta (lectura ↔ escritura)

Ejemplo: Hacer que **usuarios** (dani, santi) puedan **escribir** en `/publico` (actualmente solo lectura).

```bash
# Opción A: Cambiar ACL del sistema de archivos
sudo setfacl -R -m g:usuarios:rwx /srv/datacorp/publico
sudo setfacl -R -d -m g:usuarios:rwx /srv/datacorp/publico

# Opción B: También cambiar en smb.conf para mayor claridad
sudo nano /etc/samba/smb.conf
# En la sección [publico], cambiar:
#   write list = @administradores
# por:
#   write list = @administradores @usuarios

# Reiniciar Samba
sudo systemctl restart smbd
```

Para **revertir** (volver a solo lectura para usuarios):
```bash
sudo setfacl -R -m g:usuarios:r-x /srv/datacorp/publico
sudo setfacl -R -d -m g:usuarios:r-x /srv/datacorp/publico
# Y en smb.conf, quitar @usuarios del write list
sudo systemctl restart smbd
```

### Caso 5: Deshabilitar un usuario temporalmente

```bash
# Deshabilitar (el usuario no puede conectarse pero no se borra)
sudo smbpasswd -d dani

# Habilitar de nuevo
sudo smbpasswd -e dani
```

### Caso 6: Verificar quién está conectado en este momento

```bash
# Ver conexiones activas de Samba
sudo smbstatus

# Esto muestra: qué usuarios están conectados, desde qué IP, a qué share
```

### Resumen de comandos de administración

| Acción | Comando |
|--------|---------|
| Ver usuarios Samba | `sudo pdbedit -L` |
| Ver grupos de un usuario | `groups <usuario>` |
| Agregar usuario a grupo | `sudo usermod -aG <grupo> <usuario>` |
| Quitar usuario de grupo | `sudo gpasswd -d <usuario> <grupo>` |
| Crear usuario Samba | `sudo useradd -M -s /usr/sbin/nologin <user>` + `sudo smbpasswd -a <user>` |
| Deshabilitar usuario | `sudo smbpasswd -d <usuario>` |
| Habilitar usuario | `sudo smbpasswd -e <usuario>` |
| Cambiar contraseña Samba | `sudo smbpasswd <usuario>` |
| Modificar ACLs | `sudo setfacl -R -m g:<grupo>:<permisos> <ruta>` |
| Ver ACLs | `getfacl <ruta>` |
| Ver conexiones activas | `sudo smbstatus` |
| Reiniciar Samba | `sudo systemctl restart smbd` |

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
| Red | DHCP por defecto | DHCP por defecto (Netplan) |
| SMB1 | Deshabilitado por defecto | Deshabilitado por defecto |
| Protocolo mín. | SMB2_02 | SMB2_02 |
| UFW | Activo si se instaló | Puede estar activo |
| systemd-resolved | Activo | Activo (puede interferir con DNS) |

**Diferencia importante:** En Ubuntu 24.04, `systemd-resolved` gestiona el DNS. Si tienes problemas de resolución de nombres, verifica con `resolvectl status`.

---

### Errores comunes en Windows

### Error W1: `Error de sistema 53 — No se encontró la ruta de acceso de red`

**Síntoma:** Al ejecutar `net use`:
```
Error de sistema 53 ha ocurrido.
No se encontró la ruta de acceso de red.
```

**Solución:**
1. Verificar que el servidor está accesible:
   ```powershell
   ping <IP_SERVIDOR>
   Test-NetConnection -ComputerName <IP_SERVIDOR> -Port 445
   ```
2. Si el ping funciona pero el puerto 445 no, revisa el firewall del servidor.

---

### Error W2: `Error de sistema 5 — Acceso denegado`

**Síntoma:** Windows muestra "Acceso denegado" al intentar mapear un share.

**Causa:** El usuario no tiene permiso para ese share (¡esto es el comportamiento correcto en nuestras pruebas!). O la contraseña es incorrecta.

**Solución:**
1. Verificar usuario y contraseña.
2. Limpiar credenciales cacheadas:
   ```powershell
   net use * /delete /yes
   ```
3. Abrir el **Administrador de credenciales** de Windows (buscar "Credential Manager" en el menú Inicio) y eliminar entradas del servidor DataCorp.

---

### Error W3: Windows usa credenciales antiguas (no pide contraseña)

**Síntoma:** Windows se conecta automáticamente con un usuario anterior y no te deja cambiar.

**Solución:**
```powershell
# 1. Desconectar todas las unidades
net use * /delete /yes

# 2. Limpiar cache de credenciales
# Abrir: Panel de control → Cuentas de usuario → Administrador de credenciales
# Eliminar las credenciales de Windows que apunten a <IP_SERVIDOR>

# 3. Reconectar con el usuario deseado
net use K: \\<IP_SERVIDOR>\contabilidad /user:dani Dani2026
```

---

### Nota sobre compatibilidad SMB entre los tres sistemas

| Sistema | Rol | Cliente SMB | Versiones soportadas |
|---------|-----|-------------|---------------------|
| Ubuntu 24.04 | Servidor | Samba 4.19+ | SMB2, SMB3 (SMB1 deshabilitado) |
| Arch Linux | Cliente | cifs-utils | SMB2, SMB3 |
| Windows 10/11 | Cliente | Nativo | SMB2, SMB3 (SMB1 opcional, deshabilitado por defecto) |

**Todos negocian SMB3 automáticamente.** No debería haber problemas de compatibilidad entre estos tres sistemas. Si por alguna razón falla, forza `vers=3.0` en Linux o verifica con `Get-SmbConnection` en Windows.

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

**R:** El bit SGID (Set Group ID) en un directorio hace que todos los archivos creados dentro **hereden automáticamente el grupo del directorio**, no el grupo principal del usuario que los crea. Ejemplo: si dani crea un archivo en `/departamentos/contabilidad/` (que tiene SGID y grupo `contabilidad`), el archivo pertenecerá al grupo `contabilidad`, no al grupo personal de dani. Esto es esencial para que todos los del departamento puedan acceder a los archivos de los demás.

### P: ¿Qué pasa si el servidor se apaga?

**R:** Los clientes que tienen shares montados verán errores de "stale file handle" o "host is down" al intentar acceder a los archivos. La solución es desmontar (`umount -l`) y volver a montar cuando el servidor esté disponible. Además, como usamos IP dinámica (DHCP), la IP del servidor podría cambiar al reiniciar; Manuela debe verificarla con `ip -4 addr show` y comunicarla nuevamente a Santiago y Daniel.

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

**R:** ¡Sí! Y de hecho, en este laboratorio lo hacemos. Windows soporta SMB nativamente (Microsoft inventó el protocolo). El equipo de Daniel (Windows) se conecta al mismo servidor que el de Santiago (Arch Linux), demostrando que Samba permite compartir archivos entre **cualquier sistema operativo**. Desde Windows se accede con `Win + R → \\<IP_SERVIDOR>` o con `net use` en la terminal.

### P: ¿Por qué Windows no necesita instalar nada pero Arch Linux sí?

**R:** Windows incluye el cliente SMB integrado en el sistema operativo desde Windows 95. El Explorador de archivos ya sabe cómo conectarse a shares SMB. En Linux, el soporte SMB/CIFS requiere instalar `cifs-utils` (para montar) y opcionalmente `smbclient` (para explorar). Esto es porque Linux fue diseñado originalmente con NFS como protocolo de red, no SMB.
