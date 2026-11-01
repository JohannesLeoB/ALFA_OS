# Skizzen-Datensatz (ein Durchgang über einen Trainingsplan)

Ausgabe: JSON, keine Namen von Personen, Kunden, Firmen, Lieferanten, Adressen. Pläne heißen „Runde N“, Geräte nach Funktion (gsp, spuele, armatur, muellsystem, steckdose, kochfeld …).

```json
{
  "runde": 1,
  "durchgang": "A",
  "seiten_gelesen": "4/4",
  "zeile": {"nische_b": null, "nische_h": null, "arbeitsplatte_d": null, "ok_ap": null, "elemente": []},
  "schraenke": [
    {
      "pos": 1,
      "typ": "US-…",
      "b": null, "h": null, "t": null, "sockel_h": null,
      "fronten": [{"art": "…", "h": null}],
      "innen": [{"art": "…", "zarge_h": null}],
      "traverse_vorn": null,
      "geraet": null,
      "abweichungen": [{"param": "…", "typwert": null, "ist": null}],
      "belege": {"b": "S.2 Maßkette", "…": "…"},
      "status": {"b": "B|A|N", "…": "…"}
    }
  ],
  "plan_widersprueche": [{"was": "…", "rechnung": "…", "seite": "…"}],
  "unsicher": ["…"]
}
```

Status: B = als Maßzahl im Plan; A = aus Maßzahlen gerechnet (Rechnung in belege); N = geschätzt/angenommen.
Plan-Widersprüche (Summen, die nicht aufgehen; Ansichten, die sich widersprechen) werden notiert, nicht korrigiert. Reale Pläne enthalten menschliche Fehler – das ist normal.
Kein Raster unterstellen: jedes Maß so, wie es im Plan steht oder sich errechnet.
