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

class Frame:
	var rect
	var duration

const FORMAT_HASH = 0
const FORMAT_ARRAY = 1

var _loaded = false
var _dict = {}

var _format
var _texture_filename
var _texture_size
var _frames = []
var _animations = null

var _error_message = "No error message available"

func get_error_message():
	return _error_message

const ERRMSG_INVALID_JSON =\
"""Sheet JSON is not valid JSON"""
const ERRMSG_MISSING_KEY_STRF =\
"""Missing key "%s" in sheet"""
const ERRMSG_MISSING_VALUE_STRF =\
"""Missing value for key "%s\""""
const ERRMSG_INVALID_KEY_STRF =\
"""Invalid key: "%s\""""
const ERRMSG_INVALID_VALUE_STRF =\
"""Invalid value for key "%s\""""

func is_loaded():
	return _loaded

func get_texture_filename():
	return _texture_filename

func get_texture_size():
	return _texture_size

func get_frames():
	return _frames

func get_frame( frame_index ):
	return _frames[frame_index]

func get_frame_count():
	return _frames.size()

func is_animations_enabled():
	# type nil otherwise
	return typeof(_animations) == TYPE_DICTIONARY

func get_animation_names():
	return _animations.keys()

func get_animation( anim_name ):
	var frames = []
	for i in _animations[anim_name]:
		frames.push_back( get_frame( i ))
	return frames

func get_animation_length( anim_name ):
	var length = 0
	for frame_index in _animations[anim_name]:
		length += get_frame( frame_index ).duration
	return length

func get_animation_count():
	return _animations.size()

func get_format():
	return _format

func parse_json( json ):
	var error = _dict.parse_json( json )
	if error != OK:
		_error_message = ERRMSG_INVALID_JSON
		return error
	error = _initialize()
	return error

func _initialize():
	var error = _validate_base()
	if error != OK:
		return error
	error = _parse_meta()
	if error != OK:
		return error
	error = _determine_format()
	if error != OK:
		return error
	if get_format() == FORMAT_HASH:
		error = _parse_frames_dict( _dict.frames )
	elif get_format() == FORMAT_ARRAY:
		error = _parse_frames_array( _dict.frames )
	else: assert( false )
	if error != OK:
		return error
	if is_animations_enabled():
		error = _parse_animations()
		if error != OK:
			return error
	_loaded = true
	return OK

static func make_vector2( dict ):
	if dict.has('w') and dict.has('h'):
		return Vector2( dict.w, dict.h )

static func make_rect2( dict ):
	if dict.has('w') and dict.has('h') and dict.has('x') and dict.has('y'):
		return Rect2( dict.x, dict.y, dict.w, dict.h )

func _parse_meta():
	var meta = _dict.meta
	_texture_filename = meta.image.get_file()
	_texture_size = make_vector2( meta.size )
	## \TODO meta.scale
	if meta.has('frameTags'):
		_animations = {}
	return OK

func _determine_format():
	var type = typeof(_dict.frames)
	if type == TYPE_DICTIONARY:
		_format = FORMAT_HASH
		return OK
	elif type == TYPE_ARRAY:
		_format = FORMAT_ARRAY
		return OK
	_error_message = ERRMSG_INVALID_VALUE_STRF % 'frames'
	return ERR_INVALID_DATA

func _parse_frames_dict( frames ):
	if frames.size() == 1:
		var old_name = frames.keys()[0]
		var numbered_name = old_name.basename() + ' 0' + old_name.extension()
		frames[numbered_name] = frames[old_name]
		frames.erase( old_name )
		
	var ordered_frames = []
	ordered_frames.resize( frames.size() )
	for key in frames:
		# `file 0.ase` => `file 0` => `0`
		var index = key.basename().split(' ')
		index = index[index.size()-1]
		if not index.is_valid_integer():
			_error_message = ERRMSG_INVALID_KEY_STRF % key
			return ERR_INVALID_DATA
		ordered_frames[index.to_int()] = key
		
	for i in range(ordered_frames.size()):
		frames[ordered_frames[i]].filename = ordered_frames[i]
		ordered_frames[i] = frames[ordered_frames[i]]
	return _parse_frames_array( ordered_frames )

func _parse_frames_array( array ):
	var error
	for frame in array:
		error = _validate_frame( frame )
		if error != OK:
			return error
		error = _parse_frame( frame )
		if error != OK:
			return error
	return OK

func _parse_frame( sheet_frame ):
	var frame = Frame.new()
	var rect = sheet_frame.frame
	frame.rect = Rect2( rect.x, rect.y, rect.w, rect.h )
	frame.duration = sheet_frame.duration
	_frames.append( frame )
	return OK

const DIRECTION_FORWARD = 'forward'
const DIRECTION_REVERSE = 'reverse'
const DIRECTION_PINGPONG = 'pingpong'

func _parse_animations():
	var error
	for animation in _dict.meta.frameTags:
		error = _validate_animation( animation )
		if error != OK:
			return error
		var sequence = []
		if animation.direction == DIRECTION_FORWARD or animation.direction == DIRECTION_PINGPONG:
			for frame_index in range( animation.from, animation.to+1 ):
				sequence.push_back( frame_index )
		if animation.direction == DIRECTION_REVERSE or animation.direction == DIRECTION_PINGPONG:
			for frame_index in range( animation.to-1, animation.from, -1 ):
				sequence.push_back( frame_index )
		_animations[animation.name] = sequence
		if animation.direction == DIRECTION_REVERSE:
			sequence.push_front( animation.to )
			sequence.push_back( animation.from )
	return OK

## \name Validation
## \{

func _validate_base():
	var errmsg = _get_value_error( _dict, 'frames', null )
	if errmsg:
		_error_message = errmsg
		return ERR_INVALID_DATA
	
	if _dict.frames.size() <= 0:
		_error_message = ERRMSG_MISSING_VALUE_STRF % 'frames'
		return ERR_INVALID_DATA
	
	errmsg = _get_value_error( _dict, 'meta', TYPE_DICTIONARY )
	if errmsg:
		_error_message = errmsg
		return ERR_INVALID_DATA
	
	errmsg = _get_value_error( _dict.meta, 'image', TYPE_STRING )
	if errmsg:
		_error_message = errmsg
		return ERR_INVALID_DATA
	
	errmsg = _get_value_error( _dict.meta, 'size', TYPE_DICTIONARY )
	if errmsg:
		_error_message = errmsg
		return ERR_INVALID_DATA
	
	if make_vector2( _dict.meta.size ) == null:
		_error_message = ERRMSG_INVALID_VALUE_STRF % 'meta.size'
		return ERR_INVALID_DATA
	return OK

func _validate_frame( frame ):
	var errmsg = _get_value_error( frame, 'frame', TYPE_DICTIONARY )
	if errmsg:
		_error_message = errmsg
		return ERR_INVALID_DATA
	if make_rect2( frame.frame ) == null:
		_error_message = ERRMSG_INVALID_VALUE_STRF % 'frame'
		return ERR_INVALID_DATA
	errmsg = _get_value_error( frame, 'duration', TYPE_REAL )
	if errmsg:
		_error_message = errmsg
		return ERR_INVALID_DATA
	return OK

func _validate_animation( anim ):
	var errmsg = _get_value_error( anim, 'name', TYPE_STRING )
	if errmsg:
		_error_message = errmsg
		return ERR_INVALID_DATA
	
	errmsg = _get_value_error( anim, 'direction', TYPE_STRING )
	if errmsg:
		_error_message = errmsg
		return ERR_INVALID_DATA
	
	var direction_is_valid = false
	for direction in [DIRECTION_FORWARD, DIRECTION_REVERSE, DIRECTION_PINGPONG]:
		if anim.direction == direction:
			direction_is_valid = true
			break
	if not direction_is_valid:
		_error_message = ERRMSG_INVALID_VALUE_STRF % 'direction'
		return ERR_INVALID_DATA
	
	errmsg = _get_value_error( anim, 'from', TYPE_REAL )
	if errmsg:
		_error_message = errmsg
		return ERR_INVALID_DATA
	errmsg = _get_value_error( anim, 'to', TYPE_REAL )
	if errmsg:
		_error_message = errmsg
		return ERR_INVALID_DATA
	return OK

static func _get_value_error( dict, expected_key, expected_type ):
	if not dict.has( expected_key ):
		return ERRMSG_MISSING_KEY_STRF % expected_key
	if expected_type!=null and not typeof(dict[expected_key]) == expected_type:
		return ERRMSG_INVALID_VALUE_STRF % expected_key
	return false

## \}
