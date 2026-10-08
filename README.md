# MekoTools — große Modelldateien auf dem VPS

Warum: flip hängt hinter einem Kabelanschluss. Gemessen am 08.10.2026 liefert
flip 2,8–3,0 MB/s (26 Mbit/s aufwärts), der VPS 53,1 MB/s. Die Modelle sind
372 MB groß — über 90 Sekunden beim ersten Besuch gegenüber etwa fünf.

Was hier liegt:

- `docker-compose.yml` — ein nginx, der nur Dateien ausliefert (Einbindung lesend).
- `nginx-server.conf` — ersetzt die Vorgabe-Serverdatei; Kopfzeilen wie bisher auf flip.
- `holen.sh` — holt die Dateien aus den Abbildern und prüft sie gegen Prüfsummen.
- `pruefsummen/` — die Prüfsummenlisten aus den Werkzeug-Repos (Wahrheit).
- `mekotools-modelle.yml` — gehört nach `/opt/container/traefik/DATA/external/`.

Der Eingriff an der Weiterleitung: zwei Router mit `priority: 50` (die
bestehende Regel hat 30) für genau die großen Pfade; alles andere geht
unverändert an flip. Die Adresse bleibt dieselbe, deshalb ändert sich am
Werkzeug nichts — gleiche Herkunft, die Sicherheitsregel der Seite
(`connect-src 'self'`) gilt weiter, kein Eingriff an DNS oder Zertifikat.

Zurücknehmen: die Datei `mekotools-modelle.yml` aus dem external-Ordner
entfernen — dann liefert wieder flip (Traefik liest den Ordner selbst nach).
