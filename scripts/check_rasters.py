from PIL import Image
import os

BASE = "/mnt/d/projects/26-0523_maps/maps/rastr"

groups = {
    "=== 44-12: 1:1 000 000 Lage West ===": [
        ("44-12-01", f"{BASE}/44-12/44-12-01 1M Lage West.tif"),
        ("44-12-02", f"{BASE}/44-12/44-12-02 1M Lage West.tif"),
        ("44-12-06", f"{BASE}/44-12/44-12-06 1M Lage West-2.tif"),
        ("44-12-14", f"{BASE}/44-12/44-12-14 1M Lage West.tif"),
        ("44-12-20", f"{BASE}/44-12/44-12-20 1M Lage West.tif"),
    ],
    "=== 44-12: 1:100 000 (Aachen-Monschau / Lothringen) ===": [
        ("44-12-02 Aachen", f"{BASE}/44-12/44-12-02 100K Aachen-Monschau.tif"),
        ("44-12-03 Aachen", f"{BASE}/44-12/44-12-03 100K Aachen-Monschau.tif"),
        ("44-12-05 Aachen", f"{BASE}/44-12/44-12-05 100K Aachen-Monschau-1.tif"),
        ("44-12-04 Lothringen", f"{BASE}/44-12/44-12-04 100K Lothringen-1.tif"),
        ("44-12-06 Lothringen", f"{BASE}/44-12/44-12-06 100K Lothringen-1.tif"),
        ("44-12-08 Lothringen", f"{BASE}/44-12/44-12-08 100K Lothringen.tif"),
        ("44-12-10 Lothringen", f"{BASE}/44-12/44-12-10 100K Lothringen.tif"),
    ],
    "=== 44-12: 1:80 000 Lorient ===": [
        ("44-12-09 Lorient", f"{BASE}/44-12/44-12-09 80K Lorient.tif"),
    ],
    "=== 1942: Lage West PNG ===": [
        ("42-Aug-09 PNG",  f"{BASE}/1942/1942/August/LageWest 9-Aug-1942.png"),
        ("42-Aug-11 PNG",  f"{BASE}/1942/1942/August/Lage West  11-Aug-1942.png"),
        ("42-Sep-12 PNG",  f"{BASE}/1942/1942/September/LageWest 12 Sep 1942.png"),
    ],
    "=== Lage Margarethe (Hungary 1944) ===": [
        ("Margarethe 27.03", f"{BASE}/Lage Margarethe (Hungary 44-03 and 44-04)/Lage Margarethe (Hungary 44-03 and 44-04)/Lage Margarethe - 270344.jpg"),
        ("Margarethe 09.04", f"{BASE}/Lage Margarethe (Hungary 44-03 and 44-04)/Lage Margarethe (Hungary 44-03 and 44-04)/Lage Margarethe - 090444.jpg"),
    ],
}

HDR = f"{'Файл':<22} {'W':>6} {'H':>6} {'mpx':>5} {'DPI':>5} {'Режим':<8} {'МБ':>6}"
SEP = "-" * 66

for group_name, files in groups.items():
    print(f"\n{group_name}")
    print(HDR)
    print(SEP)
    for name, path in files:
        if not os.path.exists(path):
            print(f"{name:<22}  НЕ НАЙДЕН")
            continue
        try:
            img = Image.open(path)
            w, h = img.size
            mpx = round(w * h / 1_000_000, 1)
            dpi_raw = img.info.get("dpi")
            dpi = round(dpi_raw[0]) if dpi_raw else "—"
            size_mb = round(os.path.getsize(path) / 1024 / 1024, 1)
            print(f"{name:<22} {w:>6} {h:>6} {mpx:>5} {str(dpi):>5} {img.mode:<8} {size_mb:>6}")
        except Exception as e:
            print(f"{name:<22}  ОШИБКА: {e}")
