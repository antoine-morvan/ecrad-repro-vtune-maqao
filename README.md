# ecRad @ HPCW reproducer

Script to install toolchain & run ecRad using HPCW. It installs:

| Tool | Version | Usage |
|------|---------|-------|
| CMake | 4.2.0 | recent vesion to run HPCW |
| hwloc | 2.12.2 | For binding |
| OneAPI | 2023.2.4 | Latest version that ships icc/icpc |
| GCC | 12.5.0 | more recent versions make OneAPI 2023.2.4 fail |
| VTune | 2025.7.0 | To profile ecRad |

This also checks HPCW out (to the proper version).

:warning:

* Requires ~40GB of space
* Default settings runs the small case of ecRad 
* Medium test case requires ~60GB of RAM
* Edit `TMP_DIR=${SCRIPT_DIR}/.tmp` to something that suits your machine

## Offline

Everything needed is put under ` .cache` ; you can run the script on a machine with internet, then move the cache folder arround.
