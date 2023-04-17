GDPC                 0                                                                         T   res://.godot/exported/133200997/export-14584830dbc22d3f76a596eed5f4948e-node_3d.scn r      >p      K��fc{�U��\���R�    ,   res://.godot/global_script_class_cache.cfg                 ��Р�8���8~$}P�    L   res://.godot/imported/godot_game.png-4bcde959ee8b69fdb2ad84fe7ccea0f0.ctex  �5      -      �%�$����<�׿�+    D   res://.godot/imported/icon.svg-218a8f2b3041327d8a5756f3a245f83b.ctex�c      ^      2��r3��MgB�[79    D   res://.godot/imported/icon.svg-5acf970b50c2d9cf408de2ec4e209a9f.ctex0.      �      / �h���W�8���	��       res://.godot/uid_cache.bin  ��      �       _Dn�Y�����*(sO    (   res://HTML_export/godot_game.png.import c      �       ��nO5�����R       res://Player.gd P�      �      ��[d�9 ����Bz�    (   res://addons/curvemesh3d/curvemesh3d.gd         .      �;2��_Z�`��W�    (   res://addons/curvemesh3d/icon.svg.import�/      �       �)�O�����=��\    $   res://addons/curvemesh3d/plugin.gd  �0      %      \���>���}�A���       res://icon.svg  ��      N      ]��s�9^w/�����       res://icon.svg.import   @q      �       '�	���|j~�J�(-V       res://node_3d.tscn.remap�      d       �k�	���c{oo�       res://project.binaryp�      �      �b"�y-*��#�m�    ��<"list=Array[Dictionary]([])
���/# Copyright (C) 2022 Claudio Z. (cloudofoz)
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

@tool
extends Path3D

#---------------------------------------------------------------------------------------------------
# CONSTANTS
#---------------------------------------------------------------------------------------------------
const CM_HALF_PI = PI / 2.0

#---------------------------------------------------------------------------------------------------
# PUBLIC VARIABLES
#---------------------------------------------------------------------------------------------------
@export_category("CurveMesh3D")

## Sets the radius of the generated mesh
@export_range(0.001, 1.0, 0.0001, "or_greater") var radius: float = 0.1:
	set(value):
		radius = value
		curve_changed.emit()

## Use this [Curve] to modify the mesh radius
@export var radius_profile: Curve:
	set(value):
		radius_profile = value
		if(radius_profile != null):
			radius_profile.changed.connect(cm_on_curve_changed)
		curve_changed.emit()

## Number of vertices of a circular section.
## To increase the curve subdivisions you can change [Property: curve.bake_interval] instead.
@export_range(4, 64, 1) var radial_resolution: int = 8:
	set(value):
		radial_resolution = value
		curve_changed.emit()

## Material of the generated mesh surface
@export var material: StandardMaterial3D:
	set(value):
		material = value
		if(cm_mesh && cm_mesh.get_surface_count() > 0): 
			cm_mesh.surface_set_material(0, value)


@export_group("Caps", "cap_")

## If 'true' the generated mesh starts with an hemispherical surface
@export var cap_start: bool = true:
	set(value):
		cap_start = value
		curve_changed.emit()

## If 'true' the generated mesh ends with an hemispherical surface
@export var cap_end: bool = true:
	set(value):
		cap_end = value
		curve_changed.emit()
 
## Number of rings that are used to create the hemispherical cap
## note: the number of vertices of each ring depends on [radial_resolution]
@export_range(1, 32, 1, "or_greater") var cap_rings: int = 4:
	set(value):
		cap_rings = value
		curve_changed.emit()

## Scale caps UV coords by this factor
@export var cap_uv_scale: float = 0.1:
	set(value):
		cap_uv_scale = value
		curve_changed.emit()

## Shift caps UV coords by this offset 
@export var cap_uv_offset: Vector2 = Vector2.ZERO:
	set(value):
		cap_uv_offset = value
		curve_changed.emit()


@export_group("View", "cm_")

## Turn this off to disable mesh generation
@export var cm_enabled = true:
	set(value):
		cm_enabled = value
		if(!value): cm_clear()
		else: curve_changed.emit()

## If [cm_debug_mode=true] the node will draw only a run-time visibile curve
@export var cm_debug_mode = false:
	set(value):
		cm_debug_mode = value
		curve_changed.emit()

#---------------------------------------------------------------------------------------------------
# PRIVATE VARIABLES
#---------------------------------------------------------------------------------------------------

var cm_mesh_instance: MeshInstance3D = null
@export var cm_mesh: ArrayMesh = null
var cm_st: SurfaceTool = null

#---------------------------------------------------------------------------------------------------
# STATIC METHODS
#---------------------------------------------------------------------------------------------------

## creates a mat3x4 to align a point on a plane orthogonal to the direction
## note: geometry is firstly created on a XZ plane (normal: 0.0, 1.0, 0.0)
static func cm_get_aligned_transform(from: Vector3, to: Vector3, t: float) -> Transform3D:
	var up = Vector3.UP # normal of a XZ plane
	var direction = (to - from).normalized() 
	var center = from.move_toward(to, t)
	var axis = direction.cross(up).normalized()
	var angle = direction.angle_to(up)
	return Transform3D.IDENTITY.rotated(axis, angle).translated_local(-center)

static func cm_get_curve_length(plist: PackedVector3Array) -> float:
	var d = 0.0
	var pcount = plist.size()
	for i in range(0, pcount - 1):
		d += plist[i].distance_to(plist[i+1])
	return d

#---------------------------------------------------------------------------------------------------
# VIRTUAL METHODS
#---------------------------------------------------------------------------------------------------

func _ready() -> void:
	cm_clear_duplicated_internal_children()
	if(!cm_st): 
		cm_st = SurfaceTool.new()
	if(!cm_mesh): 
		cm_mesh = ArrayMesh.new()
	else: 
		cm_mesh.clear_surfaces()
	if(!cm_mesh_instance):
		cm_mesh_instance = MeshInstance3D.new()
		cm_mesh_instance.mesh = cm_mesh
		cm_mesh_instance.set_meta("__cm3d_internal__", true)
		add_child(cm_mesh_instance)
	if(!curve || curve.point_count < 2): 
		curve = cm_create_default_curve()
	if(!material): 
		material = cm_create_default_material()
	if(!radius_profile): 
		self.radius_profile = cm_create_default_radius_profile()
	curve_changed.connect(cm_on_curve_changed)
	curve_changed.emit()

#---------------------------------------------------------------------------------------------------
# CALLBACKS
#---------------------------------------------------------------------------------------------------

# rebuild when some property changes
func cm_on_curve_changed() -> void:
	if(!cm_enabled): return
	if(!cm_debug_mode): cm_build_curve()
	else: cm_debug_draw()

#---------------------------------------------------------------------------------------------------
# PRIVATE METHODS
#---------------------------------------------------------------------------------------------------

func cm_get_radius(t: float):
	if(!radius_profile || radius_profile.point_count == 0):
		return radius
	return radius * radius_profile.sample(t)

func cm_gen_circle_verts(t3d: Transform3D, t: float = 0.0):
	var rad_step: float = TAU / radial_resolution
	var center = Vector3.ZERO * t3d
	var r = cm_get_radius(t)
	for i in range(0, radial_resolution + 1):
		var k = i % radial_resolution
		var angle = k * rad_step
		var v = Vector3(r * cos(angle), 0.0, r * sin(angle)) * t3d
		cm_st.set_normal((v-center).normalized())
		cm_st.set_uv(Vector2(float(i) / radial_resolution, t))
		cm_st.add_vertex(v)

func cm_gen_curve_segment(start_ring_idx: int):
	# radial_resolution +1 because: first and last vertices are in the same position 
	# BUT have 2 different UVs: v_first = uv[0.0, y_coord] | v_last = uv[1.0, y_coord] 
	var ring_vtx_count = radial_resolution + 1 
	start_ring_idx *= ring_vtx_count
	for a in range(start_ring_idx, start_ring_idx + radial_resolution):
		var b = a + 1
		var d = a + ring_vtx_count
		var c = d + 1
		cm_st.add_index(a)
		cm_st.add_index(b)
		cm_st.add_index(c)
		cm_st.add_index(a)
		cm_st.add_index(c)
		cm_st.add_index(d)

func cm_gen_curve_segments_range(start_ring_idx: int, ring_count: int) -> int:
	for i in ring_count:
		cm_gen_curve_segment(start_ring_idx + i)
	return start_ring_idx + ring_count

# parametric eq. for hemisphere on a XZ plane:
#1. x = x0 + r * sin(beta) * cos(alpha)
#2. y = z0 + r * cos(beta)
#3. z = y0 + r * sin(beta) * sin(alpha)
#4. 0 <= beta  <= HALF_PI                 # "it's an hemisphere!"
#5. 0 <= alpha <= TAU                     # TAU = 2 * PI
func cm_gen_cap_verts(t3d: Transform3D, is_cap_start: bool):
	var alpha_step: float = TAU / radial_resolution
	var beta_step: float = CM_HALF_PI / cap_rings
	var c = Vector3.ZERO * t3d
	var r: float
	var beta_offset: float
	var beta_direction: float
	if is_cap_start:
			r = cm_get_radius(0.0)
			beta_offset = CM_HALF_PI
			beta_direction = +1.0
	else: #is_cap_end
			r = cm_get_radius(1.0)
			beta_offset = 0.0
			beta_direction = -1.0
	for ring_idx in range(cap_rings, -1, -1):
		var beta = beta_offset + ring_idx * beta_step * beta_direction
		var sin_beta = sin(beta)
		var cos_beta = cos(beta)
		for v_idx in (radial_resolution + 1):
			var alpha = (v_idx % radial_resolution) * alpha_step
			var v = Vector3(r * sin_beta * cos(alpha), r * cos_beta, r * sin_beta * sin(alpha)) * t3d
			cm_st.set_uv(Vector2(float(v_idx) / float(radial_resolution), 1.0) * sin_beta * cap_uv_scale + cap_uv_offset) 
			cm_st.set_normal((v-c).normalized())
			cm_st.add_vertex(v)

func cm_gen_vertices():
	if(!curve): return 0
	var plist = curve.get_baked_points() as PackedVector3Array
	var psize = plist.size()
	if(psize < 2): return 0
	var cur_length = 0.0
	var total_length = cm_get_curve_length(plist)
	var t3d = cm_get_aligned_transform(plist[0], plist[1], 0.0)
	if(cap_start): cm_gen_cap_verts(t3d, true)
	cm_gen_circle_verts(t3d, 0.0)
	for i in range(0, psize - 1):
		cur_length += plist[i].distance_to(plist[i + 1])
		t3d = cm_get_aligned_transform(plist[i], plist[i + 1], 1.0)
		cm_gen_circle_verts(t3d, min(cur_length / total_length, 1.0))
	if(cap_end): cm_gen_cap_verts(t3d, false)
	return psize

# The whole mesh could be generated by one call, like this:
# cm_gen_curve_segments_range(0, cap_rings * 2 + psize - 1).
# But, at the moment, the two caps have a different uv mapping than the curve mesh.
# For this reason caps don't share vertices with the main curve and so 
# we need 3 separated calls of 'cm_gen_curve_segments_range()':
# cap_start_mesh |+1| curve_mesh |+1| cap_end_mesh
# (+1 means that we "jump" to another set of vertices).
func cm_gen_faces(psize: int):
	var start_idx: int = 0
	if(cap_start):
		start_idx = cm_gen_curve_segments_range(0, cap_rings) + 1
	start_idx = cm_gen_curve_segments_range(start_idx, psize - 1) + 1
	if(cap_end):
		start_idx = cm_gen_curve_segments_range(start_idx, cap_rings) + 1

func cm_clear() -> bool:
	if(!cm_st || !cm_mesh): return false
	cm_st.clear()
	cm_mesh.clear_surfaces()
	return true

# commits the computed geometry to the mesh array
func cm_curve_to_mesh_array():
	cm_st.commit(cm_mesh)
	cm_mesh.surface_set_material(0, material)

func cm_build_curve():
	if(!cm_clear()): return
	cm_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var psize = cm_gen_vertices()
	if(psize < 2): return
	cm_gen_faces(psize)
	cm_curve_to_mesh_array()

func cm_debug_draw():
	if(!cm_clear()): return
	cm_st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	for v in curve.get_baked_points():
		cm_st.add_vertex(v)
	cm_curve_to_mesh_array()

func cm_create_default_curve() -> Curve3D:
	var c = Curve3D.new()
	var ctp = Vector3(0.6, 0.46, 0)
	c.add_point(Vector3.ZERO, ctp, ctp)
	c.add_point(Vector3.UP, -ctp, -ctp)
	c.bake_interval = 0.1
	return c

func cm_create_default_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.from_string("009de1", Color.LIGHT_SKY_BLUE)
	mat.roughness = 0.5
	return mat

func cm_create_default_radius_profile() -> Curve:
	var c = Curve.new()
	c.add_point(Vector2(0.0, 0.05))
#	c.add_point(Vector2(0.5, 0.5))
	c.add_point(Vector2(1.0, 1.0))
	return c

func cm_clear_duplicated_internal_children():
	for c in get_children(): 
		if(c.get_meta("__cm3d_internal__", false)):
			c.queue_free()
r(��u���GST2            ����                        �  RIFF|  WEBPVP8Lo  /����$Qw�{K��=۶���P���/�mc�Vl��m'��*#��tI�R�m���l���k0i���vK�TC��,�,�PLq�S�7�yA������W�$:3�2x��S���Q� ��O��2�Fd�ǁ�h ��ǝ$7\�����$
�b=��N4�9��� �|�DG7#���$)
��""���e���h����QG#��@f�h��� �Z�A' &���5X���A�y?#=�L|����$����C(�����l��@��!�,�"!�.��~t
�/������~t(&���@e�*Q�����~8꺬�� )4�(�^?
�b�^�y�x9
G(��I����  ddH�[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://c75unax6vwsjq"
path="res://.godot/imported/icon.svg-5acf970b50c2d9cf408de2ec4e209a9f.ctex"
metadata={
"vram_texture": false
}
 %mN�R�x�-p�f��p# Copyright (C) 2022 Claudio Z. (cloudofoz)
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type("CurveMesh3D", "Path3D", preload("curvemesh3d.gd"), preload("icon.svg"))
	

func _exit_tree() -> void:
	remove_custom_type("CurveMesh3D")
363����h_�GST2      X     ����                X       �,  RIFF�,  WEBPVP8L�,  /Õ�mۆq�����1�Ve���G�N^6۶�'�����L �	���������'�G�n$�V����p����̿���H�9��L߃�E۶c��ۘhd�1�Nc��6���I܁���[�(�#�m�9��'�mۦL���f�����~�=��!i�f��&�"�	Y���,�A����z����I�mmN����#%)Ȩ��b��P
��l"��m'���U�,���FQ�S�m�$�pD��жm�m۶m#�0�F�m�6����$I�3���s�������oI�,I�l���Cn����Bm&�*&sӹEP���|[=Ij[�m۝m��m���l۶m��g{gK�jm���$�vۦ�W=n�  q��I$Ij�	�J�x����U��޽�� I�i[up�m۶m۶m۶m۶m�ټ�47�$)Ι�j�E�|�C?����/�����/�����/�����/�����/�����/�����/�����̸k*�u����j_R�.�ΗԳ�K+�%�=�A�V0#��������3��[ނs$�r�H�9xޱ�	T�:T��iiW��V�`������h@`��w�L�"\�����@|�
a2�T� ��8b����~�z��'`	$� KśϾ�OS��	���;$�^�L����α��b�R鷺�EI%��9  �7� ,0 @Nk�p�Uu��R�����Ω��5p7�T�'`/p����N�گ�
�F%V�9;!�9�)�9��D�h�zo���N`/<T�����֡cv��t�EIL���t  �qw�AX�q �a�VKq���JS��ֱ؁�0F�A�
�L��2�ѾK�I%�}\ �	�*�	1���i.'���e.�c�W��^�?�Hg���Tm�%�o�
oO-  x"6�& `��R^���WU��N��" �?���kG�-$#���B��#���ˋ�銀�z֊�˧(J�'��c  ��� vNmŅZX���OV�5X R�B%an	8b!		e���6�j��k0C�k�*-|�Z  ��I� \���v  ��Qi�+PG�F������E%����o&Ӎ��z���k��;	Uq�E>Yt�����D��z��Q����tɖA�kӥ���|���1:�
v�T��u/Z�����t)�e����[K㡯{1<�;[��xK���f�%���L�"�i�����S'��󔀛�D|<�� ��u�={�����L-ob{��be�s�V�]���"m!��*��,:ifc$T����u@8 	!B}� ���u�J�_  ��!B!�-� _�Y ��	��@�����NV]�̀����I��,|����`)0��p+$cAO�e5�sl������j�l0 vB�X��[a��,�r��ς���Z�,| % ȹ���?;9���N�29@%x�.
k�(B��Y��_  `fB{4��V�_?ZQ��@Z�_?�	,��� � ��2�gH8C9��@���;[�L�kY�W�
*B@� 8f=:;]*LQ��D
��T�f=�` T����t���ʕ�￀�p�f�m@��*.>��OU�rk1e�����5{�w��V!���I[����X3�Ip�~�����rE6�nq�ft��b��f_���J�����XY�+��JI�vo9��x3�x�d�R]�l�\�N��˂��d�'jj<����ne������8��$����p'��X�v����K���~ � �q�V������u/�&PQR�m����=��_�EQ�3���#����K���r  ��J	��qe��@5՗�/# l:�N�r0u���>��ׁd��ie2� ���G'& �`5���s����'����[%9���ۓ�Хމ�\15�ƀ�9C#A#8%��=%�Z%y��Bmy�#�$4�)dA�+��S��N}��Y�%�Q�a�W��?��$�3x $��6��pE<Z�Dq��8���p��$H�< �֡�h�cާ���u�  �"Hj$����E%�@z�@w+$�	��cQ��
1�)��������R9T��v�-  xG�1�?����PO�}Eq�i�p�iJ@Q�=@�ݹ:t�o��{�d`5�����/W^�m��g���B~ h�  ����l  נ�6rߙ�����^�?r���   ���⤖��  �!��#�3\?��/  �ݝRG��\�9;6���}P6������K>��V̒=l��n)��p	 ����0n䯂���}   ���S*	 ��t%ͤ+@�����T�~��s����oL)�J� 0>��W�-  �*N�%x=�8ikfV^���3�,�=�,}�<Z��T�+'��\�;x�Y���=���`}�y�>0����/'ـ�!z9�pQ��v/ֶ�Ǜ����㗬��9r���}��D���ל���	{�y����0&�Q����W��y ����l��.�LVZ��C���*W��v����r���cGk�
^�Ja%k��S���D"j���2���RW/������ض1 ����
.bVW&�gr��U\�+���!���m ;+۞�&�6]�4R�/��Y�L�Ά`"�sl,Y/��x��|&Dv�_
Q*� V�NWYu�%��-�&D�(&��"  Wc��ZS���(�x� ,�!����!�L�AM�E�]}X�!��wB�o��-  �-���16���i���ю�z��� ���B��oB�0������v]���ȓ�����3�� +S�χ�=Q_�����˨�d��|)D>��k ��uȣ���Y[9̂�����! ^�!��r���j0Y+i��΍e(�ț� ���x��
��{��<6 R���پ�b��Y
C����+���������;���a ���,�o��bC�{�?���1 �(��¤ �V�������;�=��I��� ���EI���Z��)D����t=S ��] X��9K�= �.~�K[��Ŋ��,2��� p}>w<n�g h�
�t���R�u�G�1k���!��x���������� �L���|>D�0�Ǣ(Qc�� ����= �ۊ�Z0�^��c �
|�����L�%�d��q���(�WB� ��(	���� �J��8D�0�~$�Dsy�Ѿ!������j�^ ��mOa�8.�qce��s|%Dq~,X�u�������=T	���Q�M�ȣm�Y�%Y+�[�0|"DΞ�j�u�L6�(Qe��qw�V�э���ǂ���!j�K � �:�wQ�dÛ������R�
��C���X�u�`����\"j讀Dq21� �F>B[��[������]@K-���C�e�q�tWP�:W�۞X�z��,��t�p���P��Se����T���{dG��
KA���w�t3t��[ܘ�4^>�5ŉ�^�n�Eq�U��Ӎ��α�v�O6C�
�F%�+8eů��M����hk��w�欹񔈓����C��y訫���J�Is�����Po|��{�Ѿ)+~�W��N,�ů��޽���O��J�_�w��N8����x�?�=X��t�R�BM�8���VSyI5=ݫ�	-�� �ֶ��oV�����G������3��D��aEI��ZI5�݋����t��b��j��G����U���΃�C�������ق�в����b���}s����xkn��`5�����>��M�Ev�-�͇\��|�=� '�<ތ�Ǜ���<O�LM�n.f>Z�,~��>��㷾�����x8���<x�����h}��#g�ж��������d�1xwp�yJO�v�	TV����گ�.�=��N����oK_={?-����@/�~�,��m ��9r.�6K_=�7#�SS����Ao�"�,TW+I��gt���F�;S���QW/�|�$�q#��W�Ƞ(�)H�W�}u�Ry�#���᎞�ͦ�˜QQ�R_��J}�O���w�����F[zjl�dn�`$� =�+cy��x3������U�d�d����v��,&FA&'kF�Y22�1z�W!�����1H�Y0&Ӎ W&^�O�NW�����U����-�|��|&HW������"�q����� ��#�R�$����?�~���� �z'F��I���w�'&����se���l�̂L�����-�P���s��fH�`�M��#H[�`,,s]��T����*Jqã��ł�� )-|yč��G�^J5]���e�hk�l;4�O��� ���[�������.��������������xm�p�w�չ�Y��(s�a�9[0Z�f&^��&�ks�w�s�_F^���2΂d��RU� �s��O0_\읅�,���2t�f�~�'t�p{$`6���WĽU.D"j�=�d��}��}���S["NB�_MxQCA[����\	�6}7Y����K���K6���{���Z۔s�2 �L�b�3��T��ݹ����&'ks����ܓ�ЛϾ�}f��,�Dq&������s��ϼ��{������&'k�����Qw窭�_i�+x�6ڥ��f�{j)���ퟎƍ3ou�R�Y����徙�k����X�Z
m.Y+=Z��m3�L47�j�3o�=�!J
5s���(��A ��t)���N�]68�u< Ƞ��_�im>d ��z(���(��⤶�� �&�ۥ� ��  Vc�8�'��qo9 �t��i�ρdn��Of���O�RQP���h'������P֡���n ���č����k�K@�>����pH>z)-|��B��j���!j:�+������˧��t�������1����.`v�M�k�q#�$���N:�����-M5a10y����(�T��� X5 \�:� ?+�7#�?�*Y+-,s� ~�|\)뀀ap �drn�g��RN�X�er ��@ĕ���;��z��8ɱ�����	�- �
�bKc����kt�U]�䎚���hgu���|�_J{ �`p��o�p�T�U��p���/���Hϑ�H�$X ܬm3���ŉ�U'��뻩t��G9�}�)O������p�΃g���JO���\9�׫�����ڳ�!k����/��9R���^�%��C����T���;ji<�>�KY����;�J��ƶm .P��pT��
@HA��r��98V���b�v���YwaZ>�$oւ?-փ��ʹ|0�.��3���b駁�c��;?8E;���V�B�؀����|%\\s��%����e{o��Z�i�������^���s�Jx������B jh�\ �h�<��V��sh@:���.�ІYl��˂�`3hE.,P�2^����J��+�����p��
�ЊJd��x�*�@�7R��� �"�G="!�� �p����u�o��wV�m�g���~F��?����/�����}~����sо7� ���\,,k�J�T�6������Z�y�rBZ[D�>v�HQ�R��mq�������DD�-6+�V`���J�E�����\� 9!ߑ�`��6���ml�~ZM�Z�ȎV���g���������3?*u3���ctW����YQa�Cb�P�,B5�p0�m�cͺEt�{,��>s9f�^��`OG��]����2�Fk�9_�G�vd��	��)��=�1^Ų�Wl3{�����1��H)�e������9�هZ�]}�b���)b�C��es}�cVi~x���e
Z�)܃��39������C�(�+R����!�j����F�n���<?�p��l�8a�4xOb��������c�8&�UA�|	/l�8�8���3t�6�͏���v���� ����סy�wU��`� =��|M�Y?�'�A��&�@*�c~!�/{��),�>�=xr"	�qlF:��L&���=<5t�h.�#ᣭ���O�z�!�&`A�F�yK=�c<\GZ�� 4HG�0i�F녠uB"���<��c�Jeۈ�3!����O��q萞PiZ&�$M[���(G��e���ؤ���ã��O���5����'�gH~�����=��g�F|8�+�X�4�u���G�2����'��.��5[�OlB��$f4���`��mS�L�,y�t&V�#P�3{ ��763�7N���"��P��I�X��BgV�n�a:$:�FZ���'�7����f������z!�����KA�G��D#������ˑ`ڶs���&� ݱ��4�j��n�� ݷ�~s��F�pD�LE�q+wX;t,�i�y��Y��A�۩`p�m#�x�kS�c��@bVL��w?��C�.|n{.gBP�Tr��v1�T�;"��v����XSS��(4�Ύ�-T�� (C�*>�-
�8��&�;��f;�[Փ���`,�Y�#{�lQ�!��Q��ّ�t9����b��5�#%<0)-%	��yhKx2+���V��Z� �j�˱RQF_�8M���{N]���8�m��ps���L���'��y�Ҍ}��$A`��i��O�r1p0�%��茮�:;�e���K A��qObQI,F�؟�o��A�\�V�����p�g"F���zy�0���9"� �8X�o�v����ߕڄ��E �5�3�J�ص�Ou�SbVis�I���ص�Z���ڒ�X��r�(��w��l��r"�`]�\�B���Ija:�O\���/�*]�þR������|���ʑ@�����W�8f�lA���Xl��촻�K<�dq1+x�*U�;�'�Vnl`"_L�3�B����u�����M���'�!-�<;S�F�܊�bSgq� ���Xt�肦�a��RZ�Y_ި��ZRSGA��-:8����yw_}XW�Z���-k�g.U��|�7P�
&���$˳��+��~?7�k�bQ���g������~�Z�e����H�-p�7S�� 
�w"XK�`K%?�`Tr|p���"��\�a�?�٧ ��'u�cv�&��<LM�Ud��T���Ak��������'+7��XR`��[\�-0���e�AiW]�Dk���$u���0[?�-���L����X�ĚSK-�.%�9=j�3t^���(c�yM-��/�ao����\%�?�б �~���b][
tٵ�<qF�)�
�J�'QZY�����*pB�I4�޸�,������.Т�1���/
t�1-1������E�*��Cl/Ю©f�<,0�S�bf�^���[8Z$��@���kw�M<?�[`��)3)1� �U����:��/pR��XV`XE,/0���d���1>ѫ��i�z��*o�}&R{���$f�JV=5͉Ύ��Rl�/�N4.�U~Cm�N~��HPRS�?G��g�-���qvT{�G _�[ua�;���kco�9�Kw����n����E{d�j��C���,q����Y���cwY<$#�ؤ�m+�LL-�z� �y<{/7���[��X�?�-6(cO ?�XZ�M�������sb�[
�.����j|;d�!0lCIqZ�z�&��~�|7�A���A~��á@�� 417��}t ��,� X�6��lS)6v�G
��I:�).~��8R���#'��߶;9�'���U�$1nC�L��찦3�+b黙u�NJ�����8���X�?5�0��^��[B/+�0�Ur(��J��+Xr�H�����HZm&�#�p	�Y ����*���hM]��m���b�ݢ����G����s��z-�x��������� �J�"���Ћ�g�Ҝ �Aа��?��?6��c�Zx�$�t��{s
-R�E�24�?�{�l�-��1�3S�EJ��v6X]L�B^ ��]N��R�yN��62�����'R�p-�����n2�d�?Th|�h��3X������Rc8&��_,��;T�8�� �hΗv�(7I;�3Obn;��O�!����Lߍ*�E~wU,���n�MN1���Z��Y̖��tY;5�^�<Z�Ǩ�T#�bt�xfA�n�cq����"9GD*�^JL��HJ���4���V�-�܉��4*��u]�[
���,"ҏ�i!�r~L��_�����8 ]j�?x���<k+%w��Bk��=�u�ڤ��>%2Bۃ�Y�n<jBo������Κ�0M~�t>�#b/jZ�}���B��Q��#���6R$v�����k�R$c/:�~���(V�7;)��ߊ[̣0?F��;.�*ݪd������{A`w>~�i=D�c��������Y2�X�q~�r2��8@v=f�?��X��S�"X�j?��@$?�����x�(�k���c7��\�����>A�=fpM?9d?�׻{���)f�.⪝���3�������f,N;"��,N���X��*�"V���"��C��?���(2=���A��1�Ul���h�8Ao(5X�B�X�>S�j��s�!
l����GgGp��>�v;c���V�N1���-��K�S�=6PiN�fNq������,
�3SWx�ei����f'�*�r�rʹ̙�e�7���b�o���>_i��M�_��V�p�r�9��X�$�����B���t5�4#�B(E���3�������`����I�M�e��b6_����{~�f/��@��B��Y����E�4��޲�d�O�$���M�����ݖv�P����TR�oj~��+}��#���"�]1Υ_���nR���œ����^pQ2�7첾b��3�ba�\��uu2�~O�G�����5�^>v������m��?���mC;$eT��C񎋋��V��8�:��
���ʱlt��~e]�cC7dl���.�i����\w����/..F�Q5���œ��`�o���E����E�͛�ٽ-�o�z�"n��/��[�����ͳI���S��Dڢ��V�6��!��esq��AC���ڻ���OMk�y��{7`c0�ٺ���5C5�yiw��`ps�OC��f�X�5oQ�\_*m�f�)稹"���a2$O;�]C�A�;V.���c��iޢ�R5�X��t%�s����ȸ�; 5�����)��X|?����9&��wĽjdn�{��7��/����q]3Ɲ�}�[��yF~�Q0����x��U�� ���˘?����a�;���/yޫ�����6.��C}���&L��9�_�ս�w�o���W�^�;�^u�xoݖ��Q8����4��kW��'����:9>����Xp5H��ONtL��=��_�&�0��H"Q��|H���4!���]�'�!޹Eܢ���}=soϢ~	K�$���`"!]j�+{'e�M��D]��=�>c��xS��Y����X��7�7+�Me̯/���u�Q����i���Eg�9�g�RU��#'��ޑW\r�aS�/3�"/v
IgX���}ٻ���ʏr�r���_��<�6�Gʋ&���z%�Pl^d����㑭v�ʎو�w�[���Q��k�K�����IWˈ��`/�Y�X��9J"��_��V{��je�i��6�<�ZS��� �t���W�Bg��@5���..��X�eʡ��*�HRgkD^>�y裝"�9�+wQ4ABR������^�k3�>2�����x�C�l���f:��#gщ�s� ��ߜ��ȁ���+���A��˾�g�1K9Cܹ��:���T"!I������Hs�;���ue��9@#ChE5&!��'�2�����w*a/Q��I	�E������I�w�����?��v })B��GQ�n�h"]0��]Z֑���.}�&~x2��
eĞsF�n�+�b�e�i����0Ix�y��Aѕ���
[1�B�R$$����:�4E疳��#�4���y���ӈ�6o1O�V'��7]�H�.)/)�OwW./�g�l��£���"$d���}[���t���U~�MQԲ�$��~��c��S�M�a���ш=��diH��(N�+U�D����f"V�"�����.ƈ�#Ͼ�eH:�x��d!k 6�J�f9�GW�4����Kp��T��3��~��G�؀��,�zZ��澰؋7����v#� &�r+O�@Ud7͐�$�\�D�O��W_�Ew�ͻ�7��oD����y��,��Ƣ�cƙd	���U�u�:�#�h6]�R
�U~	V�՟R�V������/�:r�F¬�k?|Ī�r\�<.�^9����?��]Aʻ�iT;vg�PpyM���1��},�dY\e8��I��2�wjM��S/�p�1�\^�6$4�F��(:�\nۢ�2�}�Pm�X�'.����U�3��bq�nXK�i_BD�_H}�r;Y^�t�<���o��#gw��2q_�|�^�<��E�h���O�����R�-Ɖ���S�	!��z�1�+iH�1G���+<����~�;|�F�{�}v�;s�j�Q;�٩�;&f�}�������tL ���#��Ъ>;��z���?U˽�~������e��{K%��/:F�/<�n�2k�8�x��S-�5�`��ԗ�H�{���R�y�S�(w��ѥe
�	0���w�޻�U1��7V-Q�̶ꪸ�g�X��3V&�T[+)b����2���(���B��,��z����9���B`��!��o�ע(�W�RZ���m��%/V�&��|g��f��*[_��nn��M�M`�%��)��Z�K$�����F�� ��$r^�k�K,	u;w������X���;�L�eoI�6��y%����~����)���0"�zc�BH�<�kW�E\.�b��R>mٺ��<����͑Թ���a=2X���=/��_;	Ρ�e&o.����]��2!�嫈�"I������j�höR��͒\L�0�e������,)ýf�; ��E��0��<%�Q�Aø�x8�� �]eQL�;|���꼬z�W2
�H�z�_��
/K`J�O�O�Y�~j���>����d�v��%�ެ7�4{%��٥7Z��>����|��5^�\ױ���:��Z^;��U��s�)��#�|�.̡���R2��j����şBб���*cMvD�W^{�������m�D��0�,������#���?O����
����?z�{ȓ'�|����/�����/�����/�����/�����/�����/�����/�����/|� O����x���[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://ddxnuh0s13cp"
path="res://.godot/imported/godot_game.png-4bcde959ee8b69fdb2ad84fe7ccea0f0.ctex"
metadata={
"vram_texture": false
}
 �����̤*}GST2   �   �      ����               � �        &  RIFF  WEBPVP8L  /������!"2�H�l�m�l�H�Q/H^��޷������d��g�(9�$E�Z��ߓ���'3���ض�U�j��$�՜ʝI۶c��3� [���5v�ɶ�=�Ԯ�m���mG�����j�m�m�_�XV����r*snZ'eS�����]n�w�Z:G9�>B�m�It��R#�^�6��($Ɓm+q�h��6�4mb�h3O���$E�s����A*DV�:#�)��)�X/�x�>@\�0|�q��m֋�d�0ψ�t�!&����P2Z�z��QF+9ʿ�d0��VɬF�F� ���A�����j4BUHp�AI�r��ِ���27ݵ<�=g��9�1�e"e�{�(�(m�`Ec\]�%��nkFC��d���7<�
V�Lĩ>���Qo�<`�M�$x���jD�BfY3�37�W��%�ݠ�5�Au����WpeU+.v�mj��%' ��ħp�6S�� q��M�׌F�n��w�$$�VI��o�l��m)��Du!SZ��V@9ד]��b=�P3�D��bSU�9�B���zQmY�M~�M<��Er�8��F)�?@`�:7�=��1I]�������3�٭!'��Jn�GS���0&��;�bE�
�
5[I��=i�/��%�̘@�YYL���J�kKvX���S���	�ڊW_�溶�R���S��I��`��?֩�Z�T^]1��VsU#f���i��1�Ivh!9+�VZ�Mr�טP�~|"/���IK
g`��MK�����|CҴ�ZQs���fvƄ0e�NN�F-���FNG)��W�2�JN	��������ܕ����2
�~�y#cB���1�YϮ�h�9����m������v��`g����]1�)�F�^^]Rץ�f��Tk� s�SP�7L�_Y�x�ŤiC�X]��r�>e:	{Sm�ĒT��ubN����k�Yb�;��Eߝ�m�Us�q��1�(\�����Ӈ�b(�7�"�Yme�WY!-)�L���L�6ie��@�Z3D\?��\W�c"e���4��AǘH���L�`L�M��G$𩫅�W���FY�gL$NI�'������I]�r��ܜ��`W<ߛe6ߛ�I>v���W�!a��������M3���IV��]�yhBҴFlr�!8Մ�^Ҷ�㒸5����I#�I�ڦ���P2R���(�r�a߰z����G~����w�=C�2������C��{�hWl%��и���O������;0*��`��U��R��vw�� (7�T#�Ƨ�o7�
�xk͍\dq3a��	x p�ȥ�3>Wc�� �	��7�kI��9F}�ID
�B���
��v<�vjQ�:a�J�5L&�F�{l��Rh����I��F�鳁P�Nc�w:17��f}u}�Κu@��`� @�������8@`�
�1 ��j#`[�)�8`���vh�p� P���׷�>����"@<�����sv� ����"�Q@,�A��P8��dp{�B��r��X��3��n$�^ ��������^B9��n����0T�m�2�ka9!�2!���]
?p ZA$\S��~B�O ��;��-|��
{�V��:���o��D��D0\R��k����8��!�I�-���-<��/<JhN��W�1���(�#2:E(*�H���{��>��&!��$| �~�+\#��8�> �H??�	E#��VY���t7���> 6�"�&ZJ��p�C_j����	P:�~�G0 �J��$�M���@�Q��Yz��i��~q�1?�c��Bߝϟ�n�*������8j������p���ox���"w���r�yvz U\F8��<E��xz�i���qi����ȴ�ݷ-r`\�6����Y��q^�Lx�9���#���m����-F�F.-�a�;6��lE�Q��)�P�x�:-�_E�4~v��Z�����䷳�:�n��,㛵��m�=wz�Ξ;2-��[k~v��Ӹ_G�%*�i� ����{�%;����m��g�ez.3���{�����Kv���s �fZ!:� 4W��޵D��U��
(t}�]5�ݫ߉�~|z��أ�#%���ѝ܏x�D4�4^_�1�g���<��!����t�oV�lm�s(EK͕��K�����n���Ӌ���&�̝M�&rs�0��q��Z��GUo�]'G�X�E����;����=Ɲ�f��_0�ߝfw�!E����A[;���ڕ�^�W"���s5֚?�=�+9@��j������b���VZ^�ltp��f+����Z�6��j�`�L��Za�I��N�0W���Z����:g��WWjs�#�Y��"�k5m�_���sh\���F%p䬵�6������\h2lNs�V��#�t�� }�K���Kvzs�>9>�l�+�>��^�n����~Ěg���e~%�w6ɓ������y��h�DC���b�KG-�d��__'0�{�7����&��yFD�2j~�����ټ�_��0�#��y�9��P�?���������f�fj6͙��r�V�K�{[ͮ�;4)O/��az{�<><__����G����[�0���v��G?e��������:���١I���z�M�Wۋ�x���������u�/��]1=��s��E&�q�l�-P3�{�vI�}��f��}�~��r�r�k�8�{���υ����O�֌ӹ�/�>�}�t	��|���Úq&���ݟW����ᓟwk�9���c̊l��Ui�̸z��f��i���_�j�S-|��w�J�<LծT��-9�����I�®�6 *3��y�[�.Ԗ�K��J���<�ݿ��-t�J���E�63���1R��}Ғbꨝט�l?�#���ӴQ��.�S���U
v�&�3�&O���0�9-�O�kK��V_gn��k��U_k˂�4�9�v�I�:;�w&��Q�ҍ�
��fG��B��-����ÇpNk�sZM�s���*��g8��-���V`b����H���
3cU'0hR
�w�XŁ�K݊�MV]�} o�w�tJJ���$꜁x$��l$>�F�EF�޺�G�j�#�G�t�bjj�F�б��q:�`O�4�y�8`Av<�x`��&I[��'A�˚�5��KAn��jx ��=Kn@��t����)�9��=�ݷ�tI��d\�M�j�B�${��G����VX�V6��f�#��V�wk ��W�8�	����lCDZ���ϖ@���X��x�W�Utq�ii�D($�X��Z'8Ay@�s�<�x͡�PU"rB�Q�_�Q6  s�[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://dvn62x3bb1jj7"
path="res://.godot/imported/icon.svg-218a8f2b3041327d8a5756f3a245f83b.ctex"
metadata={
"vram_texture": false
}
 ݊z��Z�nl�X�|RSRC                     PackedScene            ��������                                            �      ..    CharacterBody3D3    CharacterBody3D4    CharacterBody3D5    resource_local_to_scene    resource_name    custom_solver_bias    margin    size    script    lightmap_size_hint 	   material    custom_aabb    flip_faces    add_uv2    uv2_padding    subdivide_width    subdivide_height    subdivide_depth    script/source    radius    height    radial_segments    rings    is_hemisphere    bake_interval    _data    point_count    up_vector_enabled 
   min_value 
   max_value    bake_resolution    render_priority 
   next_pass    transparency    blend_mode 
   cull_mode    depth_draw_mode    no_depth_test    shading_mode    diffuse_mode    specular_mode    disable_ambient_light    vertex_color_use_as_albedo    vertex_color_is_srgb    albedo_color    albedo_texture    albedo_texture_force_srgb    albedo_texture_msdf 	   metallic    metallic_specular    metallic_texture    metallic_texture_channel 
   roughness    roughness_texture    roughness_texture_channel    emission_enabled 	   emission    emission_energy_multiplier    emission_operator    emission_on_uv2    emission_texture    normal_enabled    normal_scale    normal_texture    rim_enabled    rim 	   rim_tint    rim_texture    clearcoat_enabled 
   clearcoat    clearcoat_roughness    clearcoat_texture    anisotropy_enabled    anisotropy    anisotropy_flowmap    ao_enabled    ao_light_affect    ao_texture 
   ao_on_uv2    ao_texture_channel    heightmap_enabled    heightmap_scale    heightmap_deep_parallax    heightmap_flip_tangent    heightmap_flip_binormal    heightmap_texture    heightmap_flip_texture    subsurf_scatter_enabled    subsurf_scatter_strength    subsurf_scatter_skin_mode    subsurf_scatter_texture &   subsurf_scatter_transmittance_enabled $   subsurf_scatter_transmittance_color &   subsurf_scatter_transmittance_texture $   subsurf_scatter_transmittance_depth $   subsurf_scatter_transmittance_boost    backlight_enabled 
   backlight    backlight_texture    refraction_enabled    refraction_scale    refraction_texture    refraction_texture_channel    detail_enabled    detail_mask    detail_blend_mode    detail_uv_layer    detail_albedo    detail_normal 
   uv1_scale    uv1_offset    uv1_triplanar    uv1_triplanar_sharpness    uv1_world_triplanar 
   uv2_scale    uv2_offset    uv2_triplanar    uv2_triplanar_sharpness    uv2_world_triplanar    texture_filter    texture_repeat    disable_receive_shadows    shadow_to_opacity    billboard_mode    billboard_keep_scale    grow    grow_amount    fixed_size    use_point_size    point_size    use_particle_trails    proximity_fade_enabled    proximity_fade_distance    msdf_pixel_range    msdf_outline_size    distance_fade_mode    distance_fade_min_distance    distance_fade_max_distance    _blend_shape_names 
   _surfaces    blend_shape_mode    shadow_mesh 	   _bundled       Script (   res://addons/curvemesh3d/curvemesh3d.gd ��������      local://BoxShape3D_uj1s8          local://BoxMesh_70p1k @         local://GDScript_icn0c l         local://GDScript_gmard b         local://CapsuleShape3D_bfyo8 @         local://SphereMesh_1j3dl w         local://Curve3D_xg8fh �         local://Curve_comf3 �      !   local://StandardMaterial3D_82f76 e         local://ArrayMesh_tnw32 �         local://BoxMesh_al04v �f         local://BoxShape3D_glfsb �f         local://PackedScene_nhr72 �f         BoxShape3D            �B  �?  �B	         BoxMesh            �B  �?  �B	      	   GDScript             PlayerController       �  extends Node3D

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	# Align Curve to Targets
	var alignment_force = 40
	var drag_force = 20
	var path_targets = get_node("PathTargets").get_children()
	var curvemesh: Curve3D = get_node("CurveMesh3D").curve
	for i in range(0, len(path_targets)):
		print(path_targets[i].global_position)
		curvemesh.set_point_position(i, path_targets[i].global_position)
	# Apply Alignment Force
	for i in range(1, len(path_targets)):
		var direction = path_targets[i].position.direction_to(path_targets[i-1].position)
		var distance = path_targets[i-1].position.distance_to(path_targets[i].position)
		var	target_pos = direction*(distance-0.2)
		var target_vel = (target_pos)*alignment_force
		path_targets[i].velocity = target_vel
		if not path_targets[i].is_on_floor():
			path_targets[i].velocity.y -= gravity*gravity * delta
		path_targets[i].move_and_slide()
	# Limit Distance
	
 	   GDScript          �  extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
    CapsuleShape3D          ��L=      ��L>	         SphereMesh          ���=      ��L>	         Curve3D          ���=               points #      ��?��>                                                      �?                                   @                                  �@              tilts !                               	         Curve             
          ?                            
   U�?  �?                            
     �?   ?                                     	         StandardMaterial3D    -          ��?��a?  �?5         ?	      
   ArrayMesh    �            	         format         
   primitive             vertex_data    p#  ��L��01      ���L��01E��"  ���L��01f��"  ���L��01E��"  ���L��01�,y  ���L��01E���  ���L��01f��  ���L��01E���  ���L��01      ��5=�C���    }%�Z�5=���]���]<H/[h�5=�1�
1D��<}%��5=���]<��]<H/���5=�E��<y�,"}%|��5=���]<��]��G��5=�1�
1D���  |��5=���]���]���P�5=�C���    }%�Z������    �?�?�����̼���<�J�Z���g�0��=�?�������<���<�J|������=E��"�?��������<��̼}%�����g�0���  �������̼��̼}%5������    �?�?E����5=�    �Z}%E��������= cND����e0�5==�Z�C�����=��= c�C����5==S��"�Z��C�����=����1��D����e0�5=�  ��E����������1�E����5=�    �Z}%�0���L�    �  g԰�����=��?e�a"g�a���L=��g�0��=��=����01��L=f��"���g�0��=�������h�a"�l)#��L�����g԰�������?  �0���L�    �  �0���L�    �  g԰�����=��?<�%�f�a���L=��g�0��=��=����01��L=f��"���g�0��=�������[��l)#��L�����g԰�������?  �0���L�    �  ��/=@�L�    �    0=���=��?  0=    @�L=��  0=�=�=��� 0=@�L=��"���  0=�=������  0=    @�L�����  0=������  ��/=@�L�    �    �==�M�    �    �=�l��l=��?  �=    =�M=��  �=�l=�l=���  �==�M=���"���  �=�l=�l�����  �=    =�M�����  �=�l��l���    �==�M�    �     >^9O�    �     >�����=��?   >    ^9O=��   >��=��=���   >^9O=��"���   >��=�������   >    ^9O�����   >��������     >^9O�    �   �m>�R�    �   �m>�����=��? �m>    �R=�� �m>��=��=��� �m>�R=��"��� �m>��=������� �m>    �R����� �m>��������   �m>�R�    �    �>�HV�    �    �>�����=��?  �>    �HV=��  �>��=��=���  �>�HV=�\�"���  �>��=�������  �>    �HV�����  �>��������    �>�HV�    �   @�>z\�    �   @�>���=��? @�>    z\=�� @�>�=�=��� @�>z\=C��"��� @�>�=������ @�>    z\����� @�>������   @�>z\�    �     ?C.c�    �     ?� �� =��?   ?    C.c=��   ?� =� =���   ?C.c='��"���   ?� =� �����   ?    C.c�����   ?� �� ���     ?C.c�    �   �?.`k�    �   �?�o&��o&=��? �?    .`k=�� �?�o&=�o&=��� �?.`k=�#��� �?�o&=�o&����� �?    .`k����� �?�o&��o&���   �?.`k�    �    /?>2t�    �    /??�,�?�,=��?  /?    >2t=��  /??�,=?�,=���  /?>2t=v�#���  /??�,=?�,�����  /?    >2t�����  /??�,�?�,���    /?>2t�    �   �D?N}�    �   �D?R�2�R�2=��? �D?    N}=�� �D?R�2=R�2=��� �D?N}='�#��� �D?R�2=R�2����� �D?    N}����� �D?R�2�R�2���   �D?N}�    �    X?ʂ�    �    X?��8���8=��?  X?    ʂ=��  X?��8=��8=���  X?ʂ=�C#���  X?��8=��8�����  X?    ʂ�����  X?��8���8���    X?ʂ�    �   `h?���    �   `h?39>�39>=��? `h?    ��=�� `h?39>=39>=��� `h?��=�]#��� `h?39>=39>����� `h?    ������� `h?39>�39>���   `h?���    �    u?Bs��    �    u?LbB�LbB=��?  u?    Bs�=��  u?LbB=LbB=���  u?Bs�=��#���  u?LbB=LbB�����  u?    Bs������  u?LbB�LbB���    u?Bs��    �    �?���    �    �?VF�VF=��?  �?    ��=��  �?VF=VF=���  �?��=�|#���  �?VF=VF�����  �?    �������  �?VF�VF���    �?���    �   ��?���    �   ��?��I���I=��? ��?    ��=�� ��?��I=��I=��� ��?��=�f#��� ��?��I=��I����� ��?    ������� ��?��I���I���   ��?���    �   Ћ?�Ñ�    �   Ћ?x$N�x$N=��? Ћ?    �Ñ=�� Ћ?x$N=x$N=��� Ћ?�Ñ=Q� #��� Ћ?x$N=x$N����� Ћ?    �Ñ����� Ћ?x$N�x$N���   Ћ?�Ñ�    �    �?Ǖ�    �    �?8�S�8�S=��?  �?    Ǖ=��  �?8�S=8�S=���  �?Ǖ=f5%#���  �?8�S=8�S�����  �?    Ǖ�����  �?8�S�8�S���    �?Ǖ�    �   ��?���    �   ��?a�Z�a�Z=��? ��?    ��=�� ��?a�Z=a�Z=��� ��?��=Jy*#��� ��?a�Z=a�Z����� ��?    ������� ��?a�Z�a�Z���   ��?���    �   ��?@ޟ�    �   ��?ub�ub=��? ��?    @ޟ=�� ��?ub=ub=��� ��?@ޟ=�V0#��� ��?ub=ub����� ��?    @ޟ����� ��?ub�ub���   ��?@ޟ�    �   �?m|��    �   �?Xj�Xj=��? �?    m|�=�� �?Xj=Xj=��� �?m|�=�6#��� �?Xj=Xj����� �?    m|������ �?Xj�Xj���   �?m|��    �    �?�%��    �    �?�	r��	r=��?  �?    �%�=��  �?�	r=�	r=���  �?�%�=��<#���  �?�	r=�	r�����  �?    �%������  �?�	r��	r���    �?�%��    �   ��?���    �   ��?4�y�4�y=��? ��?    ��=�� ��?4�y=4�y=��� ��?��=��B#��� ��?4�y=4�y����� ��?    ������� ��?4�y�4�y���   ��?���    �   ��?����    �   ��?Ik��Ik�=��? ��?    ���=�� ��?Ik�=Ik�=��� ��?���=�RH#��� ��?Ik�=Ik������ ��?    �������� ��?Ik��Ik����   ��?����    �   P�?.��    �   P�?$���$��=��? P�?    .�=�� P�?$��=$��=��� P�?.�=(,M#��� P�?$��=$������� P�?    .������ P�?$���$�����   P�?.��    �    �?���    �    �?�����=��?  �?    ��=��  �?��=��=���  �?��=y4Q#���  �?��=�������  �?    �������  �?��������    �?���    �   0�?V���    �   0�?J!��J!�=��? 0�?    V��=�� 0�?J!�=J!�=��� 0�?V��=�YT#��� 0�?J!�=J!������ 0�?    V������� 0�?J!��J!����   0�?V���    �   ��?��½    �   ��?ؑ��ؑ�=��? ��?    ���=�� ��?ؑ�=ؑ�=��� ��?���=�V#��� ��?ؑ�=ؑ������ ��?    ��½���� ��?ؑ��ؑ����   ��?��½    �     @�3Ľ    �     @`���`��=��?   @    �3�=��   @`��=`��=���   @�3�=�jX#���   @`��=`�������   @    �3Ľ����   @`���`�����     @�3Ľ    �   �@�ǽ    �   �@I͌�I͌=��? �@    ��=�� �@I͌=I͌=��� �@��=��[#��� �@I͌=I͌����� �@    �ǽ���� �@I͌�I͌���   �@�ǽ    �   �@��ɽ    �   �@�������=��? �@    ���=�� �@���=���=��� �@���=:�^#��� �@���=�������� �@    ��ɽ���� �@����������   �@��ɽ    �   �@g˽    �   �@g���g��=��? �@    g�=�� �@g��=g��=��� �@g�=��_#��� �@g��=g������� �@    g˽���� �@g���g�����   �@g˽    �    @!̽    �    @YK��YK�=��?  @    !�=��  @YK�=YK�=���  @!�=Ja#���  @YK�=YK������  @    !̽����  @YK��YK����    @!̽    �   �@w�̽    �   �@O���O��=��? �@    w��=�� �@O��=O��=��� �@w��=��a#��� �@O��=O������� �@    w�̽���� �@O���O�����   �@w�̽    �   �@�̽    �   �@q���q��=��? �@    ��=�� �@q��=q��=��� �@��=��a#��� �@q��=q������� �@    �̽���� �@q���q�����   �@�̽    �   �"@�H˽    �   �"@M���M��=��? �"@    �H�=�� �"@M��=M��=��� �"@�H�=D:`#��� �"@M��=M������� �"@    �H˽���� �"@M���M�����   �"@�H˽    �   �(@�AȽ    �   �(@�������=��? �(@    �A�=�� �(@���=���=��� �(@�A�=��\#��� �(@���=�������� �(@    �AȽ���� �(@����������   �(@�AȽ    �   6.@�ý    �   6.@�[���[�=��? 6.@    ��=�� 6.@�[�=�[�=��� 6.@��=��W#��� 6.@�[�=�[������ 6.@    �ý���� 6.@�[���[����   6.@�ý    �   4@.���    �   4@H��H�=��? 4@    .��=�� 4@H�=H�=��� 4@.��=|3Q#��� 4@H�=H������ 4@    .������� 4@H��H����   4@.���    �   :@=t��    �   :@�����=��? :@    =t�=�� :@��=��=��� :@=t�=w@I#��� :@��=������� :@    =t������ :@��������   :@=t��    �    @@�R��    �    @@�v��v=��?  @@    �R�=��  @@�v=�v=���  @@�R�=�H@#���  @@�v=�v�����  @@    �R������  @@�v��v���    @@�R��    �   �E@���    �   �E@�,j��,j=��? �E@    ��=�� �E@�,j=�,j=��� �E@��=]�6#��� �E@�,j=�,j����� �E@    ������� �E@�,j��,j���   �E@���    �   �K@���    �   �K@�m]��m]=��? �K@    ��=�� �K@�m]=�m]=��� �K@��=��,#��� �K@�m]=�m]����� �K@    ������� �K@�m]��m]���   �K@���    �   �Q@���    �   �Q@��P���P=��? �Q@    ��=�� �Q@��P=��P=��� �Q@��=��"#��� �Q@��P=��P����� �Q@    ������� �Q@��P���P���   �Q@���    �   �W@
��    �   �W@��D���D=��? �W@    
�=�� �W@��D=��D=��� �W@
�=H]#��� �W@��D=��D����� �W@    
������ �W@��D���D���   �W@
��    �   ]@���    �   ]@�g9��g9=��? ]@    ��=�� ]@�g9=�g9=��� ]@��=��#��� ]@�g9=�g9����� ]@    ������� ]@�g9��g9���   ]@���    �   Pb@�x�    �   Pb@�e/��e/=��? Pb@    �x=�� Pb@�e/=�e/=��� Pb@�x=��#��� Pb@�e/=�e/����� Pb@    �x����� Pb@�e/��e/���   Pb@�x�    �   Rg@�k�    �   Rg@��&���&=��? Rg@    �k=�� Rg@��&=��&=��� Rg@�k=U#��� Rg@��&=��&����� Rg@    �k����� Rg@��&���&���   Rg@�k�    �    l@8b�    �    l@;��;�=��?  l@    8b=��  l@;�=;�=���  l@8b=J�"���  l@;�=;������  l@    8b�����  l@;��;����    l@8b�    �   Np@SJZ�    �   Np@�Z��Z=��? Np@    SJZ=�� Np@�Z=�Z=��� Np@SJZ=���"��� Np@�Z=�Z����� Np@    SJZ����� Np@�Z��Z���   Np@SJZ�    �   0t@`�T�    �   0t@�_��_=��? 0t@    `�T=�� 0t@�_=�_=��� 0t@`�T=S��"��� 0t@�_=�_����� 0t@    `�T����� 0t@�_��_���   0t@`�T�    �   �z@��N�    �   �z@U�U=��? �z@    ��N=�� �z@U=U=��� �z@��N=���"��� �z@U=U����� �z@    ��N����� �z@U�U���   �z@��N�    �    �@��L�    �    �@�����=��?  �@    ��L=��  �@��=��=���  �@��L=f��"���  �@��=�������  �@    ��L�����  �@��������    �@��L�    �    �@��L=    ���  �@��=�������  �@    ��L�����  �@��������    �@��L�f���    �@�����=��?  �@    ��L=��  �@��=��=���  �@��L=    ������@�5==    |��ڿ��@��=���~��⿜�@ �e��5=���}%���@������~�����@�5=�S�Т|�}%���@�����=��N���@ �e��5==|�����@��=��=������@�5==    |��ڢ!�@��=    �����!�@���<��̼���ʢ!�@�g԰������?�!�@��̼��̼��5�!�@���E������?�!�@��̼���<��Z�!�@�g԰��=����!�@���<���<�|��!�@��=    ����lz�@C��<    ��|�lz�@��]<��]�Z�G�lz�@@�
�D������Zlz�@��]���]�Z�Plz�@E���y�,��ڂZlz�@��]���]<��[hlz�@@�
�D��<���lz�@��]<��]<�У�lz�@C��<    ��|����@ 1�    ������@ 1�    ������@ 1�    ������@ 1�    ������@ 1�    ������@ 1�    ������@ 1�    ������@ 1�    ������@ 1�    ���      vertex_count    7        attribute_data    �      g�a#g��!g�a#g�a"g�a#�l�"g�a#g��"g�a# 0#g�a#�l)#g�a#��E#g�a#g�a#g�a#    D�=D��;D�=D�<D�=�k<D�=D��<D�=��<D�=��<D�=['	=D�=D�=D�=    �А=��<�А=�А<�А=#9�<�А=��=�А=�5=�А=#9Y=�А=Um}=�А=�А=�А=    �5�=�5=<�5�=�5�<�5�=k�=�5�=�5==�5�=_�l=�5�=k�=�5�=(��=�5�=�5�=�5�=    ���=��L<���=���<���=��=���=��L=���=  �=���=���=���=33�=���=���=���=           >      �>      �>       ?       ?      @?      `?      �?          0<   >  0<  �>  0<  �>  0<   ?  0<   ?  0<  @?  0<  `?  0<  �?  0<      �<   >  �<  �>  �<  �>  �<   ?  �<   ?  �<  @?  �<  `?  �<  �?  �<       =   >   =  �>   =  �>   =   ?   =   ?   =  @?   =  `?   =  �?   =     �m=   > �m=  �> �m=  �> �m=   ? �m=   ? �m=  @? �m=  `? �m=  �? �m=      �=   >  �=  �>  �=  �>  �=   ?  �=   ?  �=  @?  �=  `?  �=  �?  �=     @�=   > @�=  �> @�=  �> @�=   ? @�=   ? @�=  @? @�=  `? @�=  �? @�=       >   >   >  �>   >  �>   >   ?   >   ?   >  @?   >  `?   >  �?   >     �>   > �>  �> �>  �> �>   ? �>   ? �>  @? �>  `? �>  �? �>      />   >  />  �>  />  �>  />   ?  />   ?  />  @?  />  `?  />  �?  />     �D>   > �D>  �> �D>  �> �D>   ? �D>   ? �D>  @? �D>  `? �D>  �? �D>      X>   >  X>  �>  X>  �>  X>   ?  X>   ?  X>  @?  X>  `?  X>  �?  X>     `h>   > `h>  �> `h>  �> `h>   ? `h>   ? `h>  @? `h>  `? `h>  �? `h>      u>   >  u>  �>  u>  �>  u>   ?  u>   ?  u>  @?  u>  `?  u>  �?  u>      �>   >  �>  �>  �>  �>  �>   ?  �>   ?  �>  @?  �>  `?  �>  �?  �>     ��>   > ��>  �> ��>  �> ��>   ? ��>   ? ��>  @? ��>  `? ��>  �? ��>     Ћ>   > Ћ>  �> Ћ>  �> Ћ>   ? Ћ>   ? Ћ>  @? Ћ>  `? Ћ>  �? Ћ>      �>   >  �>  �>  �>  �>  �>   ?  �>   ?  �>  @?  �>  `?  �>  �?  �>     ��>   > ��>  �> ��>  �> ��>   ? ��>   ? ��>  @? ��>  `? ��>  �? ��>     ��>   > ��>  �> ��>  �> ��>   ? ��>   ? ��>  @? ��>  `? ��>  �? ��>     �>   > �>  �> �>  �> �>   ? �>   ? �>  @? �>  `? �>  �? �>      �>   >  �>  �>  �>  �>  �>   ?  �>   ?  �>  @?  �>  `?  �>  �?  �>     ��>   > ��>  �> ��>  �> ��>   ? ��>   ? ��>  @? ��>  `? ��>  �? ��>     ��>   > ��>  �> ��>  �> ��>   ? ��>   ? ��>  @? ��>  `? ��>  �? ��>     P�>   > P�>  �> P�>  �> P�>   ? P�>   ? P�>  @? P�>  `? P�>  �? P�>      �>   >  �>  �>  �>  �>  �>   ?  �>   ?  �>  @?  �>  `?  �>  �?  �>     0�>   > 0�>  �> 0�>  �> 0�>   ? 0�>   ? 0�>  @? 0�>  `? 0�>  �? 0�>     ��>   > ��>  �> ��>  �> ��>   ? ��>   ? ��>  @? ��>  `? ��>  �? ��>       ?   >   ?  �>   ?  �>   ?   ?   ?   ?   ?  @?   ?  `?   ?  �?   ?     �?   > �?  �> �?  �> �?   ? �?   ? �?  @? �?  `? �?  �? �?     �?   > �?  �> �?  �> �?   ? �?   ? �?  @? �?  `? �?  �? �?     �?   > �?  �> �?  �> �?   ? �?   ? �?  @? �?  `? �?  �? �?      ?   >  ?  �>  ?  �>  ?   ?  ?   ?  ?  @?  ?  `?  ?  �?  ?     �?   > �?  �> �?  �> �?   ? �?   ? �?  @? �?  `? �?  �? �?     �?   > �?  �> �?  �> �?   ? �?   ? �?  @? �?  `? �?  �? �?     �"?   > �"?  �> �"?  �> �"?   ? �"?   ? �"?  @? �"?  `? �"?  �? �"?     �(?   > �(?  �> �(?  �> �(?   ? �(?   ? �(?  @? �(?  `? �(?  �? �(?     6.?   > 6.?  �> 6.?  �> 6.?   ? 6.?   ? 6.?  @? 6.?  `? 6.?  �? 6.?     4?   > 4?  �> 4?  �> 4?   ? 4?   ? 4?  @? 4?  `? 4?  �? 4?     :?   > :?  �> :?  �> :?   ? :?   ? :?  @? :?  `? :?  �? :?      @?   >  @?  �>  @?  �>  @?   ?  @?   ?  @?  @?  @?  `?  @?  �?  @?     �E?   > �E?  �> �E?  �> �E?   ? �E?   ? �E?  @? �E?  `? �E?  �? �E?     �K?   > �K?  �> �K?  �> �K?   ? �K?   ? �K?  @? �K?  `? �K?  �? �K?     �Q?   > �Q?  �> �Q?  �> �Q?   ? �Q?   ? �Q?  @? �Q?  `? �Q?  �? �Q?     �W?   > �W?  �> �W?  �> �W?   ? �W?   ? �W?  @? �W?  `? �W?  �? �W?     ]?   > ]?  �> ]?  �> ]?   ? ]?   ? ]?  @? ]?  `? ]?  �? ]?     Pb?   > Pb?  �> Pb?  �> Pb?   ? Pb?   ? Pb?  @? Pb?  `? Pb?  �? Pb?     Rg?   > Rg?  �> Rg?  �> Rg?   ? Rg?   ? Rg?  @? Rg?  `? Rg?  �? Rg?      l?   >  l?  �>  l?  �>  l?   ?  l?   ?  l?  @?  l?  `?  l?  �?  l?     Np?   > Np?  �> Np?  �> Np?   ? Np?   ? Np?  @? Np?  `? Np?  �? Np?     0t?   > 0t?  �> 0t?  �> 0t?   ? 0t?   ? 0t?  @? 0t?  `? 0t?  �? 0t?     �z?   > �z?  �> �z?  �> �z?   ? �z?   ? �z?  @? �z?  `? �z?  �? �z?      �?   >  �?  �>  �?  �>  �?   ?  �?   ?  �?  @?  �?  `?  �?  �?  �?    ��̽��L���̽��̼��̽�����̽��L���̽  ����̽������̽33����̽��̽��̽    �5���5=��5���5���5��k���5���5=��5��_�l��5��k荽�5��(����5���5���5��    �А�����А��А��А�#9ټ�А�����А��5��А�#9Y��А�Um}��А��А��А�    D��D���D��D��D���k�D��D���D���üD����D��['	�D��D��D��                                                                              aabb    ��L��̽�̽33�@��L>��L>      index_data    �     
   
 	      
                                     	 
  	   
   
                                                                         !  !     "  " !   #  # "   %  % $   &  & %   '  ' &   (  ( '    )  ) (   ! *   * ) ! " + ! + * " # , " , + - . 7 - 7 6 . / 8 . 8 7 / 0 9 / 9 8 0 1 : 0 : 9 1 2 ; 1 ; : 2 3 < 2 < ; 3 4 = 3 = < 4 5 > 4 > = 6 7 @ 6 @ ? 7 8 A 7 A @ 8 9 B 8 B A 9 : C 9 C B : ; D : D C ; < E ; E D < = F < F E = > G = G F ? @ I ? I H @ A J @ J I A B K A K J B C L B L K C D M C M L D E N D N M E F O E O N F G P F P O H I R H R Q I J S I S R J K T J T S K L U K U T L M V L V U M N W M W V N O X N X W O P Y O Y X Q R [ Q [ Z R S \ R \ [ S T ] S ] \ T U ^ T ^ ] U V _ U _ ^ V W ` V ` _ W X a W a ` X Y b X b a Z [ d Z d c [ \ e [ e d \ ] f \ f e ] ^ g ] g f ^ _ h ^ h g _ ` i _ i h ` a j ` j i a b k a k j c d m c m l d e n d n m e f o e o n f g p f p o g h q g q p h i r h r q i j s i s r j k t j t s l m v l v u m n w m w v n o x n x w o p y o y x p q z p z y q r { q { z r s | r | { s t } s } | u v  u  ~ v w � v �  w x � w � � x y � x � � y z � y � � z { � z � � { | � { � � | } � | � � ~  � ~ � �  � �  � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � � �  �  � � � �  � � � � � � � � � � � � � � � � � � �  	� 	 
 
	
		
	

!! ""!##"$$#%%$&&%''&((' !* *)!"+!+*"#,",+#$-#-,$%.$.-%&/%/.&'0&0/'(1'10)*3)32*+4*43+,5+54,-6,65-.7-76./8.87/09/9801:0:923<2<;34=3=<45>4>=56?5?>67@6@?78A7A@89B8BA9:C9CB;<E;ED<=F<FE=>G=GF>?H>HG?@I?IH@AJ@JIABKAKJBCLBLKDENDNMEFOEONFGPFPOGHQGQPHIRHRQIJSISRJKTJTSKLUKUTMNWMWVNOXNXWOPYOYXPQZPZYQR[Q[ZRS\R\[ST]S]\TU^T^]VW`V`_WXaWa`XYbXbaYZcYcbZ[dZdc[\e[ed\]f\fe]^g]gf_`i_ih`aj`jiabkakjbclblkcdmcmldendnmefoeonfgpfpohirhrqijsisrjktjtsklukutlmvlvumnwmwvnoxnxwopyoyxqr{q{zrs|r|{st}s}|tu~t~}uvu~vw�v�wx�w��xy�x��z{�z��{|�{��|}�|��}~�}��~�~�������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������������� � ����������������������� 	�	

  !! ""!##"$$#&&%''&((' ))( !* *)!"+!+*"#,",+#$-#-,%&/%/.&'0&0/'(1'10()2(21)*3)32*+4*43+,5+54,-6,65      index_count    @     	   material          	         BoxMesh    	         BoxShape3D    	         PackedScene    �      	         names "         Node3D    DirectionalLight3D 
   transform    shadow_enabled    StaticBody3D    CollisionShape3D    shape    MeshInstance3D    mesh    Node    script    PathTargets    CharacterBody3D    visible 	   Camera3D    fov    CharacterBody3D3 	   skeleton    CharacterBody3D4    CharacterBody3D5    CharacterBody3D2    CurveMesh3D    curve    radius_profile 	   material    cm_mesh    Path3D    StaticBody3D2    	   variants          kQ?���>צ?    o�`����>��?��Ⱦ�n7�    �Γ@K�BA                     �?              �?              �?v�����=#=                       �?              �?              �?    �2�?                                           �?            г]?   ?       �г]?    ��>�F�?     �B     �?              �?              �?�n�?��@                          �?              �?              �?M�@�2l@                                           �?              �?              �?M@�2�?                                               	        �?              �?              �?    �^�>          
                  node_count             nodes       ��������        ����                      ����                                  ����                     ����                          ����                               	   ����   
                        ����                     ����         
                       ����                          ����      	      
                    ����                                ����                          ����                          ����      	      
                          ����                          ����                          ����      	      
                          ����                          ����                          ����      	      
                          ����                          ����                          ����      	      
                    ����         
                                          ����                          ����                          ����                   conn_count              conns               node_paths              editable_instances              version       	      RSRC��extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	move_and_slide()
�[remap]

path="res://.godot/exported/133200997/export-14584830dbc22d3f76a596eed5f4948e-node_3d.scn"
�Y%{��X-]]�<svg height="128" width="128" xmlns="http://www.w3.org/2000/svg"><g transform="translate(32 32)"><path d="m-16-32c-8.86 0-16 7.13-16 15.99v95.98c0 8.86 7.13 15.99 16 15.99h96c8.86 0 16-7.13 16-15.99v-95.98c0-8.85-7.14-15.99-16-15.99z" fill="#363d52"/><path d="m-16-32c-8.86 0-16 7.13-16 15.99v95.98c0 8.86 7.13 15.99 16 15.99h96c8.86 0 16-7.13 16-15.99v-95.98c0-8.85-7.14-15.99-16-15.99zm0 4h96c6.64 0 12 5.35 12 11.99v95.98c0 6.64-5.35 11.99-12 11.99h-96c-6.64 0-12-5.35-12-11.99v-95.98c0-6.64 5.36-11.99 12-11.99z" fill-opacity=".4"/></g><g stroke-width="9.92746" transform="matrix(.10073078 0 0 .10073078 12.425923 2.256365)"><path d="m0 0s-.325 1.994-.515 1.976l-36.182-3.491c-2.879-.278-5.115-2.574-5.317-5.459l-.994-14.247-27.992-1.997-1.904 12.912c-.424 2.872-2.932 5.037-5.835 5.037h-38.188c-2.902 0-5.41-2.165-5.834-5.037l-1.905-12.912-27.992 1.997-.994 14.247c-.202 2.886-2.438 5.182-5.317 5.46l-36.2 3.49c-.187.018-.324-1.978-.511-1.978l-.049-7.83 30.658-4.944 1.004-14.374c.203-2.91 2.551-5.263 5.463-5.472l38.551-2.75c.146-.01.29-.016.434-.016 2.897 0 5.401 2.166 5.825 5.038l1.959 13.286h28.005l1.959-13.286c.423-2.871 2.93-5.037 5.831-5.037.142 0 .284.005.423.015l38.556 2.75c2.911.209 5.26 2.562 5.463 5.472l1.003 14.374 30.645 4.966z" fill="#fff" transform="matrix(4.162611 0 0 -4.162611 919.24059 771.67186)"/><path d="m0 0v-47.514-6.035-5.492c.108-.001.216-.005.323-.015l36.196-3.49c1.896-.183 3.382-1.709 3.514-3.609l1.116-15.978 31.574-2.253 2.175 14.747c.282 1.912 1.922 3.329 3.856 3.329h38.188c1.933 0 3.573-1.417 3.855-3.329l2.175-14.747 31.575 2.253 1.115 15.978c.133 1.9 1.618 3.425 3.514 3.609l36.182 3.49c.107.01.214.014.322.015v4.711l.015.005v54.325c5.09692 6.4164715 9.92323 13.494208 13.621 19.449-5.651 9.62-12.575 18.217-19.976 26.182-6.864-3.455-13.531-7.369-19.828-11.534-3.151 3.132-6.7 5.694-10.186 8.372-3.425 2.751-7.285 4.768-10.946 7.118 1.09 8.117 1.629 16.108 1.846 24.448-9.446 4.754-19.519 7.906-29.708 10.17-4.068-6.837-7.788-14.241-11.028-21.479-3.842.642-7.702.88-11.567.926v.006c-.027 0-.052-.006-.075-.006-.024 0-.049.006-.073.006v-.006c-3.872-.046-7.729-.284-11.572-.926-3.238 7.238-6.956 14.642-11.03 21.479-10.184-2.264-20.258-5.416-29.703-10.17.216-8.34.755-16.331 1.848-24.448-3.668-2.35-7.523-4.367-10.949-7.118-3.481-2.678-7.036-5.24-10.188-8.372-6.297 4.165-12.962 8.079-19.828 11.534-7.401-7.965-14.321-16.562-19.974-26.182 4.4426579-6.973692 9.2079702-13.9828876 13.621-19.449z" fill="#478cbf" transform="matrix(4.162611 0 0 -4.162611 104.69892 525.90697)"/><path d="m0 0-1.121-16.063c-.135-1.936-1.675-3.477-3.611-3.616l-38.555-2.751c-.094-.007-.188-.01-.281-.01-1.916 0-3.569 1.406-3.852 3.33l-2.211 14.994h-31.459l-2.211-14.994c-.297-2.018-2.101-3.469-4.133-3.32l-38.555 2.751c-1.936.139-3.476 1.68-3.611 3.616l-1.121 16.063-32.547 3.138c.015-3.498.06-7.33.06-8.093 0-34.374 43.605-50.896 97.781-51.086h.066.067c54.176.19 97.766 16.712 97.766 51.086 0 .777.047 4.593.063 8.093z" fill="#478cbf" transform="matrix(4.162611 0 0 -4.162611 784.07144 817.24284)"/><path d="m0 0c0-12.052-9.765-21.815-21.813-21.815-12.042 0-21.81 9.763-21.81 21.815 0 12.044 9.768 21.802 21.81 21.802 12.048 0 21.813-9.758 21.813-21.802" fill="#fff" transform="matrix(4.162611 0 0 -4.162611 389.21484 625.67104)"/><path d="m0 0c0-7.994-6.479-14.473-14.479-14.473-7.996 0-14.479 6.479-14.479 14.473s6.483 14.479 14.479 14.479c8 0 14.479-6.485 14.479-14.479" fill="#414042" transform="matrix(4.162611 0 0 -4.162611 367.36686 631.05679)"/><path d="m0 0c-3.878 0-7.021 2.858-7.021 6.381v20.081c0 3.52 3.143 6.381 7.021 6.381s7.028-2.861 7.028-6.381v-20.081c0-3.523-3.15-6.381-7.028-6.381" fill="#fff" transform="matrix(4.162611 0 0 -4.162611 511.99336 724.73954)"/><path d="m0 0c0-12.052 9.765-21.815 21.815-21.815 12.041 0 21.808 9.763 21.808 21.815 0 12.044-9.767 21.802-21.808 21.802-12.05 0-21.815-9.758-21.815-21.802" fill="#fff" transform="matrix(4.162611 0 0 -4.162611 634.78706 625.67104)"/><path d="m0 0c0-7.994 6.477-14.473 14.471-14.473 8.002 0 14.479 6.479 14.479 14.473s-6.477 14.479-14.479 14.479c-7.994 0-14.471-6.485-14.471-14.479" fill="#414042" transform="matrix(4.162611 0 0 -4.162611 656.64056 631.05679)"/></g></svg>
�^   *�Hb!   res://addons/curvemesh3d/icon.svg�oU��!    res://HTML_export/godot_game.pngvoU�Η5x   res://icon.svg�)�Fڳ�1   res://node_3d.tscn��ǚ>�5��ECFG      application/config/name         New Game Project   application/run/main_scene         res://node_3d.tscn     application/config/features(   "         4.0    GL Compatibility       application/config/icon         res://icon.svg     dotnet/project/assembly_name         New Game Project   editor_plugins/enabled0   "      $   res://addons/curvemesh3d/plugin.cfg *   rendering/renderer/rendering_method.mobile         gl_compatibility��^�
x�=x!�a�