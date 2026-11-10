import sys, os, bpy
sys.path.insert(0, os.path.dirname(__file__))
from mathutils import Vector
import mocap
a = sys.argv[sys.argv.index('--') + 1:]
blend, bvh, name, out = a[0], a[1], a[2], a[3]
lo, hi = float(a[4]), float(a[5])
bpy.ops.wm.open_mainfile(filepath=blend)
rig = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
sp = mocap.clip(rig, bvh, name, loop=(lo, hi) if hi > 0 else None, seconds=None if hi > 0 else lo)
print('VEL', sp)
act = bpy.data.actions[name]
rig.animation_data.action = act
for t in rig.animation_data.nla_tracks:
    t.mute = True
sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.color_type = 'TEXTURE'
sc.render.resolution_x, sc.render.resolution_y = 600, 700
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
sc.collection.objects.link(cam); sc.camera = cam
cam.location = (3.4, -1.2, 1.1)
cam.rotation_euler = (Vector((0, 0, .9)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
pl = bpy.data.objects.new('floor', bpy.data.meshes.new('f'))
pl.data.from_pydata([(-3, -3, 0), (3, -3, 0), (3, 3, 0), (-3, 3, 0)], [], [(0, 1, 2, 3)]); sc.collection.objects.link(pl)
n = int(act.frame_range[1])
for k, f in enumerate([1, 1 + n // 4, 1 + n // 2, 1 + 3 * n // 4]):
    sc.frame_set(f)
    sc.render.filepath = out.replace('.png', '_%d.png' % k)
    bpy.ops.render.render(write_still=True)
