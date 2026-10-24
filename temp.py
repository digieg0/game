import subprocess, os, sys
exe = r"D:\Steam\steamapps\common\Godot Engine\editor\windows_debug_x86_64_console.exe"
print("exists:", os.path.exists(exe))
try:
    r = subprocess.run([exe, "--version"], capture_output=True, text=True, timeout=90)
    print("stdout:", r.stdout.strip())
    print("stderr:", r.stderr.strip())
    print("code:", r.returncode)
except Exception as e:
    print("ERR:", e)
