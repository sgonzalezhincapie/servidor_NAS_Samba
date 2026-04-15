# Guion de Exposición — Santiago (Cliente Arch Linux)

**Rol:** Cliente Linux  
**Equipo:** Arch Linux  
**Duración estimada:** ~8-10 minutos

---

## BLOQUE 1 — Introducción y ejecutar el script del cliente

> **[Mostrar en pantalla: terminal de Arch Linux]**

**Decir:**

> Yo soy Santiago y voy a mostrar la parte del **cliente Linux** con Arch Linux. Ya Manuela configuró el servidor con Samba en Ubuntu. Ahora lo que yo hago es conectarme desde otro computador para acceder a las carpetas compartidas.
>
> Voy a usar un script que automatiza la configuración del cliente. El script hace 5 cosas: instala los paquetes necesarios, verifica conectividad con el servidor, crea las carpetas donde se van a montar los shares, verifica la versión de SMB y muestra los comandos de montaje.

**Ejecutar:**

```bash
sudo bash setup_cliente_arch.sh
```

**Decir (mientras el script corre, explicar lo que aparece):**

> El script primero instala **cifs-utils** y **smbclient**:
> - **cifs-utils** nos da el comando `mount.cifs`, que permite montar una carpeta remota como si fuera un directorio local en nuestro computador.
> - **smbclient** es una herramienta de terminal para explorar el servidor y listar los recursos compartidos.
>
> Después verifica la conexión con el servidor usando ping y probando que el puerto 445 de SMB esté abierto. Y por último crea las carpetas en `/mnt/datacorp/` donde vamos a montar cada recurso compartido.

---

## BLOQUE 2 — Montar carpetas compartidas y explicar el montaje

> **[Mostrar en pantalla: terminal]**

**Decir:**

> Ahora viene lo importante: **montar las carpetas remotas**. Montar significa que una carpeta que físicamente está en el servidor de Manuela va a aparecer en MI computador como si fuera una carpeta local. Puedo navegar por ella, ver archivos, e incluso crear archivos si tengo permisos.
>
> El script ya creó las carpetas vacías en `/mnt/datacorp/`. Ahora monto cada share con `mount.cifs`.

---

### 2.1 Montar /publico como invitado

**Ejecutar:**

```bash
sudo mount.cifs //<IP_SERVIDOR>/publico /mnt/datacorp/publico \
  -o username=invitado,password=Invitado2026,vers=3.0,uid=$(id -u),gid=$(id -g),iocharset=utf8
```

**Decir (explicando las opciones):**

> Explico cada parte del comando:
> - `//<IP_SERVIDOR>/publico` — es la ruta del share remoto, con la IP del servidor y el nombre del recurso compartido.
> - `/mnt/datacorp/publico` — es la carpeta local donde se va a montar.
> - `username=invitado,password=Invitado2026` — me conecto como el usuario invitado. Aunque en la práctica es una cuenta con permisos mínimos, en Samba tiene su propia contraseña.
> - `vers=3.0` — uso la versión 3 de SMB, que es la más segura. SMB1 está deshabilitado en nuestro servidor porque tiene vulnerabilidades graves (el ransomware WannaCry de 2017 las aprovechó).

**Ejecutar:**

```bash
ls -la /mnt/datacorp/publico
```

**Decir:**

> Y ahí están los archivos del servidor, visibles desde mi computador. Eso es compartir archivos en red.

---

## BLOQUE 3 — Probar que los permisos funcionan (RBAC en acción)

> **[Mostrar en pantalla: terminal]**

**Decir:**

> Ahora viene la parte que demuestra que el modelo RBAC funciona. Voy a conectarme como distintos usuarios y probar qué pueden y qué no pueden hacer.

---

### Prueba 1: santi puede escribir en /sistemas ✓

**Ejecutar:**

```bash
sudo mount.cifs //<IP_SERVIDOR>/sistemas /mnt/datacorp/sistemas \
  -o username=santi,password=Santi2026,vers=3.0,uid=$(id -u),gid=$(id -g)
```

```bash
echo "Reporte de red - prueba de escritura" > /mnt/datacorp/sistemas/reporte_santi.txt
cat /mnt/datacorp/sistemas/reporte_santi.txt
```

**Decir:**

> Me conecto como `santi`, que pertenece al grupo `sistemas`. Puedo escribir en la carpeta de sistemas sin problema. El archivo se creó en el servidor de Manuela, no en mi disco local.

---

### Prueba 2: santi NO puede acceder a /contabilidad ✗

**Ejecutar:**

```bash
sudo mount.cifs //<IP_SERVIDOR>/contabilidad /mnt/datacorp/contabilidad \
  -o username=santi,password=Santi2026,vers=3.0
```

**Decir:**

> Y ahora intento acceder a `/contabilidad` como `santi`... y me dice **Permission denied**. Eso es correcto: `santi` está en el grupo `sistemas`, no en `contabilidad`. Las tres capas de seguridad que explicó Manuela están bloqueando el acceso: Samba ve que `santi` no está en el `valid users` de contabilidad, y el sistema de archivos ve que no tiene ACL para ese directorio.

---

### Prueba 3: santi NO puede acceder a /privado ✗

**Ejecutar:**

```bash
sudo mount.cifs //<IP_SERVIDOR>/privado /mnt/datacorp/privado \
  -o username=santi,password=Santi2026,vers=3.0
```

**Decir:**

> Tampoco puedo entrar a `/privado`, que es exclusivo para administradores. Denegado de nuevo. El sistema RBAC impide que un usuario normal acceda a recursos que no le corresponden.

---

### Prueba 4: admin puede acceder a todo ✓

**Ejecutar:**

```bash
sudo mount.cifs //<IP_SERVIDOR>/privado /mnt/datacorp/privado \
  -o username=admin,password=Admin2026,vers=3.0,uid=$(id -u),gid=$(id -g)
```

```bash
echo "Documento confidencial - solo admin" > /mnt/datacorp/privado/confidencial.txt
cat /mnt/datacorp/privado/confidencial.txt
```

**Decir:**

> Ahora me conecto como `admin` y sí puedo entrar a `/privado`, porque admin está en el grupo `administradores` que tiene acceso total a todas las carpetas. Acá se ve que el mismo computador puede acceder a diferentes recursos según **con qué usuario te conectes**, no según qué computador seas. Eso es la diferencia entre autenticación basada en usuario vs. autenticación basada en IP.

---

## BLOQUE 4 — Explorar con smbclient (modo interactivo)

> **[Mostrar en pantalla: terminal]**

**Decir:**

> Además de montar carpetas, puedo usar `smbclient` en modo interactivo, que funciona como un mini explorador de archivos en la terminal. Es útil para pruebas rápidas.

**Ejecutar:**

```bash
smbclient //<IP_SERVIDOR>/sistemas -U santi
```

*(Poner contraseña: Santi2026)*

**Dentro de smbclient, ejecutar:**

```
smb: \> ls
smb: \> put /etc/hostname prueba_arch.txt
smb: \> ls
smb: \> exit
```

**Decir:**

> Con `ls` listo los archivos del servidor. Con `put` subo un archivo desde mi computador al servidor. Con `get` podría descargar. Es como un FTP pero usando el protocolo SMB. Y noten que estoy usando SMB versión 3, que va cifrado — nadie en la red puede espiar qué archivos estoy transfiriendo.

---

## BLOQUE 5 — Desmontar y verificar SMB

**Ejecutar:**

```bash
# Ver los shares montados actualmente
mount | grep cifs
```

**Decir:**

> Acá veo todos los shares que tengo montados y la versión de SMB que se negoció. Se ve `vers=3.0`, que confirma que estamos usando la versión segura.

**Ejecutar:**

```bash
# Desmontar todo
sudo umount /mnt/datacorp/publico 2>/dev/null
sudo umount /mnt/datacorp/sistemas 2>/dev/null
sudo umount /mnt/datacorp/privado 2>/dev/null
```

**Decir:**

> Cuando terminamos de trabajar, desmontamos con `umount`. Los archivos siguen en el servidor, solo desaparecen de la vista local de mi computador.
>
> En resumen: desde Arch Linux puedo conectarme al servidor de Manuela, montar carpetas remotas como si fueran locales, y los permisos funcionan exactamente igual que si estuviera en el servidor. Ahora Daniel va a mostrar lo mismo pero desde Windows, que es interesante porque es otro sistema operativo totalmente diferente accediendo al mismo servidor Linux.

---

## TIPS PARA LA GRABACIÓN

- Si un montaje ya está hecho de antes, desmontalo primero con `sudo umount /mnt/datacorp/<share>` para que se vea en vivo.
- Si `mount.cifs` da error `Host is down`, agregá `vers=3.0` o `vers=2.1` a las opciones.
- Tené la IP del servidor a mano (Manuela te la da).
- Si te sale `Permission denied` donde se espera acceso, verificá que la contraseña esté bien (es case-sensitive: `Santi2026`, no `santi2026`).
- Usá `clear` entre pruebas para que la pantalla quede limpia.
- Lo más impactante visualmente es la prueba de acceso denegado vs. acceso concedido — resaltá eso.
