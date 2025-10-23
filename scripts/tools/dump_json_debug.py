import json
from pathlib import Path

root = Path(r"d:/Proyectos/PetJam")
data_dir = root / "data"
logs_dir = root / "logs"
logs_dir.mkdir(parents=True, exist_ok=True)

files = ["materials.json", "tuning.json"]

for f in files:
    p = data_dir / f
    out = logs_dir / (f.replace('.','_') + '.log')
    with out.open('w', encoding='utf-8') as fh:
        fh.write(f"File: {p}\n")
        if not p.exists():
            fh.write("Status: MISSING\n")
            print(f"{f}: MISSING")
            continue
        try:
            text = p.read_text(encoding='utf-8')
        except Exception as e:
            fh.write(f"Status: READ_ERROR - {e}\n")
            print(f"{f}: READ_ERROR - {e}")
            continue
        fh.write(f"Length: {len(text)}\n")
        fh.write("--- Preview (512) ---\n")
        fh.write(text[:512] + "\n")
        fh.write("--- End preview ---\n")
        try:
            obj = json.loads(text)
            fh.write("Status: PARSED_OK\n")
            # write a small summary
            if isinstance(obj, dict):
                fh.write(f"Type: dict, keys_count: {len(obj)}\n")
                fh.write("Keys: \n")
                for k in list(obj.keys())[:50]:
                    fh.write(f"  - {k}\n")
            elif isinstance(obj, list):
                fh.write(f"Type: list, len: {len(obj)}\n")
            else:
                fh.write(f"Type: {type(obj)}\n")
            print(f"{f}: PARSED_OK")
        except json.JSONDecodeError as jde:
            fh.write(f"Status: JSON_ERROR - {str(jde)}\n")
            print(f"{f}: JSON_ERROR - {str(jde)}")
        except Exception as e:
            fh.write(f"Status: OTHER_ERROR - {e}\n")
            print(f"{f}: OTHER_ERROR - {e}")

print('Done')
