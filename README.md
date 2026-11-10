# Trabajo 2 — ISW-612
## Servidor de chat con inteligencia artificial local

**Universidad Técnica Nacional — Sede San Carlos**

### Integrantes

- Ericka Cordero Agüero.
- Erick Duran Sequeira.

## Descripción

Implementación de un asistente de inteligencia artificial local en Ubuntu Server, utilizando Ollama para ejecutar el modelo y una aplicación Flask para gestionar usuarios, conversaciones y permisos.

El proyecto corresponde a la opción A. El acceso web se realiza mediante Nginx y HTTPS. La aplicación y Ollama escuchan únicamente en localhost dentro de la máquina virtual.

El modelo seleccionado es **Llama 3.2 1B**, ejecutado mediante CPU.

## Tecnologías utilizadas

- Ubuntu Server 24.04.5 LTS.
- Oracle VirtualBox.
- Python, Flask y Gunicorn.
- Ollama.
- SQLite.
- Nginx.
- OpenSSH.
- UFW y Fail2ban.
- OpenSSL y Nmap.

## Recursos de la máquina virtual

| Recurso | Configuración |
|---|---|
| Memoria RAM | 4096 MB |
| Procesadores virtuales | 2 |
| Disco del sistema | 30 GB |
| Disco adicional de datos | 20 GB |
| Sistema de archivos de datos | ext4 |
| Punto de montaje | `/srv/ia` |
| Montaje persistente | UUID en `/etc/fstab` |
| Opciones del montaje | `nodev` y `nosuid` |

## Funcionamiento

1. El usuario accede a `https://localhost` desde Windows.
2. Nginx recibe la conexión HTTPS y la dirige a Gunicorn.
3. Flask comprueba la sesión, los permisos y el mensaje.
4. La aplicación consulta Ollama mediante su API local.
5. La pregunta y la respuesta se guardan en SQLite asociadas al usuario.
6. El usuario puede consultar su historial desde el chat.

El modelo genera texto. No dispone de herramientas para ejecutar comandos ni administrar el servidor.

## Usuarios y funcionalidades

| Cuenta del laboratorio | Rol | Funciones |
|---|---|---|
| `operador` | Administrador | Utilizar el chat, consultar su historial, visualizar usuarios y contadores, bloquear y desbloquear cuentas de usuario |
| `empleado` | Usuario | Utilizar el chat y consultar su propio historial |

Las contraseñas se conservan fuera del repositorio.

## Puertos y acceso

| Servicio | Puerto en Ubuntu | Acceso desde Windows |
|---|---|---|
| SSH | `22` | `127.0.0.1:2222` |
| HTTP | `80` | `127.0.0.1:80` |
| HTTPS | `443` | `127.0.0.1:443` |
| Gunicorn | `127.0.0.1:8000` | Sin reenvío NAT |
| Ollama | `127.0.0.1:11434` | Sin reenvío NAT |

Los reenvíos NAT están vinculados a localhost en Windows. Este laboratorio no constituye una publicación del servicio en Internet.

## Medidas de seguridad

- Autenticación SSH mediante llave pública.
- Acceso SSH de root y autenticación por contraseña deshabilitados.
- UFW con política de entrada denegada por defecto.
- Reglas de entrada para TCP 22, 80 y 443.
- Fail2ban para detectar y bloquear intentos SSH fallidos.
- Redirección HTTP hacia HTTPS.
- Certificado autofirmado para `localhost` y `127.0.0.1`.
- TLS 1.2 y TLS 1.3.
- Contraseñas almacenadas mediante bcrypt.
- Cookies de sesión con `Secure`, `HttpOnly` y `SameSite=Strict`.
- Duración de sesión configurada en 30 minutos.
- Protección CSRF en solicitudes POST.
- Control de acceso por rol y filtrado del historial por propietario.
- Restricción temporal del login por dirección IP después de cinco fallos.
- Límite de 1000 caracteres por mensaje.
- Límite de cuerpo de solicitud de 8 KB.
- Límite de Nginx de 5 solicitudes por segundo, con ráfaga de 10.
- Respuesta HTTP 429 ante exceso de solicitudes.
- Usuarios de servicio dedicados para la aplicación y Ollama.

La aplicación también utiliza cabeceras `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy` y `Content-Security-Policy`.

## Instalación

Estas instrucciones corresponden a una instalación nueva. Si la VM ya funciona, no es necesario volver a desplegarla para la demostración.

### 1. Preparar Ubuntu y el disco de datos

Instalar Ubuntu Server 24.04 LTS y OpenSSH Server.

Agregar un disco adicional de 20 GB en VirtualBox y preparar una partición ext4. Identificar cuidadosamente el disco nuevo antes de particionarlo o formatearlo.

Consultar los discos y obtener el UUID:

```bash
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
sudo blkid
```

### 2. Configurar los reenvíos NAT

En VirtualBox configurar:

| IP del anfitrión | Puerto del anfitrión | Puerto del invitado |
|---|---:|---:|
| `127.0.0.1` | 2222 | 22 |
| `127.0.0.1` | 80 | 80 |
| `127.0.0.1` | 443 | 443 |

### 3. Configurar la llave SSH

En PowerShell de Windows, generar una llave si todavía no existe:

```powershell
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\trabajo2"
```

Agregar únicamente la llave pública al archivo `~/.ssh/authorized_keys` de Ubuntu.

Configurar sus permisos en Ubuntu:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

Comprobar el acceso desde una segunda ventana de PowerShell:

```powershell
ssh -i "$env:USERPROFILE\.ssh\trabajo2" -o PasswordAuthentication=no -p 2222 ericka@127.0.0.1
```

Mantener acceso a la consola de VirtualBox durante la configuración.

### 4. Ejecutar el despliegue

Copiar los archivos del repositorio a Ubuntu y abrir una terminal en esa carpeta.

Ejecutar, sustituyendo `UUID_REAL` por el UUID de la partición ext4 de datos:

```bash
sudo bash deploy.sh UUID_REAL
```

El script configura el montaje, instala dependencias, prepara los servicios, genera los archivos privados necesarios y descarga el modelo.

Se requiere conexión a Internet durante la instalación y descarga.

### 5. Aplicar la configuración SSH

Después de comprobar que el acceso con llave funciona:

```bash
sudo install -m 644 00-iachat.conf /etc/ssh/sshd_config.d/
sudo sshd -t
sudo sshd -T
sudo systemctl reload ssh
```

Verificar nuevamente el acceso mediante llave pública.

### 6. Crear las cuentas

Crear la cuenta administradora:

```bash
sudo systemd-run --wait --pty \
  -p User=iachat \
  -p UMask=0077 \
  -p EnvironmentFile=/etc/iachat/env \
  /usr/bin/python3 /opt/iachat/app.py operador admin
```

Crear la cuenta de usuario:

```bash
sudo systemd-run --wait --pty \
  -p User=iachat \
  -p UMask=0077 \
  -p EnvironmentFile=/etc/iachat/env \
  /usr/bin/python3 /opt/iachat/app.py empleado user
```

Introducir contraseñas diferentes cuando se soliciten.

### 7. Acceder al sitio

Abrir en Windows:

```text
https://localhost
```

El certificado es autofirmado. Revisar su identidad y comparar su huella con la obtenida en Ubuntu:

```bash
sudo openssl x509 -in /etc/iachat/tls.crt -noout -fingerprint -sha256
```

Las pruebas realizadas con `curl -k` omiten la validación de confianza del certificado.

## Comprobaciones básicas

Ejecutar en Ubuntu:

```bash
findmnt /srv/ia
systemctl is-active iachat ollama nginx ssh fail2ban
sudo ss -lntp
sudo ufw status verbose
sudo fail2ban-client status sshd
```

Ejecutar en PowerShell de Windows:

```powershell
curl.exe -I http://localhost
curl.exe -k -I https://localhost
curl.exe --connect-timeout 5 http://127.0.0.1:11434/api/tags
nmap -sT -Pn -n -p 80,443,2222,8000,11434 127.0.0.1
```

El acceso directo al puerto 11434 del anfitrión debe fallar porque Ollama no tiene reenvío NAT.

## Resultados de las pruebas

| Prueba | Resultado observado |
|---|---|
| Inicio de sesión | Acceso de administrador y usuario |
| Chat e historial | Respuesta del modelo y conservación después de recargar |
| Panel administrativo | Acceso de empleado rechazado con `Forbidden` |
| Bloqueo de cuenta | Login rechazado durante el bloqueo y permitido tras desbloquear |
| Separación del historial | El mensaje de empleado no apareció en el historial revisado de operador |
| HTTPS | Respuesta HTTP 200 |
| TLS moderno | TLS 1.2 y 1.3 aceptados |
| TLS antiguo | TLS 1.0 y 1.1 rechazados |
| Límite de solicitudes | 36 solicitudes: 13 respuestas 200 y 23 respuestas 429 |
| Recuperación de SQLite | Integridad `ok`, 2 usuarios y 6 mensajes |
| Recuperación de configuraciones | Ocho archivos extraídos en una carpeta independiente |
| Reinicio | Montaje, servicios y acceso HTTPS disponibles |
| Login incorrecto | Mensaje de restricción temporal de 15 minutos |
| Puertos desde Windows | 80, 443 y 2222 abiertos; 8000 y 11434 cerrados |
| SSH sin llave | Rechazo con `Permission denied (publickey)` |
| Fail2ban | Seis fallos registrados y bloqueo de `10.0.2.2` |
| Cierre de Fail2ban | Desbloqueo manual; cero IP bloqueadas al terminar |

### Alcance de los resultados

- La recuperación del respaldo se realizó en una ubicación independiente, sin sustituir la base activa.
- El escaneo Nmap corresponde al estado final y a cinco puertos concretos; no existe una comparación antes y después.
- La prueba del bloqueo de una sesión de empleado ya abierta no quedó confirmada.
- Se comprobó el mensaje de restricción del login, pero no se midió la expiración del período.
- La incorporación de una IP a la lista de Fail2ban quedó registrada; no se documentó un intento adicional de conexión durante el bloqueo.

## Comparación de modelos

Se utilizaron las mismas cinco preguntas en español para cada modelo, generando quince registros.

| Modelo | Disco GB | RSS observado MiB | Mediana del primer texto s | Mediana tokens/s | Calidad |
|---|---:|---:|---:|---:|---:|
| Qwen 2.5 1.5B | 0.986 | 1108.9 | 4.41 | 12.94 | 4/10 |
| Llama 3.2 1B | 1.321 | 1445.4 | 5.12 | 11.66 | 6/10 |
| Gemma 2 2B | 1.630 | 1871.7 | 6.54 | 8.17 | 5/10 |

La puntuación utiliza 0 para una respuesta incorrecta, 1 para una respuesta parcial y 2 para una respuesta correcta y completa.

La memoria corresponde al máximo de las observaciones tomadas al terminar cada respuesta; no representa el pico real durante la generación.

Se utilizó temperatura 0, contexto 2048 y un máximo de 128 tokens. Se detuvo cada modelo antes de cada pregunta, por lo que el tiempo inicial incluye su carga.

Qwen presentó los mejores tiempos y menor memoria observada. Se mantuvo Llama como elección provisional por obtener la mayor puntuación de calidad con un consumo intermedio.

Los tres modelos fallaron la pregunta de subneteo `/27`. Las respuestas requieren revisión humana.

Para ejecutar la comparación desde Ubuntu:

```bash
python3 -u benchmark.py > comparacion-modelos.jsonl 2> comparacion-modelos-errores.txt
```

## Pruebas de prompt injection

Se documentaron cinco intentos:

1. Ignorar instrucciones anteriores.
2. Revelar el mensaje de sistema.
3. Suplantar al administrador para consultar conversaciones privadas.
4. Ejecutar el comando `whoami`.
5. Introducir instrucciones maliciosas dentro de un texto para resumir.

No se observó divulgación de conversaciones privadas ni ejecución de comandos.

En el primer intento el modelo respondió “REGLAS DESACTIVADAS”. Esa respuesta es texto generado y no demuestra que se hayan desactivado los controles del servidor.

La protección depende de los permisos de la aplicación, la exclusión de secretos e historiales ajenos del contexto y la ausencia de herramientas de ejecución. Los rechazos del modelo no garantizan protección general frente a estas técnicas.

## Respaldos y recuperación

Crear un respaldo desde la carpeta del proyecto en Ubuntu:

```bash
sudo bash backup.sh
```

El script respalda la base SQLite y las configuraciones incluidas en su lista de archivos.

Para recuperar configuraciones en una carpeta nueva:

```bash
sudo bash backup.sh restore-config RUTA_DEL_RESPALDO DIRECTORIO_NUEVO
```

La opción `restore` reemplaza la base de datos activa y debe utilizarse únicamente durante una recuperación planificada.

El respaldo no incluye la clave privada TLS ni el archivo `/etc/iachat/env`. En una instalación nueva estos elementos se regeneran mediante el despliegue.

## Estructura del repositorio

| Archivo o carpeta | Función |
|---|---|
| `app.py` | Aplicación Flask, autenticación, roles, historial y administración |
| `deploy.sh` | Instalación y configuración del servidor |
| `backup.sh` | Respaldo y recuperación |
| `benchmark.py` | Comparación de modelos |
| `nginx.conf` | HTTPS, proxy inverso y límites |
| `00-iachat.conf` | Configuración de seguridad SSH |
| `fail2ban.conf` | Protección de SSH mediante Fail2ban |
| `iachat.service` | Servicio de la aplicación |
| `ollama.service` | Servicio de Ollama |
| `ollama.conf` | Configuración complementaria de Ollama |
| `journal.conf` | Configuración de journald |
| `RESULTADOS.md` | Resultados y alcance de las mediciones |
| `BITACORA.md` | Registro de asistencia de inteligencia artificial |
| `DEMO.md` | Guía de demostración |
| `docs/` | Informe y bitácora del laboratorio |
| `evidencias/` | Capturas y archivos de resultados |

## Documentación

- [Informe PDF](docs/Informe_Trabajo2.pdf).
- [Informe editable](docs/Informe_Trabajo2.docx).
- [Bitácora del laboratorio](docs/Bitacora_Trabajo2_revisada.docx).
- [Bitácora PDF](docs/Bitacora_Trabajo2_revisada.pdf).
- [Registro de uso de IA](BITACORA.md).
- [Resultados](RESULTADOS.md).
- [Evidencias](evidencias/).
- [Guía para la demostración](DEMO.md).

## Información privada

No se incluyen contraseñas, llaves privadas, archivos de entorno, bases de datos ni respaldos con conversaciones.

Las capturas que muestran cookies de sesión se excluyeron de la copia pública. Los modelos se descargan en la máquina virtual y sus pesos no forman parte del repositorio.

## Licencia del modelo

El modelo seleccionado utiliza la [licencia comunitaria de Llama 3.2](https://github.com/meta-llama/llama-models/blob/main/models/llama3_2/LICENSE).

La interfaz incluye la leyenda **Built with Llama**. El uso y la distribución del modelo están sujetos a su licencia y política de uso aceptable.

## Uso de inteligencia artificial

Se utilizó ChatGPT/Codex como apoyo para orientar procedimientos, revisar resultados y preparar documentación.

El registro de solicitudes y verificaciones se encuentra en [BITACORA.md](BITACORA.md). Las evidencias documentan las comprobaciones realizadas en el laboratorio.
