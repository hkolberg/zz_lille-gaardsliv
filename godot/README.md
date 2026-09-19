# Lille Gårdsliv – Godot prototype

Dette er første vertikale skive av en ny Godot-versjon. Den bruker det eksisterende
Settlers-inspirerte kartet, men har en separat spillkontroller som kan flyttes til en
autoritativ server når nettverksspillet bygges ut.

## Testkontroller

- WASD/piltaster: gå eller kjør
- Trykk i verden: gå/kjør mot punktet
- E: gå inn i traktor, samle egg eller selge varer
- SPACE: bruk valgt redskap
- 1/2/3/4: såmaskin, tresker, tilhenger eller plog
- F: gå ut av traktoren
- H/J: opprett vert eller koble til lokal vert

## Første mekanikk

- Spilleren kan gå til traktoren og kjøre den.
- Tilhengeren følger traktoren og beholder retningen.
- Jordet starter som pløyd. Såing gjør jordet voksende, og etter en kort prototypetid blir kornet modent for høsting.
- Tresker gir korn, tilhenger brukes til transport, og markedet selger korn og egg.
- Hønsehuset har et lite egglager som kan sankes én gang per test.

## Videre arbeid

Neste steg er å erstatte de midlertidige geometriske blokkeringene med redigerbare
Godot TileSet-/Polygon2D-lag, flytte gårdsreglene til serverautoritet og legge til
MultiplayerSpawner/MultiplayerSynchronizer for spiller- og kjøretøysynkronisering.
