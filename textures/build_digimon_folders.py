#!/usr/bin/env python3
import re
import shutil
from pathlib import Path

# ----------------------------------------------------------------------
# CONFIG – CHANGE THESE TO MATCH YOUR FOLDER STRUCTURE
# ----------------------------------------------------------------------

# Folder that contains "0 - Egg", "1 - Fresh", ..., each with PNGs
SPRITES_BANK_ROOT = Path("DigimonSpritesBank")

# Where you want the generated digimon folders to go
# Example: "Digimon" → "Digimon/0 - Zurumon", "Digimon/1 - Agumon", etc.
OUTPUT_ROOT = Path("Digimon")

# Which frame indices to use for idle + attack
IDLE_FRAME_INDEX = 2
ATTACK_FRAME_INDEX = 8

# ----------------------------------------------------------------------
# SCRIPT
# ----------------------------------------------------------------------

# Example filename pattern:
#   m001_zurumon_main_0.png
#   [code]_[name]_main_[frame].png
FILENAME_RE = re.compile(
    r"^(?P<code>[^_]+)_(?P<name>.+)_main_(?P<frame>\d+)$",
    re.IGNORECASE,
)

def extract_stage_number(dir_name: str) -> str:
    """
    Pulls the leading number out of a folder name like '0 - Egg' → '0'.
    If none, returns the full name.
    """
    m = re.match(r"\s*(\d+)", dir_name)
    if m:
        return m.group(1)
    return dir_name


def nice_name(raw: str) -> str:
    """
    Turns 'zurumon' into 'Zurumon'. If your filenames already have
    proper capitalization, you can just 'return raw' instead.
    """
    if not raw:
        return raw
    return raw[0].upper() + raw[1:]


def main():
    if not SPRITES_BANK_ROOT.exists():
        print(f"[ERROR] Sprites root not found: {SPRITES_BANK_ROOT}")
        return

    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)

    # Loop over stage folders: "0 - Egg", "1 - Fresh", ...
    for stage_dir in SPRITES_BANK_ROOT.iterdir():
        if not stage_dir.is_dir():
            continue

        stage_num = extract_stage_number(stage_dir.name)
        print(f"\n=== Processing stage folder: {stage_dir.name} (stage {stage_num}) ===")

        # Collect all frames per digimon name
        #   frames_by_digi["zurumon"] = { 0: Path(...), 2: Path(...), 8: Path(...) }
        frames_by_digi: dict[str, dict[int, Path]] = {}

        for png_path in stage_dir.glob("*.png"):
            m = FILENAME_RE.match(png_path.stem)
            if not m:
                print(f"  [WARN] Skipping file with unexpected name: {png_path.name}")
                continue

            digi_name = m.group("name")
            frame_idx = int(m.group("frame"))

            frames_by_digi.setdefault(digi_name, {})[frame_idx] = png_path

        # Now for each digimon, create output folder and copy/rename the two frames
        for digi_name, frames in frames_by_digi.items():
            pretty_name = nice_name(digi_name)
            out_dir = OUTPUT_ROOT / f"{stage_num} - {pretty_name}"
            out_dir.mkdir(parents=True, exist_ok=True)

            # Idle / main sprite
            if IDLE_FRAME_INDEX in frames:
                src_idle = frames[IDLE_FRAME_INDEX]
                dst_idle = out_dir / f"{pretty_name}.png"
                shutil.copy2(src_idle, dst_idle)
                print(f"  [OK] {src_idle.name} -> {dst_idle}")
            else:
                print(
                    f"  [WARN] No *_main_{IDLE_FRAME_INDEX} for {digi_name} "
                    f"in {stage_dir.name}"
                )

            # Attack sprite
            if ATTACK_FRAME_INDEX in frames:
                src_attack = frames[ATTACK_FRAME_INDEX]
                dst_attack = out_dir / f"{pretty_name}_Attack.png"
                shutil.copy2(src_attack, dst_attack)
                print(f"  [OK] {src_attack.name} -> {dst_attack}")
            else:
                print(
                    f"  [WARN] No *_main_{ATTACK_FRAME_INDEX} for {digi_name} "
                    f"in {stage_dir.name}"
                )

    print("\nDone.")


if __name__ == "__main__":
    main()
