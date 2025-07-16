nasm -f win64 -o functions.obj functions.asm
link /subsystem:console /entry:mainCRTStartup kernel32.lib libcmt.lib functions.obj
functions.exe