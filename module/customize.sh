#!/system/bin/sh
SKIPUNZIP=1

MOD_PROP="${TMPDIR}/module.prop"
MOD_NAME="$(grep_prop name "$MOD_PROP")"
MOD_VER="$(grep_prop version "$MOD_PROP") ($(grep_prop versionCode "$MOD_PROP"))"

APNF="apns-conf.xml"
APN_PATH="apns/$APNF"

extract() {
    file=$1
    dir=$2
    junk=${3:-false}
    opts="-o"

    [ -z "$dir" ] && dir="$MODPATH"
    file_path="$dir/$file"
    hash_path="$TMPDIR/$file.sha256"

    if [ "$junk" = true ]; then
        opts="-oj"
        file_path="$dir/$(basename "$file")"
        hash_path="$TMPDIR/$(basename "$file").sha256"
    fi

    unzip $opts "$ZIPFILE" "$file" -d "$dir" >&2
    [ -f "$file_path" ] || abort "! $file does NOT exist"

    unzip $opts "$ZIPFILE" "${file}.sha256" -d "$TMPDIR" >&2
    [ -f "$hash_path" ] || abort "! ${file}.sha256 does NOT exist"

    expected_hash="$(cat "$hash_path")"
    calculated_hash="$(sha256sum "$file_path" | cut -d ' ' -f1)"

    if [ "$expected_hash" == "$calculated_hash" ]; then
        ui_print "- Verified $file" >&1
    else
        abort "! Failed to verify $file"
    fi
}
ui_print "- Setting up $MOD_NAME"
ui_print "- Version: $MOD_VER"
extract "customize.sh" "$TMPDIR"
extract "$APN_PATH" "$TMPDIR"
extract "module.prop"

MIUI_VER=$(getprop | grep "ro.miui.ui.version.*")
if [ -n "$MIUI_VER" ]; then
    if ! pm list packages | grep "com.xiaomi.xmsf" >/dev/null 2>&1; then
        ui_print "! Detect MIUI/HyperOS version properties"
        ui_print "! but doesn't find out xmsf"
        ui_print "- Continue anyway because it might be"
        ui_print "- a simple properties spoof"
    else
        ui_print "! Detect MIUI/HyperOS"
        abort "! You don’t need to flash $MOD_NAME"
    fi
fi

apn_list=""

apn_system=$(find /system -name "$APNF" -type f)
apn_product=$(find /product -name "$APNF" -type f)
apn_etc=$(find /etc -name "$APNF" -type f)
apn_vendor=$(find /vendor -name "$APNF" -type f)

add_to_apn_list() {

    while [ $# -gt 0 ]; do
        if [ -n "$1" ]; then
            if [ -z "$apn_list" ]; then
                apn_list="$1"
            else
                apn_list="${apn_list}
$1"
            fi
        fi
        shift
    done

}

add_to_apn_list "$apn_system" "$apn_product" "$apn_etc" "$apn_vendor"
apn_list=$(echo "$apn_list" | sort -u)
apn_list_count=$(echo "$apn_list" | wc -l)

if [ $apn_list_count -le 0 ]; then
    abort "! $APNF is not found!"
fi

IFS='
'

apns_conf="$TMPDIR/apns/apns-conf.xml"

for xml in $apn_list; do

    [ -z "$xml" ] && continue

    ui_print "- Process $xml"
    xml_dir="${xml%/*}"

    case "$xml_dir" in
        /product*|/etc*|/vendor*) xml_dir="/system${xml_dir}" ;;
    esac

    apn_conf_dir="${MODPATH}${xml_dir}"

    if [ ! -d "$apn_conf_dir" ]; then
        mkdir -p "$apn_conf_dir"
        cp "$apns_conf" "$apn_conf_dir"
    fi

done

ui_print "- Setting permissions"
set_perm_recursive "$MODPATH" 0 0 0755 0644
ui_print "- Welcome to $MOD_NAME!"