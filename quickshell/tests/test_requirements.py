#!/usr/bin/env python3
"""
tests/test_requirements.py: Requirement Acceptance Verification Suite (Tier 4)
==============================================================================
Automated acceptance verifiers covering:
  - Requirement 1 (R1): Clean Quote & Status Flavor Separation
  - Requirement 2 (R2): Complete Elimination of Font / PUA Glyph Hacks
  - Requirement 3 (R3): Bento Shell UI Consistency & Geometry
  - Requirement 4 (R4): Settings Schema & Test Harness Integrity

Exit 0: All requirement acceptance criteria satisfied.
Exit 1: Acceptance criterion failure detected.
"""

import os
import re
import subprocess
import sys
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent

# Resolve matugen template path
MATUGEN_TEMPLATE_PATH = PROJECT_ROOT.parent / "matugen" / "templates" / "Theme.qml"
if not MATUGEN_TEMPLATE_PATH.exists():
    MATUGEN_TEMPLATE_PATH = PROJECT_ROOT / "matugen" / "templates" / "Theme.qml"

THEME_QML_PATH = PROJECT_ROOT / "Theme.qml"
QMLDIR_PATH = PROJECT_ROOT / "qmldir"
ASSETS_ICONS_DIR = PROJECT_ROOT / "assets" / "icons"


# ============================================================================
# Helpers
# ============================================================================

def is_pua_codepoint(cp: int) -> bool:
    """Returns True if codepoint is within BMP or Supplementary PUA ranges."""
    return (0xE000 <= cp <= 0xF8FF) or (0xF0000 <= cp <= 0x10FFFF)


PUA_ESCAPE_PATTERN = re.compile(
    r"\\u[eE][0-9a-fA-F]{3}|\\u[fF][0-8a-fA-F]{3}|"
    r"\\u\{[eE][0-9a-fA-F]{3}\}|\\u\{[fF][0-8a-fA-F]{3}\}|"
    r"\\u\{[fF][0-9a-fA-F]{4}\}|\\u\{10[0-9a-fA-F]{4}\}|"
    r"\\U000[fF][0-9a-fA-F]{4}|\\U0010[0-9a-fA-F]{4}"
)


def scan_file_for_pua(path: Path):
    """Scans a file for literal PUA characters and raw unicode escape sequences."""
    text = path.read_text(encoding="utf-8", errors="ignore")
    violations = []

    # 1. Check literal decoded characters
    for line_no, line in enumerate(text.splitlines(), 1):
        for col, ch in enumerate(line, 1):
            cp = ord(ch)
            if is_pua_codepoint(cp):
                violations.append({
                    "line": line_no,
                    "col": col,
                    "type": "literal",
                    "codepoint": f"U+{cp:04X}",
                    "char": ch,
                    "snippet": line.strip()[:80]
                })

    # 2. Check source escape sequences
    for line_no, line in enumerate(text.splitlines(), 1):
        for m in PUA_ESCAPE_PATTERN.finditer(line):
            violations.append({
                "line": line_no,
                "col": m.start() + 1,
                "type": "escape",
                "escape": m.group(),
                "snippet": line.strip()[:80]
            })

    return violations


def get_all_target_files(extensions=(".qml", ".conf", ".py")):
    """Recursively collects all repository files matching given extensions."""
    files = []
    for root, dirs, filenames in os.walk(PROJECT_ROOT):
        # Skip tests directory from PUA search to avoid self-flagging test patterns
        if "tests" in Path(root).parts or ".git" in Path(root).parts:
            continue
        for f in filenames:
            if f.endswith(extensions):
                files.append(Path(root) / f)

    # Include matugen template if located outside PROJECT_ROOT
    if MATUGEN_TEMPLATE_PATH.exists() and MATUGEN_TEMPLATE_PATH not in files:
        files.append(MATUGEN_TEMPLATE_PATH)
    return files


# ============================================================================
# Requirement 1: Clean Quote & Status Flavor Separation
# ============================================================================

class TestRequirement1QuotesAndFlavor(unittest.TestCase):
    """Validates R1: bifurcation of quotes vs statusFlavor, APIs, and elimination of meme text."""

    def test_r1_bifurcated_quotes_and_status_flavor_properties(self):
        """Theme.qml and matugen/templates/Theme.qml must bifurcate quotes and statusFlavor."""
        target_files = [THEME_QML_PATH, MATUGEN_TEMPLATE_PATH]

        required_quote_categories = {"system", "philosophy", "focus", "simplicity"}
        required_status_categories = {
            "battery_charging", "battery_low", "battery_full",
            "network_on", "network_off",
            "media_playing", "media_quiet",
            "notes_empty", "notifs_empty",
            "volume_muted", "volume_high",
            "brightness_high", "brightness_low",
            "screenshot"
        }

        for path in target_files:
            self.assertTrue(path.is_file(), f"Target file missing: {path}")
            text = path.read_text(encoding="utf-8")

            # 1. Must declare property var quotes
            quotes_match = re.search(r"(?:readonly\s+)?property\s+var\s+quotes\s*:\s*Object\.freeze\(\{([\s\S]*?)\}\)", text)
            self.assertIsNotNone(quotes_match, f"{path.name} is missing 'property var quotes: Object.freeze({{...}})' declaration")

            # 2. Must declare property var statusFlavor
            flavor_match = re.search(r"(?:readonly\s+)?property\s+var\s+statusFlavor\s*:\s*Object\.freeze\(\{([\s\S]*?)\}\)", text)
            self.assertIsNotNone(flavor_match, f"{path.name} is missing 'property var statusFlavor: Object.freeze({{...}})' declaration")

            # 3. Check categories in quotes
            quotes_body = quotes_match.group(1)
            found_quote_cats = set(re.findall(r'["\']?([a-zA-Z0-9_]+)["\']?\s*:\s*\[', quotes_body))
            missing_quote_cats = required_quote_categories - found_quote_cats
            self.assertEqual(len(missing_quote_cats), 0, f"{path.name} quotes missing required categories: {missing_quote_cats}")

            # 4. Check categories in statusFlavor
            flavor_body = flavor_match.group(1)
            found_status_cats = set(re.findall(r'["\']?([a-zA-Z0-9_]+)["\']?\s*:\s*\[', flavor_body))
            missing_status_cats = required_status_categories - found_status_cats
            self.assertEqual(len(missing_status_cats), 0, f"{path.name} statusFlavor missing required categories: {missing_status_cats}")

    def test_r1_quotes_attribution_contract(self):
        """All entries in Theme.quotes must be attributed quotes (featuring em-dash or attribution marker)."""
        text = THEME_QML_PATH.read_text(encoding="utf-8")
        quotes_match = re.search(r"(?:readonly\s+)?property\s+var\s+quotes\s*:\s*Object\.freeze\(\{([\s\S]*?)\}\)", text)
        self.assertIsNotNone(quotes_match, "Theme.qml is missing quotes definition")

        quotes_body = quotes_match.group(1)
        # Extract all string literals inside quotes arrays [ ... ]
        # Capture both single-quoted ('...') and double-quoted ("...") strings so single-quoted quotes cannot evade attribution checking
        # quote_items = re.findall(r'["\']([^"\'\\]*(?:\\.[^"\'\\]*)*)["\']', quotes_body)
        arrays = re.findall(r"\[([\s\S]*?)\]", quotes_body)
        quote_items = []
        for arr in arrays:
            matches = re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"|\'([^\'\\]*(?:\\.[^\'\\]*)*)\'', arr)
            quote_items.extend([m[0] or m[1] for m in matches])
        self.assertGreater(len(quote_items), 10, "Theme.quotes must contain meaningful quote entries")

        # Every quote entry must contain an attribution marker (— / em-dash, --, or - with author)
        unattributed = []
        for q in quote_items:
            if not any(sep in q for sep in ["—", "–", "--", " - "]):
                unattributed.append(q)

        self.assertEqual(
            len(unattributed), 0,
            f"Found unattributed quote items in Theme.quotes (quotes must have author attribution): {unattributed[:5]}"
        )

    def test_r1_theme_quote_and_flavor_api_contracts(self):
        """Theme.qml and template must declare getQuote(), getStatusFlavor(), and backward-compatible getFlavor()."""
        for path in [THEME_QML_PATH, MATUGEN_TEMPLATE_PATH]:
            text = path.read_text(encoding="utf-8")

            # Check getQuote API
            has_get_quote = bool(re.search(r"function\s+getQuote\s*\(\s*category\s*(?::\s*string)?\s*,\s*fallback\s*(?::\s*string)?\s*\)", text))
            self.assertTrue(has_get_quote, f"{path.name} missing 'function getQuote(category, fallback)'")

            # Check getStatusFlavor API
            has_get_status_flavor = bool(re.search(r"function\s+getStatusFlavor\s*\(\s*category\s*(?::\s*string)?\s*,\s*fallback\s*(?::\s*string)?\s*\)", text))
            self.assertTrue(has_get_status_flavor, f"{path.name} missing 'function getStatusFlavor(category, fallback)'")

            # Check backward-compatible getFlavor adapter
            has_get_flavor = bool(re.search(r"function\s+getFlavor\s*\(\s*category\s*(?::\s*string)?\s*,\s*fallback\s*(?::\s*string)?\s*\)", text))
            self.assertTrue(has_get_flavor, f"{path.name} missing backward-compatible 'function getFlavor(category, fallback)'")

    def test_r1_elimination_of_hardcoded_meme_fallbacks(self):
        """Consumer widgets must not contain hardcoded meme fallbacks or unhinged gimmick text."""
        sa_path = PROJECT_ROOT / "controls" / "ScreenshotActions.qml"
        self.assertTrue(sa_path.is_file(), "ScreenshotActions.qml missing")
        sa_text = sa_path.read_text(encoding="utf-8")

        # Assert elimination of "snitch mode" in ScreenshotActions.qml
        self.assertNotIn("snitch mode", sa_text.lower(), "ScreenshotActions.qml still contains 'snitch mode' hardcoded meme fallback")
        self.assertNotIn("flavorQuotes", sa_text, "ScreenshotActions.qml directly accesses 'flavorQuotes'")

        # Scan all consumer QML files for banned meme strings
        banned_memes = [
            "snitch mode",
            "chuggin watts",
            "spicy pillow",
            "tactical flashbang",
            "fastest snitch in the west",
            "permanent hearing loss speedrun"
        ]

        qml_files = get_all_target_files((".qml",))
        meme_violations = []
        for p in qml_files:
            content = p.read_text(encoding="utf-8")
            for meme in banned_memes:
                if meme in content.lower():
                    # If it's Theme.qml, statusFlavor may contain playful status strings, but consumers must not
                    if p == THEME_QML_PATH or p == MATUGEN_TEMPLATE_PATH:
                        continue
                    meme_violations.append((p.relative_to(PROJECT_ROOT) if p.is_relative_to(PROJECT_ROOT) else p, meme))

        self.assertEqual(
            len(meme_violations), 0,
            f"Found consumer files with unhinged meme text: {meme_violations}"
        )

    def test_r1_consumer_widgets_do_not_access_raw_flavor_quotes(self):
        """Consumer widgets must use Theme accessor functions, not index Theme.flavorQuotes directly."""
        qml_files = get_all_target_files((".qml",))
        violations = []
        pattern = re.compile(r"Theme\.flavorQuotes|\.flavorQuotes")

        for p in qml_files:
            if p == THEME_QML_PATH or p == MATUGEN_TEMPLATE_PATH:
                continue
            text = p.read_text(encoding="utf-8")
            if pattern.search(text):
                violations.append(str(p.relative_to(PROJECT_ROOT) if p.is_relative_to(PROJECT_ROOT) else p))

        self.assertEqual(
            len(violations), 0,
            f"Consumer widgets directly querying flavorQuotes (must use getQuote/getStatusFlavor): {violations}"
        )

    def test_r1_lockscreen_quote_mode_contract(self):
        """LockScreen.qml must support clean quote modes and query Theme quote APIs."""
        lock_path = PROJECT_ROOT / "lockscreen" / "LockScreen.qml"
        self.assertTrue(lock_path.is_file(), "LockScreen.qml missing")
        text = lock_path.read_text(encoding="utf-8")

        # Verify LockScreen supports quoteMode
        self.assertIn("property string quoteMode", text, "LockScreen.qml missing quoteMode property")

        # Verify LockScreen does not directly query Theme.flavorQuotes
        self.assertNotIn("Theme.flavorQuotes", text, "LockScreen.qml directly references Theme.flavorQuotes")


# ============================================================================
# Requirement 2: Elimination of Font / PUA Glyph Hacks
# ============================================================================

class TestRequirement2ZeroFontHacks(unittest.TestCase):
    """Validates R2: 0 PUA glyphs, 0 FontLoaders, 0 fontIcon bindings, bundled SVGs, native IconImage."""

    def test_r2_zero_pua_glyphs_across_all_codebase(self):
        """Zero PUA Unicode characters or escape sequences allowed across all .qml, .conf, .py files."""
        target_files = get_all_target_files((".qml", ".conf", ".py"))
        total_violations = []

        for p in target_files:
            violations = scan_file_for_pua(p)
            if violations:
                rel = p.relative_to(PROJECT_ROOT) if p.is_relative_to(PROJECT_ROOT) else p
                for v in violations:
                    v["file"] = str(rel)
                    total_violations.append(v)

        if total_violations:
            summary = "\n".join(
                f"  {v['file']}:{v['line']}:{v['col']} [{v['type']}] {v.get('codepoint') or v.get('escape')}: {v['snippet']}"
                for v in total_violations[:20]
            )
            self.fail(
                f"Found {len(total_violations)} PUA Unicode glyph violations across {len(set(v['file'] for v in total_violations))} files:\n{summary}\n"
                f"... (showing first 20)"
            )

    def test_r2_zero_font_loaders_in_theme(self):
        """Theme.qml and matugen/templates/Theme.qml must have 0 FontLoader elements."""
        for path in [THEME_QML_PATH, MATUGEN_TEMPLATE_PATH]:
            text = path.read_text(encoding="utf-8")
            loaders = re.findall(r"\bFontLoader\s*\{", text)
            self.assertEqual(
                len(loaders), 0,
                f"{path.name} still contains {len(loaders)} FontLoader blocks (all icon fonts must be removed)"
            )
            # Assert elimination of specific legacy font loader IDs
            for legacy_id in ["loaderMatRounded", "loaderFaSolid", "loaderSegoe", "loaderMatOutlined", "loaderMatSharp"]:
                self.assertNotIn(legacy_id, text, f"{path.name} still contains legacy font loader ID '{legacy_id}'")

    def test_r2_zero_font_icon_bindings_in_consumer_components(self):
        """Zero consumer components may bind to Theme.fontIcon or use font-based icon glyphs."""
        qml_files = get_all_target_files((".qml",))
        violations = []
        pattern = re.compile(r"font\.family:\s*(?:[^\n]*\?\s*)?Theme\.fontIcon|\bTheme\.fontIcon\b")

        for p in qml_files:
            text = p.read_text(encoding="utf-8")
            matches = pattern.findall(text)
            if matches:
                rel = p.relative_to(PROJECT_ROOT) if p.is_relative_to(PROJECT_ROOT) else p
                violations.append((str(rel), len(matches)))

        self.assertEqual(
            len(violations), 0,
            f"Found {sum(v[1] for v in violations)} Theme.fontIcon bindings across {len(violations)} QML files:\n" +
            "\n".join(f"  {v[0]}: {v[1]} occurrences" for v in violations)
        )

    def test_r2_bundled_svg_asset_library_complete(self):
        """assets/icons/ must exist and provide valid SVG vector assets for specialty icons."""
        self.assertTrue(ASSETS_ICONS_DIR.is_dir(), f"Bundled icon asset directory missing at {ASSETS_ICONS_DIR}")

        required_svgs = [
            "arch.svg",
            "coffee.svg",
            "flame.svg",
            "sparkles.svg",
            "pin.svg",
            "tray.svg",
            "cpu.svg",
            "thermo.svg",
            "equalizer.svg",
            "radio.svg",
            "filter.svg"
        ]

        # Check distro SVGs (nixos.svg or nix.svg, arch.svg)
        nix_present = (ASSETS_ICONS_DIR / "nixos.svg").exists() or (ASSETS_ICONS_DIR / "nix.svg").exists()
        self.assertTrue(nix_present, "assets/icons/ missing nixos.svg or nix.svg")

        for svg_name in required_svgs:
            svg_file = ASSETS_ICONS_DIR / svg_name
            self.assertTrue(svg_file.is_file(), f"Required bundled icon missing: {svg_name}")
            self.assertGreater(svg_file.stat().st_size, 50, f"SVG file {svg_name} is abnormally small or empty")

            # Validate XML parseability
            try:
                tree = ET.parse(svg_file)
                root = tree.getroot()
                self.assertTrue(
                    root.tag.endswith("svg"),
                    f"{svg_name} XML root is not '<svg>' (found {root.tag})"
                )
            except ET.ParseError as e:
                self.fail(f"Invalid XML syntax in {svg_name}: {e}")

    def test_r2_controls_icon_primitive_contract(self):
        """controls/Icon.qml must exist, be registered in qmldir, and wrap Quickshell IconImage."""
        icon_qml_path = PROJECT_ROOT / "controls" / "Icon.qml"
        self.assertTrue(icon_qml_path.is_file(), "controls/Icon.qml does not exist")

        # Verify qmldir registration
        qmldir_text = QMLDIR_PATH.read_text(encoding="utf-8")
        self.assertTrue(
            bool(re.search(r"^\s*Icon\s+controls/Icon\.qml", qmldir_text, re.M)),
            "qmldir does not register 'Icon controls/Icon.qml'"
        )

        icon_text = icon_qml_path.read_text(encoding="utf-8")
        # Must import Quickshell.Widgets or Quickshell
        self.assertTrue(
            bool(re.search(r"import\s+Quickshell(?:\.Widgets)?", icon_text)),
            "controls/Icon.qml does not import Quickshell or Quickshell.Widgets"
        )
        # Must instantiate IconImage
        self.assertIn("IconImage", icon_text, "controls/Icon.qml does not instantiate native 'IconImage'")
        # Must NOT use fontIcon
        self.assertNotIn("fontIcon", icon_text, "controls/Icon.qml improperly references fontIcon")

        # Verify property interface
        self.assertTrue(bool(re.search(r"property\s+string\s+source", icon_text)), "Icon.qml missing 'property string source'")
        self.assertTrue(bool(re.search(r"property\s+int\s+size|implicitWidth", icon_text)), "Icon.qml missing size property")

    def test_r2_controls_icon_button_contract(self):
        """controls/IconButton.qml must utilize native icon rendering instead of fontIcon Text."""
        icon_btn_path = PROJECT_ROOT / "controls" / "IconButton.qml"
        self.assertTrue(icon_btn_path.is_file(), "controls/IconButton.qml does not exist")

        btn_text = icon_btn_path.read_text(encoding="utf-8")
        # Must NOT bind to Theme.fontIcon
        self.assertNotIn("Theme.fontIcon", btn_text, "controls/IconButton.qml still binds to Theme.fontIcon")
        # Must instantiate native IconImage or Icon control
        has_native_icon = "IconImage" in btn_text or "Icon {" in btn_text or "Icon\n" in btn_text
        self.assertTrue(has_native_icon, "controls/IconButton.qml does not render via native IconImage or Icon component")

    def test_r2_theme_resolve_icon_source_and_icon_properties(self):
        """Theme.qml must provide icon URL resolution and icon* properties returning valid paths."""
        text = THEME_QML_PATH.read_text(encoding="utf-8")

        # Must declare resolveIconSource
        has_resolve = bool(re.search(r"function\s+resolveIconSource\s*\(", text))
        self.assertTrue(has_resolve, "Theme.qml missing 'function resolveIconSource(name)'")

        # Verify icon properties do not contain unicode escapes
        icon_props = re.findall(r"readonly\s+property\s+string\s+icon([a-zA-Z0-9_]+)\s*:\s*([^\n;]+)", text)
        self.assertGreater(len(icon_props), 50, "Theme.qml must declare comprehensive icon* properties")

        pua_in_props = []
        for name, val in icon_props:
            if PUA_ESCAPE_PATTERN.search(val) or any(is_pua_codepoint(ord(c)) for c in val):
                pua_in_props.append(f"icon{name}: {val.strip()[:40]}")

        self.assertEqual(
            len(pua_in_props), 0,
            f"Theme icon properties still return PUA glyphs instead of image/icon URLs:\n" +
            "\n".join(f"  {p}" for p in pua_in_props[:10])
        )


# ==============================================================================
# Requirement 3: Bento Geometry & Shell UI Consistency
# ==============================================================================

class TestRequirement3BentoGeometryAndWaybarElimination(unittest.TestCase):
    """Verifies R3 bento component integration, declaration, and elimination of Waybar pill hacks."""

    BAR_CONTAINER_FILES = [
        "bar/StatusBar.qml",
        "widgets/Workspaces.qml",
        "widgets/WindowTitle.qml",
        "widgets/Clock.qml",
        "widgets/Battery.qml",
        "widgets/SystemTray.qml",
        "widgets/VolumeControl.qml",
        "widgets/IdleInhibitor.qml",
        "widgets/NetworkStatus.qml",
        "widgets/Bluetooth.qml",
        "widgets/NowPlaying.qml",
        "widgets/PowerMenu.qml",
        "widgets/DynamicNotch.qml",
    ]

    POPUP_CARD_FILES = [
        "widgets/BatteryPopup.qml",
        "widgets/Bluetooth.qml",
        "widgets/NetworkStatus.qml",
        "widgets/NowPlaying.qml",
        "widgets/PowerMenu.qml",
        "widgets/AppLauncher.qml",
        "widgets/QuickSettings.qml",
        "controls/PopupPanel.qml",
    ]

    def test_01_bento_controls_exist_and_declared_in_qmldir(self):
        """BentoCard.qml, BentoBox.qml, and BentoHeader.qml must exist and be declared in qmldir."""
        card_path = PROJECT_ROOT / "controls" / "BentoCard.qml"
        box_path = PROJECT_ROOT / "controls" / "BentoBox.qml"
        header_path = PROJECT_ROOT / "controls" / "BentoHeader.qml"

        self.assertTrue(card_path.is_file() and card_path.stat().st_size > 0,
                        f"Missing or empty {card_path}")
        self.assertTrue(box_path.is_file() and box_path.stat().st_size > 0,
                        f"Missing or empty {box_path}")
        self.assertTrue(header_path.is_file() and header_path.stat().st_size > 0,
                        f"Missing or empty {header_path}")

        qmldir_path = PROJECT_ROOT / "qmldir"
        qmldir_content = qmldir_path.read_text(encoding="utf-8")
        declarations = {}
        for line in qmldir_content.splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) >= 2:
                declarations[parts[0]] = parts[1]

        self.assertIn("BentoCard", declarations, "qmldir must declare BentoCard")
        self.assertEqual(declarations["BentoCard"], "controls/BentoCard.qml")

        self.assertIn("BentoBox", declarations, "qmldir must declare BentoBox")
        self.assertEqual(declarations["BentoBox"], "controls/BentoBox.qml")

        self.assertIn("BentoHeader", declarations, "qmldir must declare BentoHeader")
        self.assertEqual(declarations["BentoHeader"], "controls/BentoHeader.qml")

    def test_02_bento_components_property_contracts(self):
        """Verify BentoCard, BentoBox, and BentoHeader implement required API properties."""
        card_content = (PROJECT_ROOT / "controls" / "BentoCard.qml").read_text(encoding="utf-8")
        self.assertRegex(card_content, r"property\s+alias\s+contentItem\b|contentItem\b",
                         "BentoCard must expose contentItem")
        self.assertRegex(card_content, r"property\s+bool\s+hoverLift\b",
                         "BentoCard must expose hoverLift property")
        self.assertIn("Theme.radiusMd", card_content,
                      "BentoCard must bind radius to Theme.radiusMd (or effectiveCardRadius)")

        box_content = (PROJECT_ROOT / "controls" / "BentoBox.qml").read_text(encoding="utf-8")
        self.assertRegex(box_content, r"property\s+alias\s+contentItem\b|contentItem\b",
                         "BentoBox must expose contentItem")
        self.assertIn("Theme.radiusSm", box_content,
                      "BentoBox must bind radius to Theme.radiusSm (or effectiveCardRadius)")

        header_path = PROJECT_ROOT / "controls" / "BentoHeader.qml"
        self.assertTrue(header_path.is_file(), f"controls/BentoHeader.qml does not exist at {header_path}")
        header_content = header_path.read_text(encoding="utf-8")
        self.assertRegex(header_content, r"property\s+string\s+title\b",
                         "BentoHeader must expose title property")
        self.assertRegex(header_content, r"property\s+string\s+(?:subtitle|status)\b",
                         "BentoHeader must expose subtitle property")
        self.assertRegex(header_content, r"property\s+(?:string|var)\s+iconSource\b|property\s+string\s+icon\b",
                         "BentoHeader must expose iconSource property")

    def test_03_bento_components_active_utilization_no_zero_callers(self):
        """BentoCard and BentoBox must be actively imported and instantiated in consumer widgets (no 0 callers)."""
        card_pattern = re.compile(r"\bBentoCard\s*\{")
        box_pattern = re.compile(r"\bBentoBox\s*\{")
        header_pattern = re.compile(r"\bBentoHeader\s*\{")

        card_callers = []
        box_callers = []
        header_callers = []

        for p in PROJECT_ROOT.glob("**/*.qml"):
            if "matugen" in p.parts:
                continue
            if p.name in {"BentoCard.qml", "BentoBox.qml", "BentoHeader.qml"}:
                continue
            content = p.read_text(encoding="utf-8")
            if card_pattern.search(content):
                card_callers.append(str(p.relative_to(PROJECT_ROOT)))
            if box_pattern.search(content):
                box_callers.append(str(p.relative_to(PROJECT_ROOT)))
            if header_pattern.search(content):
                header_callers.append(str(p.relative_to(PROJECT_ROOT)))

        self.assertGreater(
            len(card_callers), 0,
            f"BentoCard has 0 callers across the repository. Expected adoption in popups/bars. Callers: {card_callers}"
        )
        self.assertGreater(
            len(box_callers), 0,
            f"BentoBox has 0 callers across the repository. Expected adoption in widgets. Callers: {box_callers}"
        )
        self.assertGreater(
            len(header_callers), 0,
            f"BentoHeader has 0 callers across the repository. Expected adoption across popups. Callers: {header_callers}"
        )

    def test_04_elimination_of_generic_waybar_pill_hacks_on_bar_containers(self):
        """Verify absence of raw radiusPill (9999) or Theme.radiusPill on bar container modules."""
        pill_pattern = re.compile(r"radius\s*:\s*(?:Theme\??\.)?radiusPill|radius\s*:\s*9999?")

        offenders = []
        for rel_path in self.BAR_CONTAINER_FILES:
            full_path = PROJECT_ROOT / rel_path
            if not full_path.is_file():
                continue
            content = full_path.read_text(encoding="utf-8")
            if pill_pattern.search(content):
                offenders.append(rel_path)

        self.assertEqual(
            offenders, [],
            f"Generic Waybar pill hacks (radiusPill / 9999) detected on bar container roots in: {offenders}. "
            f"Use cohesive Bento tokens (Theme.radiusMd, Theme.radiusSm, Theme.widgetRadius) instead."
        )

    def test_05_elimination_of_pill_hacks_on_popup_cards(self):
        """Verify absence of Theme.radiusPill / 9999 on popup card background containers."""
        card_pill_pattern = re.compile(r"(?:card|panel|popup|dialog|section).*?radius\s*:\s*(?:Theme\??\.)?radiusPill", re.IGNORECASE | re.DOTALL)

        offenders = []
        for rel_path in self.POPUP_CARD_FILES:
            full_path = PROJECT_ROOT / rel_path
            if not full_path.is_file():
                continue
            content = full_path.read_text(encoding="utf-8")
            if card_pill_pattern.search(content):
                offenders.append(rel_path)

        self.assertEqual(
            offenders, [],
            f"Generic pill styling detected on popup cards in: {offenders}. Use BentoCard / BentoBox or Theme.radiusLg/Md."
        )

    def test_06_cohesive_radii_and_padding_tokens_in_theme(self):
        """Verify Theme.qml defines cohesive Bento geometry and padding tokens."""
        theme_path = PROJECT_ROOT / "Theme.qml"
        theme_content = theme_path.read_text(encoding="utf-8")

        required_radii = [
            "effectiveCardRadius",
            "radiusXs",
            "radiusSm",
            "radiusMd",
            "radiusLg",
            "radiusXl",
            "radiusXxl",
        ]
        required_padding = [
            "widgetPaddingH",
            "widgetPaddingV",
            "widgetSpacing",
            "paddingScale",
            "paddingScaleMult",
            "popupPadding",
        ]

        missing_radii = [r for r in required_radii if not re.search(rf"\b{r}\b", theme_content)]
        missing_padding = [p for p in required_padding if not re.search(rf"\b{p}\b", theme_content)]

        self.assertEqual(missing_radii, [], f"Theme.qml missing cohesive radii tokens: {missing_radii}")
        self.assertEqual(missing_padding, [], f"Theme.qml missing padding/spacing tokens: {missing_padding}")


# ==============================================================================
# Requirement 4: Configuration & Test Suite Integrity
# ==============================================================================

class TestRequirement4ConfigurationAndTestSuiteIntegrity(unittest.TestCase):
    """Verifies R4 configuration compatibility, test_schema.py unit tests, and runner orchestration."""

    def test_01_test_schema_suite_integrity_and_25_unit_tests_pass(self):
        """tests/test_schema.py must exist, contain all 6 test suites, and execute 25 tests with exit 0."""
        schema_script = PROJECT_ROOT / "tests" / "test_schema.py"
        self.assertTrue(schema_script.is_file(), "tests/test_schema.py must exist")

        content = schema_script.read_text(encoding="utf-8")
        required_suites = [
            "TestSettingsSchemaParity",
            "TestQuickSettingsCustomization",
            "TestSaveRoundtripLossless",
            "TestPresetServiceResilience",
            "TestAppLauncherStateAndSerialization",
            "TestStatePathIsolationAndJsonElimination",
        ]
        for suite_name in required_suites:
            self.assertIn(f"class {suite_name}", content, f"Missing test suite: {suite_name}")

        # Execute test_schema.py and assert clean zero exit
        proc = subprocess.run(
            [sys.executable, str(schema_script)],
            capture_output=True,
            text=True,
            cwd=str(PROJECT_ROOT)
        )
        self.assertEqual(
            proc.returncode, 0,
            f"test_schema.py failed (exit {proc.returncode}):\n{proc.stdout}\n{proc.stderr}"
        )
        output = proc.stdout + proc.stderr
        self.assertIn("Ran 25 tests", output, "test_schema.py must execute all 25 unit tests")
        self.assertIn("OK", output, "test_schema.py must report OK")

    def test_02_settings_conf_file_validity_and_schema_parity(self):
        """settings.conf must parse losslessly and maintain bidirectional parity with Settings.qml._schema."""
        conf_path = PROJECT_ROOT / "settings.conf"
        qml_path = PROJECT_ROOT / "services" / "Settings.qml"
        self.assertTrue(conf_path.is_file(), "settings.conf must exist")
        self.assertTrue(qml_path.is_file(), "services/Settings.qml must exist")

        conf_content = conf_path.read_text(encoding="utf-8")
        qml_content = qml_path.read_text(encoding="utf-8")

        # Verify key Bento settings are represented in schema and conf
        bento_keys = ["bentoHoverLift", "bentoGap", "widgetPaddingV", "paddingScale"]
        for key in bento_keys:
            self.assertIn(f'"{key}"', qml_content, f"Settings.qml._schema missing key: {key}")
            self.assertRegex(conf_content, rf"(?m)^{key}\s*=", f"settings.conf missing default for key: {key}")

    def test_03_run_all_orchestrator_wiring_and_exit_semantics(self):
        """tests/run_all.sh must orchestrate all 4 tiers sequentially with strict exit semantics."""
        run_all_path = PROJECT_ROOT / "tests" / "run_all.sh"
        self.assertTrue(run_all_path.is_file(), "tests/run_all.sh must exist")
        content = run_all_path.read_text(encoding="utf-8")

        # Verify registration of Tier 4 script
        self.assertRegex(content, r"T4_SCRIPT=.*test_requirements\.py",
                         "run_all.sh must define T4_SCRIPT pointing to test_requirements.py")

        # Verify sequential invocation of all 4 tiers
        self.assertRegex(content, r"run_tier\s+1\b", "run_all.sh must invoke Tier 1")
        self.assertRegex(content, r"run_tier\s+2\b", "run_all.sh must invoke Tier 2")
        self.assertRegex(content, r"run_tier\s+3\b", "run_all.sh must invoke Tier 3")
        self.assertRegex(content, r"run_tier\s+4\b", "run_all.sh must invoke Tier 4")

        # Verify --bail flag and summary calculation
        self.assertIn("--bail", content, "run_all.sh must support --bail flag")
        self.assertIn("print_summary", content, "run_all.sh must invoke print_summary")
        self.assertIn("ALL TIERS PASSED", content, "run_all.sh must report ALL TIERS PASSED on success")
        self.assertIn("VALIDATION SUITE FAILED", content, "run_all.sh must report failure on error")

    def test_04_execution_timing_and_summary_contract(self):
        """tests/run_all.sh must capture start and end timestamps and report duration in seconds."""
        run_all_path = PROJECT_ROOT / "tests" / "run_all.sh"
        content = run_all_path.read_text(encoding="utf-8")

        self.assertIn("start_time=$(date +%s)", content, "run_all.sh must record start_time")
        self.assertIn("end_time=$(date +%s)", content, "run_all.sh must record end_time")
        self.assertIn("DURATIONS+=", content, "run_all.sh must append tier duration")


if __name__ == "__main__":
    print("========================================================================")
    print(" Running Requirement Acceptance Verification Suite (R1 - R4)...")
    print(f" Target: {PROJECT_ROOT}")
    print("========================================================================")
    unittest.main(verbosity=2)
