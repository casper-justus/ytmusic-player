import subprocess, os, shutil, urllib.request, zipfile, tempfile

url = "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
zip_path = "/tmp/cmdline-tools.zip"
urllib.request.urlretrieve(url, zip_path)
print("Downloaded")

extract_dir = tempfile.mkdtemp()
with zipfile.ZipFile(zip_path) as zf:
    zf.extractall(extract_dir)
print("Extracted")

sdk_base = "/usr/local/lib/android/sdk"
os.makedirs(sdk_base, exist_ok=True)
os.makedirs(os.path.join(sdk_base, "cmdline-tools"), exist_ok=True)

src = os.path.join(extract_dir, "cmdline-tools")
dst = os.path.join(sdk_base, "cmdline-tools", "latest")
if os.path.exists(dst):
    shutil.rmtree(dst)
shutil.move(src, dst)
shutil.rmtree(extract_dir)
os.remove(zip_path)

subprocess.run(["sudo", "chown", "-R", "codespace:codespace", "/usr/local/lib/android"], check=False)
print("Tools installed")

sdkmanager = os.path.join(sdk_base, "cmdline-tools", "latest", "bin", "sdkmanager")
env = os.environ.copy()
env["ANDROID_HOME"] = sdk_base

# Accept licenses
subprocess.run("yes | " + sdkmanager + " --licenses", shell=True, env=env, capture_output=True)
print("Licenses accepted")

# Install components
for pkg in ["platforms;android-34", "build-tools;34.0.0", "platform-tools"]:
    r = subprocess.run([sdkmanager, pkg], env=env, capture_output=True, text=True)
    print(pkg + ": " + str(r.returncode))
    if r.stdout:
        print(r.stdout[-300:])
    if r.stderr:
        print(r.stderr[-300:])

print("DONE")
