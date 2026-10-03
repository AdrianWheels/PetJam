"""Conecta el arte aprobado a recursos; conserva intactos los originales antiguos."""
import json
import re
import shutil
from pathlib import Path
from inventory import ROOT, ART, update

def replace_textures(path, mapping):
    text = path.read_text(encoding='utf-8')
    for old, new in mapping.items():
        if not (ROOT / new.removeprefix('res://')).exists():
            raise FileNotFoundError(new)
        pattern = r'\[ext_resource type="Texture2D"(?: uid="[^"]+")? path="' + re.escape(old) + r'"'
        text = re.sub(pattern, '[ext_resource type="Texture2D" path="'+new+'"', text)
    path.write_text(text, encoding='utf-8')

for folder, category in [('items','gear'),('materials','materials')]:
    for path in (ROOT/'data'/folder).glob('*.tres'):
        text=path.read_text(encoding='utf-8')
        old=re.search(r'\[ext_resource type="Texture2D"(?: uid="[^"]+")? path="([^"]+)"',text)
        if old:
            replace_textures(path,{old[1]:f'res://art/stickers/sources/{category}/{path.stem}.png'})

workshop=ART/'sources/backgrounds/workshop.png'
workshop.parent.mkdir(parents=True,exist_ok=True)
shutil.copy2(ROOT/'art/pilot_illustrated_2026_10_02/forge.png', workshop)
data=json.loads((ROOT/'doc/arte/inventario-produccion.json').read_text(encoding='utf-8'))
if not any(row['id']=='backgrounds/workshop' for row in data['records']):
    data['records'].append(dict(id='backgrounds/workshop',category='backgrounds',brief='Taller ilustrado: reutiliza el piloto aprobado',active=True,status='revisado',source='art/stickers/sources/backgrounds/workshop.png'))
(ROOT/'doc/arte/inventario-produccion.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')

maps={
'scenes/UI/HUD_Main.tscn':{
 'res://art/assets/Imagenes/Menu/blueprints_icon.png':'res://art/stickers/sources/ui/blueprints.png',
 'res://art/assets/Imagenes/Menu/closet_icon.png':'res://art/stickers/sources/ui/equipment.png',
 'res://art/assets/Imagenes/Menu/forge_icon.png':'res://art/stickers/sources/ui/shop.png',
 'res://art/placeholders/forge_background.png':'res://art/stickers/sources/backgrounds/workshop.png'},
'scenes/UI/EquipmentPanel.tscn':{'res://art/ui/mochila.png':'res://art/stickers/sources/ui/backpack.png'},
'scenes/UI/StartScreen.tscn':{'res://art/assets/Imagenes/Menu/main_tittle_screen.png':'res://art/stickers/sources/screens/start.png'},
'scenes/Minigames/HammerMinigame.tscn':{
 'res://art/assets/Imagenes/Trial Resources/Hammer/hammer_background.png':'res://art/stickers/sources/stations/hammer.png',
 'res://art/assets/Imagenes/Trial Resources/Hammer/hammer.png':'res://art/stickers/sources/tools/hammer.png'},
'scenes/Minigames/SewOSU.tscn':{'res://art/assets/Imagenes/Trial Resources/Stitches/leather_background.png':'res://art/stickers/sources/stations/sew.png'},
'scenes/Minigames/QuenchWater.tscn':{'res://art/assets/Imagenes/Trial Resources/Tempered/steel_bar.png':'res://art/stickers/sources/tools/steel_bar.png'},
'scenes/Minigames/ForgeTemp.tscn':{'res://art/assets/Imagenes/Trial Resources/Heat/Heat.png':'res://art/stickers/sources/materials/fire.png'},
}
for name in ['MaterialIcon','MaterialRow']:
    maps[f'scenes/UI/{name}.tscn']={'res://art/placeholders/forge/material_wood.png':'res://art/stickers/sources/materials/wood.png'}
for name in ['BlueprintQueueSlot','RequestSlot']:
    maps[f'scenes/UI/{name}.tscn']={'res://art/placeholders/forge/blueprint_armor_leather.png':'res://art/stickers/sources/ui/blueprints.png'}
for path,mapping in maps.items(): replace_textures(ROOT/path,mapping)

for path in (ROOT/'data/blueprints').glob('*.tres'):
    if not (ART/'sources/gear'/(path.stem+'.png')).exists():
        continue  # prototipos históricos fuera de la biblioteca activa
    text=path.read_text(encoding='utf-8')
    for old in re.findall(r'\[ext_resource type="Texture2D"(?: uid="[^"]+")? path="([^"]+)"',text):
        new=f'res://art/stickers/sources/gear/{path.stem}.png' if 'Blueprints/' in old else 'res://art/stickers/sources/backgrounds/workshop.png'
        if old.startswith('res://art/stickers/'):
            continue
        replace_textures(path,{old:new})

path=ROOT/'scripts/core/Potions.gd'
text=path.read_text(encoding='utf-8').replace('res://art/ui/pocion_vida.png','res://art/stickers/sources/potions/potion_heal.png')
for name in ['speed','luck']:
    text=text.replace(f'&"potion_{name}": {{"display_name":',f'&"potion_{name}": {{"icon": "res://art/stickers/sources/potions/potion_{name}.png", "display_name":') if f'sources/potions/potion_{name}.png' not in text else text
path.write_text(text,encoding='utf-8')
update()
print('ART_LINKS_OK: equipo, materiales, pociones, menús, estaciones y taller')
