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

## \TODO toggle for track stretching
## \TODO toggle for delete_unused_imported_tracks
## \TODO allow EditorScenePostImport script
## \TODO toggle for aggressive?

tool
extends EditorImportPlugin

func get_name():
	return 'aseprite'

func get_visible_name():
	return "Aseprite sheet"

var Sheet
var SheetToScene
var dialog
var _base_control

const ERRMSG_PRETEXT =\
"""ERROR: """
const ERRMSG_POSTTEXT =\
"""\n\nImport canceled.\n"""
const ERRMSG_POSTCODE_STRF =\
""" (Code %d)"""
const ERRMSG_SHEET_PRETEXT_STRF =\
"""Sprite sheet file "%s" has invalid data:\n"""
const ERRMSG_MISSING_SCENE =\
"""Not handed a target path"""
const ERRMSG_MISSING_JSON =\
"""Not handed any JSON file"""
const ERRMSG_FILE_OPEN_STRF =\
"""Failed to open %s file "%s" for import"""
const ERRMSG_FILE_INVALID_STRF =\
"""File "%s" is not a valid %s file"""
const ERRMSG_PACKING_STRF =\
"""Packing scene "%s" failed"""
const ERRMSG_SAVE_STRF =\
"""Failed to save file "%s\""""
const ERRMSG_MERGE_PRETEXT_STRF =\
"""Merging sprite sheet scene "%s" failed\n"""
const WARNMSG_ANIMATION_EXPORT_STRF=\
"""File "%s" was exported without animations.
Enable "Meta: Frame Tags" in Aseprite's "Export Sprite Sheet" dialog to export frame tags as animations"""

func _warning( text ):
	_message( "Aseprite import warning", text )

func _error( text ):
	_message( "Aseprite import error", str( ERRMSG_PRETEXT, text, ERRMSG_POSTTEXT ))
	open_dialog()

func _message( title, text ):
	var msg_dialog = AcceptDialog.new()
	msg_dialog.set_title( title )
	msg_dialog.set_text( text )
	msg_dialog.connect( 'popup_hide', msg_dialog, 'queue_free' )
	_base_control.add_child( msg_dialog )
	msg_dialog.call_deferred( 'popup_centered_minsize' )

func _init( base_control ):
	_base_control = base_control

func _init_dialog():
	dialog = load('res://addons/aseprite-import/dialog.gd').new( _base_control )
	dialog.connect( 'import_confirmed', self, '_on_dialog_import_confirmed' )
	_base_control.add_child( dialog )

func _is_dialog_init():
	return dialog and dialog.get_script()

func open_dialog():
	if !_is_dialog_init(): _init_dialog()
	dialog.popup_centered_minsize(Vector2( dialog.MIN_WIDTH, 0 ))

func import_dialog( target_path ):
	if !_is_dialog_init(): _init_dialog()
	var json_path = null
	var tex_path = null
	if typeof(target_path) == TYPE_STRING and not target_path.empty():
		var old_import_meta = ResourceLoader.load_import_metadata( target_path )
#		target_path = target_path.basename() + '.scn'
		if old_import_meta:
			assert( old_import_meta.get_source_count() == 2 )
			var path1 = old_import_meta.get_source_path( 0 )
			if path1.extension() == 'json':
				json_path = expand_source_path( path1 )
				tex_path = expand_source_path( old_import_meta.get_source_path( 1 ))
			else:
				json_path = expand_source_path( old_import_meta.get_source_path( 1 ))
				tex_path = expand_source_path( path1 )
	dialog.setup( json_path, tex_path, target_path )
	open_dialog()

func _on_dialog_import_confirmed( source_path, texture_path, target_path ):
	var res_import = ResourceImportMetadata.new()
	res_import.add_source( validate_source_path( source_path ))
	if texture_path:
		res_import.add_source( validate_source_path( texture_path ))
	import( target_path, res_import )

func import( target_path, suggested_import_meta ):
	var source_count = suggested_import_meta.get_source_count()
	assert( 1 <= source_count and source_count <= 2 )
	
	var json_path
	var texture_path = null
	for i in range( suggested_import_meta.get_source_count() ):
		var source_path = suggested_import_meta.get_source_path( i )
		if source_path.extension() == 'json':
			json_path = expand_source_path( source_path )
		else:
			texture_path = expand_source_path( source_path )
	if json_path == null:
		_error( ERRMSG_MISSING_JSON )
		return ERR_INVALID_PARAMETER
	
	if typeof(target_path) != TYPE_STRING or target_path.empty() or target_path.extension() != 'scn':
		_error( ERRMSG_MISSING_SCENE )
		return ERR_INVALID_PARAMETER
	
	var file = File.new()
	var error = file.open( json_path, File.READ )
	if error != OK:
		if file.is_open(): file.close()
		_error( str( ERRMSG_FILE_OPEN_STRF % ["JSON", json_path], ERRMSG_POSTCODE_STRF % error ))
		import_dialog( null )
		return error
	
	if !Sheet: Sheet = load( 'res://addons/aseprite-import/sheet.gd' )
	var sheet = Sheet.new()
	error = sheet.parse_json( file.get_as_text() )
	file.close()
	if error != OK:
		_error(str( ERRMSG_SHEET_PRETEXT_STRF % json_path, sheet.get_error_message(), ERRMSG_POSTCODE_STRF % error ))
		return error
	if not sheet.is_animations_enabled():
		_warning( WARNMSG_ANIMATION_EXPORT_STRF % json_path )
	
	if !texture_path:
		texture_path = json_path.get_base_dir().plus_file( sheet.get_texture_filename() )
	if not file.file_exists( texture_path ):
		_error( ERRMSG_FILE_OPEN_STRF % ["texture", texture_path] )
		return ERR_FILE_NOT_FOUND
	var texture = load( texture_path )
	if not typeof(texture) == TYPE_OBJECT or not texture extends Texture:
		_error( ERRMSG_FILE_INVALID_STRF % [texture_path, "texture"] )
		return ERR_INVALID_DATA
	texture = texture.duplicate()
	
	var scene
	if file.file_exists( target_path ):
		scene = ResourceLoader.load( target_path )
		assert( scene extends PackedScene )
	else:
		scene = PackedScene.new()
	
	if !SheetToScene: SheetToScene = load( 'res://addons/aseprite-import/sheet2scene.gd' )
	var sheet2scene = SheetToScene.new()
	error = sheet2scene.merge( sheet, texture, scene )
	if error != OK:
		_error( str( ERRMSG_MERGE_PRETEXT_STRF % target_path, sheet2scene.get_error_message(), ERRMSG_POSTCODE_STRF % error ))
		return error
	
	var res_import = ResourceImportMetadata.new()
	res_import.add_source( validate_source_path( json_path ), file.get_md5( json_path ))
	res_import.add_source( validate_source_path( texture_path ), file.get_md5( texture_path ))
	res_import.set_editor( 'aseprite' )
	scene.set_import_metadata( res_import )
	texture.set_import_metadata( res_import )
	error = ResourceSaver.save( target_path, scene )
	if error != OK:
		_error( str( ERRMSG_SAVE_STRF % target_path, ERRMSG_POSTCODE_STRF % error ))
		return ERR_INVALID_PARAMETER
#	ResourceSaver.save( target_path.basename() + '.tex', texture )
