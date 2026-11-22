#!/usr/bin/env bash
# ==============================================================================
# tests/test_lint.sh: Static QML Syntax & Import Linter
# ==============================================================================
# Verifies all QML files for:
#   1. QML syntax errors (unmatched braces, invalid tokens, ID duplications)
#   2. Missing module imports and undeclared singletons in qmldir
# Exits 0 on success, non-zero if fatal syntax or import defects are discovered.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Toolchain and module paths (allow environment overrides)
QMLLINT="${QMLLINT:-/nix/store/0jnxd2cwya279hyr7hmklbpdb0298lg1-qtdeclarative-6.12.0/bin/qmllint}"
QS_QML="${QS_QML:-/nix/store/6hwxy68b99xz9yb43n8wycy8lxsplw53-quickshell-0.3.2/lib/qt-6/qml}"
QT_QML="${QT_QML:-/nix/store/0jnxd2cwya279hyr7hmklbpdb0298lg1-qtdeclarative-6.12.0/lib/qt-6/qml}"

if [[ ! -x "$QMLLINT" ]]; then
    echo "ERROR: qmllint binary not found or not executable at: $QMLLINT" >&2
    exit 2
fi

# Collect target files
if [[ $# -gt 0 ]]; then
    FILES=("$@")
else
    mapfile -t FILES < <(find "$PROJECT_DIR" -type f -name "*.qml" | sort)
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "ERROR: No QML files found to validate." >&2
    exit 2
fi

echo "========================================================================"
echo " Running QML Static Linting across ${#FILES[@]} file(s)..."
echo " qmllint: $QMLLINT"
echo "========================================================================"

# Run qmllint with json output and evaluate results
python3 - << 'EOF' "$QMLLINT" "$QS_QML" "$QT_QML" "$PROJECT_DIR" "${FILES[@]}"
import sys
import json
import subprocess

qmllint_bin = sys.argv[1]
qs_qml = sys.argv[2]
qt_qml = sys.argv[3]
project_dir = sys.argv[4]
files = sys.argv[5:]

cmd = [
    qmllint_bin,
    "-I", qs_qml,
    "-I", qt_qml,
    "-I", project_dir,
    "--json", "-"
] + files

proc = subprocess.run(cmd, capture_output=True, text=True)

if not proc.stdout.strip():
    if proc.returncode != 0:
        print(f"FATAL: qmllint failed to run (exit {proc.returncode}):\n{proc.stderr}", file=sys.stderr)
        sys.exit(1)
    else:
        print("No lint output received.")
        sys.exit(0)

try:
    data = json.loads(proc.stdout)
except Exception as e:
    print(f"FATAL: Failed to parse qmllint JSON output: {e}\nRaw output:\n{proc.stdout}", file=sys.stderr)
    sys.exit(1)

file_entries = data.get("files", [])
syntax_errors = []
import_errors = []
other_criticals = []
advisory_count = 0

for fe in file_entries:
    filename = fe.get("filename", "")
    rel_path = filename.replace(project_dir + "/", "")
    warnings = fe.get("warnings", [])
    
    for w in warnings:
        wid = w.get("id", "")
        line = w.get("line")
        col = w.get("column")
        msg = w.get("message", "")
        wtype = w.get("type", "warning")
        location = f"{rel_path}:{line}:{col}" if line is not None else rel_path

        # 1. Syntax errors
        if wid.startswith("syntax") or "syntax" in msg.lower() or "expected token" in msg.lower():
            syntax_errors.append(f"  [SYNTAX] {location} - {msg}")
        # 2. Module / import / singleton registration errors
        elif wid == "import" or ("import" in msg.lower() and "unused import" not in msg.lower()):
            import_errors.append(f"  [IMPORT] {location} - {msg}")
        elif wtype in ("error", "critical"):
            other_criticals.append(f"  [ERROR]  {location} - {msg} (rule: {wid})")
        else:
            advisory_count += 1

total_fatals = len(syntax_errors) + len(import_errors) + len(other_criticals)

if total_fatals > 0:
    print(f"\n[FAIL] Static QML linting failed with {total_fatals} fatal defect(s):")
    if syntax_errors:
        print(f"\n Syntax Errors ({len(syntax_errors)}):")
        for err in syntax_errors:
            print(err)
    if import_errors:
        print(f"\n Import & Registration Errors ({len(import_errors)}):")
        for err in import_errors:
            print(err)
    if other_criticals:
        print(f"\n Other Critical Defects ({len(other_criticals)}):")
        for err in other_criticals:
            print(err)
    print(f"\nChecked {len(files)} file(s). Found {total_fatals} fatal defect(s) and {advisory_count} advisory warning(s).")
    sys.exit(1)
else:
    print(f"\n[PASS] All {len(files)} QML file(s) passed static syntax and import checks.")
    print(f"       Zero syntax errors, zero missing module / import defects.")
    print(f"       ({advisory_count} non-fatal advisory warnings noted)")
    sys.exit(0)
EOF
