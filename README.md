# KopfFit

Tägliches Kopfrechnen (Standard 5 Minuten) mit Erinnerungen, die so lange nerven, bis die Übung erledigt ist.

## Was die App macht

- **Adaptive Aufgaben** in 10 Stufen: von „Plus & Minus bis 20“ über das Einmaleins bis zu „Zweistellig × zweistellig“ und Prozentrechnung. Nach 4 schnellen richtigen Antworten in Folge geht es eine Stufe hoch, nach 2 Fehlern in Folge eine runter. Jeder Tag startet eine Stufe unter dem Vortag zum Aufwärmen.
- **Ziffernblock mit Auto-Prüfung**: Sobald so viele Ziffern eingetippt sind wie das Ergebnis hat, wird geprüft. Kein Enter nötig.
- **Tipps per Glühbirne**: Bei jeder Rechenaufgabe zeigt „Tipp“ die Vorgehensweise für die Rechenart, Eselsbrücken und auf Wunsch den Rechenweg mit den konkreten Zahlen (ohne Endergebnis). Solange der Tipp offen ist, steht die Uhr. Ein Tipp ist ungestraft: Lesezeit zählt weder fürs Tempo noch für den Level-Aufstieg.
- **5-Minuten-Timer**, der nur läuft, solange die App offen ist. Wegwischen pausiert ihn. Abbrechen ist möglich, aber dann zählt der Tag nicht.
- **Serie (Streak)**, Rekord und die letzten 7 Tage auf dem Startbildschirm.
- **Penetrante Erinnerungen**: Von 9 bis 22 Uhr alle 30 Minuten (einstellbar), Texte werden im Laufe des Tages deutlicher, die letzte warnt vor dem Verlust der Serie. Ein Tipp auf die Mitteilung startet die Übung sofort. Ist die Übung erledigt, ist für den Tag Ruhe.

## Projekt erzeugen (auf dem Mac)

Das Xcode-Projekt wird mit [XcodeGen](https://github.com/yonaskolb/XcodeGen) aus `project.yml` erzeugt:

```sh
brew install xcodegen
cd kopffit
xcodegen generate
open KopfFit.xcodeproj
```

Dann in Xcode: Target **KopfFit › Signing & Capabilities › Team** auswählen. Falls die Bundle-ID `de.stefan.kopffit` schon vergeben ist, eine eigene eintragen (z. B. `de.deinname.kopffit`).

## Aufbau

| Datei | Inhalt |
|---|---|
| `App/KopfFitApp.swift` | Einstieg, Mitteilungs-Delegate |
| `Model/Problem.swift` | Aufgabengenerator (10 Level) |
| `Model/Hints.swift` | Tipps und Eselsbrücken je Rechenart |
| `Model/SessionModel.swift` | Timer, Eingabe, adaptive Schwierigkeit |
| `Model/ProgressStore.swift` | Verlauf, Serie, Einstellungen (UserDefaults) |
| `Services/ReminderScheduler.swift` | Planung der Erinnerungen (max. 64 lokale Mitteilungen bei iOS) |
| `Views/*` | Start, Übung, Ergebnis, Einstellungen |

## Ideen für später

- **Social-Media-Sperre** über Apples Screen-Time-API (FamilyControls): Instagram & Co. bleiben gesperrt, bis die Übung erledigt ist. Braucht eine zusätzliche Freigabe von Apple für TestFlight.
- Weitere Aufgabentypen: Zahlenreihen merken (Arbeitsgedächtnis), Schätzen, Uhrzeit-Rechnen.
- Widget auf dem Sperrbildschirm mit Serie und „offen/erledigt“.

## Updates über SideStore

Jeder Push auf `main`, der `KopfFit/` oder `project.yml` ändert, startet `.github/workflows/release.yml`:
GitHub baut eine unsignierte `KopfFit.ipa` und legt ein Release an.

Die SideStore-Quelle für alle Apps liegt in [vwx089/vwx089.github.io](https://github.com/vwx089/vwx089.github.io)
und holt neue Releases alle 15 Minuten ab. Adresse für SideStore:

```
https://vwx089.github.io/source.json
```
