#!/usr/bin/env python3
"""Assemble the Pelican egg from install.sh so the two never drift apart.

Usage: python3 egg/build-egg.py ghcr.io/<your-org>/reclaimer-wine:latest
Writes egg/egg-project-reclaimer.yaml next to this script.
"""
import pathlib
import sys
from datetime import datetime, timezone

import yaml

HERE = pathlib.Path(__file__).resolve().parent
IMAGE = sys.argv[1] if len(sys.argv) > 1 else "ghcr.io/YOUR-ORG/reclaimer-wine:latest"


class Literal(str):
    pass


yaml.add_representer(
    Literal, lambda d, s: d.represent_scalar("tag:yaml.org,2002:str", s, style="|")
)


def var(sort, name, env, default, desc, rules, viewable=True, editable=True):
    return {
        "sort": sort,
        "name": name,
        "description": desc,
        "env_variable": env,
        "default_value": default,
        "user_viewable": viewable,
        "user_editable": editable,
        "rules": rules,
    }


egg = {
    "_comment": "Project Reclaimer dedicated server on Pelican (custom Wine image)",
    "meta": {"version": "PLCN_v3", "update_url": None},
    "exported_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S+00:00"),
    "name": "Project Reclaimer",
    "author": "admin@localhost",
    "uuid": "0e7c60b1-d52d-43f8-83d3-ee659b44700b",
    "description": (
        "Project Reclaimer (Halo 3) dedicated server under Wine. One game server "
        "per panel server, on its default allocation (UDP). Upload Halo 3's files "
        "from your own MCC install into game/ before the first start."
    ),
    "tags": ["halo", "wine"],
    "features": [],
    "docker_images": {"Reclaimer Wine": IMAGE},
    "file_denylist": [],
    "startup_commands": {"Default": "wine project-reclaimer.exe dedicated"},
    "config": {
        "files": {
            "dedicated.toml": {
                "parser": "file",
                "find": {
                    "name = ": 'name = "{{server.environment.SERVER_NAME}}"',
                    "port = ": "port = {{server.allocations.default.port}}",
                },
            }
        },
        "startup": {"done": "Hole punching ready"},
        "logs": {},
        "stop": "^C",
    },
    "scripts": {
        "installation": {
            "script": Literal((HERE / "install.sh").read_text()),
            "container": "ghcr.io/pelican-eggs/installers:debian",
            "entrypoint": "bash",
        }
    },
    "variables": [
        var(1, "Server Name", "SERVER_NAME", "Reclaimer",
            "Shown in the Server Browser. Up to 48 characters, no double quotes or backslashes.",
            ["required", "string", "max:48", 'regex:/^[^"\\\\]+$/']),
        var(2, "Host Name", "RECLAIMER_DEDICATED_HOST_NAME", "",
            "Shown under the server's name in the browser and lobby. Empty uses dedicated.toml.",
            ["nullable", "string", "max:64"]),
        var(3, "Admin Player IDs", "RECLAIMER_DEDICATED_ADMINS", "",
            "64-character player IDs (Settings > Online services in the client), separated by commas. Admins can kick and ban in game.",
            ["nullable", "string", "max:2000"]),
        var(4, "Max Players", "RECLAIMER_DEDICATED_MAX_PLAYERS", "16",
            "Players admitted at once, 1 to 127. Large games need about a CPU core and 0.6 to 0.9 GB.",
            ["required", "integer", "between:1,127"]),
        var(5, "Join Password", "RECLAIMER_DEDICATED_PASSWORD", "",
            "Leave empty for a public server.",
            ["nullable", "string", "max:128"]),
        var(6, "Release Tag", "RELEASE_TAG", "latest",
            "Project Reclaimer version the installer downloads, such as v0.9.13. Reinstall the server to apply. Players must run the same version.",
            ["required", "string", "max:40"]),
        var(7, "Virtual Display", "XVFB", "1",
            "1 runs Xvfb for Wine. Leave on unless you know the server runs without it.",
            ["required", "in:0,1"]),
        var(8, "Local Master", "RECLAIMER_DEDICATED_MASTER_ENABLED", "false",
            "Off: this server reports to the public masters only, so it needs just one allocation.",
            ["required", "in:false"], viewable=False, editable=False),
    ],
}

out = HERE / "egg-project-reclaimer.yaml"
out.write_text(yaml.dump(egg, sort_keys=False, allow_unicode=True, width=1000))
print(f"Wrote {out} with image {IMAGE}")
