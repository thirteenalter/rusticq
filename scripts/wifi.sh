#!/bin/bash

# Pastikan iwctl tidak menghasilkan warna ANSI escape sequence
export NO_COLOR=1

if ! command -v jq &>/dev/null; then
  echo '{"error": "jq tidak ditemukan"}'
  exit 1
fi

# 1. Mengambil Nama Adapter / Device
DEVICES=$(iwctl device list | awk 'NR>4 && NF {print $1}' | grep -v '^\s*$' | jq -R . | jq -s .)

# Ambil device pertama (misal: wlan0)
DEVICE_NAME=$(echo "$DEVICES" | jq -r '.[0] // empty')

if [ -z "$DEVICE_NAME" ]; then
  jq -n '{adapters: [], active_connection: null, available_networks: [], saved_profiles: []}'
  exit 0
fi

# 2. Mengambil Profil Tersimpan (Known Networks)
# iwd menampilkan: Network name / Security / Hidden / Last connected
SAVED_PROFILES=$(iwctl known-networks list | awk '
NR>4 && NF {
    # Kolom keamanan biasanya psk, open, 8021x (kolom ke-NF-2 atau sejenis)
    # Kita ambil nama SSID dari awal baris sampai sebelum jenis keamanan
    match($0, /[[:space:]]+(psk|open|8021x)[[:space:]]/);
    if (RSTART > 0) {
        ssid = substr($0, 1, RSTART-1);
        # Trim leading/trailing spaces
        gsub(/^[ \t]+|[ \t]+$/, "", ssid);
        if (ssid != "") print ssid;
    }
}' | jq -R . | jq -s .)

# 3. Mengambil Network Terjangkau (Scanned Available Networks)
AVAILABLE_NETWORKS=$(iwctl station "$DEVICE_NAME" get-networks | awk '
NR>4 && NF {
    active = ($0 ~ /^[[:space:]]*[\*>]/) ? true : false;
    
    # Hapus karakter pemarkah aktif (* atau >)
    gsub(/^[[:space:]]*[\*>][[:space:]]*/, "");
    
    # Deteksi jenis security di kolom paling kanan
    sec = $NF;
    
    # Sisa teks di tengah adalah SSID
    $NF = "";
    gsub(/^[ \t]+|[ \t]+$/, "");
    ssid = $0;
    
    if (ssid != "") {
        printf "{\"ssid\":\"%s\",\"security\":\"%s\",\"active\":%s}\n", ssid, sec, active;
    }
}' | jq -s .)

# 4. Status Koneksi Aktif
ACTIVE_CONNECTION=$(iwctl station "$DEVICE_NAME" show | awk '
    /State/ { state=$2 }
    /Connected network/ { 
        $1=$2=""; 
        gsub(/^[ \t]+|[ \t]+$/, ""); 
        ssid=$0 
    }
    END {
        if (state == "connected" && ssid != "") {
            printf "{\"device\":\"'"$DEVICE_NAME"'\",\"ssid\":\"%s\",\"state\":\"%s\"}\n", ssid, state;
        } else {
            print "null";
        }
    }' | jq .)

# Gabungkan ke dalam satu Objek JSON
jq -n \
  --argjson adapters "$DEVICES" \
  --argjson active "$ACTIVE_CONNECTION" \
  --argjson available "$AVAILABLE_NETWORKS" \
  --argjson saved "$SAVED_PROFILES" \
  '{
    adapters: $adapters,
    active_connection: $active,
    available_networks: $available,
    saved_profiles: $saved
  }'
