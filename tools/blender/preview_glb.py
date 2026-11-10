"""Renderiza um .glb de personagem no Blender (workbench) para conferir poses: -- arquivo.glb ação frame saída.png"""
import sys, bpy, math
from mathutils import Vector
a = sys.argv[sys.argv.index('--') + 1:]
glb, act, frame, out = a[0], a[1], int(a[2]), a[3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
rig = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
rig.animation_data.action = bpy.data.actions[act]
bpy.context.scene.frame_set(frame)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'
sc.render.resolution_x, sc.render.resolution_y = 900, 900
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
sc.collection.objects.link(cam)
sc.camera = cam
cam.location = (2.0, -2.8, 1.5)
d = Vector((0, 0, .9)) - cam.location
cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
cam.data.lens = 50
pl = bpy.data.objects.new('floor', bpy.data.meshes.new('f'))
pl.data.from_pydata([(-2, -2, 0), (2, -2, 0), (2, 2, 0), (-2, 2, 0)], [], [(0, 1, 2, 3)])
sc.collection.objects.link(pl)
sc.display.shading.light = 'STUDIO'
sc.display.shading.color_type = 'TEXTURE'
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
