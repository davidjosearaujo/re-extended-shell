# Your environment variables. Loaded right after modules/core/env.sh and before
# every other module, so what you set here is what the modules see.
# Keep the 'export'. This folder is git-ignored.

# Core
# Your intercepting proxy (ZAP, Burp, mitmproxy, ...): its port and root CA
# export RE_PROXY_PORT=8080
# export RE_PROXY_CERT="$HOME/.mitmproxy/mitmproxy-ca-cert.pem"
# export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"

# Android
# export ANDROID_HOME="$HOME/sdk/android"
# export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/27.2.12479018"
# export RE_EMULATOR_SNAPSHOT=re-ready
# export RE_CONTAINER_ENGINE=podman
# export RE_ANDROID_CONTAINER_IMAGE=us-docker.pkg.dev/android-emulator-268719/images/30-google-x64
# export APKEDITOR_JAR="$HOME/tools/APKEditor.jar"
# jadx has no 'apt' package; point these at however you installed it (the value
# may include arguments). Defaults: jadx / jadx-gui on PATH.
# export JADX="flatpak run com.github.skylot.jadx"
# export JADX_GUI="flatpak run --command=jadx-gui com.github.skylot.jadx"
# export JADX="$HOME/tools/jadx/bin/jadx"; export JADX_GUI="$HOME/tools/jadx/bin/jadx-gui"
# frida-server: which build to push, and the on-device name it hides behind.
# 'florida-zygisk' (default) is the Florida anti-detection build (tracking the
# latest Frida); 'frida' is the stock build.
# The name is random and persisted; set RE_FRIDA_NAME only to pin a fixed one.
# export RE_FRIDA_SOURCE=florida-zygisk
# export RE_FRIDA_NAME=mediaserverd

# frida-server --ssl-unpinning: which HTTP Toolkit scripts to load
# export RE_FRIDA_UNPIN_REF=main
# export RE_FRIDA_UNPIN_SCRIPTS="native-tls-hook.js android/android-proxy-override.js android/android-system-certificate-injection.js android/android-certificate-unpinning.js android/android-certificate-unpinning-fallback.js android/android-disable-root-detection.js"
