import json
import psycopg2
import numpy as np
import cv2
from shapely.geometry import shape
import geopandas as gpd
import rasterio
from skimage.morphology import skeletonize
from pilot_rail_color_mask import (
    read_clip_highres, load_reference_line, orange_score_map, score_to_mask,
    apply_corridor_mask, refine_mask, prune_skeleton_spurs, RASTER_PATH, BUFFER_DEG,
)

reference = load_reference_line(1)
ref_geom = reference.geometry.iloc[0]
b = ref_geom.bounds
clip_bounds = (b[0]-BUFFER_DEG, b[1]-BUFFER_DEG, b[2]+BUFFER_DEG, b[3]+BUFFER_DEG)
rgb, transform = read_clip_highres(RASTER_PATH, clip_bounds)
score = orange_score_map(rgb)
mask = score_to_mask(score)
mask = apply_corridor_mask(mask, reference, transform)
print("mask px", int((mask>0).sum()))
mask2 = refine_mask(mask)
print("refined px", int((mask2>0).sum()))
skel = skeletonize(mask2 > 0)
print("skel px", int(skel.sum()))
skel2 = prune_skeleton_spurs(skel, 22)
print("pruned skel px", int(skel2.sum()))
