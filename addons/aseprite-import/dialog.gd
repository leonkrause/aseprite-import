# Copyright (c) eska <eska@eska.me>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

tool
extends ConfirmationDialog

signal import_confirmed( json_path, texture_path, target_path )

const MIN_WIDTH = 500
var _vb
var _json_edit
var _texture_edit
var _target_edit
#var _texture_display
var _base_control

var _proxy = EditorImportPlugin.new()

func validate_source_path( abs_path ):
	return _proxy.validate_source_path( abs_path )

func _init( base_control ):
	_base_control = base_control
	set_title( "Aseprite sheet import" )
	get_ok().set_text( "Import" )
	connect( 'confirmed', self, '_on_confirmed' )
	
	_vb = VBoxContainer.new()
	add_child( _vb )
#	set_child_rect( _vb ) # not exposed, so:
	var label = get_label()
	for i in range(4):
		_vb.set_anchor_and_margin( i, label.get_anchor(i), label.get_margin(i) )
	label.hide()
	
	_add_section_header( "Source" )
	
	var json_controls = _add_path_edit( "Sprite sheet JSON:" \
	, EditorFileDialog.ACCESS_FILESYSTEM, false, '*.json;'+"Aseprite sheet JSON" )
	_json_edit = json_controls.edit
	
	var tex_controls = _add_path_edit( "Sprite sheet texture (only if directory differs):" \
	, EditorFileDialog.ACCESS_FILESYSTEM, false \
	, _get_extensions_hint_for_type( 'Texture' ) + ';' + "Sprite sheet texture" )
	_texture_edit = tex_controls.edit
	tex_controls.tween = Tween.new()
	tex_controls.hb.add_child( tex_controls.tween )
	connect( 'visibility_changed', self, '_on_visibility_changed', [tex_controls] )
	_texture_edit.connect( 'text_changed', self, '_update_tex_edit', [tex_controls] )
	_texture_edit.connect( 'focus_enter', self, '_update_tex_edit', [' ', tex_controls] ) # not empty
	_texture_edit.connect( 'focus_exit', self, '_update_tex_edit', [null, tex_controls] )
	tex_controls.dialog.connect( 'file_selected', self, '_update_tex_edit', [tex_controls] )
	
	var sep = HSeparator.new()
	sep.set_opacity( 0 )
	_vb.add_child( sep )
	_add_section_header( "Target" )
	
	var target_controls = _add_path_edit( "Scene:" \
	, EditorFileDialog.ACCESS_RESOURCES,  true,  '*.scn;'+"Scene" )
	_target_edit = target_controls.edit
	
#	var out_tex_controls = _add_path_edit( "Texture (same path as scene):", 0,  true, '' )
#	out_tex_controls.edit.set_editable( false )
#	out_tex_controls.edit.set_focus_mode( FOCUS_NONE )
#	out_tex_controls.button.hide()
#	out_tex_controls.dialog.hide()
#	_texture_display = out_tex_controls.edit
	
#	_target_edit.connect( 'text_changed', self, '_update_target_texture' )
#	_texture_display.connect( 'visibility_changed', self, '_update_target_texture', [null] )
#	target_controls.dialog.connect( 'file_selected', self, '_update_target_texture' )

const DISABLED_GUI_OPACITY = 0.55
var last_tweened_towards_enabled = true

func _on_visibility_changed( tex_controls ):
	last_tweened_towards_enabled = not tex_controls.edit.get_text().empty()
	tex_controls.hb.set_opacity( [DISABLED_GUI_OPACITY, 1.0][0+last_tweened_towards_enabled] )

func _update_tex_edit( text, tex_controls ):
	if typeof( text ) != TYPE_STRING:
		text = _texture_edit.get_text()
	var duration = 0.3
	if tex_controls.tween.get_runtime() != 0:
		duration = tex_controls.tween.tell()
	
	var direction = null
	if text.empty() and not tex_controls.edit.has_focus():# and not tex_controls.dialog.is_visible():
		if last_tweened_towards_enabled:
			last_tweened_towards_enabled = false
			direction = Tween.EASE_IN
	elif not last_tweened_towards_enabled:
		last_tweened_towards_enabled = true
		direction = Tween.EASE_OUT
	
	if direction != null:
		tex_controls.tween.remove_all()
		tex_controls.tween.interpolate_property( tex_controls.hb \
		, 'visibility/opacity', tex_controls.hb.get_opacity() \
		, [DISABLED_GUI_OPACITY, 1.0][direction], duration, Tween.TRANS_LINEAR \
		, direction )
		tex_controls.tween.start()

#func _update_target_texture( scene_path ):
#	if scene_path == null:
#		scene_path = _target_edit.get_text()
#	if not scene_path.ends_with( '.scn' ):
#		_texture_display.clear()
#	else:
#		_texture_display.set_text( scene_path.basename() + '.tex' )

func _get_extensions_hint_for_type( string ):
	var hint = ''
	for ext in ResourceLoader.get_recognized_extensions_for_type( string ):
		hint += '*.%s,' % ext
	hint.erase( hint.length() - 1, 1 )
	return hint

func _add_path_edit( label, access, save, filters ):
	var path_edit = {}
	path_edit.label = Label.new()
	path_edit.label.set_text( label )
	_vb.add_child( path_edit.label )
	
	var margin_container = MarginContainer.new()
	_vb.add_child( margin_container )
	path_edit.hb = HBoxContainer.new()
	margin_container.add_child( path_edit.hb )
	
	path_edit.edit = LineEdit.new()
	path_edit.edit.set_h_size_flags( SIZE_EXPAND_FILL )
	path_edit.hb.add_child( path_edit.edit )
	
	path_edit.button = Button.new()
	path_edit.button.set_text( " .. " )
	path_edit.hb.add_child( path_edit.button )
	
	path_edit.dialog = EditorFileDialog.new()
	path_edit.button.connect( 'pressed', path_edit.dialog, 'popup_centered_ratio' )
	path_edit.dialog.set_access( access )
	if typeof(filters) == TYPE_ARRAY:
		for filter in filters: path_edit.dialog.add_filter( filter )
	else:
		path_edit.dialog.add_filter( filters )
	path_edit.dialog.set_mode( [EditorFileDialog.MODE_OPEN_FILE,EditorFileDialog.MODE_SAVE_FILE][0+save] )
	if access == EditorFileDialog.ACCESS_FILESYSTEM:
		path_edit.dialog.connect( 'file_selected', self, '_set_validated_path', [path_edit.edit] )
	else:
		path_edit.dialog.connect( 'file_selected', path_edit.edit, 'set_text' )
		
	_base_control.add_child( path_edit.dialog )
	return path_edit

func _add_section_header( name ):
	var hb = HBoxContainer.new()
	_vb.add_child( hb )
	var sep = HSeparator.new()
	sep.set_h_size_flags( SIZE_EXPAND_FILL )
	hb.add_child( sep )
	var label = Label.new()
	label.set_text( name )
	hb.add_child( label )
	sep = sep.duplicate()
	hb.add_child( sep )

func _set_validated_path( path, edit ):
	edit.set_text( validate_source_path( path ) )

func _on_confirmed():
	emit_signal( 'import_confirmed', _json_edit.get_text() \
	, _texture_edit.get_text(), _target_edit.get_text() )

func setup( source_path, tex_path, target_path ):
	if source_path != null:
		_set_validated_path( source_path, _json_edit )
	if tex_path != null:
		_set_validated_path( tex_path, _texture_edit )
	if target_path != null:
		_target_edit.set_text( target_path )
