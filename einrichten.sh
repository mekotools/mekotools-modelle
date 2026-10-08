#!/bin/bash
# Richtet die Auslieferung auf einem frischen VPS ein (Wiederaufbau).
#
# Annahme: Docker vorhanden, das Netz "traefik-proxy" existiert (Traefik läuft),
# und /opt/container/traefik/DATA/external/ ist der nachgelesene Ordner.
#
#   ./einrichten.sh <verdauungswert-sprachmodell> <verdauungswert-vorlesen>
#   ./einrichten.sh --nur-regeln          # ohne Modelle zu holen
set -euo pipefail
HIER="$(cd "$(dirname "$0")" && pwd)"
TRAEFIK="${TRAEFIK_ORDNER:-/opt/container/traefik/DATA/external}"

if [ "${1:-}" != "--nur-regeln" ]; then
  "$HIER/holen.sh" "$1" "$2"
fi

echo "== Auslieferdienst starten =="
cd "$HIER"
docker compose up -d
sleep 3
docker exec mekotools-modelle nginx -t 2>&1 | tail -1

echo "== Weiterleitung einschalten =="
mkdir -p "$TRAEFIK"
if [ -e "$TRAEFIK/mekotools-modelle.yml" ]; then
  echo "   Regel liegt schon dort — unverändert gelassen"
else
  cp "$HIER/mekotools-modelle.yml" "$TRAEFIK/"
  echo "   Regel kopiert nach $TRAEFIK/mekotools-modelle.yml"
fi
sleep 6

echo "== Gegenprobe =="
for u in "https://sprachmodell.mekotools.de/modelle/qwen2.5-0.5b/resolve/main/mlc-chat-config.json" \
         "https://sherpa-tts.mekotools.de/stimmen/stimmen.json"; do
  echo "   $(curl -s -o /dev/null -w '%{http_code}' "$u")  $u"
done
echo "Fertig. Zurücknehmen: $TRAEFIK/mekotools-modelle.yml löschen."
