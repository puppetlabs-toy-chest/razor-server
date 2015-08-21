# Adding extra drivers to WinPE image

Place any extra drivers (with .inf extension) in this folder. Subfolders will
be searched as well. Only signed drivers will be included.

To allow unsigned drivers, the -ForceUnsigned argument needs to be added to
the "add-windowsdriver" method call.