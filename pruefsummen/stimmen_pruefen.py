"""Prüft die vier Stimmen gegen die Angaben der Stimmenliste.

Beide Werte kommen aus derselben Quelle: stimmen.json nennt Dateiname, Größe
und die vollständige Prüfsumme. Der Dateiname trägt zusätzlich die ersten acht
Zeichen der Prüfsumme — weicht das ab, ist die Datei nicht die, die sie
behauptet zu sein.
"""
import hashlib
import json
import os
import sys

wurzel = sys.argv[1]
liste = os.path.join(wurzel, "stimmen", "stimmen.json")
with open(liste, encoding="utf-8") as fh:
    katalog = json.load(fh)

fehler = []
for stimme in katalog["stimmen"]:
    pfad = os.path.join(wurzel, "stimmen", stimme["datei"])
    if not os.path.isfile(pfad):
        fehler.append(f"fehlt: {stimme['datei']}")
        continue
    groesse = os.path.getsize(pfad)
    if groesse != stimme["groesse"]:
        fehler.append(f"{stimme['datei']}: {groesse} B statt {stimme['groesse']} B")
        continue
    h = hashlib.sha256()
    with open(pfad, "rb") as fh:
        for stueck in iter(lambda: fh.read(1 << 20), b""):
            h.update(stueck)
    ist = h.hexdigest()
    if ist != stimme["pruefsumme"]:
        fehler.append(f"{stimme['datei']}: Prüfsumme {ist[:16]} statt {stimme['pruefsumme'][:16]}")
        continue
    # Der Dateiname führt die ersten acht Zeichen der Prüfsumme mit.
    ohne_endung = stimme["datei"].rsplit(".onnx", 1)[0]
    kurz = ohne_endung.rsplit("-", 1)[-1]
    if not ist.startswith(kurz):
        fehler.append(f"{stimme['datei']}: Namenskürzel {kurz} passt nicht zur Prüfsumme")

if fehler:
    print("ABBRUCH: die Stimmen stimmen nicht mit der Liste überein:")
    for f in fehler:
        print("   " + f)
    raise SystemExit(1)
print(f"   Stimmen: {len(katalog['stimmen'])} Dateien in Ordnung "
      f"({sum(s['groesse'] for s in katalog['stimmen']) / 1048576:.1f} MB)")
