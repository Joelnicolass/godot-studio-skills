---
name: godot-feature-research
description: >-
  Investiga cómo funciona una mecánica o feature de un juego similar buscando
  en la web (wikis, devlogs, charlas, guías, video de gameplay) y observándola
  y midiéndola, después deduce el comportamiento y escribe código propio en
  Godot 4. Usar cuando el usuario dice "como en X", "quiero la mecánica de
  Y", "cómo hace Z", o /research-feature. Sin ingeniería inversa: nunca abre,
  decompila ni desensambla otro juego; no copia código ni assets.
---

# Godot — investigar una feature (web + deducción)

Para hacer algo "como en X", entendé **cómo se comporta** con fuentes públicas y jugándolo o mirándolo, y escribilo en Godot desde cero. Curva de salto, fórmula de daño, oleadas, cámara, tabla de loot: bajalos a un `F<n>` con números y criterios, e implementalo como cualquier feature (composición, `@export`, `.tres`). Pedido acotado: command `/research-feature`.

## Límites (obligatorio)

- **Sin ingeniería inversa.** Nunca abras, decompiles, desensambles, desempaquetes ni parchees otro juego o app, ni leas sus archivos o su memoria. Lo que se encuentra sale de fuentes públicas y de observarlo.
- Extraés **comportamiento**: fórmulas, tiempos, estados, orden de eventos, valores. El código que escribís es GDScript propio. No pegues código de artículos o repos del original; si una fuente muestra código, describí qué hace y escribilo de nuevo.
- No copies sprites, audio, niveles ni textos del original.

## Dónde buscar

Buscá en la web (las herramientas de búsqueda y lectura del agente) y decí de dónde sale cada dato.

| Fuente | Qué da |
|--------|--------|
| La wiki del juego y las guías de la comunidad | Valores que midieron los jugadores (frames, daño, velocidades, probabilidades) |
| Devlogs, postmortems, charlas de GDC / conferencias de sus desarrolladores | Cómo y por qué se diseñó, a veces los números exactos |
| Páginas de speedrun y de frame data | Tiempos precisos: coyote time, buffers, frames de invulnerabilidad |
| Videos de gameplay | Lo que se puede medir cuadro por cuadro (contar frames, comparar posiciones) |
| Artículos y tutoriales que analizan la mecánica | Modelos conocidos (curvas, máquinas de estados) para comparar |
| Jugarlo, si el usuario lo tiene | Probar los bordes a mano (¿salta todavía 6 frames después de dejar la cornisa?) |

Si las fuentes no coinciden, quedate con la más directa (un desarrollador, un conteo de frames) y anotá las otras. Lo que ninguna fuente muestra queda **desconocido**: proponé un valor razonable para ajustar, marcado como supuesto.

## Flujo

1. **Pregunta concreta**: "¿cómo calcula X el knockback según la velocidad?", no "copiá el juego".
2. **Investigación**: la corre el orquestador (este chat), no `studio-developer`. Resumí para el usuario con los links; no pegues páginas enteras.
3. **Deducí** el modelo: una fórmula, una tabla de valores o una máquina de estados que explique lo que muestran las fuentes, y lo desconocido.
4. **Informe** en el `F<n>` de `FEATURES.md` (o `research/<slug>.md` si es largo): qué hace, el modelo, las fuentes y qué pasa a `@export` / `.tres`.
5. **Implementación**: `/implement-feature`. El tech lead planifica piezas propias (los números van a `@export` / `.tres`); el developer escribe GDScript nuevo; el reviewer marca **FAIL** si hay código o assets tomados del original.

Los criterios del playtest usan los valores deducidos ("coyote time de 6 frames", "el knockback se duplica a velocidad máxima").
