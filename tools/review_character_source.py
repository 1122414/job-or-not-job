"""Inspect a private FBX candidate and render review evidence with Blender 4.5.

Run Blender with --background --disable-autoexec --python this_file -- ... .
Source geometry and the editable studio stay under ignored build/. Only summary
metrics and rendered images go to the evidence directory; this is not a game export.
"""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def inspect_character():
    meshes = [o for o in bpy.context.scene.objects if o.get("review_character") and o.type == "MESH"]
    rigs = [o for o in bpy.context.scene.objects if o.get("review_character") and o.type == "ARMATURE"]
    result = {"meshes": [], "rigs": [], "images": [], "materials": []}
    for obj in meshes:
        mesh = obj.data
        mesh.calc_loop_triangles()
        names = {g.index: g.name for g in obj.vertex_groups}
        armatures = [m.object for m in obj.modifiers if m.type == "ARMATURE" and m.object]
        deform_names = {b.name for a in armatures for b in a.data.bones if b.use_deform}
        bad, unweighted, nonunit, maximum = 0, 0, 0, 0
        for v in mesh.vertices:
            weights = [g.weight for g in v.groups if names.get(g.group) in deform_names]
            bad += sum(not math.isfinite(w) or w < 0 for w in weights)
            positives = [w for w in weights if math.isfinite(w) and w > 0]
            maximum = max(maximum, len(positives))
            unweighted += not positives
            nonunit += bool(positives) and abs(sum(positives) - 1) > 1e-4
        result["meshes"].append({
            "name": obj.name, "vertices": len(mesh.vertices), "polygons": len(mesh.polygons),
            "triangles": len(mesh.loop_triangles), "uv_layers": len(mesh.uv_layers),
            "materials": [m.name if m else None for m in mesh.materials],
            "armatures": [a.name for a in armatures], "invalid_weights": bad,
            "unweighted_vertices": unweighted, "nonunit_weight_vertices": nonunit,
            "max_positive_influences": maximum,
            "degenerate_triangles": sum(t.area < 1e-12 for t in mesh.loop_triangles),
            "shape_keys": len(mesh.shape_keys.key_blocks) if mesh.shape_keys else 0,
            "world_bounds_m": bounds([obj]),
        })
    for obj in rigs:
        result["rigs"].append({
            "name": obj.name, "bones": len(obj.data.bones),
            "bone_names": [b.name for b in obj.data.bones],
            "zero_length_bones": [b.name for b in obj.data.bones if b.length < 1e-6],
            "object_scale": list(obj.scale),
        })
    for img in bpy.data.images:
        if img.source != "FILE":
            continue
        path = Path(bpy.path.abspath(img.filepath))
        result["images"].append({
            "name": img.name, "file": path.name, "size": list(img.size),
            "colorspace": img.colorspace_settings.name, "exists": path.is_file(),
            "sha256": sha(path) if path.is_file() else None,
            "decoded_rgba8_mib": img.size[0] * img.size[1] * 4 / 1024 ** 2,
        })
    materials = {m for obj in meshes for m in obj.data.materials if m}
    for material in sorted(materials, key=lambda m: m.name):
        tree = material.node_tree
        result["materials"].append({
            "name": material.name,
            "nodes": [{"name": n.name, "type": n.type,
                       "image": n.image.name if n.type == "TEX_IMAGE" and n.image else None,
                       "operation": n.operation if n.type == "MATH" else None}
                      for n in sorted(tree.nodes, key=lambda n: n.name)],
            "links": sorted([f"{l.from_node.name}.{l.from_socket.name} -> "
                             f"{l.to_node.name}.{l.to_socket.name}" for l in tree.links]),
        })
    result["lod_meshes"] = [o.name for o in meshes if "lod" in o.name.lower()]
    result["actions"] = [a.name for a in bpy.data.actions]
    return result


def bounds(objects):
    points = [o.matrix_world @ Vector(c) for o in objects for c in o.bound_box]
    return {"min": [min(v[i] for v in points) for i in range(3)],
            "max": [max(v[i] for v in points) for i in range(3)]}


def prepare_materials(source):
    """Explicit map semantics; never infer alpha or skin masks by appearance."""
    mapping = {"_dif": "sRGB", "_gloss": "Non-Color", "_norm": "Non-Color"}
    candidates = {}
    for suffix, colorspace in mapping.items():
        found = list((source.parent / "tex").glob(f"*{suffix}.jpg"))
        if len(found) != 1:
            raise ValueError(f"Expected one {suffix} map beside {source}; found {len(found)}")
        img = bpy.data.images.load(str(found[0]), check_existing=True)
        img.colorspace_settings.name = colorspace
        candidates[suffix] = img
    for material in {m for o in bpy.context.scene.objects if o.type == "MESH" for m in o.data.materials if m}:
        material.use_nodes = True
        tree = material.node_tree
        tree.nodes.clear()
        surface = tree.nodes.new("ShaderNodeBsdfPrincipled")
        surface.inputs["Specular IOR Level"].default_value = .35
        output = tree.nodes.new("ShaderNodeOutputMaterial")
        tree.links.new(surface.outputs["BSDF"], output.inputs["Surface"])
        nodes = {}
        for suffix, img in candidates.items():
            node = tree.nodes.new("ShaderNodeTexImage")
            node.image = img
            node.label = suffix
            nodes[suffix] = node
        tree.links.new(nodes["_dif"].outputs["Color"], surface.inputs["Base Color"])
        inverse = tree.nodes.new("ShaderNodeMath")
        inverse.operation = "SUBTRACT"
        inverse.inputs[0].default_value = 1
        tree.links.new(nodes["_gloss"].outputs["Color"], inverse.inputs[1])
        tree.links.new(inverse.outputs[0], surface.inputs["Roughness"])
        normal = tree.nodes.new("ShaderNodeNormalMap")
        tree.links.new(nodes["_norm"].outputs["Color"], normal.inputs["Color"])
        tree.links.new(normal.outputs["Normal"], surface.inputs["Normal"])


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def studio(box):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 1200
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    scene.world = bpy.data.worlds.new("review_world")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.16, .18, .22, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = .4
    for name, pos, power, size in [("key", (2, -3, 3.4), 450, 3),
                                  ("fill", (-3, -1.5, 2.3), 200, 3),
                                  ("rim", (1, 2, 3), 350, 2)]:
        light = bpy.data.lights.new(name, "AREA")
        light.energy, light.shape, light.size = power, "DISK", size
        obj = bpy.data.objects.new(name, light)
        scene.collection.objects.link(obj)
        obj.location = pos
        aim(obj, (0, 0, 1))
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, box["min"][2] - .003))
    floor = bpy.context.object
    floor.name = "review_floor"
    material = bpy.data.materials.new("review_floor_material")
    material.use_nodes = True
    material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.055, .07, .09, 1)
    material.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .85
    floor.data.materials.append(material)
    camera = bpy.data.objects.new("review_camera", bpy.data.cameras.new("review_camera"))
    scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    scene.camera = camera
    return camera


def render(camera, evidence, name, position, target, scale):
    camera.location = position
    camera.data.ortho_scale = scale
    aim(camera, target)
    bpy.context.scene.render.filepath = str(evidence / f"{name}.png")
    bpy.ops.render.render(write_still=True)


def pose_probe(evidence, camera, rig, height):
    targets = {"lowerarm_l": 70, "lowerleg_l": 65}
    if any(name not in rig.pose.bones for name in targets):
        return {"status": "not_run", "reason": "This probe requires Renderpeople joint names."}
    mesh_objects = [o for o in bpy.context.scene.objects if o.get("review_character") and o.type == "MESH"]
    mesh = mesh_objects[0]
    def evaluated_positions():
        evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        deformed = evaluated.to_mesh()
        positions = [evaluated.matrix_world @ v.co for v in deformed.vertices]
        evaluated.to_mesh_clear()
        return positions

    before = evaluated_positions()
    original_lengths = {b.name: b.length for b in rig.data.bones}
    originals = {name: rig.pose.bones[name].matrix_basis.copy() for name in targets}
    actual_angles = {}
    for name, degrees in targets.items():
        bone = rig.pose.bones[name]
        direction = (bone.tail - bone.head).normalized()
        world_bend_direction = Vector((0, -1 if "arm" in name else 1, 0))
        bend_direction = rig.matrix_world.to_3x3().inverted() @ world_bend_direction
        axis = direction.cross(bend_direction).normalized()
        matrix = Quaternion(axis, math.radians(degrees)).to_matrix().to_4x4() @ bone.matrix
        matrix.translation = bone.head
        bone.matrix = matrix
        bpy.context.view_layer.update()
        actual_angles[name] = math.degrees(direction.angle((bone.tail - bone.head).normalized()))
    bpy.context.view_layer.update()
    distances = [(v - p).length for v, p in zip(evaluated_positions(), before)]
    finite = all(math.isfinite(d) for d in distances)
    if not finite or any(abs(actual_angles[n] - degrees) > .01 for n, degrees in targets.items()):
        raise ValueError("Joint probe failed to produce the requested finite bend")
    render(camera, evidence, "joint_probe", (3, -5, height / 2), (0, 0, height / 2), height * 1.3)
    for name, matrix in originals.items():
        rig.pose.bones[name].matrix_basis = matrix
    bpy.context.view_layer.update()
    return {"status": "rendered", "requested_bend_degrees": targets,
            "observed_bend_degrees": actual_angles, "finite_vertices": finite,
            "moved_vertices": sum(d > 1e-5 for d in distances), "max_displacement_m": max(distances),
            "rest_bone_lengths_unchanged": all(b.length == original_lengths[b.name] for b in rig.data.bones),
            "scope": "Two static joint probes, not animation or clothing acceptance."}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path)
    parser.add_argument("--private-dir", required=True, type=Path)
    parser.add_argument("--evidence-dir", required=True, type=Path)
    parser.add_argument("--reopen", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    private, evidence = args.private_dir.resolve(), args.evidence_dir.resolve()
    if not private.is_relative_to(ROOT / "build"):
        raise ValueError("Editable source must remain under this project's ignored build/.")
    private.mkdir(parents=True, exist_ok=True)
    evidence.mkdir(parents=True, exist_ok=True)
    blend = private / "candidate-studio.blend"
    if args.reopen:
        bpy.ops.wm.open_mainfile(filepath=str(blend), use_scripts=False)
        actual = inspect_character()
        original = json.loads((evidence / "audit.json").read_text())["character"]
        if actual != original:
            raise ValueError("Reopened character metrics or external textures changed")
        write_json(evidence / "reopen.json", {"metrics_identical": True, "blend_sha256": sha(blend)})
        print("CHARACTER_REOPEN_OK")
        return
    if not args.source or args.source.suffix.lower() != ".fbx":
        parser.error("--source must name an existing FBX")
    source = args.source.resolve(strict=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(source), use_anim=False)
    for obj in bpy.context.scene.objects:
        obj["review_character"] = True
    imported_images = [{"name": i.name, "size": list(i.size)} for i in bpy.data.images]
    prepare_materials(source)
    bpy.context.view_layer.update()
    character = inspect_character()
    meshes, rigs = character["meshes"], character["rigs"]
    if not meshes or not rigs:
        raise ValueError("Candidate lacks a mesh or skeleton")
    if any(m["invalid_weights"] or m["unweighted_vertices"] or not m["armatures"] for m in meshes):
        raise ValueError("Candidate has invalid/unassigned skeletal weights")
    if any(not i["exists"] or not all(i["size"]) for i in character["images"]):
        raise ValueError("Candidate is missing texture data")
    box = bounds([o for o in bpy.context.scene.objects if o.type == "MESH"])
    height = box["max"][2] - box["min"][2]
    camera = studio(box)
    mid = (box["max"][2] + box["min"][2]) / 2
    for name, position in [("front", (0, -5, mid)), ("side", (5, 0, mid)), ("back", (0, 5, mid))]:
        render(camera, evidence, name, position, (0, 0, mid), height * 1.2)
    head_z = box["max"][2] - height * .08
    render(camera, evidence, "face", (0, -4, head_z), (0, 0, head_z), height * .27)
    rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    probe = pose_probe(evidence, camera, rig, height)
    camera.location = (0, -5, mid)
    camera.data.ortho_scale = height * 1.2
    aim(camera, (0, 0, mid))
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    write_json(evidence / "audit.json", {
        "source_file": source.name, "source_sha256": sha(source),
        "tool_sha256": sha(Path(__file__)), "blender": bpy.app.version_string,
        "imported_images_before_material_rebuild": imported_images,
        "character": character, "pose_probe": probe,
        "material_mapping": {"diffuse": "sRGB", "normal": "Non-Color tangent, unchanged RGB",
                             "roughness": "1 - Non-Color gloss", "unused": "mask01/mask02: semantics unverified"},
        "blend_sha256": sha(blend), "game_export": False,
    })
    print("CHARACTER_SOURCE_REVIEW_OK")


if __name__ == "__main__":
    main()
