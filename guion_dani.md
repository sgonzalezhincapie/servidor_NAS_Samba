# Guion de Exposición — Daniel (Cliente Windows)

**Rol:** Cliente Windows  
**Equipo:** Windows 10/11  
**Duración estimada:** ~8-10 minutos

---

## BLOQUE 1 — Por qué Windows no necesita instalar nada

> **[Mostrar en pantalla: escritorio de Windows con PowerShell abierto]**

**Decir:**

> Yo soy Daniel y muestro la parte del **cliente Windows**. Ya Manuela configuró el servidor en Ubuntu y Santiago se conectó desde Arch Linux. Ahora yo me conecto desde Windows al **mismo servidor**.
>
> Lo primero que hay que saber es que Windows **no necesita instalar nada**. ¿Por qué? Porque el protocolo SMB lo inventó Microsoft. Windows tiene el cliente SMB integrado desde hace décadas: el Explorador de archivos ya sabe cómo conectarse a carpetas compartidas en red. En cambio, en Linux (como vimos con Santiago) hubo que instalar `cifs-utils` y `smbclient` porque Linux fue diseñado originalmente con otro protocolo, NFS.
>
> Esto demuestra que Samba es **multiplataforma**: un servidor Linux puede atender clientes de cualquier sistema operativo sin problemas.

---

## BLOQUE 2 — Verificar conectividad con el servidor

> **[Mostrar en pantalla: PowerShell]**

**Decir:**

> Antes de conectarme, verifico que hay comunicación con el servidor.

**Ejecutar:**

```powershell
ping <IP_SERVIDOR>
```

*(Reemplazar `<IP_SERVIDOR>` por la IP real que dio Manuela)*

**Decir:**

> El ping responde, hay conexión de red. Ahora verifico que el puerto 445 esté abierto. El puerto 445 es por donde viaja el protocolo SMB.

**Ejecutar:**

```powershell
Test-NetConnection -ComputerName <IP_SERVIDOR> -Port 445
```

**Decir:**

> `TcpTestSucceeded: True` — eso significa que Samba está escuchando y acepta conexiones en ese puerto. Si dijera `False`, sería un problema de firewall o que Samba no está corriendo.

---

## BLOQUE 3 — Acceder desde el Explorador de archivos (método visual)

> **[Mostrar en pantalla: escritorio de Windows]**

**Decir:**

> La forma más intuitiva de acceder es desde el Explorador de archivos, que es como normalmente uno navega carpetas en Windows.

**Ejecutar:**

1. Presionar **Win + R** (se abre "Ejecutar")
2. Escribir `\\<IP_SERVIDOR>` y presionar Enter

**Decir:**

> Windows me pide un usuario y contraseña. Voy a entrar como `dani`, que es el usuario del departamento de contabilidad.

3. Escribir: Usuario → `dani`, Contraseña → `Dani2026`
4. Se abre una ventana con los shares visibles

**Decir (señalando la ventana):**

> Acá vemos las carpetas compartidas del servidor: `publico`, `contabilidad`, `sistemas` y `privado`. Noten que `admin` no aparece — está configurado como oculto en el servidor. Para entrar a ese habría que escribir la ruta completa: `\\<IP_SERVIDOR>\admin`.
>
> Ahora voy a hacer doble clic en `contabilidad`...

5. Abrir la carpeta `contabilidad`

**Decir:**

> Puedo ver los archivos y crear nuevos, porque `dani` tiene permiso de lectura y escritura en contabilidad.

6. Clic derecho → Nuevo → Documento de texto → Nombrar "informe_windows.txt"

**Decir:**

> Acabo de crear un archivo desde Windows que ahora mismo está guardado en el servidor de Manuela, en Ubuntu. Eso es compartir archivos en red de forma multiplataforma.

7. Intentar abrir la carpeta `privado`

**Decir:**

> Y si intento entrar a `privado`... **acceso denegado**. Windows me dice que no tengo permiso. Eso es porque `dani` no está en el grupo `administradores`. Las tres capas de seguridad que explicó Manuela están funcionando: Samba rechaza a cualquiera que no sea administrador para ese recurso.

---

## BLOQUE 4 — Mapear unidades de red con net use (método terminal)

> **[Mostrar en pantalla: PowerShell como Administrador]**

**Decir:**

> La otra forma, que es más técnica y se puede automatizar, es desde PowerShell con el comando `net use`. Esto crea lo que en Windows se llaman **unidades de red mapeadas**, que aparecen en "Este Equipo" con una letra de unidad, como si fueran un disco externo.

**Primero limpiar conexiones anteriores:**

```powershell
net use * /delete /yes
```

**Ejecutar:**

```powershell
net use K: \\<IP_SERVIDOR>\contabilidad /user:dani Dani2026
```

**Decir:**

> Le asigné la letra `K:` al share de contabilidad. La `K` es de Kontabilidad — es solo una convención nuestra para recordar. Ahora puedo navegar esa unidad como si fuera un disco más.

**Ejecutar:**

```powershell
dir K:\
```

**Decir:**

> Ahí están los archivos del servidor. Si Santiago creó un archivo desde Arch Linux, yo lo puedo ver acá desde Windows. Y viceversa.

---

### Mapear el resto de shares como admin

**Ejecutar:**

```powershell
net use P: \\<IP_SERVIDOR>\publico /user:admin Admin2026
net use S: \\<IP_SERVIDOR>\sistemas /user:admin Admin2026
net use V: \\<IP_SERVIDOR>\privado /user:admin Admin2026
```

**Decir:**

> Acá me conecto como `admin`, que tiene acceso a todo. Fíjense las letras que usamos:
> - **P** de Público
> - **K** de Kontabilidad
> - **S** de Sistemas
> - **V** de priVado
>
> Ahora en "Este Equipo" aparecen todas esas unidades como si fueran discos locales, pero los archivos están en el servidor Ubuntu de Manuela.

---

## BLOQUE 5 — Verificar la versión de SMB

> **[Mostrar en pantalla: PowerShell como Administrador]**

**Decir:**

> Un detalle de seguridad importante: ¿qué versión de SMB estamos usando? Nuestro servidor exige mínimo **SMB2** y se negocia automáticamente la más alta disponible. SMB1 está deshabilitado porque tiene vulnerabilidades graves.

**Ejecutar:**

```powershell
Get-SmbConnection | Format-Table ServerName, ShareName, Dialect
```

**Decir:**

> En la columna `Dialect` se ve la versión negociada. Debería decir `3.x.x`, que es SMB3 — la versión más moderna y segura que **cifra los datos en tránsito**. Eso significa que aunque alguien capture el tráfico de la red, no puede leer los archivos que estamos transfiriendo.

---

## BLOQUE 6 — Pruebas de permisos cruzadas

> **[Mostrar en pantalla: PowerShell]**

**Decir:**

> Ahora hago las mismas pruebas de permisos que hizo Santiago pero desde Windows, para demostrar que el control de acceso funciona igual sin importar el sistema operativo del cliente.

---

### Prueba 1: dani puede escribir en contabilidad ✓

**Ejecutar:**

```powershell
net use * /delete /yes
net use K: \\<IP_SERVIDOR>\contabilidad /user:dani Dani2026
echo "Informe desde Windows - dani" > K:\informe_dani_windows.txt
type K:\informe_dani_windows.txt
```

**Decir:**

> Funciona. `dani` puede crear archivos en contabilidad porque pertenece a ese grupo.

---

### Prueba 2: dani NO puede entrar a sistemas ✗

**Ejecutar:**

```powershell
net use S: \\<IP_SERVIDOR>\sistemas /user:dani Dani2026
```

**Decir:**

> Error de sistema 5: **acceso denegado**. `dani` no pertenece al grupo `sistemas`, así que no puede entrar. El mismo usuario, en el mismo servidor, pero con resultados distintos según la carpeta. Eso es RBAC en acción.

---

### Prueba 3: admin accede a todo ✓

**Ejecutar:**

```powershell
net use V: \\<IP_SERVIDOR>\privado /user:admin Admin2026
echo "Documento confidencial desde Windows" > V:\secreto.txt
type V:\secreto.txt
```

**Decir:**

> El admin puede entrar a `privado` y escribir sin problemas. Y si Manuela ejecuta `sudo smbstatus` en el servidor ahora mismo, va a poder ver mi conexión activa desde Windows con la IP de mi equipo.

---

## BLOQUE 7 — Desconectar y cierre

**Ejecutar:**

```powershell
net use * /delete /yes
```

**Decir:**

> Para desconectar todas las unidades uso `net use * /delete`. Los archivos siguen en el servidor, solo se desconecta mi acceso.
>
> En resumen: desde Windows accedemos al **mismo servidor Linux** que Santiago accede desde Arch Linux. Los permisos son los mismos, las carpetas son las mismas, la seguridad es la misma. Eso es lo que hace Samba: ser el puente entre todos los sistemas operativos para compartir archivos de forma segura y controlada.

---

## BLOQUE 8 — Cierre conjunto (si aplica)

**Decir (cualquiera de los tres):**

> Para cerrar: lo que demostramos hoy es un NAS funcional con Samba, donde un servidor Linux comparte archivos con clientes de diferentes sistemas operativos, con un modelo de control de acceso basado en roles que usa tres capas de seguridad: permisos POSIX, ACLs y directivas de Samba. Todo con software libre y en un entorno real con tres computadores.

---

## TIPS PARA LA GRABACIÓN

- Si Windows te dice "¿desea permitir que este dispositivo sea detectable?" al conectarte, dale que sí.
- Si no te pide contraseña y entra con credenciales viejas, ejecutá `net use * /delete /yes` primero para limpiar cache.
- Si aún así no pide contraseña, abrí el **Administrador de credenciales** (buscar "Credential Manager" en el menú Inicio) y eliminá las entradas del servidor.
- Ejecutá PowerShell **como Administrador** (clic derecho → "Ejecutar como administrador").
- El método visual (Win + R → `\\IP`) es más impactante para la grabación que `net use` — mostrá los dos.
- Tené la IP del servidor anotada en un sticky note en la pantalla.
