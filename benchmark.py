import json
import subprocess
import sys
import time
import urllib.request

MODELS = ("qwen2.5:1.5b", "llama3.2:1b", "gemma2:2b")
QUESTIONS = (
    "¿Qué diferencia hay entre TCP y UDP? Da un caso de uso de cada uno.",
    "¿Cuántas direcciones utilizables tiene una red IPv4 /27 convencional? Explica.",
    "Explica qué es DNS en dos frases.",
    "Convierte 3 horas y 45 minutos a segundos. Muestra el cálculo.",
    "Escribe tres pasos para reconocer un correo de phishing sin abrir sus enlaces."
)
URL = "http://127.0.0.1:11434/api/"

def call(endpoint, payload):
    return urllib.request.urlopen(urllib.request.Request(
        URL + endpoint, json.dumps(payload).encode(), {"Content-Type": "application/json"}), timeout=180)

for model in MODELS:
    subprocess.run(["ollama", "pull", model], check=True, stdout=sys.stderr)
    with urllib.request.urlopen(URL + "tags") as response:
        size = next(item["size"] for item in json.load(response)["models"] if item["name"] == model)
    for question in QUESTIONS:
        subprocess.run(["ollama", "stop", model], check=False)
        start = time.monotonic()
        first = None
        parts = []
        with call("generate", {"model": model, "prompt": question,
                               "options": {"num_ctx": 2048, "num_predict": 128, "temperature": 0}}) as response:
            for line in response:
                result = json.loads(line)
                if "error" in result:
                    raise RuntimeError(result["error"])
                if result.get("response"):
                    if first is None:
                        first = time.monotonic() - start
                    parts.append(result["response"])
        with urllib.request.urlopen(URL + "ps") as response:
            resident = next(item["size"] for item in json.load(response)["models"] if item["name"] == model)
        rss = subprocess.check_output(["ps", "-u", "ollama", "-o", "rss="], text=True)
        duration = result.get("eval_duration", 0)
        print(json.dumps(dict(modelo=model, bytes_disco=size, bytes_estimados_modelo=resident,
                              rss_servicio_kib=sum(map(int, rss.split())),
                              primer_texto_s=first, tokens_s=result["eval_count"] * 1e9 / duration if duration else None,
                              pregunta=question, respuesta="".join(parts)), ensure_ascii=False), flush=True)
    subprocess.run(["ollama", "stop", model], check=True)
