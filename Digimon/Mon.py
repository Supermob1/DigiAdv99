#!/usr/bin/env python3
from pathlib import Path

# ----------------------------------------------------------------------
# CONFIGURATION
# ----------------------------------------------------------------------

# Folder containing all your digimon subfolders like "0 - Punimon", "1 - Koromon", etc.
DIGIMON_ROOT = Path("Sprites")

# Output folder for .mon files
OUTPUT_DIR = Path("Digimon/Species")

# Default base values (you can change these globally)
DEFAULT_TYPE = "Data"
DEFAULT_STAGE = "Rookie"
DEFAULT_MIN_LEVEL = 1
DEFAULT_MIN_BOND = 0

# ----------------------------------------------------------------------
# SCRIPT
# ----------------------------------------------------------------------

def extract_stage_number(folder_name: str) -> str:
    """Extracts the leading number before the dash in '1 - Koromon'."""
    parts = folder_name.split("-", 1)
    if parts and parts[0].strip().isdigit():
        return parts[0].strip()
    return "?"

def extract_name(folder_name: str) -> str:
    """Extracts the name part after the dash in '1 - Koromon'."""
    parts = folder_name.split("-", 1)
    if len(parts) > 1:
        return parts[1].strip()
    return folder_name.strip()

def guess_stage_name(stage_num: str) -> str:
    """Maps numeric stage to Digimon stages."""
    STAGE_MAP = {
        "0": "Egg",
        "1": "InTraining",
        "2": "Rookie",
        "3": "Champion",
        "4": "Ultimate",
        "5": "Mega",
        "6": "Ultra",
    }
    return STAGE_MAP.get(stage_num, DEFAULT_STAGE)

def make_mon_content(digid: str, stage_num: str) -> str:
    """Generate a minimal .mon file for the Digimon."""
    stage_name = guess_stage_name(stage_num)
    lines = [
        f"Id={digid}",
        f"Name={digid}",
        f"Type={DEFAULT_TYPE}",
        f"Stage={stage_name}",
        f"MinLevel={DEFAULT_MIN_LEVEL}",
        f"MinBond={DEFAULT_MIN_BOND}",
        "",
        "Digivolution=[]",
        "",
        "# Customize Type, Stage, MinLevel, MinBond, Digivolution manually later.",
        "",
    ]
    return "\n".join(lines)

def main():
    if not DIGIMON_ROOT.exists():
        print(f"[ERROR] Folder not found: {DIGIMON_ROOT}")
        return

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    count = 0

    for sub in DIGIMON_ROOT.iterdir():
        if not sub.is_dir():
            continue

        stage_num = extract_stage_number(sub.name)
        digimon_name = extract_name(sub.name)

        if not digimon_name:
            continue

        out_path = OUTPUT_DIR / f"{digimon_name}.mon"
        if out_path.exists():
            print(f"[SKIP] {digimon_name} already exists")
            continue

        content = make_mon_content(digimon_name, stage_num)
        out_path.write_text(content, encoding="utf-8")
        print(f"[OK] Created {out_path}")
        count += 1

    print(f"\nDone. Generated {count} .mon files in {OUTPUT_DIR}.")

if __name__ == "__main__":
    main()
