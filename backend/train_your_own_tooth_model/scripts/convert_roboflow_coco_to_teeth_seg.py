"""Convert a Roboflow COCO Segmentation export to YOLO segmentation labels.

Roboflow folder layout (typical):
  train/_annotations.coco.json + images
  valid/_annotations.coco.json + images
  test/_annotations.coco.json + images

Output layout (matches this repo):
  datasets/teeth_seg/images/{train,val,test}
  datasets/teeth_seg/labels/{train,val,test}

Usage (PowerShell):
  cd D:\\Downloads\\dentalogic_new\\backend\\train_your_own_tooth_model
  .\\.venv\\Scripts\\activate
  python scripts\\convert_roboflow_coco_to_teeth_seg.py --src "D:\\Downloads\\your-export-folder"
"""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DST = ROOT / "datasets" / "teeth_seg"

CLASS_ORDER = ["upper_teeth", "lower_teeth"]


def _ensure_dir(p: Path) -> None:
    p.mkdir(parents=True, exist_ok=True)


def _coco_to_normalized_polygon(poly: list[float], w: int, h: int) -> list[float]:
    out: list[float] = []
    for i in range(0, len(poly), 2):
        out.append(poly[i] / w)
        out.append(poly[i + 1] / h)
    return out


def _build_category_map(coco: dict) -> dict[int, int]:
    mapping: dict[int, int] = {}
    for cat in coco.get("categories", []):
        name = str(cat.get("name", "")).strip()
        cid = int(cat["id"])
        if name in CLASS_ORDER:
            mapping[cid] = CLASS_ORDER.index(name)
    if len(mapping) != len(CLASS_ORDER):
        raise SystemExit(
            "Could not map all classes from COCO categories.\n"
            f"Expected names: {CLASS_ORDER}\n"
            f"Found in export: {[c.get('name') for c in coco.get('categories', [])]}"
        )
    return mapping


def _find_image_path(split_dir: Path, file_name: str) -> Path:
    direct = split_dir / file_name
    if direct.exists():
        return direct
    # Roboflow sometimes stores only the basename but nests files.
    base = Path(file_name).name
    matches = list(split_dir.rglob(base))
    if len(matches) == 1:
        return matches[0]
    if not matches:
        raise FileNotFoundError(f"Image not found in {split_dir}: {file_name}")
    raise FileNotFoundError(f"Multiple matches for {base} under {split_dir}")


def convert_split(
    *,
    src_split: Path,
    dst_images: Path,
    dst_labels: Path,
    cat_map: dict[int, int],
) -> None:
    ann_path = src_split / "_annotations.coco.json"
    if not ann_path.exists():
        raise SystemExit(f"Missing {ann_path}")

    coco = json.loads(ann_path.read_text(encoding="utf-8"))
    img_by_id = {int(im["id"]): im for im in coco.get("images", [])}
    anns_by_img: dict[int, list[dict]] = {}
    for ann in coco.get("annotations", []):
        anns_by_img.setdefault(int(ann["image_id"]), []).append(ann)

    _ensure_dir(dst_images)
    _ensure_dir(dst_labels)

    for img_id, im in sorted(img_by_id.items(), key=lambda kv: kv[0]):
        file_name = str(im["file_name"])
        w = int(im["width"])
        h = int(im["height"])

        src_img = _find_image_path(src_split, file_name)
        out_name = Path(file_name).name
        shutil.copy2(src_img, dst_images / out_name)

        lines: list[str] = []
        for ann in anns_by_img.get(img_id, []):
            if int(ann.get("iscrowd", 0)) == 1:
                continue

            cls = cat_map.get(int(ann["category_id"]))
            if cls is None:
                continue

            seg = ann.get("segmentation")
            if not seg:
                continue

            polys: list[list[float]]
            if isinstance(seg, list) and seg and isinstance(seg[0], list):
                polys = [list(map(float, p)) for p in seg]  # type: ignore[arg-type]
            elif isinstance(seg, list) and seg and isinstance(seg[0], (int, float)):
                polys = [list(map(float, seg))]  # single flat polygon
            else:
                # RLE or unknown — skip
                continue

            for poly in polys:
                if len(poly) < 6 or len(poly) % 2 != 0:
                    continue
                normed = _coco_to_normalized_polygon(poly, w, h)
                if any(not (0.0 <= v <= 1.0) for v in normed):
                    continue
                lines.append(str(cls) + " " + " ".join(f"{v:.6f}" for v in normed))

        label_path = dst_labels / f"{Path(out_name).stem}.txt"
        label_path.write_text(("\n".join(lines) + "\n") if lines else "", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--src",
        required=True,
        help=r'Roboflow export folder, e.g. D:\Downloads\project.v1i.coco-segmentation',
    )
    parser.add_argument(
        "--dst",
        default=str(DEFAULT_DST),
        help=f"Output dataset root (default: {DEFAULT_DST})",
    )
    args = parser.parse_args()

    src = Path(args.src)
    dst = Path(args.dst)
    if not src.exists():
        raise SystemExit(f"Source folder not found: {src}")

    # Read categories from train split (should match all splits)
    train_ann = src / "train" / "_annotations.coco.json"
    if not train_ann.exists():
        raise SystemExit(f"Missing {train_ann} (expected Roboflow COCO export layout)")
    coco0 = json.loads(train_ann.read_text(encoding="utf-8"))
    cat_map = _build_category_map(coco0)

    mapping = {
        "train": src / "train",
        "val": src / "valid",
        "test": src / "test",
    }

    for out_split, split_dir in mapping.items():
        if not split_dir.exists():
            continue
        convert_split(
            src_split=split_dir,
            dst_images=dst / "images" / out_split,
            dst_labels=dst / "labels" / out_split,
            cat_map=cat_map,
        )

    print(f"Done. Wrote YOLO-seg labels under: {dst}")


if __name__ == "__main__":
    main()
