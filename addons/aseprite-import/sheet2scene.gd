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

## \TODO try harder to find correct AnimationPlayer and Sprite nodes
var delete_unused_imported_tracks = false

tool

const Sheet = preload('res://addons/aseprite-import/sheet.gd')

const TRACK_PATH_REGION_RECT= ':region_rect'

const ERRMSG_INCOMPATIBLE_STRF = \
"""Target scene has unmergable changes: %s"""

var _error_message = "No error message available"

func get_error_message():
	return _error_message

## \TODO no longer needed
static func _inherit_properties( parent, child ):
	for prop in parent.get_property_list():
		if child.has( prop.name ):
			child.set( prop.name, parent.get( prop.name ) )

## \TODO no longer needed
static func _adopt_children( parent, adopter ):
	for child in parent.get_children():
		parent.remove_child( child )
		adopter.add_child( child )

func _cleanup( scene ):
	scene.call_deferred( 'free' )

## \TODO no longer needed
func get_parent_path_to( node ):
	var root = node.get_parent()
	if !root:
		return node.get_name()
	while root.get_parent():
		root = root.get_parent()
	return str( root.get_name(), '/', root.get_path_to( node ) )

static func _stretch_animation_track( animation, track, length ):
	if animation.get_length() == length: return
	for key_index in range( animation.track_get_key_count( track ) ):
		var time = animation.track_get_key_time( track, key_index )
		var value = animation.track_get_key_value( track, key_index )
		var transition = animation.track_get_key_transition( track, key_index )
		animation.track_remove_key( track, key_index )
		time *= length / animation.get_length()
		animation.track_insert_key( track, time, value, transition )

func merge( sheet, texture, packed_scene, aggressive=false ):
	assert( typeof(sheet) == TYPE_OBJECT and sheet extends Sheet )
	assert( typeof(texture) == TYPE_OBJECT and texture extends Texture )
	assert( typeof(packed_scene) == TYPE_OBJECT and packed_scene extends PackedScene )
	
	var scene = null
	var sprite = null
	var player = null
	if packed_scene.can_instance():
		scene = packed_scene.instance()
		for child in scene.get_children():
			if !sprite and child extends Sprite:
				sprite = child
			if !player and child extends AnimationPlayer:
				player = child
			if player and sprite: break
	else:
		scene = Node2D.new()
	if !sprite:
		sprite = Sprite.new()
		scene.add_child( sprite, true )
		sprite.set_owner( scene )
	
	if sprite.get_texture() != texture:
		sprite.set_texture( texture )
	sprite.set_region_rect( sheet.get_frame( 0 ).rect )
	sprite.set_region( true )
	
	var error
	if sheet.is_animations_enabled():
		if !player:
			player = AnimationPlayer.new()
			scene.add_child( player, true )
			player.set_owner( scene )
		var track_path_sprite = player.get_node( player.get_root() ).get_path_to( sprite )
		var track_path = str( track_path_sprite, TRACK_PATH_REGION_RECT )
		if delete_unused_imported_tracks:
			_remove_invalid_imported_animations( player, sheet.get_animation_names(), track_path )
		error = _merge_animations( player, track_path, sheet, aggressive )
		if error != OK:
			_cleanup( scene )
			return error
	
	error = packed_scene.pack( scene )
	_cleanup( scene )
	return error

func _remove_invalid_imported_animations( player, valid_anims, imported_track_path ):
	for anim_name in player.get_animation_list():
		if anim_name in valid_anims:
			continue
		var anim = player.get_animation( anim_name )
		var imported_track_path = anim.find_track( imported_track_path )
		if imported_track_path != -1 and anim.track_is_imported( imported_track_path ):
			player.remove_animation( anim_name )

func _merge_animations( player, track_path, sheet, aggressive ):
	for anim_name in sheet.get_animation_names():
		var anim
		if player.has_animation( anim_name ):
			anim = player.get_animation( anim_name )
		else:
			anim = Animation.new()
			anim.set_loop( true )
			player.add_animation( anim_name, anim )
		
		var new_length = sheet.get_animation_length( anim_name ) / 1000
		var old_length = anim.get_length()
		
		var sequence = sheet.get_animation( anim_name )
		var error = _merge_animation_track( sequence, anim, track_path )
		if error != OK: return error
		
		for track_index in range( anim.get_track_count() ):
			if anim.track_get_path( track_index ) != track_path:
				_stretch_animation_track( anim, track_index, new_length )
		anim.set_length( new_length )
	return OK

func _merge_animation_track( sequence, anim, track_path ):
	var track = anim.find_track( track_path )
	if track == -1:
		track = anim.add_track( Animation.TYPE_VALUE, 0 )
		anim.track_set_path( track, track_path )
		anim.track_set_interpolation_type( track, Animation.INTERPOLATION_NEAREST )
		anim.value_track_set_update_mode( track, Animation.UPDATE_DISCRETE )
	else:
		if anim.track_get_type( track ) != Animation.TYPE_VALUE:
			_error_message = ERRMSG_INCOMPATIBLE_STRF % str( "Differing track type in track ", track_path )
			return ERR_INVALID_PARAMETER
	
	while anim.track_get_key_count( track ):
		anim.track_remove_key( track, 0 )
	
	var time = 0
	for frame in sequence:
		anim.track_insert_key( track, time/1000.0, frame.rect )
		time += frame.duration
	
	anim.track_set_imported( track, true )
	return OK
