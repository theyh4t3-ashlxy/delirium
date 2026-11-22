#!/usr/bin/env python3
"""
tests/test_schema.py: Configuration Schema & Key Consistency Validator
======================================================================
Validates key parity and lossless persistence across:
  1. settings.conf (Disk default configuration)
  2. services/Settings.qml (_schema array and reactive properties)
  3. widgets/QuickSettings.qml (User-facing customization controls)
  4. Lossless save roundtrips (toConf serialization integrity)

Exit 0: All schema, parity, and roundtrip contracts satisfied.
Exit 1: Schema mismatch, missing keys, or serialization loss detected.
"""

import os
import re
import sys
import unittest
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent

SETTINGS_CONF_PATH = PROJECT_ROOT / "settings.conf"
SETTINGS_QML_PATH = PROJECT_ROOT / "services" / "Settings.qml"
QUICK_SETTINGS_QML_PATH = PROJECT_ROOT / "widgets" / "QuickSettings.qml"

REQUIRED_19_MODULES = [
    "showWorkspaces",
    "showLayoutSwitcher",
    "showWindowTitle",
    "showClock",
    "showBattery",
    "showSystemTray",
    "showVolume",
    "showMedia",
    "showNotifications",
    "showLauncher",
    "showPowerMenu",
    "showNetwork",
    "showBluetooth",
    "showClipboard",
    "showIdleInhibitor",
    "showScreenCapture",
    "showBarDate",
    "showBarStudio",
    "showMotionSandbox",
]

REQUIRED_STYLE_CONTROLS = [
    "cardOpacity",
    "surfaceOpacity",
    "glassmorphismLevel",
    "bentoGap",
    "widgetPaddingV",
]

VALID_SCHEMA_TYPES = {"string", "int", "float", "bool", "json"}


def parse_settings_conf(path: Path) -> dict:
    """Parses key-value pairs from settings.conf ignoring comments and blank lines."""
    if not path.is_file():
        raise FileNotFoundError(f"settings.conf not found at {path}")
    
    pairs = {}
    for line_num, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            key, val = line.split("=", 1)
            pairs[key.strip()] = val.strip()
    return pairs


def parse_settings_qml_schema(path: Path) -> list:
    """Extracts the _schema item dictionaries from services/Settings.qml."""
    if not path.is_file():
        raise FileNotFoundError(f"Settings.qml not found at {path}")
    
    content = path.read_text(encoding="utf-8")
    # Matches: { key: "foo", type: "bar", def: baz }
    matches = re.findall(
        r'\{\s*key:\s*"([^"]+)",\s*type:\s*"([^"]+)",\s*def:\s*([^}]+)\}',
        content
    )
    items = []
    for key, typ, def_val in matches:
        items.append({
            "key": key.strip(),
            "type": typ.strip(),
            "def": def_val.strip()
        })
    return items


def parse_settings_qml_properties(path: Path) -> set:
    """Extracts declared property names on Settings.qml."""
    content = path.read_text(encoding="utf-8")
    # Matches: property <type> <name>[: ...]
    matches = re.findall(r'property\s+[a-zA-Z0-9_<>.]+\s+([a-zA-Z0-9_]+)', content)
    return set(matches)


class TestSettingsSchemaParity(unittest.TestCase):
    """Tests bidirectional parity between settings.conf and Settings.qml schema."""

    @classmethod
    def setUpClass(cls):
        cls.conf_pairs = parse_settings_conf(SETTINGS_CONF_PATH)
        cls.conf_keys = set(cls.conf_pairs.keys())
        cls.schema_items = parse_settings_qml_schema(SETTINGS_QML_PATH)
        cls.schema_keys = {item["key"] for item in cls.schema_items}
        cls.declared_props = parse_settings_qml_properties(SETTINGS_QML_PATH)

    def test_01_all_conf_keys_exist_in_schema(self):
        """All keys present in settings.conf must be declared in Settings.qml._schema."""
        missing_in_schema = self.conf_keys - self.schema_keys
        self.assertFalse(
            missing_in_schema,
            f"Keys in settings.conf missing from Settings.qml._schema: {sorted(missing_in_schema)}"
        )

    def test_02_all_schema_keys_have_defaults_in_conf(self):
        """All keys declared in Settings.qml._schema must have a default in settings.conf."""
        missing_in_conf = self.schema_keys - self.conf_keys
        self.assertFalse(
            missing_in_conf,
            f"Keys in Settings.qml._schema missing from settings.conf: {sorted(missing_in_conf)}"
        )

    def test_03_all_schema_keys_declared_as_properties(self):
        """Every schema key must correspond to a declared property in Settings.qml."""
        unmapped_props = self.schema_keys - self.declared_props
        self.assertFalse(
            unmapped_props,
            f"Schema keys not declared as QML properties on Settings: {sorted(unmapped_props)}"
        )

    def test_04_schema_items_syntax_and_types(self):
        """Each schema item must have a valid type from VALID_SCHEMA_TYPES."""
        for item in self.schema_items:
            key = item["key"]
            typ = item["type"]
            self.assertIn(
                typ,
                VALID_SCHEMA_TYPES,
                f"Schema key '{key}' has invalid type '{typ}'. Expected one of {VALID_SCHEMA_TYPES}"
            )


class TestQuickSettingsCustomization(unittest.TestCase):
    """Tests QuickSettings.qml user-facing controls and property bindings."""

    @classmethod
    def setUpClass(cls):
        if not QUICK_SETTINGS_QML_PATH.is_file():
            raise FileNotFoundError(f"QuickSettings.qml not found at {QUICK_SETTINGS_QML_PATH}")
        cls.qs_content = QUICK_SETTINGS_QML_PATH.read_text(encoding="utf-8")
        cls.schema_items = parse_settings_qml_schema(SETTINGS_QML_PATH)
        cls.schema_keys = {item["key"] for item in cls.schema_items}
        cls.declared_props = parse_settings_qml_properties(SETTINGS_QML_PATH)

    def test_01_quicksettings_references_valid_properties(self):
        """Settings.<prop> accesses in QuickSettings.qml must be valid properties on Settings."""
        refs = set(re.findall(r'Settings\.([a-zA-Z0-9_]+)', self.qs_content))
        # Known methods, signals, or internals on Settings singleton
        methods_or_signals = {
            "save", "resetToDefaults", "loadFromFile", "toConf", "loadConf",
            "loadObject", "queueSave", "requestWelcomeOpen", "requestWelcomeClose",
            "requestWelcomeToggle", "setNetworkAlias", "moveModule", "transferModule",
            "clock24h", "qml"
        }
        props_only = refs - methods_or_signals
        invalid_refs = props_only - (self.schema_keys | self.declared_props)
        self.assertFalse(
            invalid_refs,
            f"QuickSettings.qml references undefined Settings properties: {sorted(invalid_refs)}"
        )

    def test_02_quicksettings_exposes_all_19_module_toggles(self):
        """QuickSettings.qml must provide user controls for all 19 module toggles."""
        missing_modules = [m for m in REQUIRED_19_MODULES if m not in self.qs_content]
        self.assertFalse(
            missing_modules,
            f"QuickSettings.qml is missing user controls for module toggles: {missing_modules}"
        )

    def test_03_quicksettings_exposes_style_controls(self):
        """QuickSettings.qml must provide controls for granular styling properties."""
        missing_styles = [s for s in REQUIRED_STYLE_CONTROLS if s not in self.qs_content]
        self.assertFalse(
            missing_styles,
            f"QuickSettings.qml is missing controls for style properties: {missing_styles}"
        )

    def test_04_quicksettings_exposes_theme_mode(self):
        """QuickSettings.qml must provide Dark/Light theme mode selection bound to matugenMode."""
        self.assertIn(
            "matugenMode",
            self.qs_content,
            "QuickSettings.qml is missing control for 'matugenMode' (Dark / Light mode toggle)"
        )


class TestSaveRoundtripLossless(unittest.TestCase):
    """Tests that serialization does not strip or drop configuration keys."""

    @classmethod
    def setUpClass(cls):
        cls.conf_pairs = parse_settings_conf(SETTINGS_CONF_PATH)
        cls.settings_content = SETTINGS_QML_PATH.read_text(encoding="utf-8")
        cls.schema_items = parse_settings_qml_schema(SETTINGS_QML_PATH)
        cls.schema_keys = {item["key"] for item in cls.schema_items}

    def test_01_save_roundtrip_preserves_all_conf_keys(self):
        """Simulate toConf serialization and verify no keys from settings.conf are stripped."""
        # Find any hardcoded additions in toConf (e.g. lines.push("hasCompletedWelcome=..."))
        to_conf_body = re.search(r'function toConf\(\)\s*\{([\s\S]*?)\n\s*\}', self.settings_content)
        self.assertIsNotNone(to_conf_body, "Could not find toConf() function in Settings.qml")
        
        body_text = to_conf_body.group(1)
        hardcoded_keys = set(re.findall(r'lines\.push\(["\']([a-zA-Z0-9_]+)=', body_text))

        # Serialized keys comprise schema keys + hardcoded keys serialized in toConf()
        serialized_keys = self.schema_keys | hardcoded_keys

        # Check for any keys in settings.conf that would be lost upon save
        stripped_keys = set(self.conf_pairs.keys()) - serialized_keys
        self.assertFalse(
            stripped_keys,
            f"toConf() drops the following keys from disk settings.conf upon save: {sorted(stripped_keys)}"
        )

    def test_02_special_keys_persistence(self):
        """Verify globalRounding, showShellTab, and hasCompletedWelcome are preserved."""
        to_conf_body = re.search(r'function toConf\(\)\s*\{([\s\S]*?)\n\s*\}', self.settings_content)
        body_text = to_conf_body.group(1) if to_conf_body else ""
        hardcoded_keys = set(re.findall(r'lines\.push\(["\']([a-zA-Z0-9_]+)=', body_text))
        all_serialized = self.schema_keys | hardcoded_keys

        for key in ["globalRounding", "showShellTab", "hasCompletedWelcome"]:
            self.assertIn(
                key,
                all_serialized,
                f"Critical key '{key}' is omitted from Settings serialization and will be lost on save!"
            )

    def test_03_arbitrary_keys_collision_free(self):
        """Verify toConf() preserves arbitrary keys without QtObject property/method collisions."""
        import subprocess

        # Static check: toConf must not use `else if (root[key] !== undefined)`
        self.assertNotIn(
            "root[key] !== undefined",
            self.settings_content,
            "toConf() must not check `root[key] !== undefined` as it collides with QtObject methods (objectName, save, destroy)"
        )

        # Dynamic execution check via node
        lines = self.settings_content.splitlines()
        start_schema = next(i for i, l in enumerate(lines) if "readonly property var _schema:" in l)
        end_schema = next(i for i in range(start_schema, len(lines)) if lines[i].strip() == "]")
        schema_js = "const _schema = " + "\n".join(lines[start_schema:end_schema+1]).split(":", 1)[1] + ";"

        start_toconf = next(i for i, l in enumerate(lines) if "function toConf()" in l)
        end_toconf = next(i for i in range(start_toconf, len(lines)) if lines[i].strip() == "function save() {") - 1
        while lines[end_toconf].strip() != "}":
            end_toconf -= 1

        toconf_js = "\n".join(lines[start_toconf:end_toconf+1])

        test_js = f"""
{schema_js}
const root = {{
    _schema: _schema,
    _rawConfText: "",
    objectName: "qt_internal_object_name",
    save: function() {{ return "corrupted_fn"; }},
    destroy: function() {{ return "corrupted_fn"; }},
    barHeight: 34
}};
for (let item of _schema) {{
    if (root[item.key] === undefined) root[item.key] = item.def;
}}
const confFile = {{ text: () => "" }};
const fallbackConfFile = {{ text: () => "" }};

{toconf_js}

root._rawConfText = `objectName="custom_desktop"
save="custom_save_val"
destroy="custom_destroy"
toString="custom_val"
valueOf="123"
constructor="foo"
hasOwnProperty="bar"
__proto__="test_proto"
arbitraryCustomKey="hello_world"
`;

const out = toConf();
process.stdout.write(out);
"""
        res = subprocess.run(["node", "-e", test_js], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"node execution failed: {res.stderr}")
        out = res.stdout

        self.assertIn('objectName="custom_desktop"', out, "objectName arbitrary key was collided or corrupted")
        self.assertIn('save="custom_save_val"', out, "save arbitrary key was collided with save() method")
        self.assertIn('destroy="custom_destroy"', out, "destroy arbitrary key was collided with destroy() method")
        self.assertIn('toString="custom_val"', out, "toString prototype property was collided or corrupted")
        self.assertIn('valueOf="123"', out, "valueOf prototype property was collided or corrupted")
        self.assertIn('constructor="foo"', out, "constructor prototype property was collided or corrupted")
        self.assertIn('hasOwnProperty="bar"', out, "hasOwnProperty prototype property was collided or corrupted")
        self.assertIn('__proto__="test_proto"', out, "__proto__ arbitrary key was collided or corrupted")
        self.assertIn('arbitraryCustomKey="hello_world"', out, "arbitrary custom key was dropped")
        self.assertNotIn("corrupted_fn", out, "Function definition leaked into toConf() output")
        self.assertNotIn("undefined=undefined", out, "Prototype method collision produced undefined=undefined in toConf() output")

    def test_04_inline_comments_preservation(self):
        """Verify toConf() preserves inline comments on schema lines during serialization."""
        import subprocess

        lines = self.settings_content.splitlines()
        start_schema = next(i for i, l in enumerate(lines) if "readonly property var _schema:" in l)
        end_schema = next(i for i in range(start_schema, len(lines)) if lines[i].strip() == "]")
        schema_js = "const _schema = " + "\n".join(lines[start_schema:end_schema+1]).split(":", 1)[1] + ";"

        start_toconf = next(i for i, l in enumerate(lines) if "function toConf()" in l)
        end_toconf = next(i for i in range(start_toconf, len(lines)) if lines[i].strip() == "function save() {") - 1
        while lines[end_toconf].strip() != "}":
            end_toconf -= 1

        toconf_js = "\n".join(lines[start_toconf:end_toconf+1])

        test_js = f"""
{schema_js}
const root = {{
    _schema: _schema,
    _rawConfText: "",
    barHeight: 36,
    cornerStyle: "continuous-bezier"
}};
for (let item of _schema) {{
    if (root[item.key] === undefined) root[item.key] = item.def;
}}
const confFile = {{ text: () => "" }};
const fallbackConfFile = {{ text: () => "" }};

{toconf_js}

root._rawConfText = `barHeight=32 # height of the bar in pixels   \\t  
cornerStyle="cubic" # smoothly curved corners   
`;

const out = toConf();
process.stdout.write(out);
"""
        res = subprocess.run(["node", "-e", test_js], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"node execution failed: {res.stderr}")
        out = res.stdout

        self.assertIn("barHeight=36 # height of the bar in pixels\n", out, "Inline comment on barHeight lost, not preserved, or trailing whitespace not trimmed")
        self.assertIn('cornerStyle="continuous-bezier" # smoothly curved corners\n', out, "Inline comment on cornerStyle lost, not preserved, or trailing whitespace not trimmed")

    def test_05_terminal_newline_preservation(self):
        """Verify toConf() output always ends with a terminal newline."""
        import subprocess

        lines = self.settings_content.splitlines()
        start_schema = next(i for i, l in enumerate(lines) if "readonly property var _schema:" in l)
        end_schema = next(i for i in range(start_schema, len(lines)) if lines[i].strip() == "]")
        schema_js = "const _schema = " + "\n".join(lines[start_schema:end_schema+1]).split(":", 1)[1] + ";"

        start_toconf = next(i for i, l in enumerate(lines) if "function toConf()" in l)
        end_toconf = next(i for i in range(start_toconf, len(lines)) if lines[i].strip() == "function save() {") - 1
        while lines[end_toconf].strip() != "}":
            end_toconf -= 1

        toconf_js = "\n".join(lines[start_toconf:end_toconf+1])

        test_js = f"""
{schema_js}
const root = {{
    _schema: _schema,
    _rawConfText: ""
}};
for (let item of _schema) {{
    if (root[item.key] === undefined) root[item.key] = item.def;
}}
const confFile = {{ text: () => "" }};
const fallbackConfFile = {{ text: () => "" }};

{toconf_js}

// Test with partial conf text missing most schema keys
root._rawConfText = "barHeight=32";
const out1 = toConf();

// Test with empty conf text
root._rawConfText = "";
const out2 = toConf();

console.log(JSON.stringify({{
    out1EndsInNewline: out1.endsWith("\\n"),
    out2EndsInNewline: out2.endsWith("\\n")
}}));
"""
        res = subprocess.run(["node", "-e", test_js], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"node execution failed: {res.stderr}")
        import json
        data = json.loads(res.stdout)
        self.assertTrue(data["out1EndsInNewline"], "toConf() did not end with a terminal newline when appending un-emitted keys")
        self.assertTrue(data["out2EndsInNewline"], "toConf() did not end with a terminal newline on empty input")

    def test_06_qml_v4_engine_compatibility(self):
        """Verify QML V4 engine compatibility: no trimEnd() call and emittedKeys has null prototype."""
        import glob
        import shutil
        import subprocess
        import tempfile

        # Static checks:
        self.assertNotIn(
            ".trimEnd()",
            self.settings_content,
            "Settings.qml must not call String.prototype.trimEnd() because it is undefined in Qt 6 QML V4 engine"
        )
        self.assertIn(
            "let emittedKeys = Object.create(null);",
            self.settings_content,
            "Settings.qml must initialize emittedKeys with Object.create(null) to avoid __proto__ TypeError in QML V4 engine"
        )

        # Dynamic check with native Qt 6 Declarative QML runtime if present
        qml_bin = shutil.which("qml")
        if not qml_bin:
            candidates = glob.glob("/nix/store/*-qtdeclarative-*/bin/qml")
            if candidates:
                qml_bin = candidates[0]

        if qml_bin and Path(qml_bin).is_file():
            qml_lib = str(Path(qml_bin).parent.parent / "lib" / "qt-6" / "qml")
            lines = self.settings_content.splitlines()
            start_schema = next(i for i, l in enumerate(lines) if "readonly property var _schema:" in l)
            end_schema = next(i for i in range(start_schema, len(lines)) if lines[i].strip() == "]")
            schema_js = "let _schema = " + "\n".join(lines[start_schema:end_schema+1]).split(":", 1)[1] + ";"

            start_toconf = next(i for i, l in enumerate(lines) if "function toConf()" in l)
            end_toconf = next(i for i in range(start_toconf, len(lines)) if lines[i].strip() == "function save() {") - 1
            while lines[end_toconf].strip() != "}":
                end_toconf -= 1
            toconf_js = "\n".join(lines[start_toconf:end_toconf+1])

            qml_test_script = f"""import QtQuick
Item {{
    Component.onCompleted: {{
        {schema_js}
        let root = {{
            _schema: _schema,
            _rawConfText: "",
            barHeight: 38,
            cornerStyle: "continuous-bezier"
        }};
        for (let i = 0; i < _schema.length; i++) {{
            let it = _schema[i];
            if (root[it.key] === undefined) root[it.key] = it.def;
        }}
        let confFile = {{ text: function() {{ return ""; }} }};
        let fallbackConfFile = {{ text: function() {{ return ""; }} }};

        {toconf_js}

        root._rawConfText = "barHeight=32 # height of the bar in pixels   \\t  \\n__proto__=\\"custom_proto\\"\\ncustomKey=\\"val\\"\\n";
        let out = toConf();
        console.log("QML_V4_SUCCESS_OUT:" + out);
        Qt.quit();
    }}
}}
"""
            with tempfile.NamedTemporaryFile(suffix=".qml", mode="w") as f:
                f.write(qml_test_script)
                f.flush()
                env = os.environ.copy()
                env["QT_QPA_PLATFORM"] = "offscreen"
                cmd = [qml_bin, "-a", "core", "-I", qml_lib, "--quit-after", "2000", f.name]
                p = subprocess.run(cmd, capture_output=True, text=True, env=env)
                self.assertNotIn("TypeError", p.stderr, f"QML engine threw TypeError: {p.stderr}")
                self.assertIn("QML_V4_SUCCESS_OUT:", p.stderr, f"QML engine did not complete successfully: {p.stderr}")
                self.assertIn("barHeight=38 # height of the bar in pixels\n", p.stderr, "Trailing comment whitespace not trimmed in QML V4")
                self.assertIn('__proto__="custom_proto"\n', p.stderr, "__proto__ not preserved in QML V4 serialization")


class TestPresetServiceResilience(unittest.TestCase):
    """Tests PresetService.qml command escaping and preset precedence contracts."""

    @classmethod
    def setUpClass(cls):
        preset_service_path = PROJECT_ROOT / "services" / "PresetService.qml"
        cls.content = preset_service_path.read_text(encoding="utf-8")

    def test_01_single_quote_safe_command(self):
        """presetScanProc must pass directories via positional arguments to avoid quote injection."""
        self.assertNotIn(
            "for d in '\" + root.presetsDir",
            self.content,
            "PresetService.qml must not concatenate directories into single-quoted sh string"
        )
        self.assertIn(
            '"$@"',
            self.content,
            "PresetService.qml must use positional arguments \"$@\" for safe directory iteration"
        )

    def test_02_user_presets_take_precedence(self):
        """User presets in userPresetsDir must precede builtins in scan command and seen logic."""
        self.assertNotIn(
            'let seen = { "default": true, "minimal": true, "island": true };',
            self.content,
            "PresetService.qml must not pre-populate seen with builtins to allow user preset overrides"
        )
        # Verify userPresetsDir is passed before presetsDir in positional arguments
        proc_match = re.search(r'presetScanProc: Process \{[\s\S]*?stdout:', self.content)
        self.assertIsNotNone(proc_match, "Could not find presetScanProc block")
        proc_text = proc_match.group(0)
        self.assertIsNotNone(
            re.search(r'root\.userPresetsDir[\s\S]*?,\s*root\.presetsDir\b', proc_text),
            "userPresetsDir must be listed before presetsDir to prioritize user presets"
        )


class TestAppLauncherStateAndSerialization(unittest.TestCase):
    """Unit tests for AppLauncher key-value state persistence and migration."""

    @classmethod
    def setUpClass(cls):
        launcher_path = PROJECT_ROOT / "widgets" / "AppLauncher.qml"
        cls.content = launcher_path.read_text(encoding="utf-8")

    def test_01_launcher_state_paths_relocated_to_state_dir(self):
        """AppLauncher must locate state files in stateDir, not configDir."""
        self.assertIn(
            'readonly property string pinnedStatePath: stateDir + "/pinned_apps"',
            self.content,
            "pinnedStatePath must be located in stateDir"
        )
        self.assertIn(
            'readonly property string launcherStatePath: stateDir + "/launcher_state.conf"',
            self.content,
            "launcherStatePath must be launcher_state.conf located in stateDir"
        )

    def test_02_zero_json_serialization_in_launcher_save(self):
        """saveLauncherState must serialize to key-value conf format without JSON.stringify."""
        save_match = re.search(r'function saveLauncherState\(\)\s*\{([\s\S]*?)\n    \}', self.content)
        self.assertIsNotNone(save_match, "saveLauncherState function not found in AppLauncher.qml")
        save_code = save_match.group(1)
        self.assertNotIn(
            "JSON.stringify",
            save_code,
            "saveLauncherState() must not use JSON.stringify; must write clean key-value format"
        )
        self.assertIn(
            'lines.push("usage." + k + "="',
            save_code,
            "saveLauncherState() must format usage as usage.<appKey>=<count>,<lastUsed>"
        )

    def test_03_key_value_roundtrip_and_migration_execution(self):
        """Dynamic test of parseKeyValueText, saveLauncherState, and legacy migration via node."""
        import subprocess

        parse_match = re.search(r'function parseKeyValueText\(raw:[^)]*\)\s*\{([\s\S]*?)\n    \}', self.content)
        save_match = re.search(r'function saveLauncherState\(\)\s*\{([\s\S]*?)\n    \}', self.content)
        migrate_match = re.search(r'function tryMigrateLegacyJson\(\):[^{]*\{([\s\S]*?)\n    \}', self.content)

        self.assertIsNotNone(parse_match, "parseKeyValueText not found")
        self.assertIsNotNone(save_match, "saveLauncherState not found")
        self.assertIsNotNone(migrate_match, "tryMigrateLegacyJson not found")

        test_js = f"""
const root = {{
    gridViewMode: false,
    sortMode: "smart",
    textCase: "lower",
    subtitleMode: "desc",
    rowDensity: "cozy",
    gridColumns: 4,
    autoDesktopCats: true,
    showUsageBadges: true,
    launcherWide: false,
    usageMap: {{}},
    stateLoaded: false
}};

let savedText = "";
const launcherStateFile = {{
    setText: (str) => {{ savedText = str; }}
}};

function parseKeyValueText(raw) {{
{parse_match.group(1)}
}}

function saveLauncherState() {{
{save_match.group(1)}
}}

// 1. Test parsing key-value conf
const sampleConf = `# Sample launcher state
gridViewMode=true
sortMode="recent"
textCase="upper"
subtitleMode="hide"
rowDensity="compact"
gridColumns=5
autoDesktopCats=false
showUsageBadges=false
launcherWide=true
usage.org.gnome.nautilus=7,1795208282487
usage.firefox=14,1795272000000
usage.calculator 2+2=4=5,1700000000
`;

parseKeyValueText(sampleConf);

if (root.gridViewMode !== true) throw new Error("gridViewMode parse failed");
if (root.sortMode !== "recent") throw new Error("sortMode parse failed");
if (root.textCase !== "upper") throw new Error("textCase parse failed");
if (root.subtitleMode !== "hide") throw new Error("subtitleMode parse failed");
if (root.rowDensity !== "compact") throw new Error("rowDensity parse failed");
if (root.gridColumns !== 5) throw new Error("gridColumns parse failed");
if (root.autoDesktopCats !== false) throw new Error("autoDesktopCats parse failed");
if (root.showUsageBadges !== false) throw new Error("showUsageBadges parse failed");
if (root.launcherWide !== true) throw new Error("launcherWide parse failed");
if (!root.usageMap["org.gnome.nautilus"] || root.usageMap["org.gnome.nautilus"].count !== 7) throw new Error("usageMap nautilus count failed");
if (!root.usageMap["firefox"] || root.usageMap["firefox"].lastUsed !== 1795272000000) throw new Error("usageMap firefox lastUsed failed");
if (!root.usageMap["calculator 2+2=4"] || root.usageMap["calculator 2+2=4"].count !== 5) throw new Error("usageMap calculator 2+2=4 failed");

// 2. Test saving to key-value conf
saveLauncherState();
if (savedText.includes("JSON")) throw new Error("savedText contained JSON");
if (!savedText.includes("usage.org.gnome.nautilus=7,1795208282487")) throw new Error("usage serialization failed");
if (!savedText.includes("gridViewMode=true")) throw new Error("scalar serialization failed");

// 3. Test legacy JSON migration
const legacyJson = JSON.stringify({{
    gridViewMode: false,
    sortMode: "alpha",
    textCase: "normal",
    usage: {{ "kitty": {{ count: 42, lastUsed: 123456789 }} }}
}});

const legacyStateFile = {{ text: () => legacyJson }};
const legacyConfigStateFile = {{ text: () => "" }};

function tryMigrateLegacyJson() {{
{migrate_match.group(1)}
}}

const migrated = tryMigrateLegacyJson();
if (!migrated) throw new Error("legacy migration returned false");
if (root.sortMode !== "alpha") throw new Error("legacy migration failed to set sortMode");
if (!root.usageMap["kitty"] || root.usageMap["kitty"].count !== 42) throw new Error("legacy migration failed to map usage");

process.stdout.write("OK");
"""
        res = subprocess.run(["node", "-e", test_js], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"node execution failed: {res.stderr}")
        self.assertEqual(res.stdout, "OK")


class TestStatePathIsolationAndJsonElimination(unittest.TestCase):
    """Unit tests verifying state relocation and JSON elimination across all components."""

    def test_01_lockscreen_state_path_relocated(self):
        """Lockscreen state must be stored in stateDir + /lockscreen/state."""
        lock_path = PROJECT_ROOT / "lockscreen" / "LockScreen.qml"
        lock_content = lock_path.read_text(encoding="utf-8")
        self.assertIn(
            'readonly property string lockStateDir: stateDir + "/lockscreen"',
            lock_content,
            "LockScreen.qml lockStateDir must use stateDir"
        )
        self.assertIn(
            'readonly property string lockStatePath: lockStateDir + "/state"',
            lock_content,
            "LockScreen.qml lockStatePath must use lockStateDir"
        )

        qs_path = PROJECT_ROOT / "widgets" / "QuickSettings.qml"
        qs_content = qs_path.read_text(encoding="utf-8")
        self.assertIn(
            'readonly property string lockStatePath: stateDir + "/lockscreen/state"',
            qs_content,
            "QuickSettings.qml lockStatePath must point to stateDir"
        )

    def test_02_quicknotes_state_paths_relocated_and_no_json_save(self):
        """QuickNotes must store notes and tasks in .conf files under stateDir without JSON save."""
        qn_path = PROJECT_ROOT / "widgets" / "QuickNotes.qml"
        qn_content = qn_path.read_text(encoding="utf-8")
        self.assertIn(
            'readonly property string notesFilePath: stateDir + "/notes.conf"',
            qn_content,
            "QuickNotes notesFilePath must be stateDir + /notes.conf"
        )
        self.assertIn(
            'readonly property string tasksFilePath: stateDir + "/tasks.conf"',
            qn_content,
            "QuickNotes tasksFilePath must be stateDir + /tasks.conf"
        )

        save_notes = re.search(r'function saveNotesNow\(\)\s*\{([\s\S]*?)\n    \}', qn_content)
        self.assertIsNotNone(save_notes, "saveNotesNow function not found")
        self.assertNotIn("JSON.stringify", save_notes.group(1), "saveNotesNow must not use JSON.stringify")

        save_tasks = re.search(r'function saveTasksNow\(\)\s*\{([\s\S]*?)\n    \}', qn_content)
        self.assertIsNotNone(save_tasks, "saveTasksNow function not found")
        self.assertNotIn("JSON.stringify", save_tasks.group(1), "saveTasksNow must not use JSON.stringify")

    def test_03_session_py_has_no_json_import(self):
        """session.py must not have dead import json."""
        session_path = PROJECT_ROOT / "scripts" / "session.py"
        session_content = session_path.read_text(encoding="utf-8")
        self.assertNotIn("import json", session_content, "session.py still has import json")

    def test_04_quicknotes_escaping_lossless_roundtrip(self):
        """Verify notes and tasks with backslashes and escaped newlines roundtrip losslessly."""
        import subprocess

        qn_path = PROJECT_ROOT / "widgets" / "QuickNotes.qml"
        qn_content = qn_path.read_text(encoding="utf-8")

        # Verify single-pass unescaping regex is present in QuickNotes.qml
        self.assertIn(
            r'v.replace(/\\([\\n])/g, function(_, ch) { return ch === "n" ? "\n" : "\\"; })',
            qn_content,
            "loadNotes must use single-pass regex to unescape content losslessly"
        )
        self.assertIn(
            r'.replace(/\\([\\n])/g, function(_, ch) { return ch === "n" ? "\n" : "\\"; })',
            qn_content,
            "loadTasks must use single-pass regex to unescape task text losslessly"
        )

        test_cases = [
            r"C:\notes",
            r'printf("\n")',
            r"/\n/g",
            "line1\nline2\nline3",
            r'C:\notes\file.txt' + "\n" + r'code: printf("hello\nworld");',
            "trailing backslash \\",
            "multiple backslashes \\\\\\\\",
            r"task with pipe | and backslash \ and \n",
        ]

        test_js = f"""
        const testCases = {repr(test_cases)};

        function saveNote(content) {{
            return (content || "").replace(/\\\\/g, "\\\\\\\\").replace(/\\n/g, "\\\\n");
        }}
        function loadNote(raw) {{
            return raw.replace(/\\\\([\\\\n])/g, function(_, ch) {{ return ch === "n" ? "\\n" : "\\\\"; }});
        }}

        function saveTask(text) {{
            let textStr = (text || "").replace(/\\\\/g, "\\\\\\\\").replace(/\\n/g, "\\\\n");
            return "task.1=0|normal|123456789|" + textStr;
        }}
        function loadTask(line) {{
            let parts = line.split("|");
            return parts.slice(3).join("|").replace(/\\\\([\\\\n])/g, function(_, ch) {{ return ch === "n" ? "\\n" : "\\\\"; }});
        }}

        for (const tc of testCases) {{
            const noteSaved = saveNote(tc);
            const noteLoaded = loadNote(noteSaved);
            if (noteLoaded !== tc) {{
                throw new Error("Note roundtrip failed for: " + JSON.stringify(tc) + " got: " + JSON.stringify(noteLoaded));
            }}

            const taskSaved = saveTask(tc);
            const taskLoaded = loadTask(taskSaved);
            if (taskLoaded !== tc) {{
                throw new Error("Task roundtrip failed for: " + JSON.stringify(tc) + " got: " + JSON.stringify(taskLoaded));
            }}
        }}

        process.stdout.write("OK");
        """
        res = subprocess.run(["node", "-e", test_js], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"Roundtrip node execution failed: {res.stderr}")
        self.assertEqual(res.stdout, "OK")

    def test_05_quicknotes_empty_task_list_persistence(self):
        """Verify loadTasks preserves empty task list when file contains valid task header."""
        qn_path = PROJECT_ROOT / "widgets" / "QuickNotes.qml"
        qn_content = qn_path.read_text(encoding="utf-8")
        self.assertIn(
            'if (count > 0 || raw.includes("# Quickshell Tasks"))',
            qn_content,
            "loadTasks must not resurrect default tasks if raw contains '# Quickshell Tasks' header"
        )

    def test_06_app_launcher_app_key_sanitization_and_parsing(self):
        """Verify AppLauncher appKey sanitizes '=' and parseKeyValueText parses keys containing '='."""
        al_path = PROJECT_ROOT / "widgets" / "AppLauncher.qml"
        al_content = al_path.read_text(encoding="utf-8")
        self.assertIn(
            '.replace(/=/g, "_")',
            al_content,
            "appKey must sanitize '=' to '_'"
        )
        self.assertIn(
            'line.startsWith("usage.") ? line.lastIndexOf("=") : line.indexOf("=")',
            al_content,
            "parseKeyValueText must use lastIndexOf('=') for usage lines to avoid truncating keys with '='"
        )


if __name__ == "__main__":
    print("========================================================================")
    print(" Running Settings Schema & Lossless Persistence Tests...")
    print(f" Target: {PROJECT_ROOT}")
    print("========================================================================")
    suite = unittest.TestSuite()
    suite.addTest(unittest.defaultTestLoader.loadTestsFromTestCase(TestSettingsSchemaParity))
    suite.addTest(unittest.defaultTestLoader.loadTestsFromTestCase(TestQuickSettingsCustomization))
    suite.addTest(unittest.defaultTestLoader.loadTestsFromTestCase(TestSaveRoundtripLossless))
    suite.addTest(unittest.defaultTestLoader.loadTestsFromTestCase(TestPresetServiceResilience))
    suite.addTest(unittest.defaultTestLoader.loadTestsFromTestCase(TestAppLauncherStateAndSerialization))
    suite.addTest(unittest.defaultTestLoader.loadTestsFromTestCase(TestStatePathIsolationAndJsonElimination))

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
