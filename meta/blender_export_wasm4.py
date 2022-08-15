bl_info = {
    "name": "Export WASM-4(.bytes)",
    "author": "HitchH1k3r",
    "version": (0, 1),
    "blender": (2, 80, 0),
    "location": "File > Export > WASM-4 (.bytes)",
    "description": "Export mesh to WASM-4 format (.bytes)",
    "warning": "",
    "category": "Import-Export"
}

import bpy
from bpy.props import BoolProperty #, IntProperty, EnumProperty
from bpy_extras.io_utils import ExportHelper
import time

def do_export(context, props, filepath):
    obj = context.active_object
    mesh = obj.data

    vert_buff = []
    norm_buff = []
    face_buff = []

    for poly in mesh.polygons:
        tri_buff = [poly.material_index]
        for index in poly.loop_indices:
            thisVertex = mesh.vertices[mesh.loops[index].vertex_index].co
            thisNormal = mesh.vertices[mesh.loops[index].vertex_index].normal
            i = 0
            found = 0
            for v in vert_buff:
                if(abs(v.x-thisVertex.x) <= max(1e-09 * max(abs(v.x), abs(thisVertex.x)), 0.0)):
                    if(abs(v.y-thisVertex.y) <= max(1e-09 * max(abs(v.y), abs(thisVertex.y)), 0.0)):
                        if(abs(v.z-thisVertex.z) <= max(1e-09 * max(abs(v.z), abs(thisVertex.z)), 0.0)):
                            if(not props.incl_norms or abs(norm_buff[i].x-thisNormal.x) <= max(1e-09 * max(abs(norm_buff[i].x), abs(thisNormal.x)), 0.0)):
                                if(not props.incl_norms or abs(norm_buff[i].y-thisNormal.y) <= max(1e-09 * max(abs(norm_buff[i].y), abs(thisNormal.y)), 0.0)):
                                    if(not props.incl_norms or abs(norm_buff[i].z-thisNormal.z) <= max(1e-09 * max(abs(norm_buff[i].z), abs(thisNormal.z)), 0.0)):
                                        tri_buff.append(int(i))
                                        found = 1
                                        break
                i+=1

            if(found==0):
                tri_buff.append(len(vert_buff))
                vert_buff.append(thisVertex)
                norm_buff.append(thisNormal)

        if(len(tri_buff) != 4):
            print('Export failed. The mesh must be triangulated.')
            return False

        if(len(vert_buff) > 128):
            print('Export failed. The mesh can have at most 128 verticies.')
            return False

        face_buff.append(tri_buff)


    with open(filepath, 'wb') as ofile:
        flags = 0
        if(props.incl_norms):
            flags |= 1
        ofile.write(bytearray([flags, len(vert_buff)]))
        i = 0
        for v in vert_buff:
            x = max(0, min(round(255 * v.x), 255))
            y = max(0, min(round(255 * v.z), 255))
            z = 255 - max(0, min(round(255 * v.y), 255))
            ofile.write(bytearray([x, y, z]))
            if(props.incl_norms):
                nx = max(0, min(round(255 * ( 0.5*norm_buff[i].x + 0.5)), 255))
                ny = max(0, min(round(255 * ( 0.5*norm_buff[i].z + 0.5)), 255))
                nz = max(0, min(round(255 * (-0.5*norm_buff[i].y + 0.5)), 255))
                ofile.write(bytearray([nx, ny, nz]))
            i += 1
        for tri in face_buff:
            buff = [tri[1], tri[2], tri[3]]
            buff[0] |= (tri[0] & 0b00000100) << (7-2)
            buff[1] |= (tri[0] & 0b00000010) << (7-1)
            buff[2] |= (tri[0] & 0b00000001) << (7-0)
            ofile.write(bytearray(buff))
        ofile.close()
    return {'FINISHED'}


class Export_SpaceGoose(bpy.types.Operator, ExportHelper):
    """My object export script"""
    bl_idname = "export_shape.wasm4"
    bl_label = "Export WASM-4 (.bytes)"

    filename_ext = ".bytes"

    incl_norms: BoolProperty(
        name="Include normals",
        description="Export vertext normals",
        default=False,)

    @classmethod
    def poll(cls, context):
        obj = context.active_object
        return (
            obj is not None
            and obj.type in {'MESH', 'CURVE', 'SURFACE', 'FONT'}
        )

    def execute(self, context):
        """if(context.active_object.mode == 'EDIT'):
            bpy.ops.object.mode_set(mode='OBJECT')"""

        start_time = time.time()
        print('\n_____START_____')
        props = self.properties
        filepath = self.filepath
        filepath = bpy.path.ensure_ext(filepath, self.filename_ext)

        exported = do_export(context, props, filepath)

        if exported:
            print('finished export in %s seconds' %
                  ((time.time() - start_time)))
            print(filepath)

        return {'FINISHED'}

    def invoke(self, context, event):
        wm = context.window_manager

        if True:
            # File selector
            wm.fileselect_add(self)  # will run self.execute()
            return {'RUNNING_MODAL'}
        elif True:
            # search the enum
            wm.invoke_search_popup(self)
            return {'RUNNING_MODAL'}
        elif False:
            # Redo popup
            return wm.invoke_props_popup(self, event)
        elif False:
            return self.execute(context)


# Add trigger into a dynamic menu
def menu_func_export(self, context):
    self.layout.operator(Export_SpaceGoose.bl_idname, text="WASM-4 Export (.bytes)")


def register():
    bpy.utils.register_class(Export_SpaceGoose)
    bpy.types.TOPBAR_MT_file_export.append(menu_func_export)


def unregister():
    bpy.utils.unregister_class(Export_SpaceGoose)
    bpy.types.TOPBAR_MT_file_export.remove(menu_func_export)


if __name__ == "__main__":
    register()
