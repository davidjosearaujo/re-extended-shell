#!/system/bin/sh

# inject_ca.sh - System CA Injection for Android 14+ (API 34+)
# Based on the HTTP Toolkit APEX mount namespace technique.
# Usage: inject_ca.sh /data/local/tmp/re-ext/<subject_hash_old>.0
TARGET_CERT="$1"
CERT_FILE="${TARGET_CERT##*/}"
WORK_DIR="${TARGET_CERT%/*}"

if [ "$(id -u)" != "0" ]; then
    echo "Error: must run as root (run 'adb root' first)."
    exit 1
fi

case "$TARGET_CERT" in
    /*.0) ;;
    *) echo "Error: expected an absolute path to a <subject_hash_old>.0 file, got '$TARGET_CERT'."
       exit 1 ;;
esac
if [ ! -f "$TARGET_CERT" ]; then
    echo "Error: $TARGET_CERT not found!"
    exit 1
fi

SYSTEM_CERTS="/system/etc/security/cacerts"
CONSCRYPT_CERTS="/apex/com.android.conscrypt/cacerts"
OVERRIDE_DIR="$WORK_DIR/cacerts_override"

# Skip if already injected (e.g. state restored from a snapshot)
if grep -q " $SYSTEM_CERTS tmpfs " /proc/mounts && [ -f "$SYSTEM_CERTS/$CERT_FILE" ]; then
    echo "Certificate $CERT_FILE already injected, skipping."
    exit 0
fi

# On Android 14+ the Conscrypt APEX holds the authoritative CA store
if [ -d "$CONSCRYPT_CERTS" ]; then
    SOURCE_CERTS="$CONSCRYPT_CERTS"
else
    SOURCE_CERTS="$SYSTEM_CERTS"
fi

# Prepare temporary copy of existing + injected certs
rm -rf "$OVERRIDE_DIR"
mkdir -m 700 "$OVERRIDE_DIR"
cp "$SOURCE_CERTS"/* "$OVERRIDE_DIR/" || exit 1
cp "$TARGET_CERT" "$OVERRIDE_DIR/" || exit 1

# Mount tmpfs over system certs folder and fill it
mount -t tmpfs tmpfs "$SYSTEM_CERTS" || exit 1
mv "$OVERRIDE_DIR"/* "$SYSTEM_CERTS/"
rm -rf "$OVERRIDE_DIR"
# Set permissions and SELinux context
chown root:root "$SYSTEM_CERTS"/*
chmod 644 "$SYSTEM_CERTS"/*
chcon u:object_r:system_file:s0 "$SYSTEM_CERTS"/*

if [ ! -d "$CONSCRYPT_CERTS" ]; then
    echo "Successfully injected certificate $CERT_FILE into $SYSTEM_CERTS (pre-APEX Android)."
    exit 0
fi

# Bind-mount into the Conscrypt APEX dir of every mount namespace (incl. this
# one and zygote's, so newly started apps inherit it). Many processes share a
# namespace, so mount once per namespace to avoid stacking bind mounts.
SEEN_NS=""
NS_COUNT=0
for NS in /proc/[0-9]*/ns/mnt; do
    NS_ID=$(readlink "$NS" 2>/dev/null) || continue
    case " $SEEN_NS " in
        *" $NS_ID "*) continue ;;
    esac
    SEEN_NS="$SEEN_NS $NS_ID"
    if nsenter --mount="$NS" -- mount --bind "$SYSTEM_CERTS" "$CONSCRYPT_CERTS" 2>/dev/null; then
        NS_COUNT=$((NS_COUNT + 1))
    fi
done

echo "Successfully injected certificate $CERT_FILE into $NS_COUNT Conscrypt APEX mount namespaces."
