# Resultados en la VM de entrega

Se midieron cinco preguntas en español por modelo en Ubuntu Server 24.04.5 LTS, con 4 GB de RAM y dos vCPU. Antes de cada pregunta se descargó el modelo de RAM. Se usaron contexto de 2048 tokens, temperatura cero y una salida máxima de 128 tokens.

| Modelo | Disco (GB) | RSS máx. (MiB) | Primer texto mediano (s) | Tokens/s medianos | Calidad |
|---|---:|---:|---:|---:|---:|
| Qwen2.5 1.5B | 0.99 | 1247 | 8.09 | 4.45 | 5/10 |
| Llama 3.2 1B | 1.32 | 1439 | 7.39 | 8.47 | 6/10 |
| Gemma 2 2B | 1.63 | 1859 | 8.23 | 5.88 | 5/10 |

Se seleccionó Llama 3.2 1B por la mayor tasa de generación, el menor tiempo mediano al primer texto y la mejor puntuación entre los modelos. Los tres fallaron la pregunta IPv4 /27. El límite de salida dejó incompletas varias respuestas. La primera fase coincidió con descargas en segundo plano, por lo que los tiempos describen esta ejecución.

## Controles observados

- La VM expuso 22, 80 y 443. La aplicación y Ollama quedaron en loopback. Desde Windows falló la conexión a 11434.
- UFW denegó entrada por defecto. SSH permitió la llave y rechazó el método de contraseña. Fail2ban registró un bloqueo y el posterior desbloqueo del origen NAT de prueba.
- HTTP redirigió con 308. Se comprobó TLS 1.2 y 1.3, rechazo de TLS 1.1 y cabeceras de seguridad.
- El panel devolvió 403 para el empleado y 200 para el administrador. El bloqueo de usuario retiró el acceso. La sexta contraseña incorrecta dio 429.
- En una ráfaga de 36 solicitudes se observaron 13 respuestas 429 de Nginx. Se verificaron el límite de 1000 caracteres, el límite de cuerpo HTTP y el rechazo de una solicitud sin CSRF.
- Se realizaron cinco pruebas de prompt injection con Llama. En una de ellas sugirió al usuario un comando inseguro. La aplicación carece de herramientas de ejecución y el modelo solo recibió el mensaje y la instrucción de comportamiento.
- El respaldo recuperó el historial de 6 mensajes después de insertar un séptimo. SQLite devolvió `ok` y los ocho archivos de configuración recuperados coincidieron con los activos.
- Tras reiniciar Ubuntu se montó `/srv/ia` y se verificaron activos Nginx, Ollama, la aplicación y Fail2ban.

El informe y el paquete de evidencias incluyen las respuestas y las salidas completas. [Pasos para reproducir la demo](DEMO.md).
