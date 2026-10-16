---
name: godot-reverse-engineering
description: >-
  Investiga cómo funciona una mecánica o feature de otro juego o app
  (ingeniería inversa) con REA, para reimplementarla limpia en Godot 4.
  Deduce por observación o decompila (nativo con Hopper / Ghidra / IDA,
  .NET / Unity Mono, JS / HTML5 / Electron, APK). Usar cuando el usuario
  dice "como en X", "quiero la mecánica de Y", "cómo hace Z", o
  /reverse-engineer. Solo software propio o con autorización; extrae
  comportamiento, no copia código ni assets.
---

# Godot — ingeniería inversa (REA)

[REA](https://github.com/Joelnicolass/rea) (fork de [morluto/rea](https://github.com/morluto/rea); paquete npm `rea-agents`) conecta al agente con herramientas de ingeniería inversa por MCP: binarios nativos, ensamblados .NET, apps JS / Electron, sitios web, APKs, capturas de red y de proceso. Devuelve hallazgos **con evidencia y límites**.

En el kit sirve para entender **cómo** funciona algo que el usuario quiere en su juego (curva de salto, fórmula de daño, oleadas, cámara, tabla de loot) y bajarlo a un `F<n>` con números y criterios. Después se implementa como cualquier feature: composición, `@export`, `.tres`. Pedido acotado: command `/reverse-engineer`.

## Límites (obligatorio)

- Solo software que el usuario posee o está autorizado a examinar (lo permite la licencia / EULA, investigación, interoperabilidad, preservación). Si no está claro, preguntá **antes** de abrir el binario.
- Se extrae **comportamiento**: fórmulas, tiempos, estados, orden de eventos, valores. No código ni assets. No pegues pseudocódigo decompilado en `src/`: reescribilo en GDScript propio. No copies sprites, audio, niveles ni textos del original.
- Nada de saltear DRM, anti-cheat ni licencias. Herramientas comerciales (IDA, Hopper, JEB) solo con licencia del usuario.

## Deducir o decompilar

Elegí el camino más liviano que responda la pregunta.

| Situación | Camino |
|-----------|--------|
| Se ve jugando | **Deducir**: grabar, contar frames, probar bordes (¿salta 6 frames después de caer?). Con REA, captura de proceso o de navegador si hace falta |
| Juego web / HTML5 / Electron | REA: análisis JS (módulos, source maps, rutas) u observación del sitio |
| Unity Mono (`Assembly-CSharp.dll`) u otro .NET | REA: análisis managed estático (metadata, CIL) |
| Nativo (C / C++, Unity IL2CPP `GameAssembly`) | REA nativo con Hopper / Ghidra / IDA: pseudocódigo, strings, referencias |
| Android | REA: APK con JADX |
| Otro juego Godot (`.pck`) | REA no lo lista: deducí por observación |

## Instalar (solo con OK)

```bash
npx rea-agents setup
```

Elegí Claude Code y/o Cursor en el asistente: registra el MCP de REA y sus instrucciones. Reiniciá el agente (Claude Code: sesión nueva; `/mcp` muestra si conectó). Pide Node.js 22.19+ o 24.11+. Nativo: Hopper, Ghidra o IDA ya instalado. Si usás el fork, seguí su README. Si las tools de REA no aparecen, no finjas el análisis: decí qué falta.

## Flujo

1. **Pregunta concreta**: “¿cómo calcula X el knockback según la velocidad?”, no “decompilá el juego”.
2. **Autorización** confirmada y camino elegido (tabla de arriba).
3. **Investigación**: la corre el orquestador (este chat), no `studio-developer`. Resumí al usuario; no pegues dumps.
4. **Informe** en el `F<n>` de `FEATURES.md` (o `research/RE-<slug>.md` si es largo): qué se observó, evidencia (función, offset, captura, frame), la fórmula o tabla de valores, y qué queda desconocido.
5. **Reimplementación**: `/implement-feature`. El tech lead planifica piezas propias (los números van a `@export` / `.tres`); el developer escribe GDScript nuevo; el reviewer marca **FAIL** si hay pseudocódigo portado literal o assets del original.

Criterios de playtest con los valores deducidos (“coyote de 6 frames”, “el knockback dobla a velocidad máxima”).
