---
name: godot-feature-research
description: >-
  Investiga cómo funciona una mecánica o feature de un juego similar y deduce
  su código en Godot 4: búsqueda web (wikis, devlogs, charlas, guías, código
  fuente, video de gameplay), observarla y medirla, y abrir o decompilar el
  juego cuando se puede. Usar cuando el usuario dice "como en X", "quiero la
  mecánica de Y", "cómo hace Z", o /research-feature.
---

# Godot — investigar una feature

Para hacer algo "como en X", averiguá **cómo funciona** y llevalo a Godot. Curva de salto, fórmula de daño, oleadas, cámara, tabla de loot: bajalos a un `F<n>` con números y criterios, e implementalo como cualquier feature (composición, `@export`, `.tres`). Pedido acotado: command `/research-feature`.

## Dónde buscar

Buscá en la web (las herramientas de búsqueda y lectura del agente) y decí de dónde sale cada dato.

| Fuente | Qué da |
|--------|--------|
| La wiki del juego y las guías de la comunidad | Valores que midieron los jugadores (frames, daño, velocidades, probabilidades) |
| Devlogs, postmortems, charlas de GDC / conferencias de sus desarrolladores | Cómo y por qué se diseñó, a veces los números exactos |
| Código fuente: juegos open source, mods, repos y tutoriales de la comunidad | La lógica misma, lista para adaptar |
| Páginas de speedrun y de frame data | Tiempos precisos: coyote time, buffers, frames de invulnerabilidad |
| Videos de gameplay | Lo que se puede medir cuadro por cuadro (contar frames, comparar posiciones) |
| Abrir el juego, si el usuario tiene sus archivos | Código y valores reales. Un `.pck` de Godot se abre con gdsdecomp; Unity / .NET con ILSpy o dnSpy; otros motores con su decompilador. Preguntá antes de instalar una herramienta. |
| Jugarlo, si el usuario lo tiene | Probar los bordes a mano (¿salta todavía 6 frames después de dejar la cornisa?) |

Si las fuentes no coinciden, quedate con la más directa (el código del juego, un desarrollador, un conteo de frames) y anotá las otras. Lo que ninguna fuente muestra queda **desconocido**: proponé un valor razonable para ajustar, marcado como supuesto.

El código que aparezca en una fuente o en el juego se puede usar: adaptalo a las capas y la composición del proyecto, con los números en `@export` / `.tres`. Assets del original (sprites, audio, niveles, textos): preguntale al usuario antes de traerlos al juego.

## Flujo

1. **Pregunta concreta**: "¿cómo calcula X el knockback según la velocidad?", no "copiá el juego".
2. **Investigación**: la corre el orquestador (este chat), no `studio-developer`. Primero la web; si el usuario tiene el juego y se puede abrir, ofrecé decompilarlo. Resumí para el usuario con los links; no pegues páginas enteras.
3. **Deducí** el modelo: una fórmula, una tabla de valores o una máquina de estados que explique lo que muestran las fuentes (o el código encontrado), y lo desconocido.
4. **Informe** en el `F<n>` de `FEATURES.md` (o `research/<slug>.md` si es largo): qué hace, el modelo o el código, las fuentes y qué pasa a `@export` / `.tres`.
5. **Implementación**: `/implement-feature`. El tech lead planifica piezas que encajen en las capas del proyecto (los números van a `@export` / `.tres`); el developer escribe o adapta el código.

Los criterios del playtest usan los valores encontrados ("coyote time de 6 frames", "el knockback se duplica a velocidad máxima").
