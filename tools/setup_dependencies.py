#!/usr/bin/env python3
"""Install pinned third-party Godot addons used by Garasugoshi. Setup-time only."""
from pathlib import Path
from urllib.request import Request, urlopen
from zipfile import ZipFile
from io import BytesIO
import shutil

ROOT = Path(__file__).resolve().parents[1]
ADDONS = ROOT / "addons"
DEPS = [
    {"name":"godot-vrm","commit":"651205484c35f5cd7ba56475ff636e10db8ad674","url":"https://github.com/V-Sekai/godot-vrm/archive/651205484c35f5cd7ba56475ff636e10db8ad674.zip","dest":ADDONS / "vrm"},
    {"name":"Godot-MToon-Shader","commit":"268c0d3b19c0885698b7bd39e21a16c9c2af448f","url":"https://github.com/V-Sekai/Godot-MToon-Shader/archive/268c0d3b19c0885698b7bd39e21a16c9c2af448f.zip","dest":ADDONS / "Godot-MToon-Shader"},
]

def fetch_zip(url: str) -> ZipFile:
    req = Request(url, headers={"User-Agent":"garasugoshi-setup/1"})
    return ZipFile(BytesIO(urlopen(req, timeout=60).read()))

def install(dep: dict) -> None:
    print(f"Installing {dep['name']} @ {dep['commit']} …")
    zf = fetch_zip(dep["url"])
    roots = {n.split('/',1)[0] for n in zf.namelist() if '/' in n}
    if len(roots) != 1:
        raise SystemExit(f"Unexpected archive layout for {dep['name']}")
    archive_root = next(iter(roots))
    dest: Path = dep["dest"]
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True, exist_ok=True)
    prefix = archive_root + "/"
    for info in zf.infolist():
        if not info.filename.startswith(prefix):
            continue
        rel = info.filename[len(prefix):]
        if not rel or rel.endswith('/'):
            continue
        target = (dest / rel).resolve()
        if dest.resolve() not in target.parents:
            raise SystemExit("Unsafe path in dependency archive")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(zf.read(info))
    print(f"OK: {dest.relative_to(ROOT)}")

ADDONS.mkdir(parents=True, exist_ok=True)
for dep in DEPS:
    install(dep)
print("Dependencies ready.")
