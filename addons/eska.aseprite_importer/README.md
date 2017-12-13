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

 - **Godot Engine**:       at least version __3.0__
 - **Aseprite**:           at least version __1.0__
	 - for **export GUI**: at least version __1.0.3__
	 - for **animations**: at least version __1.1.2__

Installation
============

To install the plug-in into a Godot Engine project, the `addons/eska.aseprite-importer`
directory must be moved into the project directory, so that the following
hierarchy results:

 - `sample_project/`
	- `project.godot`
	- `addons/`
		- `eska.aseprite-importer/`
			- `plugin.cfg`
			-  *several other plug-in files*

Usage
=====

Exporting from Aseprite
-----------------------

To export a sprite sheet from Aseprite, use *File → Export Sprite Sheet*.
Enable at least *Output File* and *JSON Data*. Enable *Meta: Frame Tags* to
export animations.

Animations need to be tagged for the plug-in to properly name them. To tag an
animation, hold left-click and drag the mouse across the frames you wish to save
as one animation, then right-click and choose *New Tag*. Name it and hit *OK*.

It is recommended to save the texture file to the same directory as the
JSON data file, with the same filename. That way, the path of the image file
does not need to be specified during import in Godot Engine.

After the first export, the settings dialog may be skipped by using
*File → Repeat Last Export*.

**Tip:** Keyboard shortcuts for *Repeat Last Export* can be changed and added
per *Edit → Keyboard Shortcuts…*. By default, a single shortcut is configured
as `Ctrl + Shift + X`.

Importing into Godot Engine
---------------------------

The *Aseprite import* plug-in integrates into Godot 3+'s built-in Import system.
Simply drop your exported `.json` and sprite sheet `.png` image file inside your
Godot project's directory and Godot will automatically import it while the
plug-in is active.

If the sprite sheet image file doesn't have the same name and path as the `.json`
file, you will need to click on your `.json` file in the *FileSystem* dock, open
the *Import* dock and specify the texture location using the `Sheet Image` option
and click on the *Reimport* button.

After first importing the sprite sheet, the scene will be reimported
automatically whenever the sprite sheet is changed and again exported from
Aseprite.

You can set a *post-script* file to manipulate the scene post-import by setting the
`Post Script` import option to point at a `.gd` script file with a
`post_import( scene_root )` method. That method will be given the scene's root
`Node2d` as an argument and is expected to return the changed scene afterward.
If you want to add any nodes to the scene at this point, keep in mind that it will
only be saved if you call `set_owner( scene_root )` on each new node.

The `Autoplay Animation` option lets you set the name of an animation to play as
soon as the scene loads, which is useful since the scene can't be manually edited
after importing.

Warning
=======

Overwriting data is generally avoided. However, as an exception, the plug-in
will always ignore and overwrite:

 - Added, changed or deleted keys in the `region_rect` track in imported
   animations
 - Changes to the texture path of the Sprite node

License
=======

*BSD 2-clause ‘Simplified’ License*, read `LICENSE` file.

Development
===========

To report issues or offer patches for the plug-in, please use the
[`aseprite-import` Github repository][aseprite-import].


[Godot Engine]: https://godotengine.org/ 'Godot Engine website'

[Aseprite]: http://www.aseprite.org/ 'Aseprite website'

[aseprite-import]: https://github.com/eska014/aseprite-import/ 'aseprite-import Github repository'
