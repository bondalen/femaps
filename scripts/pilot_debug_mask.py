import json
import cv2
import geopandas as gpd
import numpy as np
import psycopg2
import rasterio
from rasterio.features import rasterize
from rasterio.windows import from_bounds
from shapely.geometry import shape

RASTER = "/mnt/d/projects/26-0523_maps/maps/georef/44-12-01_1M_Lage_West_4326.tif"
conn = psycopg2.connect(
    host="localhost", port=5434, dbname="maps_db",
    user="maps_user", password="maps_pass",
)
cur = conn.cursor()
cur.execute("SELECT ST_AsGeoJSON(geom) FROM railways WHERE id=1")
ref = gpd.GeoDataFrame(
    geometry=[shape(json.loads(cur.fetchone()[0]))], crs="EPSG:4326"
)
conn.close()

g = ref.geometry.iloc[0]
bounds = (g.bounds[0] - 0.04, g.bounds[1] - 0.04, g.bounds[2] + 0.04, g.bounds[3] + 0.04)

with rasterio.open(RASTER) as src:
    window = from_bounds(*bounds, transform=src.transform).round_offsets().round_lengths()
    transform = src.window_transform(window)
    rgb = np.moveaxis(np.stack([src.read(i, window=window) for i in (1, 2, 3)]), 0, -1)

hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
mask = cv2.inRange(hsv, np.array([8, 20, 65]), np.array([58, 210, 240]))
corridor = (
    gpd.GeoSeries(ref.geometry, crs=ref.crs)
    .to_crs(3857)
    .buffer(400)
    .to_crs(4326)
    .iloc[0]
)
cr = rasterize([(corridor, 1)], out_shape=mask.shape, transform=transform, fill=0, dtype=np.uint8)
mask2 = cv2.bitwise_and(mask, mask, mask=cr)
print("mask px", int((mask > 0).sum()))
print("corridor px", int((cr > 0).sum()))
print("both px", int((mask2 > 0).sum()))
