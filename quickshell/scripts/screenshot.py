#!/usr/bin/env python3
"""
screenshot.py — ImageMagick-backed post-processor, pixel redactor, prettifier,
clipboard helper, and notification dispatcher for quickshell's screenshot studio.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

CACHE_DIR = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp") / "quickshell_captures"
MAX_CACHE_FILES = 18


def ensure_cache_dir() -> Path:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    try:
        entries = sorted(
            (p for p in CACHE_DIR.iterdir() if p.is_file()),
            key=lambda p: p.stat().st_mtime,
            reverse=True,
        )
        for old in entries[MAX_CACHE_FILES:]:
            try:
                old.unlink()
            except OSError:
                pass
    except OSError:
        pass
    return CACHE_DIR


def _kv_escape(val: str) -> str:
    return (
        str(val)
        .replace("\\", "\\\\")
        .replace("\n", "\\n")
        .replace("=", "\\e")
        .replace(",", "\\c")
        .replace(";", "\\s")
        .replace("|", "\\p")
    )


def emit_kv(data: dict) -> None:
    for k, v in data.items():
        if isinstance(v, bool):
            print(f"{k}={'true' if v else 'false'}")
        else:
            print(f"{k}={_kv_escape(str(v))}")


def _human_size(n: int) -> str:
    if n < 1024:
        return f"{n} B"
    if n < 1024 * 1024:
        return f"{n / 1024:.1f} KB"
    return f"{n / (1024 * 1024):.2f} MB"


def _identify_size(path: str) -> tuple[int, int]:
    try:
        out = subprocess.check_output(
            ["magick", "identify", "-format", "%w %h", f"{path}[0]"],
            text=True,
            timeout=5,
        ).strip()
        w_s, h_s = out.split()[:2]
        return max(1, int(w_s)), max(1, int(h_s))
    except Exception:
        return 0, 0


def copy_image_to_clipboard(file_path: str) -> bool:
    if not file_path or not os.path.exists(file_path):
        return False
    try:
        if file_path.lower().endswith(".png"):
            with open(file_path, "rb") as f:
                subprocess.run(
                    ["wl-copy", "--type", "image/png"],
                    stdin=f,
                    check=True,
                    timeout=6,
                )
            return True
        png_bytes = subprocess.check_output(
            ["magick", f"{file_path}[0]", "png:-"],
            timeout=8,
        )
        subprocess.run(
            ["wl-copy", "--type", "image/png"],
            input=png_bytes,
            check=True,
            timeout=6,
        )
        return True
    except Exception:
        return False


def copy_text_to_clipboard(text: str) -> bool:
    if text is None:
        return False
    try:
        subprocess.run(
            ["wl-copy"],
            input=text.encode("utf-8"),
            check=True,
            timeout=4,
        )
        return True
    except Exception:
        return False


def notify_capture(preview_path: str, dest_path: str, action: str) -> None:
    file_name = Path(dest_path or preview_path).name
    if action == "copy":
        body = "copied capture to clipboard"
    elif action == "pin":
        body = "pinned capture on screen"
    elif action == "edit":
        body = f"opened {file_name} in studio"
    elif action == "save":
        body = f"saved to {file_name}"
    else:
        body = f"saved {file_name} and copied to clipboard"

    icon = preview_path if (preview_path and os.path.exists(preview_path)) else "camera-photo"
    try:
        subprocess.run(
            ["notify-send", "-a", "quickshell", "-i", icon, "screenshot captured", body],
            check=False,
            timeout=3,
        )
    except Exception:
        pass


def apply_redactions(src_png: str, out_png: str, rects: list, logical_w: float, logical_h: float) -> bool:
    if not rects:
        shutil.copyfile(src_png, out_png)
        return True

    img_w, img_h = _identify_size(src_png)
    if img_w <= 0 or img_h <= 0:
        shutil.copyfile(src_png, out_png)
        return True

    sx = (img_w / logical_w) if logical_w > 1 else 1.0
    sy = (img_h / logical_h) if logical_h > 1 else 1.0

    # First pass for solid/blur with simple -region, mosaic gets isolated region crop+scale
    cur = src_png
    with tempfile.TemporaryDirectory(prefix="qs_redact_") as tmpdir:
        for idx, r in enumerate(rects):
            try:
                rx = max(0, int(round(float(r.get("x", 0)) * sx)))
                ry = max(0, int(round(float(r.get("y", 0)) * sy)))
                rw = max(2, int(round(float(r.get("w", 0)) * sx)))
                rh = max(2, int(round(float(r.get("h", 0)) * sy)))
            except Exception:
                continue

            if rx >= img_w or ry >= img_h:
                continue
            rw = min(img_w - rx, rw)
            rh = min(img_h - ry, rh)
            if rw <= 2 or rh <= 2:
                continue

            mode = str(r.get("mode", "mosaic")).lower()
            step_out = os.path.join(tmpdir, f"step_{idx}.png")
            geom = f"{rw}x{rh}+{rx}+{ry}"

            if mode == "solid":
                color = str(r.get("color", "#0f1016"))
                cmd = [
                    "magick", cur,
                    "-fill", color,
                    "-draw", f"rectangle {rx},{ry} {rx + rw - 1},{ry + rh - 1}",
                    step_out,
                ]
            elif mode == "blur":
                cmd = [
                    "magick", cur,
                    "-region", geom,
                    "-blur", "0x14",
                    "+region",
                    step_out,
                ]
            else:
                # Irreversible pixel mosaic
                mosaic_w = max(2, rw // 14)
                mosaic_h = max(2, rh // 14)
                patch = os.path.join(tmpdir, f"patch_{idx}.png")
                subprocess.run(
                    [
                        "magick", cur,
                        "-crop", geom, "+repage",
                        "-filter", "box",
                        "-resize", f"{mosaic_w}x{mosaic_h}!",
                        "-filter", "point",
                        "-resize", f"{rw}x{rh}!",
                        patch,
                    ],
                    check=True,
                    timeout=10,
                )
                cmd = [
                    "magick", cur, patch,
                    "-geometry", f"+{rx}+{ry}",
                    "-compose", "over", "-composite",
                    step_out,
                ]

            subprocess.run(cmd, check=True, timeout=10)
            cur = step_out

        shutil.copyfile(cur, out_png)
    return True


def _sanitize_hex(col: str, fallback: str) -> str:
    s = str(col or "").strip()
    if s.startswith("#") and len(s) in (4, 7, 9):
        return s
    return fallback


def apply_prettify(src_png: str, out_png: str, cfg: dict) -> bool:
    img_w, img_h = _identify_size(src_png)
    if img_w <= 0 or img_h <= 0:
        shutil.copyfile(src_png, out_png)
        return False

    pad = max(16, min(140, int(cfg.get("padding", 48))))
    radius = max(0, min(40, int(cfg.get("radius", 14))))
    shadow = bool(cfg.get("shadow", True))
    style = str(cfg.get("style", "matugen")).lower()

    c1 = _sanitize_hex(cfg.get("c1", "#3b82f6"), "#3b82f6")
    c2 = _sanitize_hex(cfg.get("c2", "#a855f7"), "#a855f7")
    bg_hex = _sanitize_hex(cfg.get("bg", "#10121a"), "#10121a")
    wallpaper = os.path.expanduser(str(cfg.get("wallpaper", "") or ""))

    canvas_w = img_w + pad * 2
    canvas_h = img_h + pad * 2

    with tempfile.TemporaryDirectory(prefix="qs_pretty_") as tmpdir:
        fg_path = os.path.join(tmpdir, "fg.png")
        bg_path = os.path.join(tmpdir, "bg.png")

        # 1) Prepare rounded inner screenshot (+ subtle crisp border)
        if radius > 0:
            mask_path = os.path.join(tmpdir, "mask.png")
            r = min(radius, img_w // 2, img_h // 2)
            subprocess.run(
                [
                    "magick",
                    "-size", f"{img_w}x{img_h}",
                    "xc:none",
                    "-fill", "white",
                    "-draw", f"roundrectangle 0,0 {img_w - 1},{img_h - 1} {r},{r}",
                    mask_path,
                ],
                check=True,
                timeout=8,
            )
            subprocess.run(
                [
                    "magick", src_png, "-alpha", "set",
                    mask_path, "-compose", "DstIn", "-composite",
                    fg_path,
                ],
                check=True,
                timeout=10,
            )
        else:
            shutil.copyfile(src_png, fg_path)

        # Add subtle shadow onto fg layer while keeping transparent margin cleanly
        if shadow:
            fg_shadow = os.path.join(tmpdir, "fg_shadow.png")
            subprocess.run(
                [
                    "magick", fg_path,
                    "(", "+clone", "-background", "black", "-shadow", "58x18+0+10", ")",
                    "+swap", "-background", "none", "-layers", "merge", "+repage",
                    fg_shadow,
                ],
                check=True,
                timeout=10,
            )
            fg_layer = fg_shadow
        else:
            fg_layer = fg_path

        # 2) Build backdrop canvas
        img_exts = (".png", ".jpg", ".jpeg", ".webp", ".bmp")
        use_wallpaper = (
            style == "wallpaper"
            and wallpaper
            and os.path.isfile(wallpaper)
            and wallpaper.lower().endswith(img_exts)
        )

        if use_wallpaper:
            subprocess.run(
                [
                    "magick", f"{wallpaper}[0]",
                    "-resize", f"{canvas_w}x{canvas_h}^",
                    "-gravity", "center",
                    "-extent", f"{canvas_w}x{canvas_h}",
                    "-blur", "0x20",
                    "-modulate", "82,115,100",
                    bg_path,
                ],
                check=True,
                timeout=12,
            )
        elif style == "oled":
            subprocess.run(
                [
                    "magick",
                    "-size", f"{canvas_w}x{canvas_h}",
                    "radial-gradient:#181a24-#050508",
                    bg_path,
                ],
                check=True,
                timeout=8,
            )
        elif style == "glass":
            subprocess.run(
                [
                    "magick",
                    "-size", f"{canvas_w}x{canvas_h}",
                    f"gradient:{c1}-{bg_hex}",
                    "-blur", "0x18",
                    "-modulate", "95,90,100",
                    bg_path,
                ],
                check=True,
                timeout=8,
            )
        else:
            # Default: smooth matugen diagonal gradient
            subprocess.run(
                [
                    "magick",
                    "-size", f"{canvas_w}x{canvas_h}",
                    "-define", "gradient:angle=135",
                    f"gradient:{c1}-{c2}",
                    "-modulate", "92,108,100",
                    bg_path,
                ],
                check=True,
                timeout=8,
            )

        # 3) Composite framed foreground onto backdrop
        subprocess.run(
            [
                "magick", bg_path, fg_layer,
                "-gravity", "center",
                "-compose", "over", "-composite",
                out_png,
            ],
            check=True,
            timeout=12,
        )
    return True


def encode_final(src_png: str, dest_path: str, fmt: str, quality: int) -> str:
    fmt = fmt.lower()
    if fmt == "jpeg":
        fmt = "jpg"
    if fmt not in ("png", "jpg", "webp"):
        fmt = "png"

    q = max(50, min(100, int(quality)))
    dest_p = Path(dest_path)
    dest_p.parent.mkdir(parents=True, exist_ok=True)

    if fmt == "png":
        shutil.copyfile(src_png, dest_p)
    elif fmt == "jpg":
        subprocess.run(
            [
                "magick", src_png,
                "-background", "#000000", "-alpha", "remove", "-alpha", "off",
                "-quality", str(q),
                str(dest_p),
            ],
            check=True,
            timeout=10,
        )
    else:
        subprocess.run(
            [
                "magick", src_png,
                "-quality", str(q),
                str(dest_p),
            ],
            check=True,
            timeout=10,
        )
    return str(dest_p)


def run_export(spec_arg: str) -> None:
    try:
        if spec_arg.lstrip().startswith("{"):
            spec = json.loads(spec_arg)
        else:
            with open(spec_arg, "r", encoding="utf-8") as f:
                spec = json.load(f)
    except Exception as exc:
        emit_kv({"ok": False, "error": str(exc)})
        return

    raw_path = str(spec.get("rawPath", ""))
    dest_path = str(spec.get("destPath", ""))
    action = str(spec.get("action", "both")).lower()
    fmt = str(spec.get("format", "png")).lower()
    quality = int(spec.get("quality", 92))
    notify_flag = bool(spec.get("notify", True))
    logical_w = float(spec.get("logicalWidth", 0) or 0)
    logical_h = float(spec.get("logicalHeight", 0) or 0)
    rects = spec.get("redactRects") or []
    prettify = spec.get("prettify") or {}
    remove_raw = bool(spec.get("removeRaw", True))

    if not raw_path or not os.path.exists(raw_path):
        emit_kv({"ok": False, "error": "missing raw capture file"})
        return

    ensure_cache_dir()
    preview_png = str(CACHE_DIR / f"shot_{int(time.time() * 1000)}.png")

    with tempfile.TemporaryDirectory(prefix="qs_export_") as tmpdir:
        stage1 = os.path.join(tmpdir, "redacted.png")
        apply_redactions(raw_path, stage1, rects, logical_w, logical_h)

        stage2 = os.path.join(tmpdir, "final.png")
        prettified = False
        if isinstance(prettify, dict) and prettify.get("enabled"):
            prettified = apply_prettify(stage1, stage2, prettify)
        else:
            shutil.copyfile(stage1, stage2)

        shutil.copyfile(stage2, preview_png)

        saved_path = ""
        saved = False
        if action in ("save", "both", "prettify") and dest_path:
            saved_path = encode_final(stage2, dest_path, fmt, quality)
            saved = os.path.exists(saved_path)

        copied = False
        if action in ("copy", "both", "pin", "prettify"):
            copied = copy_image_to_clipboard(preview_png)

        if remove_raw and raw_path != saved_path and raw_path != preview_png:
            try:
                os.remove(raw_path)
            except OSError:
                pass

    if not spec_arg.lstrip().startswith("{") and os.path.exists(spec_arg) and "qs_spec_" in os.path.basename(spec_arg):
        try:
            os.remove(spec_arg)
        except OSError:
            pass

    ref_file = saved_path if saved else preview_png
    w, h = _identify_size(ref_file)
    size_bytes = os.path.getsize(ref_file) if os.path.exists(ref_file) else 0

    if notify_flag and action != "pin":
        notify_capture(preview_png, saved_path or preview_png, action)

    emit_kv({
        "ok": True,
        "dest": saved_path,
        "preview": preview_png,
        "width": w,
        "height": h,
        "bytes": size_bytes,
        "sizeText": _human_size(size_bytes),
        "format": fmt if saved else "png",
        "action": action,
        "copied": copied,
        "saved": saved,
        "prettified": prettified,
    })


def handle_post_legacy(action: str, file_path: str, send_notification: bool) -> None:
    if not os.path.exists(file_path):
        return

    ensure_cache_dir()
    preview_png = str(CACHE_DIR / f"shot_{int(time.time() * 1000)}.png")
    shutil.copyfile(file_path, preview_png)

    copied = False
    if action in ("copy", "both"):
        copied = copy_image_to_clipboard(file_path)

    if action == "edit":
        open_editor(file_path)

    if send_notification:
        notify_capture(preview_png, file_path, action)

    if action == "copy":
        try:
            os.remove(file_path)
        except OSError:
            pass

    w, h = _identify_size(preview_png)
    emit_kv({
        "ok": True,
        "dest": file_path if action != "copy" else "",
        "preview": preview_png,
        "width": w,
        "height": h,
        "copied": copied,
        "saved": action != "copy",
    })


def clipboard_load() -> None:
    ensure_cache_dir()
    out_png = str(CACHE_DIR / f"clip_{int(time.time() * 1000)}.png")
    try:
        types = subprocess.check_output(["wl-paste", "--list-types"], text=True, timeout=3).splitlines()
    except Exception:
        emit_kv({"ok": False, "error": "nothing in clipboard"})
        return

    mime = next((t for t in types if t.strip() in ("image/png", "image/jpeg", "image/webp", "image/bmp")), None)
    if not mime:
        emit_kv({"ok": False, "error": "clipboard does not contain an image"})
        return

    try:
        raw = subprocess.check_output(["wl-paste", "--type", mime.strip()], timeout=5)
        if mime.strip() == "image/png":
            with open(out_png, "wb") as f:
                f.write(raw)
        else:
            subprocess.run(["magick", "-", out_png], input=raw, check=True, timeout=8)
        w, h = _identify_size(out_png)
        emit_kv({"ok": True, "path": out_png, "width": w, "height": h})
    except Exception as exc:
        emit_kv({"ok": False, "error": str(exc)})


def open_editor(file_path: str) -> bool:
    if not file_path or not os.path.exists(file_path):
        return False
    # Try quickshell built-in studio first
    try:
        res = subprocess.run(
            ["qs", "ipc", "call", "screenshot", "editFile", file_path],
            capture_output=True,
            timeout=3,
        )
        if res.returncode == 0:
            return True
    except Exception:
        pass
    for app in ["swappy", "satty"]:
        if shutil.which(app):
            try:
                subprocess.Popen([app, "-f", file_path])
                return True
            except Exception:
                pass
    try:
        subprocess.Popen(["xdg-open", file_path])
        return True
    except Exception:
        pass
    return False


def pick_color_fallback() -> None:
    try:
        if "gnome" in os.environ.get("XDG_CURRENT_DESKTOP", "").lower():
            res = subprocess.run(
                [
                    "gdbus", "call", "--session",
                    "--dest", "org.gnome.Shell.Screenshot",
                    "--object-path", "/org/gnome/Shell/Screenshot",
                    "--method", "org.gnome.Shell.Screenshot.PickColor",
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            m = re.search(r"\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\)", res.stdout) if res.returncode == 0 else None
            if m:
                r, g, b = (max(0, min(255, round(float(x) * 255))) for x in m.groups())
                hex_col = f"#{r:02x}{g:02x}{b:02x}"
                copy_text_to_clipboard(hex_col)
                emit_kv({"ok": True, "hex": hex_col})
            return

        slurp = subprocess.run(
            ["slurp", "-p", "-b", "00000000", "-c", "00000000"],
            capture_output=True,
            text=True,
            check=False,
        )
        geom = slurp.stdout.strip()
        if not geom:
            return
        grim = subprocess.run(["grim", "-g", geom, "-t", "ppm", "-"], capture_output=True, check=False)
        raw = grim.stdout
        if len(raw) >= 3:
            r, g, b = raw[-3], raw[-2], raw[-1]
            hex_col = f"#{r:02x}{g:02x}{b:02x}"
            copy_text_to_clipboard(hex_col)
            emit_kv({"ok": True, "hex": hex_col})
    except Exception:
        pass


def trigger_native_capture(mode: str = "region") -> None:
    if "gnome" in os.environ.get("XDG_CURRENT_DESKTOP", "").lower():
        if mode == "eyedropper":
            pick_color_fallback()
            return
        if mode in ("fullscreen", "full"):
            shot_dir = Path.home() / "Pictures" / "Screenshots"
            shot_dir.mkdir(parents=True, exist_ok=True)
            out_path = str(shot_dir / f"Screenshot_{time.strftime('%Y%m%d_%H%M%S')}.png")
            subprocess.run(
                [
                    "gdbus", "call", "--session",
                    "--dest", "org.gnome.Shell.Screenshot",
                    "--object-path", "/org/gnome/Shell/Screenshot",
                    "--method", "org.gnome.Shell.Screenshot.Screenshot",
                    "true", "true", out_path,
                ],
                check=False,
            )
            return
        subprocess.run(
            [
                "gdbus", "call", "--session",
                "--dest", "org.gnome.Shell.Screenshot",
                "--object-path", "/org/gnome/Shell/Screenshot",
                "--method", "org.gnome.Shell.Screenshot.InteractiveScreenshot",
            ],
            check=False,
        )
        return

    cmd = ["qs", "ipc", "call", "screenshot"]
    if mode in ("fullscreen", "full"):
        cmd.append("full")
    elif mode in ("window", "annotate", "eyedropper"):
        cmd.append(mode if mode != "eyedropper" else "picker")
    else:
        cmd.append("open")
    try:
        subprocess.run(cmd, check=False)
    except Exception:
        pass


def _print_help() -> None:
    from _cli_ui import get_style
    st = get_style()
    print(f"""{st.cyan}{st.bold}󰄀 shot{st.reset} {st.dim}· screenshot & annotation studio cli (hyprland + gnome){st.reset}

{st.bold}usage:{st.reset}
  shot [region|window|full|annotate|eyedropper]
  shot pick-color                 sample pixel hex and copy
  shot export <file>              composite latest capture
  shot edit <file>                open in image editor""")


def main():
    if any(a in ("-h", "--help", "help") for a in sys.argv[1:]):
        _print_help()
        return

    if len(sys.argv) < 2:
        trigger_native_capture("region")
        return

    cmd = sys.argv[1].lower()
    if cmd in ("region", "window", "full", "fullscreen", "annotate", "eyedropper"):
        trigger_native_capture(cmd)
    elif cmd == "export" and len(sys.argv) >= 3:
        run_export(sys.argv[2])
    elif cmd == "capture":
        mode = sys.argv[2].lower() if len(sys.argv) > 2 else "region"
        trigger_native_capture(mode)
    elif cmd == "post":
        action = sys.argv[2].lower() if len(sys.argv) > 2 else "both"
        file_path = sys.argv[3] if len(sys.argv) > 3 else ""
        send_note = sys.argv[4] == "1" if len(sys.argv) > 4 else True
        handle_post_legacy(action, file_path, send_note)
    elif cmd == "copy":
        file_path = sys.argv[2] if len(sys.argv) > 2 else ""
        ok = copy_image_to_clipboard(file_path)
        emit_kv({"ok": ok})
    elif cmd == "copy-color" and len(sys.argv) >= 3:
        hex_col = sys.argv[2]
        ok = copy_text_to_clipboard(hex_col)
        try:
            subprocess.run(
                ["notify-send", "-a", "quickshell", "color copied", f"{hex_col} copied to clipboard"],
                check=False,
                timeout=2,
            )
        except Exception:
            pass
        emit_kv({"ok": ok, "hex": hex_col})
    elif cmd == "clipboard-load":
        clipboard_load()
    elif cmd == "pick-color":
        pick_color_fallback()
    elif cmd == "edit":
        file_path = sys.argv[2] if len(sys.argv) > 2 else ""
        open_editor(file_path)
    elif cmd == "notify":
        file_path = sys.argv[2] if len(sys.argv) > 2 else ""
        action = sys.argv[3].lower() if len(sys.argv) > 3 else "save"
        notify_capture(file_path, file_path, action)
    else:
        trigger_native_capture("region")


if __name__ == "__main__":
    main()
