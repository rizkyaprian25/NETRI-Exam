#!/usr/bin/env python3
"""
Generator Token Desain NETRI Exam
Mengonversi tokens.json menjadi kode Dart (lib/core/theme/tokens.g.dart)
dan CSS variables (tokens/tokens.css) sebagai Single Source of Truth (SSOT).
"""

import json
import os

def resolve_ref(val, data):
    """Menyelesaikan referensi token seperti {primitive.color.blue-600}"""
    if isinstance(val, str) and val.startswith("{") and val.endswith("}"):
        path = val[1:-1].split(".")
        curr = data
        for p in path:
            curr = curr[p]
        return resolve_ref(curr, data)
    return val

def to_camel_case(snake_or_kebab):
    """Mengonversi nama kebab-case atau snake_case ke lowerCamelCase"""
    parts = snake_or_kebab.replace("-", "_").split("_")
    return parts[0] + "".join(p.capitalize() for p in parts[1:])

def hex_to_dart_color(hex_str):
    """Mengonversi #RRGGBB ke format Dart Color(0xFFRRGGBB)"""
    clean_hex = hex_str.lstrip("#")
    if len(clean_hex) == 6:
        return f"Color(0xFF{clean_hex.upper()})"
    elif len(clean_hex) == 8:
        return f"Color(0x{clean_hex.upper()})"
    return f"Color(0xFF{clean_hex.upper()})"

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    tokens_file = os.path.join(base_dir, "tokens", "tokens.json")
    dart_out_file = os.path.join(base_dir, "lib", "core", "theme", "tokens.g.dart")
    css_out_file = os.path.join(base_dir, "tokens", "tokens.css")

    with open(tokens_file, "r", encoding="utf-8") as f:
        tokens = json.load(f)

    # 1. Hasilkan Dart Token File
    os.makedirs(os.path.dirname(dart_out_file), exist_ok=True)
    
    semantic_colors = tokens["semantic"]["color"]
    dart_lines = [
        "// GENERATED CODE - JANGAN UBAH SECARA MANUAL",
        "// Sumber kebenaran tunggal (SSOT): tokens/tokens.json",
        "// Dibuat secara otomatis oleh scripts/generate_tokens.py",
        "",
        "import 'package:flutter/material.dart';",
        "",
        "/// Token Desain Semantik untuk NETRI Exam (Apple HIG & UI/UX Pro Max)",
        "abstract class NetriColors {",
    ]

    for name, modes in semantic_colors.items():
        base_name = to_camel_case(name)
        light_name = f"{base_name}Light"
        dark_name = f"{base_name}Dark"
        light_val = resolve_ref(modes["light"], tokens)
        dark_val = resolve_ref(modes["dark"], tokens)
        dart_lines.append(f"  // Token: {name}")
        dart_lines.append(f"  static const Color {light_name} = {hex_to_dart_color(light_val)};")
        dart_lines.append(f"  static const Color {dark_name} = {hex_to_dart_color(dark_val)};")
        dart_lines.append("")

    dart_lines.extend([
        "}",
        "",
        "/// Spasi Standar (Kelipatan 4pt)",
        "abstract class NetriSpacing {",
    ])

    for k, v in tokens["primitive"]["space"].items():
        dart_lines.append(f"  static const double space{k} = {float(v)};")

    dart_lines.extend([
        "}",
        "",
        "/// Radius Sudut Standar",
        "abstract class NetriRadius {",
    ])

    for k, v in tokens["primitive"]["radius"].items():
        dart_lines.append(f"  static const double {k} = {float(v)};")

    dart_lines.extend([
        "}",
        "",
        "/// Komponen Khusus Ujian",
        "abstract class NetriExamMetrics {",
        f"  static const double examBarHeight = {float(tokens['component']['exambar']['height'])};",
        f"  static const double minTouchTarget = {float(tokens['component']['exambar']['min-touch-target'])};",
        f"  static const int warningThresholdSeconds = {tokens['component']['timer']['warning-threshold-seconds']};",
        f"  static const int dangerThresholdSeconds = {tokens['component']['timer']['danger-threshold-seconds']};",
        "}",
    ])

    with open(dart_out_file, "w", encoding="utf-8") as f:
        f.write("\n".join(dart_lines) + "\n")
    print(f"[OK] Berhasil menghasilkan Dart tokens: {dart_out_file}")

    # 2. Hasilkan CSS Variables File
    css_lines = [
        "/* GENERATED CSS VARIABLES - SSOT: tokens/tokens.json */",
        ":root {",
    ]
    for name, modes in semantic_colors.items():
        light_val = resolve_ref(modes["light"], tokens)
        css_lines.append(f"  --netri-color-{name}: {light_val};")

    for k, v in tokens["primitive"]["space"].items():
        css_lines.append(f"  --netri-space-{k}: {v}px;")

    for k, v in tokens["primitive"]["radius"].items():
        css_lines.append(f"  --netri-radius-{k}: {v}px;")

    css_lines.extend([
        "}",
        "",
        "@media (prefers-color-scheme: dark) {",
        "  :root {",
    ])
    for name, modes in semantic_colors.items():
        dark_val = resolve_ref(modes["dark"], tokens)
        css_lines.append(f"    --netri-color-{name}: {dark_val};")
    css_lines.extend([
        "  }",
        "}",
        "",
        "[data-theme='dark'] {",
    ])
    for name, modes in semantic_colors.items():
        dark_val = resolve_ref(modes["dark"], tokens)
        css_lines.append(f"    --netri-color-{name}: {dark_val};")
    css_lines.append("}")

    with open(css_out_file, "w", encoding="utf-8") as f:
        f.write("\n".join(css_lines) + "\n")
    print(f"[OK] Berhasil menghasilkan CSS tokens: {css_out_file}")

if __name__ == "__main__":
    main()
