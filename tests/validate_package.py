from __future__ import annotations
import json
from pathlib import Path, PurePosixPath
import re
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as package:
    names = set(package.namelist())
    assert "extension.json" in names, "Manifest must be at ZIP root"
    assert Path(sys.argv[1]).stat().st_size <= 20 * 1024 * 1024, "Theme exceeds archive limit"
    for item in package.infolist():
        name = PurePosixPath(item.filename)
        assert not name.is_absolute() and ".." not in name.parts, item.filename
        assert name.suffix in {".json", ".qml", ".js", ".png"} or name.name == "qmldir", item.filename
    manifest = json.loads(package.read("extension.json"))
    assert manifest["id"] == "nekotune.theme-starcape"
    assert manifest["type"] == "theme" and "library" not in manifest and "main" not in manifest
    assert re.fullmatch(r"\d+\.\d+\.\d+", manifest["version"]), "Invalid version"
    themes = manifest["contributes"]["themes"]
    assert themes, "No themes declared"
    for theme in themes:
        for name in theme.get("ui", {}).values():
            assert isinstance(name, str) and name in names, f"Missing UI: {name}"
    assert "assets/artwork-default.png" in names, "Default artwork missing"
    assert not package.testzip(), "Corrupt ZIP entry"
print("Theme manifest, QML entry points, resources and ZIP layout passed")
