"""Guarda los originales y prompts de image_gen en el repositorio."""
import json
import re
import shutil
from pathlib import Path
from inventory import ROOT, ART, update

jobs=json.loads((ART/'generation_jobs.json').read_text(encoding='utf-8'))
saved=0
for job in jobs:
    if not job.get('output_hint'): continue
    match=re.search(r'as (.+\.png) by default',job['output_hint'])
    if not match: raise ValueError(job['id'])
    src=Path(match.group(1)); dst=ART/'sources'/(job['id']+'.png')
    dst.parent.mkdir(parents=True,exist_ok=True)
    if not src.exists(): raise FileNotFoundError(src)
    if not dst.exists() or dst.read_bytes()!=src.read_bytes():
        if dst.exists():
            import hashlib
            archive=ART/'archive'/(job['id']+'_'+hashlib.sha256(dst.read_bytes()).hexdigest()[:8]+'.png')
            archive.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(dst,archive)
        shutil.copy2(src,dst)
        saved+=1
    prompt=ART/'prompts'/(job['id']+'.txt')
    prompt.parent.mkdir(parents=True,exist_ok=True)
    prompt.write_text(job['prompt']+'\n',encoding='utf-8')
print(f'{saved} nuevos originales guardados')
update()
