# Fika co-op – test odbiorczy ScavTime v1.0.0

Warunek: na hostowanym backendzie SPT 4.1.6 pracuje zarówno Fika-Server, jak i ScavTime.

1. Uruchom backend SPT i zapisz: `ScavTime ACTIVE` i `FIKA_SERVER_FOLDER_PRESENT`.
2. SOLO (bez Fika): wejdz Scavem na Customs, zapisz startowy czas oraz mapę.
3. FIKA Scav: host i klient wchodza do lobby PRZED rozpoczeciem rajdu; host startuje; zapisz licznik u obu.
4. FIKA PMC: kontrola ze zwykly czas rajdu PMC nie zostal nadpisany.
5. Dla FIKA Headless: opcjonalnie powtorz test Scava z headless jako hostem.
6. Odszukaj w serwerowym logu bledy i konflikt z innymi modami zmieniajacymi czas.

Kryterium: oba Scavy przy wspolnym starcie widza standardowy pełny czas mapy
(z marginesem czasu ładowania). To NIE gwarantuje czasu osobie reconnectujacej.

Zapisz wynik osobno dla SOLO/FIKA i nie nazywaj `RUNTIME VERIFIED` przed testami.
