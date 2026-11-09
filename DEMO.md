# Demostración y pruebas en tu equipo

## 1. Windows y VirtualBox

Abre VirtualBox e inicia **ISW612-IA-ECA** si aparece apagada. En el navegador, visita **https://localhost/**. El certificado es autofirmado. Comprueba que el nombre sea localhost y compara su huella SHA-256 con la que devuelve este comando en Ubuntu:

```bash
sudo openssl x509 -in /etc/iachat/tls.crt -noout -fingerprint -sha256
```

Si la VM ya está desplegada, las contraseñas del chat se guardaron en este archivo local privado. Ábrelo para consultar las claves de **empleado** y **operador**.

```powershell
notepad "$env:LOCALAPPDATA\ISW612\credenciales-chat.json"
```

Entra como empleado y pregunta «¿Qué es DNS en dos frases?». Espera la respuesta, recarga y comprueba que sigue en el historial. En esa misma sesión, abre **https://localhost/admin** y verifica el 403. Cierra sesión, entra como operador y abre **Administración**. Muestra el contador, bloquea temporalmente a empleado y prueba su acceso en otra ventana. Desbloquéalo al terminar.

## 2. PowerShell en Windows

```powershell
curl.exe -I http://localhost/
curl.exe -kI --tlsv1.2 --tls-max 1.2 https://localhost/
curl.exe --connect-timeout 3 http://127.0.0.1:11434/api/tags
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password -p 2222 ericka@127.0.0.1
ssh -i "$env:USERPROFILE\.ssh\isw612_deploy" -p 2222 ericka@127.0.0.1
```

Busca la redirección 308, las cabeceras HTTPS, el fallo de conexión al 11434 y el rechazo de contraseña SSH. El último comando abre Ubuntu con llave. Si tienes Nmap instalado en Windows, ejecuta:

```powershell
nmap -sT -Pn -n -p 80,443,2222,8000,11434 127.0.0.1
```

El reenvío NAT publica 80, 443 y 2222 en Windows. El 2222 corresponde al 22 de Ubuntu. La API y la app interna no tienen reenvío.

## 3. Terminal Ubuntu

Desde la consola de VirtualBox o la sesión SSH abierta en el paso anterior:

```bash
findmnt /srv/ia
systemctl is-active nginx ollama iachat fail2ban
sudo ss -lntp
sudo ufw status verbose
sudo fail2ban-client status sshd
sudo journalctl -u iachat -n 15 --no-pager
sudo tail /var/log/nginx/access.log
curl -fsS http://127.0.0.1:11434/api/tags
```

Verifica ext4 en `/srv/ia`, los cuatro servicios activos y los puertos internos 8000 y 11434 enlazados a 127.0.0.1. En el firewall deben aparecer 22, 80 y 443.

## 4. Pruebas adicionales si el profesor las solicita

- **Login**. Usa una ventana privada del navegador y realiza seis intentos con una contraseña incorrecta. El sexto debe devolver 429. Hazlo al final de la demo, ya que NAT puede agrupar las sesiones bajo una sola IP. Desde Ubuntu, espera 15 minutos o limpia el contador de prueba con `sudo sqlite3 /srv/ia/db/chat.sqlite 'DELETE FROM attempts;'`.
- **Fail2ban**. Mantén abierta la consola de VirtualBox antes de repetir intentos SSH con un usuario inexistente. Desde esa consola, consulta `sudo fail2ban-client status sshd`. Si se bloquea el origen NAT, desbloquéalo con `sudo fail2ban-client set sshd unbanip 10.0.2.2`.
- **Modelos y respaldo**. Desde Ubuntu entra en `~/isw612` y usa los pasos del [README](README.md). Las pruebas de rendimiento cargan tres modelos de uno en uno. Ejecútalas fuera de la demostración si necesitas mantener el chat disponible.
- **Defensa presencial**. Ericka Cordero tiene asignada la presentación de la VM, el disco, el despliegue y la arquitectura. Erick Duran tiene asignada la repetición de las pruebas de seguridad, la revisión de las mediciones y la explicación de la restauración. Cada integrante debe entender el proyecto completo y registrar en Git su propia contribución efectiva.
