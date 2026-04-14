from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATASET = ROOT / "datasets" / "teeth_seg"


def main() -> None:
    image_sets = {
        "train": DATASET / "images" / "train",
        "val": DATASET / "images" / "val",
    }
    label_sets = {
        "train": DATASET / "labels" / "train",
        "val": DATASET / "labels" / "val",
    }

    errors: list[str] = []
    total_images = 0

    for split in ("train", "val"):
        image_dir = image_sets[split]
        label_dir = label_sets[split]
        if not image_dir.exists():
            errors.append(f"Missing image dir: {image_dir}")
            continue
        if not label_dir.exists():
            errors.append(f"Missing label dir: {label_dir}")
            continue

        images = []
        for pattern in ("*.jpg", "*.jpeg", "*.png", "*.webp"):
            images.extend(sorted(image_dir.glob(pattern)))

        total_images += len(images)
        if not images:
            errors.append(f"No images found in: {image_dir}")

        for image_path in images:
            label_path = label_dir / f"{image_path.stem}.txt"
            if not label_path.exists():
                errors.append(f"Missing label for image: {image_path.name}")
                continue

            content = label_path.read_text(encoding="utf-8").strip()
            if not content:
                continue

            for line_no, line in enumerate(content.splitlines(), start=1):
                parts = line.split()
                if len(parts) < 7:
                    errors.append(
                        f"{label_path.name}:{line_no} needs class id + at least 3 points"
                    )
                    continue

                try:
                    class_id = int(parts[0])
                except ValueError:
                    errors.append(f"{label_path.name}:{line_no} invalid class id")
                    continue

                if class_id not in (0, 1):
                    errors.append(f"{label_path.name}:{line_no} unsupported class id: {class_id}")

                coords = parts[1:]
                if len(coords) % 2 != 0:
                    errors.append(f"{label_path.name}:{line_no} has uneven coordinate count")
                    continue

                for raw in coords:
                    try:
                        value = float(raw)
                    except ValueError:
                        errors.append(f"{label_path.name}:{line_no} invalid float: {raw}")
                        continue
                    if not 0.0 <= value <= 1.0:
                        errors.append(f"{label_path.name}:{line_no} coordinate out of range: {value}")

    if errors:
        print("Dataset validation failed:")
        for err in errors:
            print(f"- {err}")
        raise SystemExit(1)

    print(f"Dataset looks valid. Total images: {total_images}")


if __name__ == "__main__":
    main()

