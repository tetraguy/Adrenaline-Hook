# Release Notes - Deep Search Edition

## Universal Deep Search for Game Pass Titles

Added recursive deep search that automatically finds game executables in subfolders, fixing the Windows File Picker permission issue when browsing protected WindowsApps directories.

### What Changed

The scanner now recursively searches through Game Pass installation folders instead of only checking manifest files. When multiple executables are found, they're all listed with filenames so you can pick the right one.

### Why

Some Game Pass games store the actual game executable in deep subfolders rather than at the root. The previous version only found the launcher from the manifest, which meant manually browsing to the real executable - but Windows File Picker blocks access to protected WindowsApps folders even with admin rights.

### Technical Details

- Recursively scans all subfolders for `.exe` files
- Filters out small utilities (<10MB) to skip launchers and helper tools  
- Prioritizes executables in deeper folder structures (game exe > launcher)

