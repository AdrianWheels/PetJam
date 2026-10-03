"""Inventario reproducible de producción visual. No modifica imágenes."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INVENTORY = ROOT / 'doc/arte/inventario-produccion.json'
ART = ROOT / 'art/stickers'


def initial():
    rows = []
    def add(category, identifier, brief, active=True, **extra):
        rows.append(dict(id=f'{category}/{identifier}', category=category, brief=brief,
                         active=active, status='pendiente', source=f'art/stickers/sources/{category}/{identifier}.png',
                         **extra))
    for identifier, weapon in [('tico_none','palo'), ('tico_basic','espada básica'),
                               ('tico_advanced','espada avanzada'), ('tico_master','espada maestra')]:
        add('characters', identifier, f'Tico con {weapon}: reposo, golpe, daño, derrota', poses=4)
    for identifier in ['slime','skeleton','bat','golem','wraith']:
        add('characters', identifier, f'{identifier}: reposo, ataque, daño, derrota', poses=4)
    for n, name in enumerate(['Rey Osario','Madre del Musgo','Señor del Magma','Coloso de Escarcha','Heraldo del Vacío']):
        add('characters', f'boss_{n}', f'{name}: reposo, ataque, daño, derrota', poses=4)
    add('characters', 'brasa', 'Brasa: reposo, martillo, coser, celebrar', poses=4)
    for p in sorted((ROOT/'data/items').glob('*.tres')):
        import re
        text = p.read_text(encoding='utf-8')
        cells = [list(map(int,m)) for m in re.findall(r'Vector2i\((\d+), (\d+)\)',
                next(line for line in text.splitlines() if line.startswith('shape_cells =')))]
        add('gear', p.stem, p.stem, cells=cells, kind='equipo_activo')
    for p in sorted((ROOT/'tools/gear_art/futuras').glob('*.json')):
        cfg=json.loads(p.read_text(encoding='utf-8'))
        add('gear', p.stem, p.stem, active=False, cells=cfg['cells'], kind='arma_futura')
    for p in sorted((ROOT/'data/materials').glob('*.tres')):
        add('materials', p.stem, p.stem)
    for name in ['heal','speed','luck']:
        add('potions', 'potion_'+name, name)
    for n in range(5):
        add('backgrounds', f'biome_{n}', f'Fondo lateral del bioma {n}')
    add('backgrounds', 'workshop', 'Taller ilustrado: reutiliza el piloto')
    for name in ['forge','hammer','sew','quench']:
        add('stations', name, f'Estación de {name}')
    for name in ['hammer','needle','steel_bar','water_bucket']:
        add('tools', name, name)
    for name in ['blueprints','equipment','shop','delivery','backpack','coin','anvil','spark']:
        add('ui', name, name)
    for name in ['start','defeat']:
        add('screens', name, name)
    return rows


def update():
    data = json.loads(INVENTORY.read_text(encoding='utf-8')) if INVENTORY.exists() else {
        'date':'2026-10-02', 'style':'Ilustración de armas antiguas; personajes sticker con 4 poses',
        'records':initial(),
        'retained':['Efectos actuales de combate y fabricación','Tipografía legible y textos localizables',
                    'Componentes de interfaz procedurales y marcos de calidad',
                    'Sonido fuera del alcance de arte visual'],
    }
    from PIL import Image
    for row in data['records']:
        source=ROOT/row['source']
        if source.exists():
            im=Image.open(source)
            row['dimensions']=list(im.size)
            row['alpha']=list(im.getchannel('A').getextrema()) if im.mode=='RGBA' else None
            if row['status']=='pendiente': row['status']='generado_por_revisar'
    INVENTORY.parent.mkdir(parents=True,exist_ok=True)
    INVENTORY.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    lines=['# Inventario de arte de PetJam','','Dirección: armas antiguas + personajes sticker con cuatro poses.',
           '', 'Armas: **3 espadas activas + 10 futuras = 13 diseños**. Equipo activo total: 12 piezas.',
           '', 'Un registro de personaje representa una hoja de cuatro poses; no un ciclo completo de animación.',
           '', '| Recurso | Uso | Estado | Original |','|---|---|---|---|']
    for row in data['records']:
        lines.append(f"| {row['id']} | {'Activo' if row['active'] else 'Futuro'} | {row['status']} | `{row['source']}` |")
    done=sum(r['status']!='pendiente' for r in data['records'])
    lines+=['',f"Recursos registrados: {len(data['records'])}. Con original guardado: {done}.",
            '', '## Recursos conservados','']+[f'- {v}' for v in data['retained']]
    (INVENTORY.parent/'inventario-produccion.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(f'{done}/{len(data["records"])} originales guardados')


if __name__=='__main__': update()
