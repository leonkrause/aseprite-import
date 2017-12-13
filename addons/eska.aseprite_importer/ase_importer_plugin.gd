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
## \TODO toggle for aggressive?

tool
extends EditorImportPlugin

var Sheet = preload('sheet.gd')
var SheetToScene = preload('sheet2scene.gd')

const ERRMSG_POSTCODE_STRF =\
""" (Code %d)"""
const ERRMSG_SHEET_PRETEXT_STRF =\
"""Sprite sheet file "%s" has invalid data:\n"""
const ERRMSG_FILE_OPEN_STRF =\
"""Failed to open %s file "%s" for import"""
const ERRMSG_FILE_INVALID_STRF =\
"""File "%s" is not a valid %s file"""
const ERRMSG_SAVE_STRF =\
"""Failed to save file "%s\""""
const ERRMSG_MERGE_PRETEXT_STRF =\
"""Merging sprite sheet scene "%s" failed\n"""
const WARNMSG_ANIMATION_EXPORT_STRF=\
"""File "%s" was exported without animations.
Enable "Meta: Frame Tags" in Aseprite's "Export Sprite Sheet" dialog to export frame tags as animations"""


const PLUGIN_NAME = "eska.aseprite_importer"

func get_importer_name():
	return PLUGIN_NAME

func get_visible_name():
	return "Aseprite Spritesheet"

func get_recognized_extensions():
	return ["json"]

func get_save_extension():
	return "scn"

func get_resource_type():
	return "PackedScene"

func get_option_visibility(option, options):
	return true

func get_preset_count():
	return 1

func get_preset_name(preset):
	return "Default"

func get_import_options(preset):
	var options =  [
		{
			name = "sheet_image",
			default_value = "",
			property_hint = PROPERTY_HINT_FILE,
			hint_string = "*.png",
			#tooltip = "Absolute path to the spritesheet .png, if its path differs from the .json after stripping extensions.",
		},
		{
			name = "post_script",
			default_value = "",
			property_hint = PROPERTY_HINT_FILE,
			hint_string = "*.gd",
			#tooltip = "Absolute path to a post script .gd file. The .gd file will have its post_import(scene) method called and is expected to return the changed scene.",
		},
		{
			name = "autoplay_animation",
			default_value = "",
			#tooltip = "The name of the animation to autoplay on scene load.",
		},
	]
	
	return options

func import(src, target_path, import_options, r_platform_variants, r_gen_files):
	var json_path = src
	var texture_path = import_options.sheet_image
	target_path = target_path + "." + get_save_extension()
	var post_script_path = import_options.post_script
	var autoplay_name = import_options.autoplay_animation
	
	var file = File.new()
	var error
	if post_script_path != "":
		error = file.open( post_script_path, File.READ )
		if error != OK:
			post_script_path = ""
		file.close()
	
	error = file.open( json_path, File.READ )
	if error != OK:
		file.close()
		print( str( ERRMSG_FILE_OPEN_STRF % ["JSON", json_path], ERRMSG_POSTCODE_STRF % error ))
		return error
	
	var sheet = Sheet.new()
	error = sheet.parse_json( file.get_as_text() )
	file.close()
	if error != OK:
		print(str( ERRMSG_SHEET_PRETEXT_STRF % json_path, sheet.get_error_message(), ERRMSG_POSTCODE_STRF % error ))
		return error
	if not sheet.is_animations_enabled():
		print( WARNMSG_ANIMATION_EXPORT_STRF % json_path )
	
	if texture_path == "":
		texture_path = json_path.get_basename() + ".png"
	
	if not file.file_exists( texture_path ):
		print( ERRMSG_FILE_OPEN_STRF % ["texture", texture_path] )
		return ERR_FILE_NOT_FOUND
	var texture = load( texture_path )
	if not typeof(texture) == TYPE_OBJECT or not texture is Texture:
		print( ERRMSG_FILE_INVALID_STRF % [texture_path, "texture"] )
		return ERR_INVALID_DATA
	
	## This code is only useful if someone wishes to manually edit the .scn file in the .import directory, which is not recommended.
#	var scene
#
#	if file.file_exists( target_path ):
#		scene = load( target_path )
#		assert( scene is PackedScene )
#	else:
	var packed_scene = PackedScene.new()
	
	var sheet2scene = SheetToScene.new()
	error = sheet2scene.merge( sheet, texture, packed_scene, post_script_path, autoplay_name )
	if error != OK:
		print( str( ERRMSG_MERGE_PRETEXT_STRF % target_path, sheet2scene.get_error_message(), ERRMSG_POSTCODE_STRF % error ))
		return error
	
	error = ResourceSaver.save( target_path, packed_scene )
	if error != OK:
		print( str( ERRMSG_SAVE_STRF % target_path, ERRMSG_POSTCODE_STRF % error ))
		return ERR_INVALID_PARAMETER
	
	return OK
