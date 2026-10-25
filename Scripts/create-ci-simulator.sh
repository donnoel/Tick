#!/bin/bash
set -euo pipefail

runtime_version="${1:-26.5}"
simulator_id="$(python3 - "$runtime_version" <<'PY'
import json
import subprocess
import sys

runtime_version = sys.argv[1]
runtimes = json.loads(
    subprocess.check_output(["xcrun", "simctl", "list", "runtimes", "--json"])
)["runtimes"]
matching_runtimes = [
    runtime for runtime in runtimes
    if runtime.get("platform") == "iOS"
    and runtime.get("isAvailable")
    and runtime.get("version") == runtime_version
]
if not matching_runtimes:
    raise SystemExit(f"Required iOS {runtime_version} simulator runtime is unavailable.")
runtime_identifier = matching_runtimes[-1]["identifier"]

device_types = json.loads(
    subprocess.check_output(["xcrun", "simctl", "list", "devicetypes", "--json"])
)["devicetypes"]
iphone_types = [
    device_type for device_type in device_types
    if device_type.get("name", "").startswith("iPhone")
]
if not iphone_types:
    raise SystemExit("No iPhone simulator device types are installed.")

preferred_names = [
    "iPhone 17 Pro",
    "iPhone 17",
    "iPhone 16 Pro",
    "iPhone 16",
    "iPhone SE (3rd generation)",
]
selected_device = next(
    (
        device_type for preferred_name in preferred_names
        for device_type in iphone_types
        if device_type.get("name") == preferred_name
    ),
    iphone_types[-1],
)
print(subprocess.check_output(
    [
        "xcrun", "simctl", "create", "CI iPhone",
        selected_device["identifier"], runtime_identifier,
    ],
    text=True,
).strip())
PY
)"

xcrun simctl boot "$simulator_id" >&2 || true
xcrun simctl bootstatus "$simulator_id" -b >&2
printf '%s\n' "$simulator_id"
