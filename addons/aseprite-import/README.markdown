Introduction
============

**Aseprite import** is a *[Godot Engine][]* import plug-in that enables import
of sprites and animations from sprite editor and pixel art tool *[Aseprite][]*.

**Sprite sheets** exported from Aseprite are imported into Godot Engine projects
as **scene** files, which can then easily be instanced into other scenes.

Further changes made from Aseprite are **merged** intelligently into already
imported scenes, so that modifications made to nodes and animations are
retained.

Requirements
============

 - **Godot Engine**:       at least version __2.1__
 - **Aseprite**:           at least version __1.0__
	 - for **export GUI**: at least version __1.0.3__
	 - for **animations**: at least version __1.1.2__

Installation
============

To install the plug-in into a Godot Engine project, the `addons/aseprite-import`
directory must be moved into the project directory, so that the following
hierarchy results:

 - `sample_project/`
	- `engine.cfg`
	- `addons/`
		- `aseprite-import/`
			- `plugin.cfg`
			-  *several other plug-in files*

Usage
=====

Exporting from Aseprite
-----------------------

To export a sprite sheet from Aseprite, use *File → Export Sprite Sheet*.
Enable at least *Output File* and *JSON Data*. Enable *Meta: Frame Tags* to
export animations.

It is recommended to save the texture file to the same directory as the
JSON data file. That way, only the path of the JSON file needs to be specified
during import in Godot Engine.

After the first export, the settings dialog may be skipped by using
*File → Repeat Last Export*.

**Tip:** Keyboard shortcuts for *Repeat Last Export* can be changed and added
per *Edit → Keyboard Shortcuts…*. By default, a single shortcut is configured
as `Ctrl + Shift + X`.

Importing into Godot Engine
---------------------------

The *Aseprite import* plug-in is accessible from the *Import* button to the
top-left of the editor. A dialog will open with three fields to specify the
settings for the sprite sheet import.

Aseprite sprite sheets consist of a texture and a JSON file containing metadata
of the sprite sheet.

In the first field, *Sprite sheet JSON*, use the button to the right to find
and select the JSON data file. This file has a `.json` file extension.

If the sprite sheet texture is located in the same directory as the JSON file,
specifying its location is not necessary. Otherwise, specify the path to the
file in next field, *Sprite sheet texture*.

In the last field, *Scene*, choose where to save the resulting scene. This
scene file must be saved in a binary format with the file extension `.scn` in
order to save some metadata and the texture.

Finally, click the *Import* button to begin the import and create the scene.

After first importing the sprite sheet, the scene will be reimported
automatically whenever the sprite sheet is changed and again exported from
Aseprite.

Warning
=======

Overwriting data is generally avoided. However, as an exception, the plug-in
will always ignore and overwrite:

 - Added, changed or deleted keys in the `region_rect` track in imported
   animations
 - Changes to the texture path of the Sprite node

License
=======

*BSD 2-clause ‘Simplified’ License*, read `LICENSE` file

Development
===========

To report issues or offer patches for the plug-in, please use the
[`aseprite-import` Github repository][aseprite-import].


[Godot Engine]: https://godotengine.org/ 'Godot Engine website'

[Aseprite]: http://www.aseprite.org/ 'Aseprite website'

[aseprite-import]: https://github.com/eska014/aseprite-import/ 'aseprite-import Github repository'
