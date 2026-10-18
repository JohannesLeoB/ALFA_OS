---
name: kein-mykilos-im-code
description: Streichliste myk, mykilos, mykilOS und alle Abwandlungen; nie in App-Code, Tokens, Schlüsseln, Metadaten; die App heißt ALFA
metadata:
  type: feedback
---

„Achtung! „Mykilos“ und alle Abwandlungen davon sollen nicht in App Code oder tokens oder Meta etc auftauchen! alfa kein mykilos!!!“ · „Das ist wichtig!!!“ · „Also bestenfalls auch „myk“ etc. auf Streichliste zum kontinuierlichen entfernen /ersetzen und neu mit verknüpften files und Funktionen, Ui usw wiren“ (19.10.2026, Lead-Sitzung)
**Why:** Die App ist ALFA, für Distribution gedacht (siehe [[reichweite-der-app]]); ein Firmenname im Code bindet sie an ein Studio.
**How to apply:** Streichliste (Suche ohne Groß-/Kleinschreibung): `myk` als Wortteil, also mykilos, mykilOS, Mykilos*, Myk*, myk-*. Bei jeder Arbeit fortlaufend entfernen oder ersetzen und die verknüpften Dateien, Funktionen und die UI mit neu verdrahten, so dass der Build strikt bleibt. Kein „mykilos“ (jede Schreibweise) in Swift, Modul- und Paketnamen, Tokens, $extensions (Schlüssel heißt `alfa`), JSON-Feldern, Schemas, IDs, Kommentaren. Stand 19.10.: Module in fundus/alpha umbenannt zu `AlfaKit` und `AlfaServices` (a76f92e, 94ae229, c4fd148); `git grep -i myk -- alfaos scripts` leer. Offen: Modul `MykilosKalkulationsCore` in fundus/alpha (Name entscheidet Johannes); Strang-Definitionen bau-* nennen noch Fundus-Pfade MykilosKit/MykilosServices. Pfade im Bestand (Labor, Fundus) dürfen in Strang-Definitionen als Leseort stehen, nie im Code.
