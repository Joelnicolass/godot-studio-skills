#!/usr/bin/env python3
"""Lists the kit classes that carry an icon and writes them to classes.tsv.

A class carries an icon when it has a `class_name` (outside tests/ and examples/) and the
editor shows it: nodes and Resources, direct or inherited. Plain RefCounted and Object
classes show in neither the scene tree nor the FileSystem, so they carry none.

Usage, from the repo root:  python3 tools/icons/list_classes.py
"""
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
ADDONS = os.path.join(ROOT, "addons")
OUT = os.path.join(ROOT, "tools", "icons", "classes.tsv")

# Native bases that end the inheritance chain. Any other native base is "other".
NODE_BASES = {
    "Node", "Node2D", "Node3D", "Control", "CanvasItem", "CanvasLayer", "Area2D", "Area3D",
    "Camera2D", "Camera3D", "CharacterBody2D", "CharacterBody3D", "StaticBody2D", "StaticBody3D",
    "Label", "Button", "Container", "GridContainer", "PanelContainer", "VBoxContainer",
    "HBoxContainer", "MarginContainer", "AnimationPlayer", "MultiplayerSpawner",
    "MultiplayerSynchronizer", "MeshInstance3D", "MultiMeshInstance3D", "NavigationRegion2D",
    "NavigationRegion3D", "Timer", "Marker2D", "Marker3D", "Sprite2D", "Sprite3D",
}
RESOURCE_BASES = {"Resource", "ImageTexture", "Texture2D", "Material", "ShaderMaterial", "Mesh", "Shape3D"}


def scan():
    classes = {}
    for kit in sorted(os.listdir(ADDONS)):
        kit_dir = os.path.join(ADDONS, kit)
        if not os.path.isdir(kit_dir):
            continue
        for folder, _dirs, files in os.walk(kit_dir):
            parts = os.path.relpath(folder, ADDONS).split(os.sep)
            if "tests" in parts or "examples" in parts:
                continue
            for name in sorted(files):
                if not name.endswith(".gd"):
                    continue
                path = os.path.join(folder, name)
                with open(path, encoding="utf-8") as handle:
                    source = handle.read()
                found = re.search(r"^class_name\s+(\w+)(?:\s+extends\s+(\w+))?", source, re.M)
                if not found:
                    continue
                base = found.group(2)
                if not base:
                    extends = re.search(r"^extends\s+(\w+)", source, re.M)
                    base = extends.group(1) if extends else "RefCounted"
                classes[found.group(1)] = {
                    "kit": kit,
                    "base": base,
                    "file": os.path.relpath(path, ROOT),
                }
    return classes


def kind_of(name, classes):
    base = name
    while base in classes:
        base = classes[base]["base"]
    if base in NODE_BASES:
        return "node", base
    if base in RESOURCE_BASES:
        return "resource", base
    return "other", base


def main():
    classes = scan()
    rows = []
    for name in sorted(classes, key=lambda n: (classes[n]["kit"], n)):
        kind, native = kind_of(name, classes)
        if kind == "other":
            continue
        info = classes[name]
        rows.append((info["kit"], name, kind, info["base"], native, info["file"]))
    with open(OUT, "w", encoding="utf-8") as handle:
        handle.write("kit\tclass\tkind\tbase\tnative_base\tscript\n")
        for row in rows:
            handle.write("\t".join(row) + "\n")
    nodes = sum(1 for row in rows if row[2] == "node")
    print(f"{len(rows)} classes with an icon ({nodes} nodes, {len(rows) - nodes} resources) -> {os.path.relpath(OUT, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
