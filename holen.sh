#!/bin/bash
# Holt die großen Modelldateien aus den eigenen Abbildern und legt sie bereit.
#
# Quelle bleibt dieselbe wie bisher: die Abbilder in der Registry. Nach dem
# Auspacken wird jede Datei gegen die Prüfsumme aus dem Werkzeug-Repo gestellt.
# Stimmt etwas nicht, bricht das Skript ab, bevor der laufende Stand ersetzt
# wird — es gibt keinen halb ausgetauschten Zustand.
#
#   ./holen.sh <verdauungswert-sprachmodell> <verdauungswert-vorlesen>
#
# Beide Verdauungswerte sind die, die auf flip im Aufsatz stehen (dort mit
# "grep image:" nachsehen) — so liefern VPS und flip dieselben Bytes.
set -euo pipefail

HIER="$(cd "$(dirname "$0")" && pwd)"
SPRACH="${1:?Verdauungswert des Sprachmodells fehlt (sha256:...)}"
VORLESE="${2:?Verdauungswert des Vorlesens fehlt (sha256:...)}"
ZIEL="$HIER/DATA"
NEU="$HIER/auspacken"

SPRACH_BILD="ghcr.io/mekotools/web-llm-chat@$SPRACH"
VORLESE_BILD="ghcr.io/mekotools/sherpa-tts@$VORLESE"

rm -rf "$NEU"
mkdir -p "$NEU/modelle" "$NEU/wasm" "$NEU/stimmen"

echo "== Abbilder holen =="
docker pull -q "$SPRACH_BILD"
docker pull -q "$VORLESE_BILD"

echo "== Sprachmodell auspacken =="
C=$(docker create "$SPRACH_BILD")
docker cp "$C:/app/public/modelle/." "$NEU/modelle/"
docker cp "$C:/app/public/wasm/." "$NEU/wasm/"
docker rm -f "$C" >/dev/null

echo "== Vorlesen auspacken =="
C=$(docker create "$VORLESE_BILD")
docker cp "$C:/usr/share/nginx/html/stimmen/." "$NEU/stimmen/"
for f in sherpa-onnx-wasm-main-tts.wasm sherpa-onnx-wasm-main-tts.data \
         sherpa-onnx-wasm-main-tts.js sherpa-onnx-tts.js sherpa-onnx-tts.worker.js; do
  docker cp "$C:/usr/share/nginx/html/$f" "$NEU/$f"
done
docker rm -f "$C" >/dev/null

echo "== Prüfsummen stellen =="
( cd "$NEU/modelle/qwen2.5-0.5b/resolve/main" \
  && sha256sum -c "$HIER/pruefsummen/sha256sums.txt" --quiet ) \
  && echo "   Gewichte: $(ls "$NEU/modelle/qwen2.5-0.5b/resolve/main" | wc -l) Dateien in Ordnung"
( cd "$NEU/wasm" \
  && sha256sum -c "$HIER/pruefsummen/sha256sums-rechenkern.txt" --quiet ) \
  && echo "   Rechenkern des Sprachmodells: in Ordnung"
python3 "$HIER/pruefsummen/stimmen_pruefen.py" "$NEU" || exit 1

echo "== Übernehmen (der laufende Stand bleibt bis zum letzten Moment stehen) =="
mkdir -p "$ZIEL"
for eintrag in modelle wasm stimmen; do
  rm -rf "$ZIEL/.alt-$eintrag"
  [ -e "$ZIEL/$eintrag" ] && mv "$ZIEL/$eintrag" "$ZIEL/.alt-$eintrag"
  mv "$NEU/$eintrag" "$ZIEL/$eintrag"
  rm -rf "$ZIEL/.alt-$eintrag"
done
for f in sherpa-onnx-wasm-main-tts.wasm sherpa-onnx-wasm-main-tts.data \
         sherpa-onnx-wasm-main-tts.js sherpa-onnx-tts.js sherpa-onnx-tts.worker.js; do
  cp -f "$NEU/$f" "$ZIEL/$f"
done
rm -rf "$NEU"

echo "== Stand =="
du -sh "$ZIEL"/modelle "$ZIEL"/wasm "$ZIEL"/stimmen
docker exec mekotools-modelle nginx -t 2>&1 | tail -1
echo "Fertig. Probe:"
echo "  curl -sI https://sprachmodell.mekotools.de/modelle/qwen2.5-0.5b/resolve/main/mlc-chat-config.json | head -3"
