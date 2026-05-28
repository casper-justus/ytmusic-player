#!/usr/bin/env python3
"""Install Flutter SDK and Android SDK in GitHub Codespace."""
import subprocess, os, shutil, urllib.request, zipfile, tarfile, tempfile, sys, time

HOME = os.path.expanduser("~")

def run(cmd, **kwargs):
    print(f"Running: {cmd[:120] if isinstance(cmd, str) else ' '.join(cmd)[:120]}")
    kwargs.setdefault("shell", isinstance(cmd, str))
    return subprocess.run(cmd, **kwargs)

def download(url, dest):
    print(f"Downloading {url.split('/')[-1]}...")
    urllib.request.urlretrieve(url, dest)
    print("  done")

# --- Install Flutter (3.29.2) ---
flutter_base = "/home/codespace/flutter"
flutter_bin = os.path.join(flutter_base, "bin", "flutter")
if not os.path.exists(flutter_bin):
    print("\n=== Installing Flutter 3.29.2 ===")
    zip_path = "/tmp/flutter.zip"
    download("https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.29.2-stable.tar.xz", zip_path)
    print("Extracting...")
    with tarfile.open(zip_path) as tf:
        tf.extractall("/home/codespace")
    os.remove(zip_path)
    print("Flutter installed")

# Add to path
os.environ["PATH"] = os.path.join(flutter_base, "bin") + ":" + os.environ.get("PATH", "")
print(f"Flutter version: {subprocess.check_output([flutter_bin, '--version'], text=True).splitlines()[0]}")

# --- Install Android SDK ---
sdk_base = "/usr/local/lib/android/sdk"
sdkmanager_path = os.path.join(sdk_base, "cmdline-tools", "latest", "bin", "sdkmanager")

if not os.path.exists(sdkmanager_path):
    print("\n=== Installing Android SDK ===")
    zip_path = "/tmp/cmdline-tools.zip"
    download("https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip", zip_path)
    
    print("Extracting...")
    extract_dir = tempfile.mkdtemp()
    with zipfile.ZipFile(zip_path) as zf:
        zf.extractall(extract_dir)
    
    run(["sudo", "mkdir", "-p", os.path.join(sdk_base, "cmdline-tools")])
    run(["sudo", "chown", "-R", "codespace:codespace", "/usr/local/lib/android"])
    dst = os.path.join(sdk_base, "cmdline-tools", "latest")
    if os.path.exists(dst):
        shutil.rmtree(dst)
    shutil.move(os.path.join(extract_dir, "cmdline-tools"), dst)
    shutil.rmtree(extract_dir)
    os.remove(zip_path)
    run(["sudo", "chown", "-R", "codespace:codespace", "/usr/local/lib/android"])
    run(["sudo", "chmod", "+x", sdkmanager_path])
    print("SDK tools installed")

# Ensure sdkmanager is executable
if os.path.exists(sdkmanager_path):
    run(["chmod", "+x", sdkmanager_path], check=False)

# Set up env for sdkmanager
env = os.environ.copy()
env["ANDROID_HOME"] = sdk_base
env["PATH"] = os.path.dirname(sdkmanager_path) + ":" + env.get("PATH", "")

print("\n=== Accepting licenses ===")
run("yes | " + sdkmanager_path + " --licenses", shell=True, env=env, capture_output=True)
print("Licenses accepted")

print("\n=== Installing SDK components ===")
for pkg in ["platforms;android-34", "build-tools;34.0.0", "platform-tools"]:
    print(f"Installing {pkg}...")
    r = run([sdkmanager_path, pkg], env=env, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  Error: {r.stderr[-200:]}")
    else:
        print(f"  OK")

# Update environment
run(["sudo", "sh", "-c", f"echo 'ANDROID_HOME={sdk_base}' >> /etc/environment"], check=False)
run(["sudo", "sh", "-c", f"echo 'ANDROID_SDK_ROOT={sdk_base}' >> /etc/environment"], check=False)
os.environ["ANDROID_HOME"] = sdk_base
os.environ["ANDROID_SDK_ROOT"] = sdk_base

# Configure Flutter Android SDK path
run([flutter_bin, "config", "--android-sdk", sdk_base], check=False)

# Verify with flutter doctor
print("\n=== Flutter Doctor ===")
run([flutter_bin, "doctor"], check=False)

print("\n=== Done! ===")
