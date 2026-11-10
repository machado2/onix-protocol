"""Gera os humanos do Protocolo Ônix com o MPFB2 (MakeHuman para Blender, ativos CC0), com o rig "game_engine".
Uso: blender -b --factory-startup -P tools/blender/humans.py -- <nome> <saída.blend|.glb> [--preview arquivo.png]
O nome escolhe a receita em CAST abaixo. Animações são aplicadas depois por tools/blender/mocap.py.
"""
import sys, os, math
import bpy
from mathutils import Vector

MPFB = 'bl_ext.user_default.mpfb'
import importlib
HumanService = importlib.import_module(MPFB + '.services.humanservice').HumanService
TargetService = importlib.import_module(MPFB + '.services.targetservice').TargetService


def pheno(gender, age=.5, muscle=.5, weight=.5, height=.5, race=(.33, .33, .33), proportions=.6):
    d = TargetService.get_default_macro_info_dict()
    d.update(gender=gender, age=age, muscle=muscle, weight=weight, height=height, proportions=proportions)
    d['race'] = {'asian': race[0], 'caucasian': race[1], 'african': race[2]}
    return d


M, F = 1.0, 0.0
# receitas: fenótipo, pele, cabelo, sobrancelha, roupas
CAST = {
    'agent_m':   dict(p=pheno(M, .45, .75, .45, .6, (.1, .6, .3)), skin='young_caucasian_male/young_caucasian_male.mhmat', hair='short02/short02.mhclo',
                      clothes=['male_elegantsuit01/male_elegantsuit01.mhclo', 'culturalibre_male_boots/culturalibre_male_boots.mhclo']),
    'agent_f':   dict(p=pheno(F, .4, .65, .4, .6, (.3, .4, .3)), skin='young_asian_female/young_asian_female.mhmat', hair='ponytail01/ponytail01.mhclo',
                      clothes=['female_elegantsuit01/female_elegantsuit01.mhclo', 'toigo_ankle_boots_female/toigo_ankle_boots_female.mhclo']),
    'guard':     dict(p=pheno(M, .5, .8, .55, .65, (.2, .5, .3)), skin='middleage_caucasian_male/middleage_caucasian_male.mhmat', hair='short04/short04.mhclo',
                      clothes=['male_worksuit01/male_worksuit01.mhclo', 'culturalibre_male_boots/culturalibre_male_boots.mhclo']),
    'police':    dict(p=pheno(M, .55, .6, .6, .55, (.1, .3, .6)), skin='middleage_african_male/middleage_african_male.mhmat', hair='short01/short01.mhclo',
                      clothes=['male_casualsuit02/male_casualsuit02.mhclo', 'shoes01/shoes01.mhclo']),
    'civ_m1':    dict(p=pheno(M, .3, .5, .45, .5, (.1, .2, .7)), skin='young_african_male/young_african_male.mhmat', hair='short03/short03.mhclo',
                      clothes=['elvs_crude_t-shirt_male/elvs_crude_t-shirt_male.mhclo', 'cortu_cargo_pants/cortu_cargo_pants.mhclo', 'shoes02/shoes02.mhclo']),
    'civ_m2':    dict(p=pheno(M, .6, .4, .7, .45, (.2, .6, .2)), skin='middleage_caucasian_male/middleage_caucasian_male.mhmat', hair='short02/short02.mhclo',
                      clothes=['male_casualsuit04/male_casualsuit04.mhclo', 'shoes03/shoes03.mhclo']),
    'civ_m3':    dict(p=pheno(M, .25, .55, .4, .55, (.7, .2, .1)), skin='young_asian_male/young_asian_male.mhmat', hair='cortu_short_messy_hair/cortu_short_messy_hair.mhclo',
                      clothes=['namuhekam_male_polo_shirt/namuhekam_male_polo_shirt.mhclo', 'toigo_wool_pants/toigo_wool_pants.mhclo', 'shoes04/shoes04.mhclo']),
    'civ_f1':    dict(p=pheno(F, .3, .45, .45, .5, (.1, .3, .6)), skin='young_african_female/young_african_female.mhmat', hair='afro01/afro01.mhclo',
                      clothes=['female_casualsuit01/female_casualsuit01.mhclo', 'toigo_flats/toigo_flats.mhclo']),
    'civ_f2':    dict(p=pheno(F, .45, .4, .55, .45, (.2, .6, .2)), skin='young_caucasian_female/young_caucasian_female.mhmat', hair='bob02/bob02.mhclo',
                      clothes=['female_casualsuit02/female_casualsuit02.mhclo', 'toigo_ankle_boots_female/toigo_ankle_boots_female.mhclo']),
    'civ_f3':    dict(p=pheno(F, .25, .5, .4, .55, (.5, .3, .2)), skin='young_asian_female/young_asian_female.mhmat', hair='long01/long01.mhclo',
                      clothes=['toigo_basic_tucked_t-shirt/toigo_basic_tucked_t-shirt.mhclo', 'cortu_cargo_pants/cortu_cargo_pants.mhclo', 'shoes05/shoes05.mhclo']),
    'vip':       dict(p=pheno(M, .7, .4, .65, .5, (.1, .8, .1)), skin='old_caucasian_male/old_caucasian_male.mhmat', hair='short04/short04.mhclo',
                      clothes=['toigo_male_suit_tie_and_jacket/toigo_male_suit_tie_and_jacket.mhclo', 'toigo_ankle_boots_male/toigo_ankle_boots_male.mhclo']),
    'scientist': dict(p=pheno(F, .55, .4, .5, .5, (.3, .5, .2)), skin='middleage_caucasian_female/middleage_caucasian_female.mhmat', hair='toigo_blunt_bob/toigo_blunt_bob.mhclo',
                      clothes=['female_elegantsuit01/female_elegantsuit01.mhclo', 'toigo_flats/toigo_flats.mhclo']),
}


def build(name):
    r = CAST[name]
    male = r['p']['gender'] > .5
    info = {
        'phenotype': r['p'], 'rig': 'game_engine',
        'eyes': 'low-poly/low-poly.mhclo', 'eyebrows': 'eyebrow001/eyebrow001.mhclo' if male else 'eyebrow006/eyebrow006.mhclo',
        'eyelashes': 'eyelashes01/eyelashes01.mhclo', 'tongue': '', 'teeth': '', 'hair': r['hair'],
        'proxy': ('male_generic/male_generic.proxy' if male else 'female_generic/female_generic.proxy'),
        'targets': [], 'clothes': r['clothes'], 'skin_mhmat': r['skin'], 'skin_material_type': 'MAKESKIN',
        'eyes_material_type': 'MAKESKIN', 'skin_material_settings': {}, 'eyes_material_settings': {}, 'expressions': [],
        'alternative_materials': {}, 'clothes_material_type': 'MAKESKIN', 'name': name,
    }
    st = HumanService.get_default_deserialization_settings()
    st['subdiv_levels'] = 0
    st['override_skin_model'] = 'MAKESKIN'
    bm = HumanService.deserialize_from_dict(info, st)
    return bm


def preview(path):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.color_type = 'TEXTURE'
    sc.display.shading.light = 'STUDIO'
    sc.render.resolution_x, sc.render.resolution_y = 900, 1100
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.location = (1.2, -3.0, 1.3)
    d = Vector((0, 0, .95)) - cam.location
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    cam.data.lens = 50
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    a = sys.argv[sys.argv.index('--') + 1:]
    name, out = a[0], a[1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bm = build(name)
    objs = [o.name + ':' + o.type for o in bpy.data.objects]
    print('OBJS', objs)
    if '--preview' in a:
        preview(a[a.index('--preview') + 1])
    if out.endswith('.blend'):
        bpy.ops.wm.save_as_mainfile(filepath=out)
    print('feito', name)
