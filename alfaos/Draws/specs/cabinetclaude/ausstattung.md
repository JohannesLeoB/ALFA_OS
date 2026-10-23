# Ausstattung

Sichtbar = in der Präsentation (Ansicht/Render) gezeigt. Modell: Part, Unit (bewegt) oder Metadatum.

| Element | Sichtbar | Modell | Status |
|---|---|---|---|
| Innenschublade | ja, bei offener Tür | Part + Unit slide | offen |
| Auszug (Vollauszug) | ja | Unit slide (Front trägt Korpusinhalt) | Front gebaut, Kasten offen |
| Apothekerauszug | ja | Unit pullout, schmal, hoch | offen |
| Eckkarussell | ja | Unit hinge/Drehung z | offen |
| Eck-Auszug | ja | Unit slide mit Gelenk | offen |
| Abfallsystem | ja im Auszug | Part + Unit | offen |
| Besteckeinsatz | ja im Auszug | Part | offen |
| Topfeinsatz | nein | Metadatum | offen |
| Beleuchtung | ja (Licht), Form nein | Metadatum + DocLight | offen |
| Steckdosen | nein | Metadatum mit Position | offen |

Regeln
- Alles in Metadaten wandert in die Stückliste, nicht ins Bild.
- UnitKind kennt drawer, pullout, door, flap, fixed (Units.swift:35).
- Unit besitzt Front-Parts und Körper-Parts; ein Part nur in einer Unit.
- Pose ohne Ausstattung bleibt gültig: Ausstattung ist optional je Schrank.
