"""Generate the EasyFace project for Number Park and optionally compile it.

Project layout follows sf-yuzifu/Monika (GPL-3.0): one full-screen Lua widget
(Shape 34) pointing at app/_lua/<name>/<name>.lua. Band 11 uses the Band 10
package byte-for-byte, so one band10 build covers both.
"""
import argparse
import json
import shutil
import struct
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
NAME = "numberpark"
TITLE = "数字乐园"

DEVICES = {
    "band10": {
        "width": 212, "height": 520, "deviceType": 466,
        "fonts": ["MiSans-Demibold", "misansw_demibold", "MiSans-Medium", "MiSans-Regular"],
        "layout": {
            "timeY": 28, "timeSize": 56,
            "capY": 118, "capSize": 22,
            "stepY": 148, "stepSize": 52,
            "ballY": 216, "ballSize": 170,
            "nameY": 390, "nameSize": 28,
            "barY": 436, "barW": 180, "barH": 16,
            "nextY": 462, "nextSize": 20,
        },
    },
}
ALIASES = {"band11": "band10"}


def lua(value):
    if isinstance(value, dict):
        return "{" + ",".join(f"[{json.dumps(k)}]={lua(v)}" for k, v in value.items()) + "}"
    if isinstance(value, list):
        return "{" + ",".join(map(lua, value)) + "}"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    return str(value)


def preview(cfg, path):
    w, h = cfg["width"], cfg["height"]
    lay = cfg["layout"]
    im = Image.new("RGB", (w, h), "black")
    d = ImageDraw.Draw(im)
    im.paste(Image.open(ROOT / "src/img/c1.png").convert("RGB"), ((w - lay["ballSize"]) // 2, lay["ballY"]))
    bx = (w - lay["barW"]) // 2
    d.rounded_rectangle([bx, lay["barY"], bx + lay["barW"], lay["barY"] + lay["barH"]], radius=8, fill="#333333")
    d.rounded_rectangle([bx, lay["barY"], bx + lay["barW"] // 3, lay["barY"] + lay["barH"]], radius=8, fill="#4aa3ff")
    im.save(path)


def patch_metadata(path, face_id, version):
    data = bytearray(path.read_bytes())
    if len(data) < 168 or data[:4] != b"\x5a\xa5\x34\x12":
        raise ValueError("Unexpected Gen2 package header")
    data[40:58] = face_id.encode("ascii").ljust(18, b"\0")
    struct.pack_into("<I", data, 4, version)
    path.write_bytes(data)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--compiler", type=Path, help="Path to EasyFace Compiler.exe")
    ap.add_argument("--id", default="886611250001", help="12-digit watchface id")
    ap.add_argument("--version", type=int, default=1)
    args = ap.parse_args()

    source = (ROOT / "src/main.lua").read_text(encoding="utf-8")
    for target, cfg in DEVICES.items():
        out = ROOT / "build" / target
        if out.exists():
            shutil.rmtree(out)
        app = out / "app/_lua" / NAME
        app.mkdir(parents=True)
        (out / "images").mkdir()
        (out / "output").mkdir()
        for png in (ROOT / "src/img").glob("*.png"):
            shutil.copyfile(png, app / png.name)
        (app / f"{NAME}.lua").write_text("local DEVICE = " + lua(cfg) + "\n" + source, encoding="utf-8")
        preview(cfg, out / "preview.png")
        shutil.copyfile(out / "preview.png", out / "images/preview.png")

        project = ET.Element("FaceProject", DeviceType=str(cfg["deviceType"]))
        screen = ET.SubElement(project, "Screen", Title=TITLE, Bitmap="preview.png")
        ET.SubElement(screen, "Widget", Shape="34", Name=f"app__lua%2F{NAME}%2F{NAME}.lua", X="0", Y="0",
                      Width=str(cfg["width"]), Height=str(cfg["height"]), Alpha="0", Visible_Src="0")
        fprj = out / f"{NAME}.fprj"
        ET.ElementTree(project).write(fprj, encoding="utf-16", xml_declaration=True)
        print(f"{target}: {fprj}")

        if args.compiler:
            staging = out / "compiled"
            staging.mkdir()
            face = staging / f"{NAME}-{target}.face"
            subprocess.run([str(args.compiler.resolve()), "-b", str(fprj), str(staging), face.name, "252661004"], check=True)
            if not face.is_file():
                raise RuntimeError("Compiler did not produce a package")
            patch_metadata(face, args.id, args.version)
            dist = ROOT / "dist"
            dist.mkdir(exist_ok=True)
            shutil.copyfile(face, dist / face.name)
            for alias, base in ALIASES.items():
                if base == target:
                    shutil.copyfile(face, dist / f"{NAME}-{alias}.face")


if __name__ == "__main__":
    main()
