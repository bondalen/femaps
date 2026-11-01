#!/usr/bin/env python3
"""Pilot 6.4.1: orange railway color mask + centerline on Lage West 1:1M.

v2: RGB+HSV score, thick-band filter, spur pruning, weighted path, simplify.
"""

import json
import heapq
from collections import deque
from pathlib import Path

import cv2
import geopandas as gpd
import numpy as np
import psycopg2
import rasterio
from rasterio.enums import Resampling
from rasterio.features import rasterize
from rasterio.transform import rowcol, xy
from rasterio.warp import reproject
from shapely.geometry import LineString, Point, shape
from skimage.measure import label, regionprops
from skimage.morphology import remove_small_objects, skeletonize

PROJECT_ROOT = Path("/mnt/d/projects/26-0523_maps")
RASTER_PATH = PROJECT_ROOT / "maps/georef/44-12-01_1M_Lage_West_4326.tif"
OUTPUT_DIR = PROJECT_ROOT / "maps/pilot/color_mask"

PG = dict(
    host="localhost",
    port=5434,
    dbname="maps_db",
    user="maps_user",
    password="maps_pass",
)

REFERENCE_ID = 1
BUFFER_DEG = 0.04
CORRIDOR_M = 400
TARGET_RES_DEG = 0.00006
MIN_COMPONENT_PX = 60
MIN_LINE_LENGTH_M = 800
MIN_ELONGATION = 1.8
MIN_BAND_WIDTH_PX = 1.8
MAX_SPUR_PX = 18
SIMPLIFY_TOL_M = 280
CHAIKIN_ITERS = 2
SCORE_THRESHOLD = 0.46
CLOSE_KERNEL_PX = 13

HSV_LOWER = np.array([8, 40, 72], dtype=np.uint8)
HSV_UPPER = np.array([54, 195, 232], dtype=np.uint8)


def read_clip_highres(path: Path, bounds: tuple[float, float, float, float]):
    minx, miny, maxx, maxy = bounds
    width = max(256, int((maxx - minx) / TARGET_RES_DEG))
    height = max(256, int((maxy - miny) / TARGET_RES_DEG))
    dst_transform = rasterio.transform.from_bounds(minx, miny, maxx, maxy, width, height)

    rgb = np.zeros((height, width, 3), dtype=np.uint8)
    with rasterio.open(path) as src:
        for band in range(3):
            reproject(
                source=rasterio.band(src, band + 1),
                destination=rgb[:, :, band],
                src_transform=src.transform,
                src_crs=src.crs,
                dst_transform=dst_transform,
                dst_crs=src.crs,
                resampling=Resampling.bilinear,
            )
    return rgb, dst_transform


def load_reference_line(feature_id: int) -> gpd.GeoDataFrame:
    conn = psycopg2.connect(**PG)
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, rail_class, ST_AsGeoJSON(geom) FROM railways WHERE id = %s",
                (feature_id,),
            )
            row = cur.fetchone()
    finally:
        conn.close()
    if not row:
        raise RuntimeError(f"railways id={feature_id} not found")
    return gpd.GeoDataFrame(
        [{"id": row[0], "rail_class": row[1]}],
        geometry=[shape(json.loads(row[2]))],
        crs="EPSG:4326",
    )


def orange_score_map(rgb: np.ndarray) -> np.ndarray:
    """0..1 confidence: railway orange vs brown relief hatching."""
    r = rgb[:, :, 0].astype(np.float32)
    g = rgb[:, :, 1].astype(np.float32)
    b = rgb[:, :, 2].astype(np.float32)
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    h, s, v = hsv[:, :, 0], hsv[:, :, 1], hsv[:, :, 2]

    hsv_ok = cv2.inRange(hsv, HSV_LOWER, HSV_UPPER).astype(np.float32) / 255.0
    red_excess = np.clip((r - np.maximum(g, b)) / 255.0, 0.0, 1.0)
    order_ok = ((r > g) & (g > b + 5)).astype(np.float32)
    sat_ok = np.clip((s.astype(np.float32) - 30.0) / 120.0, 0.0, 1.0)

    score = 0.45 * hsv_ok + 0.30 * red_excess + 0.15 * order_ok + 0.10 * sat_ok
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    score[(gray < 35) | (gray > 245)] = 0.0
    return np.clip(score, 0.0, 1.0)


def score_to_mask(score: np.ndarray) -> np.ndarray:
    mask = (score >= SCORE_THRESHOLD).astype(np.uint8) * 255
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel, iterations=1)
    dist = cv2.distanceTransform(mask, cv2.DIST_L2, 5)
    mask[dist < MIN_BAND_WIDTH_PX] = 0
    return mask


def apply_corridor_mask(mask: np.ndarray, reference: gpd.GeoDataFrame, transform) -> np.ndarray:
    corridor_geom = (
        gpd.GeoSeries(reference.geometry, crs=reference.crs)
        .to_crs(3857)
        .buffer(CORRIDOR_M)
        .to_crs(4326)
        .iloc[0]
    )
    corridor = rasterize(
        [(corridor_geom, 255)],
        out_shape=mask.shape,
        transform=transform,
        fill=0,
        dtype=np.uint8,
    )
    return cv2.bitwise_and(mask, mask, mask=corridor)


def filter_elongated_components(binary: np.ndarray) -> np.ndarray:
    labeled = label(binary)
    keep = np.zeros_like(binary, dtype=bool)
    for region in regionprops(labeled):
        if region.area < MIN_COMPONENT_PX:
            continue
        major = getattr(region, "axis_major_length", region.major_axis_length)
        minor = max(getattr(region, "axis_minor_length", region.minor_axis_length), 1.0)
        if major / minor < MIN_ELONGATION:
            continue
        keep[labeled == region.label] = True
    return keep


def refine_mask(mask: np.ndarray) -> np.ndarray:
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    closed = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=2)
    wide = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (CLOSE_KERNEL_PX, CLOSE_KERNEL_PX))
    closed = cv2.morphologyEx(closed, cv2.MORPH_CLOSE, wide, iterations=1)
    binary = closed > 0
    binary = filter_elongated_components(binary)
    binary = remove_small_objects(binary, max_size=MIN_COMPONENT_PX - 1)
    return (binary.astype(np.uint8) * 255)


def prune_skeleton_spurs(skel: np.ndarray, max_spur: int) -> np.ndarray:
    skel = skel.copy()
    neighbors = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]

    def degree(x, y, nodes):
        return sum((x + dx, y + dy) in nodes for dx, dy in neighbors)

    changed = True
    while changed:
        changed = False
        ys, xs = np.where(skel)
        nodes = {(int(x), int(y)) for x, y in zip(xs, ys)}
        to_clear = set()
        for x, y in list(nodes):
            if degree(x, y, nodes) != 1:
                continue
            chain = [(x, y)]
            cx, cy = x, y
            prev = None
            while degree(cx, cy, nodes) <= 2:
                nbrs = [
                    (cx + dx, cy + dy)
                    for dx, dy in neighbors
                    if (cx + dx, cy + dy) in nodes and (cx + dx, cy + dy) != prev
                ]
                if not nbrs:
                    break
                nxt = nbrs[0]
                if len(chain) > 1 and degree(nxt[0], nxt[1], nodes) > 2:
                    break
                prev, (cx, cy) = (cx, cy), nxt
                chain.append((cx, cy))
                if len(chain) > max_spur + 5:
                    break
            if len(chain) <= max_spur:
                to_clear.update(chain)
                changed = True
        for x, y in to_clear:
            skel[y, x] = False
    return skel


def _path_from_skeleton(skel, score, transform, ref_geom, weighted: bool) -> LineString | None:
    coords_list = list(ref_geom.coords)
    if len(coords_list) < 2:
        return None

    start, end = coords_list[0], coords_list[-1]
    sr, sc = rowcol(transform, start[0], start[1])
    er, ec = rowcol(transform, end[0], end[1])

    ys, xs = np.where(skel)
    if len(xs) == 0:
        return None

    nodes = {(int(x), int(y)) for x, y in zip(xs, ys)}
    neighbors = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]

    def nearest_node(col, row):
        return min(nodes, key=lambda n: (n[0] - col) ** 2 + (n[1] - row) ** 2)

    src = nearest_node(int(sc), int(sr))
    dst = nearest_node(int(ec), int(er))
    if src == dst:
        return None

    if weighted:
        def step_cost(a, b):
            ax, ay = a
            bx, by = b
            move = 1.414 if ax != bx and ay != by else 1.0
            local = 0.5 * (score[ay, ax] + score[by, bx])
            return move * (1.8 - local)

        dist: dict[tuple[int, int], float] = {src: 0.0}
        prev: dict[tuple[int, int], tuple[int, int] | None] = {src: None}
        heap = [(0.0, src)]
        while heap:
            cur_d, cur = heapq.heappop(heap)
            if cur == dst:
                break
            if cur_d > dist.get(cur, float("inf")):
                continue
            x, y = cur
            for dx, dy in neighbors:
                nxt = (x + dx, y + dy)
                if nxt not in nodes:
                    continue
                nd = cur_d + step_cost(cur, nxt)
                if nd < dist.get(nxt, float("inf")):
                    dist[nxt] = nd
                    prev[nxt] = cur
                    heapq.heappush(heap, (nd, nxt))
    else:
        prev = {src: None}
        queue = deque([src])
        while queue:
            cur = queue.popleft()
            if cur == dst:
                break
            x, y = cur
            for dx, dy in neighbors:
                nxt = (x + dx, y + dy)
                if nxt in nodes and nxt not in prev:
                    prev[nxt] = cur
                    queue.append(nxt)

    if dst not in prev:
        return None

    chain = []
    cur = dst
    while cur is not None:
        chain.append(cur)
        cur = prev[cur]
    chain.reverse()
    if len(chain) < 2:
        return None
    return LineString([xy(transform, y, x) for x, y in chain])


def weighted_skeleton_path(
    skel: np.ndarray, score: np.ndarray, transform, ref_geom
) -> LineString | None:
    for sk in (skel, skeletonize(cv2.dilate(skel.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0)):
        for weighted in (True, False):
            line = _path_from_skeleton(sk, score, transform, ref_geom, weighted=weighted)
            if line is not None:
                return line
    return None


SNAP_STEP_M = 500
SNAP_RADIUS_PX = 38


def snap_line_to_orange_ridge(
    score: np.ndarray, mask: np.ndarray, transform, ref_geom, step_m: float = SNAP_STEP_M
) -> LineString:
    """Sample along approximate axis; snap each point to max orange score in window."""
    ref_m = gpd.GeoSeries([ref_geom], crs="EPSG:4326").to_crs(3857).iloc[0]
    length = ref_m.length
    steps = max(3, int(length / step_m))
    h, w = score.shape
    snapped: list[tuple[float, float]] = []

    for i in range(steps + 1):
        dist = length * i / steps
        p432 = (
            gpd.GeoSeries([ref_m.interpolate(dist)], crs=3857)
            .to_crs(4326)
            .iloc[0]
        )
        col, row = rowcol(transform, p432.x, p432.y)
        col, row = int(round(col)), int(round(row))

        r0, r1 = max(0, row - SNAP_RADIUS_PX), min(h, row + SNAP_RADIUS_PX + 1)
        c0, c1 = max(0, col - SNAP_RADIUS_PX), min(w, col + SNAP_RADIUS_PX + 1)
        patch_score = score[r0:r1, c0:c1].copy()
        patch_mask = mask[r0:r1, c0:c1] > 0
        if patch_score.size == 0:
            snapped.append((p432.x, p432.y))
            continue
        patch_score[~patch_mask] *= 0.35
        br, bc = np.unravel_index(int(np.argmax(patch_score)), patch_score.shape)
        snapped.append(xy(transform, r0 + br, c0 + bc))

    return LineString(snapped)


def extract_centerline(score, mask, skel, transform, ref_geom) -> LineString:
    """Prefer ridge snapping; fallback to skeleton graph path."""
    snapped = snap_line_to_orange_ridge(score, mask, transform, ref_geom)
    path = weighted_skeleton_path(skel, score, transform, ref_geom)
    if path is None:
        return snapped
    ref_m = gpd.GeoSeries([ref_geom], crs="EPSG:4326").to_crs(3857).iloc[0]
    candidates = [snapped, path]
    best = min(
        candidates,
        key=lambda g: mean_ref_offset_m(
            gpd.GeoSeries([g], crs=4326).to_crs(3857).iloc[0], ref_m
        ),
    )
    return best


def chaikin_smooth_m(line_m: LineString, iterations: int = 2) -> LineString:
    coords = list(line_m.coords)
    for _ in range(iterations):
        if len(coords) < 2:
            break
        smoothed = [coords[0]]
        for i in range(len(coords) - 1):
            x0, y0 = coords[i]
            x1, y1 = coords[i + 1]
            smoothed.append((0.75 * x0 + 0.25 * x1, 0.75 * y0 + 0.25 * y1))
            smoothed.append((0.25 * x0 + 0.75 * x1, 0.25 * y0 + 0.75 * y1))
        smoothed.append(coords[-1])
        coords = smoothed
    return LineString(coords)


def simplify_line_m(line: LineString, tol_m: float) -> LineString:
    gdf = gpd.GeoDataFrame(geometry=[line], crs="EPSG:4326").to_crs(3857)
    geom = chaikin_smooth_m(gdf.geometry.iloc[0], CHAIKIN_ITERS)
    simplified = geom.simplify(tol_m, preserve_topology=True)
    if simplified.geom_type == "MultiLineString":
        simplified = max(simplified.geoms, key=lambda g: g.length)
    return gpd.GeoDataFrame(geometry=[simplified], crs=3857).to_crs(4326).geometry.iloc[0]


def length_m(geom, crs="EPSG:4326") -> float:
    return float(gpd.GeoDataFrame(geometry=[geom], crs=crs).to_crs(3857).geometry.iloc[0].length)


def mean_ref_offset_m(extracted_m, ref_m) -> float:
    ref_pts = [Point(c) for c in ref_m.coords]
    return float(np.mean([extracted_m.distance(p) for p in ref_pts]))


def metrics_for_line(line: LineString, reference: gpd.GeoDataFrame) -> dict:
    ref_m = reference.to_crs(3857).geometry.iloc[0]
    line_m = gpd.GeoDataFrame(geometry=[line], crs="EPSG:4326").to_crs(3857).geometry.iloc[0]
    within_200m = float(
        np.mean([Point(c).distance(line_m) <= 200 for c in ref_m.coords]) * 100
    )
    return {
        "length_m": round(line_m.length, 1),
        "reference_length_m": round(ref_m.length, 1),
        "mean_ref_offset_m": round(mean_ref_offset_m(line_m, ref_m), 1),
        "hausdorff_m": round(line_m.hausdorff_distance(ref_m), 1),
        "ref_points_within_200m_pct": round(within_200m, 1),
        "vertex_count": len(line.coords),
    }


def draw_overlay(rgb, transform, reference, line, out_path):
    canvas = rgb.copy()
    ref = reference.geometry.iloc[0]

    def draw_line(geom, color, thickness=2):
        coords = list(geom.coords)
        for a, b in zip(coords, coords[1:]):
            r0, c0 = rowcol(transform, a[0], a[1])
            r1, c1 = rowcol(transform, b[0], b[1])
            cv2.line(canvas, (int(c0), int(r0)), (int(c1), int(r1)), color, thickness)

    draw_line(ref, (0, 255, 0), 2)
    draw_line(line, (255, 0, 0), 2)
    cv2.imwrite(str(out_path), cv2.cvtColor(canvas, cv2.COLOR_RGB2BGR))


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    reference = load_reference_line(REFERENCE_ID)
    ref_geom = reference.geometry.iloc[0]
    minx, miny, maxx, maxy = ref_geom.bounds
    clip_bounds = (minx - BUFFER_DEG, miny - BUFFER_DEG, maxx + BUFFER_DEG, maxy + BUFFER_DEG)

    rgb, transform = read_clip_highres(RASTER_PATH, clip_bounds)
    score = orange_score_map(rgb)
    np.save(OUTPUT_DIR / "score.npy", score)

    mask = score_to_mask(score)
    mask = apply_corridor_mask(mask, reference, transform)
    mask = refine_mask(mask)
    skel = skeletonize(mask > 0)
    skel = prune_skeleton_spurs(skel, MAX_SPUR_PX)

    cv2.imwrite(str(OUTPUT_DIR / "01_mask_corridor.png"), mask)
    cv2.imwrite(str(OUTPUT_DIR / "02_skeleton.png"), (skel.astype(np.uint8) * 255))
    cv2.imwrite(str(OUTPUT_DIR / "00_score.png"), (score * 255).astype(np.uint8))

    raw_line = extract_centerline(score, mask, skel, transform, ref_geom)
    if raw_line is None or raw_line.is_empty:
        report = {"reference_id": REFERENCE_ID, "status": "failed", "reason": "no path on skeleton"}
        (OUTPUT_DIR / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(json.dumps(report, indent=2))
        return

    smooth_line = simplify_line_m(raw_line, SIMPLIFY_TOL_M)
    reference.to_file(OUTPUT_DIR / "reference_manual.gpkg", driver="GPKG")
    gpd.GeoDataFrame(geometry=[raw_line], crs="EPSG:4326").to_file(
        OUTPUT_DIR / "best_match_raw.gpkg", driver="GPKG"
    )
    gpd.GeoDataFrame(geometry=[smooth_line], crs="EPSG:4326").to_file(
        OUTPUT_DIR / "best_match.gpkg", driver="GPKG"
    )

    draw_overlay(rgb, transform, reference, raw_line, OUTPUT_DIR / "03_overlay_raw.png")
    draw_overlay(rgb, transform, reference, smooth_line, OUTPUT_DIR / "03_overlay.png")

    report = {
        "reference_id": REFERENCE_ID,
        "status": "ok",
        "method": "snap_ridge + optional skeleton path",
        "clip_shape": [int(rgb.shape[0]), int(rgb.shape[1])],
        "params": {
            "target_res_deg": TARGET_RES_DEG,
            "corridor_m": CORRIDOR_M,
            "simplify_tol_m": SIMPLIFY_TOL_M,
            "chaikin_iters": CHAIKIN_ITERS,
            "snap_step_m": SNAP_STEP_M,
            "min_elongation": MIN_ELONGATION,
        },
        "metrics_raw": metrics_for_line(raw_line, reference),
        "metrics_smoothed": metrics_for_line(smooth_line, reference),
        "outputs": {
            "score": str(OUTPUT_DIR / "00_score.png"),
            "mask": str(OUTPUT_DIR / "01_mask_corridor.png"),
            "skeleton": str(OUTPUT_DIR / "02_skeleton.png"),
            "overlay_raw": str(OUTPUT_DIR / "03_overlay_raw.png"),
            "overlay": str(OUTPUT_DIR / "03_overlay.png"),
            "best_match_raw": str(OUTPUT_DIR / "best_match_raw.gpkg"),
            "best_match": str(OUTPUT_DIR / "best_match.gpkg"),
        },
    }
    (OUTPUT_DIR / "report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
