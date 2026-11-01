"""Sample HSV along reference railway for threshold tuning."""
import json
import numpy as np
import cv2
import psycopg2
import rasterio
from rasterio.windows import from_bounds
from shapely.geometry import shape

RASTER = "/mnt/d/projects/26-0523_maps/maps/georef/44-12-01_1M_Lage_West_4326.tif"
conn = psycopg2.connect(
    host="localhost", port=5434, dbname="maps_db",
    user="maps_user", password="maps_pass",
)
cur = conn.cursor()
cur.execute("SELECT ST_AsGeoJSON(geom) FROM railways WHERE id=1")
geom = shape(json.loads(cur.fetchone()[0]))
conn.close()

minx, miny, maxx, maxy = geom.bounds
bounds = (minx - 0.04, miny - 0.04, maxx + 0.04, maxy + 0.04)

with rasterio.open(RASTER) as src:
    window = from_bounds(*bounds, transform=src.transform).round_offsets().round_lengths()
    transform = src.window_transform(window)
    rgb = np.moveaxis(np.stack([src.read(i, window=window) for i in (1, 2, 3)]), 0, -1)

samples = []
for dist in np.linspace(0, geom.length, 100):
    p = geom.interpolate(dist)
    col, row = ~transform * (p.x, p.y)
    col, row = int(round(col)), int(round(row))
    if 0 <= row < rgb.shape[0] and 0 <= col < rgb.shape[1]:
        samples.append(rgb[row, col])

samples = np.array(samples, dtype=np.uint8)
hsv = cv2.cvtColor(samples.reshape(-1, 1, 3), cv2.COLOR_RGB2HSV).reshape(-1, 3)
print("RGB  min", samples.min(0), "max", samples.max(0), "mean", samples.mean(0).astype(int))
print("HSV  min", hsv.min(0), "max", hsv.max(0), "mean", hsv.mean(0).astype(int))
print("HSV  p10", np.percentile(hsv, 10, axis=0).astype(int))
print("HSV  p90", np.percentile(hsv, 90, axis=0).astype(int))
