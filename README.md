# Servidor NAS con Samba

Servidor de archivos en red compartida (NAS) usando Samba sobre Linux. Permite
que equipos Windows, Arch Linux y Ubuntu accedan a carpetas compartidas con
permisos por usuario y grupo/departamento.

---

## Inicio rápido

```bash
python3 configurar.py
```

Muestra un menú para configurar el servidor, configurar un cliente o desinstalar.
No necesitas saber qué script ejecutar — el launcher lo detecta por ti.

---

## ¿Cuándo usar `configurar.py` y cuándo los scripts directamente?

| Situación | Qué usar |
|---|---|
| Primera vez, no estoy seguro de qué hacer | `python3 configurar.py` |
| Quiero configurar el servidor | `python3 configurar.py` → Servidor, o `sudo bash setup_servidor.sh` |
| Quiero configurar este equipo como cliente | `python3 configurar.py` → Cliente |
| Quiero desinstalar / revertir todo | `python3 configurar.py` → Desinstalar |
| Estoy en Windows | Ir directo al `.ps1` (Python puede no estar instalado) |
| Prefiero el script directo sin menú | `sudo bash setup_*.sh` o `sudo bash limpiar_*.sh` |

> **Nota para clientes Linux:** antes de ejecutar `setup_cliente_arch.sh` o
> `setup_cliente_ubuntu.sh` directamente, edita la variable `IP_SERVIDOR` al
> inicio del archivo con la IP real del servidor NAS.

---

## Archivos del proyecto

### Configuración

| Archivo | Para quién |
|---|---|
| `configurar.py` | Punto de entrada único — ejecutar en cualquier equipo Linux |
| `setup_servidor.sh` | Ejecutar en el servidor Ubuntu Server 22.04+ |
| `setup_cliente_arch.sh` | Ejecutar en el equipo cliente con Arch Linux |
| `setup_cliente_ubuntu.sh` | Ejecutar en el equipo cliente con Ubuntu Desktop |
| `setup_cliente_windows.ps1` | Ejecutar en el equipo cliente con Windows 10/11 |
| `smb.conf` | Configuración de Samba (instalada automáticamente por el setup del servidor) |
| `verificacion_permisos.sh` | Ejecutar en el servidor para verificar que los permisos están bien |

### Limpieza / Desinstalación

| Archivo | Para quién |
|---|---|
| `limpiar_servidor.sh` | Revertir toda la configuración del servidor (borra datos) |
| `limpiar_cliente_arch.sh` | Desinstalar cliente NAS en Arch Linux |
| `limpiar_cliente_ubuntu.sh` | Desinstalar cliente NAS en Ubuntu Desktop |
| `limpiar_cliente_windows.ps1` | Revertir configuración de cliente en Windows 10/11 |

---

## Estructura del NAS

```
/srv/datacorp/
├── publico/              → Lectura para todos, escritura solo admin
├── departamentos/
│   ├── financiera/       → Solo grupo financiera + admin
│   ├── produccion/       → Solo grupo produccion + admin
│   ├── design/           → Solo grupo design + admin
│   └── rh/               → Solo grupo rh + admin
├── privado/              → Solo admin
└── admin/                → Solo admin (oculto en la red)
```

> Los grupos de departamento se configuran durante la instalación del servidor.
> Los anteriores son los valores por defecto.

## Despliegue del servidor — Ubuntu Server 22.04.5 LTS

### Requisitos
- Ubuntu Server 22.04.5 LTS instalado
- Acceso con `sudo`
- Conexión a Internet para instalar paquetes (solo durante la instalación)
- Todos los equipos cliente en la misma red local

### Pasos

**1. Copiar los archivos al servidor**

Desde otro equipo (o directamente en el servidor):
```bash
git clone <URL_DEL_REPOSITORIO>
cd servidor_NAS
```
O copia los archivos manualmente con USB / SCP.

**2. Ejecutar el script de configuración**

```bash
sudo bash setup_servidor.sh
```

El script te hará estas preguntas antes de cambiar nada:

- ¿Usar los grupos por defecto? → `Financiera, Produccion, Design, RH` (recomendado: S)
- Contraseña para el usuario `admin` (acceso total)
- Contraseña para el usuario `invitado` (solo lectura pública)
- ¿Agregar usuarios de departamento ahora? → nombre, contraseña y grupo de cada uno

Después de confirmar, el script instala Samba, crea carpetas, aplica permisos, configura el firewall y arranca el servicio.

**3. Anotar la IP del servidor**

Al finalizar el script verás la IP del servidor. Compártela con los equipos cliente.

Si necesitas verla de nuevo:
```bash
ip -4 addr show
```

**4. Verificar que todo está correcto**

```bash
sudo bash verificacion_permisos.sh
```

Todos los tests deben salir en verde (PASS).

### Administración de usuarios después de la instalación

**Agregar un usuario nuevo:**
```bash
sudo useradd --no-create-home --shell /usr/sbin/nologin NOMBRE
sudo usermod -aG usuarios NOMBRE
sudo usermod -aG GRUPO NOMBRE        # ej: financiera, design, rh, produccion
sudo smbpasswd -a NOMBRE             # te pide la contraseña
```

**Cambiar la contraseña de un usuario:**
```bash
sudo smbpasswd NOMBRE
```

**Ver todos los usuarios registrados:**
```bash
sudo pdbedit -L
```

**Reiniciar Samba después de cambios en smb.conf:**
```bash
sudo systemctl restart smbd nmbd
```

---

## Cliente Windows — Windows 10 / 11

### Acceso rápido (sin instalar nada)

Windows soporta SMB de forma nativa. No necesitas instalar ningún programa.

1. Abre el **Explorador de archivos** (Win+E)
2. En la barra de direcciones escribe:
   ```
   \IP_DEL_SERVIDOR
   ```
3. Presiona **Enter**
4. Windows pedirá usuario y contraseña → ingresa las credenciales de tu cuenta del NAS
5. Verás las carpetas compartidas disponibles para tu usuario

### Script de configuración (opcional)

El script hace verificaciones automáticas (SMB habilitado, firewall, conectividad) y aplica el fix para el error de invitado en Windows 10/11.

**Antes de ejecutar:** edita `setup_cliente_windows.ps1` y cambia `$IP_SERVIDOR` por la IP real del servidor.

```powershell
# 1. Abrir PowerShell como Administrador
# 2. Habilitar ejecución de scripts (solo la primera vez):
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# 3. Ejecutar:
.\setup_cliente_windows.ps1
```

### Mapear unidades de red (acceso permanente)

Para que las carpetas aparezcan como unidades de disco en "Este Equipo":

```powershell
# Carpeta pública (usuario invitado)
net use P: \IP_SERVIDOR\publico /user:invitado PASS /persistent:yes

# Carpeta de departamento (reemplaza CARPETA, USUARIO y PASS)
net use D: \IP_SERVIDOR\CARPETA /user:USUARIO PASS /persistent:yes
```

O desde el Explorador: clic derecho en la carpeta → **Conectar a unidad de red**.

---

## Cliente Arch Linux

### Requisitos previos

Edita `setup_cliente_arch.sh` y cambia `IP_SERVIDOR` por la IP real del servidor.

### Instalación

```bash
sudo bash setup_cliente_arch.sh
# o desde el launcher:
python3 configurar.py
```

El script instala `cifs-utils`, `smbclient`, `gvfs` y `gvfs-smb`.

### Acceso desde Thunar (recomendado)

1. Abre **Thunar**
2. Presiona **Ctrl+L** para abrir la barra de ubicación
3. Escribe:
   ```
   smb://IP_DEL_SERVIDOR
   ```
4. Thunar pedirá usuario y contraseña
5. Navega las carpetas como si fueran locales

> Si no aparece la barra de ubicación: menú **Ver → Mostrar barra de ubicación**

### Acceso desde terminal (montaje manual)

```bash
# Crear punto de montaje
sudo mkdir -p /mnt/nas/publico

# Montar (reemplaza IP, USUARIO, PASS y CARPETA según corresponda)
sudo mount.cifs //IP_SERVIDOR/publico /mnt/nas/publico \
  -o username=invitado,vers=3.0,uid=$(id -u),gid=$(id -g),iocharset=utf8

# Ver el contenido
ls /mnt/nas/publico

# Desmontar
sudo umount /mnt/nas/publico
```

---

## Cliente Ubuntu Desktop

### Requisitos previos

Edita `setup_cliente_ubuntu.sh` y cambia `IP_SERVIDOR` por la IP real del servidor.

### Instalación

```bash
sudo bash setup_cliente_ubuntu.sh
# o desde el launcher:
python3 configurar.py
```

El script instala `cifs-utils`, `smbclient` y `gvfs-backends`.

### Acceso desde Nautilus (recomendado)

**Método 1 — Barra de ubicación:**
1. Abre el **Gestor de archivos** (Nautilus)
2. Presiona **Ctrl+L**
3. Escribe:
   ```
   smb://IP_DEL_SERVIDOR
   ```
4. Ingresa usuario y contraseña

**Método 2 — Otras ubicaciones:**
1. En Nautilus, clic en **Otras ubicaciones** (barra lateral)
2. En la barra inferior **"Conectar al servidor"** escribe:
   ```
   smb://IP_DEL_SERVIDOR
   ```

### Acceso desde terminal (montaje manual)

Mismo proceso que Arch Linux, reemplazando `pacman` por `apt`:

```bash
sudo mkdir -p /mnt/nas/publico
sudo mount.cifs //IP_SERVIDOR/publico /mnt/nas/publico \
  -o username=invitado,vers=3.0,uid=$(id -u),gid=$(id -g),iocharset=utf8
```

---

## Desinstalar / Revertir configuración

Si cometiste un error durante la configuración o simplemente quieres empezar de
cero, cada script de limpieza revierte exactamente lo que hizo su script de setup.

Desde el launcher (recomendado):

```bash
python3 configurar.py   # → opción [3] Desinstalar / Limpiar
```

O directamente:

### Servidor

> **ADVERTENCIA:** Esto elimina permanentemente todos los archivos en
> `/srv/datacorp/` (archivos de todos los usuarios), todos los usuarios y grupos
> del NAS, y desinstala Samba. **No se puede deshacer.**

```bash
sudo bash limpiar_servidor.sh
```

El script pide que escribas `CONFIRMAR` antes de borrar nada.
Detecta automáticamente qué usuarios, grupos y departamentos existen — no
necesitas editar nada.

### Cliente Arch Linux

```bash
sudo bash limpiar_cliente_arch.sh
```

Desmonta `/mnt/nas/`, elimina el directorio y desinstala `cifs-utils`,
`smbclient`, `gvfs` y `gvfs-smb`.

### Cliente Ubuntu Desktop

```bash
sudo bash limpiar_cliente_ubuntu.sh
```

Mismo comportamiento que el de Arch, usando `apt` en lugar de `pacman`.

### Cliente Windows

```powershell
# En PowerShell como Administrador:
.\limpiar_cliente_windows.ps1
```

Elimina unidades de red mapeadas, credenciales cacheadas y revierte la clave
`AllowInsecureGuestAuth` del registro a su valor predeterminado (`0`).

---

## Solución de problemas

### No puedo conectarme al servidor

```bash
# Verificar que Samba está corriendo (en el servidor):
sudo systemctl status smbd

# Verificar que el firewall permite Samba (en el servidor):
sudo ufw allow samba
sudo ufw status

# Verificar conectividad desde el cliente:
ping IP_DEL_SERVIDOR

# Verificar que el puerto SMB está abierto:
# Linux:
nc -zv IP_DEL_SERVIDOR 445
# Windows (PowerShell):
Test-NetConnection -ComputerName IP_DEL_SERVIDOR -Port 445
```

### Error de permisos al intentar escribir

El usuario conectado no tiene permisos de escritura en esa carpeta. Verifica:
- El usuario pertenece al grupo correcto en el servidor
- Estás conectado con el usuario correcto (no con `invitado`)

```bash
# Ver grupos del usuario (en el servidor):
groups NOMBRE_USUARIO

# Ver permisos de la carpeta:
getfacl /srv/datacorp/departamentos/CARPETA
```

### Windows — Error 0xc05d0004 o "acceso de invitado bloqueado"

El script de Windows (`setup_cliente_windows.ps1`) aplica automáticamente el fix. Si el problema persiste, ejecuta en PowerShell como Administrador:

```powershell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "AllowInsecureGuestAuth" -Value 1 -Type DWord -Force
```

### Windows — Las credenciales no funcionan o no pide contraseña

Windows cachea credenciales. Limpia la caché:

```powershell
net use * /delete /yes
cmdkey /delete:IP_DEL_SERVIDOR
```

### Arch/Ubuntu — "mount error(13): Permission denied" al montar

- Verifica que el usuario y contraseña son correctos
- Verifica que el usuario tiene permiso en ese share:
  ```bash
  smbclient //IP_SERVIDOR/CARPETA -U USUARIO
  ```

### smb.conf tiene errores

```bash
# Validar la configuración (en el servidor):
sudo testparm -s
```
