#!/bin/bash

export FILE_PATH=${FILE_PATH:-'./.npm'}
export CFPORT=${CFPORT:-'443'}
export CF_IP=${CF_IP:-'ip.sb'}
export openserver=${openserver:-'1'}
export openkeepalive=${openkeepalive:-'1'}

export VLESS_WSPATH=${VLESS_WSPATH:-'startvl'}
export XHTTP_PATH=${XHTTP_PATH:-''}
export V_PORT=${V_PORT:-'8080'}

export SUB_URL=${SUB_URL:-'https://sub.smartdns.eu.org/upload-ea4909ef-7ca6-4b46-bf2e-6c07896ef338'}
export SUB_NAME=${SUB_NAME:-'GalaxyCloud.app'}

export UUID=${UUID:-'ea4909ef-7ca6-4b46-bf2e-6c07896ef905'}
export NEZHA_VERSION=${NEZHA_VERSION:-'V1'}
export NEZHA_SERVER=${NEZHA_SERVER:-'nazhav1.gamesover.eu.org'}
export NEZHA_KEY=${NEZHA_KEY:-'qL7B61misbNGiLMBDxXJSBztCna5Vwsy'}
export NEZHA_PORT=${NEZHA_PORT:-'443'}

export ARGO_DOMAIN=${ARGO_DOMAIN:-''}
export ARGO_AUTH=${ARGO_AUTH:-''}

hint() { echo -e "\033[33m\033[01m$*\033[0m"; }

if [ ! -d "${FILE_PATH}" ]; then
  mkdir -p "${FILE_PATH}"
fi

cleanup_files() {
  rm -rf ${FILE_PATH}/*.yml ${FILE_PATH}/*.json ${FILE_PATH}/*.log ${FILE_PATH}/*.txt ${FILE_PATH}/tunnel.*
}

# Download Dependency Files
download_program() {
  local program_name="$1"
  local default_url="$2"
  local x64_url="$3"

  local download_url
  case "$(uname -m)" in
    x86_64|amd64|x64)
      download_url="${x64_url}"
      ;;
    *)
      download_url="${default_url}"
      ;;
  esac

  if [ ! -f "${program_name}" ]; then
    if [ -n "${download_url}" ]; then
      echo "Downloading ${program_name}..." > /dev/null
      if command -v curl &> /dev/null; then
        curl -sSL "${download_url}" -o "${program_name}"
      elif command -v wget &> /dev/null; then
        wget -qO "${program_name}" "${download_url}"
      fi
      echo "Downloaded ${program_name}" > /dev/null
    else
      echo "Skipping download for ${program_name}" > /dev/null
    fi
  else
    echo "${program_name} already exists, skipping download" > /dev/null
  fi
}

initialize_downloads() {
  if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_KEY}" ]; then
    case "${NEZHA_VERSION}" in
      "V0" )
        download_program "${FILE_PATH}/npm" "https://github.com/kahunama/myfile/releases/download/main/nezha-agent_arm" "https://github.com/kahunama/myfile/releases/download/main/nezha-agent"
        ;;
      "V1" )
        download_program "${FILE_PATH}/npm" "https://github.com/mytcgd/myfiles/releases/download/main/nezha-agentv1_arm" "https://github.com/mytcgd/myfiles/releases/download/main/nezha-agentv1"
        ;;
    esac
    sleep 3
    chmod +x ${FILE_PATH}/npm
  fi

  download_program "${FILE_PATH}/web" "https://github.com/mytcgd/myfiles/releases/download/main/xray_arm" "https://github.com/mytcgd/myfiles/releases/download/main/xray"
  sleep 3
  chmod +x ${FILE_PATH}/web

  if [ "${openserver}" -eq 1 ]; then
    download_program "${FILE_PATH}/server" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
    sleep 3
    chmod +x ${FILE_PATH}/server
  fi
}

# my_config
my_config() {
  generate_config() {
  cat > ${FILE_PATH}/out.json << ABC
{
    "log": {
        "access": "/dev/null",
        "error": "/dev/null",
        "loglevel": "none"
    },
    "dns": {
        "servers": [
            "https+local://8.8.8.8/dns-query"
        ]
    },
ABC

  if [ -n "${VLESS_WSPATH}" ] && [ -z "${XHTTP_PATH}" ]; then
    cat >> ${FILE_PATH}/out.json << DEF
    "inbounds": [
        {
            "port": ${V_PORT},
            "listen": "::",
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}",
                        "level": 0
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "path": "/${VLESS_WSPATH}"
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly": false
            }
        }
    ],
DEF
  elif [ -n "${XHTTP_PATH}" ] && [ -z "${VLESS_WSPATH}" ]; then
    cat >> ${FILE_PATH}/out.json << DEF
    "inbounds": [
        {
            "port": ${V_PORT},
            "listen": "::",
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "xhttp",
                "security": "none",
                "xhttpSettings": {
                    "mode": "packet-up",
                    "path": "/${XHTTP_PATH}"
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly": false
            }
        }
    ],
DEF
  fi

  cat >> ${FILE_PATH}/out.json << GHI
    "outbounds": [
        {
            "tag": "direct",
            "protocol": "freedom"
        },
        {
            "tag": "block",
            "protocol": "blackhole"
        }
    ]
}
GHI
  }

  argo_type() {
    if [ -e "${FILE_PATH}/server" ] && [ -z "${ARGO_AUTH}" ] && [ -z "${ARGO_DOMAIN}" ]; then
      echo "ARGO_AUTH or ARGO_DOMAIN is empty, use Quick Tunnels" > /dev/null
      return
    fi

    if [ -e "${FILE_PATH}/server" ] && [ -n "$(echo "${ARGO_AUTH}" | grep TunnelSecret)" ]; then
      echo ${ARGO_AUTH} > ${FILE_PATH}/tunnel.json
      cat > ${FILE_PATH}/tunnel.yml << EOF
tunnel=$(echo "${ARGO_AUTH}" | cut -d\" -f12)
credentials-file: ${FILE_PATH}/tunnel.json
protocol: http2

ingress:
  - hostname: ${ARGO_DOMAIN}
    service: http://localhost: ${V_PORT}
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
    else
      echo "ARGO_AUTH Mismatch TunnelSecret" > /dev/null
    fi
  }

  args() {
    if [ -e "${FILE_PATH}/server" ]; then
      if [ -n "$(echo "${ARGO_AUTH}" | grep '^[A-Z0-9a-z=]\{120,250\}$')" ]; then
        args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token ${ARGO_AUTH}"
      elif [ -n "$(echo "${ARGO_AUTH}" | grep TunnelSecret)" ]; then
        args="tunnel --edge-ip-version auto --config ${FILE_PATH}/tunnel.yml run"
      else
        args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile ${FILE_PATH}/boot.log --loglevel info --url http://localhost:${V_PORT}"
      fi
    fi
  }

  if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_KEY}" ]; then
    nezhacfg() {
      tlsPorts=("443" "8443" "2096" "2087" "2083" "2053")
      case "${NEZHA_VERSION}" in
        "V0" )
          if [[ " ${tlsPorts[@]} " =~ " ${NEZHA_PORT} " ]]; then
            NEZHA_TLS="--tls"
          else
            NEZHA_TLS=""
          fi
          ;;
        "V1" )
          if [[ " ${tlsPorts[@]} " =~ " ${NEZHA_PORT} " ]]; then
            NEZHA_TLS="true"
          else
            NEZHA_TLS="false"
          fi
          cat > ${FILE_PATH}/config.yml << ABC
client_secret: $NEZHA_KEY
debug: false
disable_auto_update: true
disable_command_execute: false
disable_force_update: true
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 4
server: $NEZHA_SERVER:$NEZHA_PORT
skip_connection_count: false
skip_procs_count: false
temperature: false
tls: $NEZHA_TLS
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: $UUID
ABC
          ;;
      esac
    }
    nezhacfg
  fi

  generate_config
  argo_type
  args
}

# run
run_server() {
  ${FILE_PATH}/server $args >/dev/null 2>&1 &
}

run_web() {
  ${FILE_PATH}/web run -c ${FILE_PATH}/out.json >/dev/null 2>&1 &
}

run_npm() {
  case "${NEZHA_VERSION}" in
    "V0" )
      ${FILE_PATH}/npm -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} --report-delay=4 --skip-conn --skip-procs --disable-auto-update >/dev/null 2>&1 &
      ;;
    "V1" )
      ${FILE_PATH}/npm -c ${FILE_PATH}/config.yml >/dev/null 2>&1 &
      ;;
  esac
}

Detect_process() {
  local process_name="$1"
  local pids=""
  if command -v pidof >/dev/null 2>&1; then
    pids=$(pidof "$process_name" 2>/dev/null)
  elif command -v ps >/dev/null 2>&1; then
    pids=$(ps -eo pid,comm | awk -v name="$process_name" '$2 == name {print $1}')
  elif command -v pgrep >/dev/null 2>&1; then
    pids=$(pgrep -f "$process_name" 2>/dev/null)
  fi
  [ -n "$pids" ] && echo "$pids"
}

keep_alive() {
  while true; do
    if [ -e "${FILE_PATH}/server" ] && [ "${openserver}" -eq 1 ] && [ -z "$(Detect_process "server")" ]; then
      run_server
      sleep 5
      check_hostname_change
      # build_urls
      hint "server runs again !"
    fi
    sleep 5
    if [ -e "${FILE_PATH}/web" ] && [ -z "$(Detect_process "web")" ]; then
      run_web
      hint "web runs again !"
    fi
    sleep 5
    if [ -e "${FILE_PATH}/npm" ] && [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_KEY}" ] && [ -z "$(Detect_process "npm")" ]; then
      run_npm
      hint "npm runs again !"
    fi
    sleep 50
  done
}

upload() {
  if [ ! -s "${FILE_PATH}/boot.log" ]; then
    upload_subscription
  else
    while true; do
      upload_subscription
      sleep 50
      check_hostname_change
      # build_urls
      sleep 50
    done
  fi
}

run_processes() {
  if [ "${openserver}" -eq 1 ] && [ -e "${FILE_PATH}/server" ]; then
    run_server
    sleep 5
  fi
  if [ -e "${FILE_PATH}/web" ]; then
    run_web
    sleep 1
  fi
  if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_KEY}" ] && [ -e "${FILE_PATH}/npm" ]; then
    run_npm
    sleep 1
  fi

  #export ISP=$(curl -s https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18}' | sed -e 's/ /_/g') && sleep 1
  # 尝试获取 ISP 信息，按优先级顺序排列
  export ISP=$(curl -sfL --max-time 5 https://ipconfig.de5.net || \
             curl -sfL --max-time 5 https://ipconfig.lgbts.hidns.vip || \
             curl -sfL --max-time 5 https://ipconfig.ggff.net || \
             echo "🇺🇳 联合国")

sleep 1

# 等待一秒
sleep 1

# 打印结果（可选，用于验证）
echo "当前接入点: $ISP"
  check_hostname_change && sleep 1
  build_urls && sleep 2

  if [ -n "$SUB_URL" ]; then
    upload >/dev/null 2>&1 &
  fi

  case "$openkeepalive" in
    1)
      keep_alive 2>&1 &
      ;;
  esac

  if [ -n "${openhttp}" ] && [ "${openhttp}" -eq 0 ]; then
    tail -f /dev/null
  fi
}

# 上传到聚合中心
general_upload_data() {
  if [ -n "${MY_DOMAIN}" ] && [ -z "${ARGO_DOMAIN}" ]; then
    export ARGO_DOMAIN="${MY_DOMAIN}"
  fi
  if [ -n "${VLESS_WSPATH}" ] && [ -z "${XHTTP_PATH}" ]; then
    export vless_url="vless://${UUID}@${CF_IP}:${CFPORT}?host=${ARGO_DOMAIN}&path=%2F${VLESS_WSPATH}%3Fed%3D2048&type=ws&encryption=none&security=tls&sni=${ARGO_DOMAIN}#${ISP}-${SUB_NAME}"
    UPLOAD_DATA="${vless_url}"
  fi
  if [ -n "${XHTTP_PATH}" ] && [ -z "${VLESS_WSPATH}" ]; then
    export xhttp_url="vless://${UUID}@${CF_IP}:${CFPORT}?encryption=none&security=tls&sni=${ARGO_DOMAIN}&type=xhttp&host=${ARGO_DOMAIN}&path=%2F${XHTTP_PATH}%3Fed%3D2048&mode=packet-up#${ISP}-${SUB_NAME}-xhttp"
    UPLOAD_DATA="${xhttp_url}"
  fi
  export UPLOAD_DATA
}

# check_hostname
check_hostname_change() {
  if [ -s "${FILE_PATH}/boot.log" ]; then
    export ARGO_DOMAIN=$(cat ${FILE_PATH}/boot.log | grep -o "info.*https://.*trycloudflare.com" | sed "s@.*https://@@g" | tail -n 1)
  fi
  general_upload_data
}

# build_urls
build_urls() {
  echo "${UPLOAD_DATA}" | base64 | tr -d '\n' > "${FILE_PATH}/log.txt"
}

# upload
upload_subscription() {
  if command -v curl &> /dev/null; then
    response=$(curl -s -X POST -H "Content-Type: application/json" -d "{\"URL_NAME\":\"$SUB_NAME\",\"URL\":\"$UPLOAD_DATA\"}" $SUB_URL)
  elif command -v wget &> /dev/null; then
    response=$(wget -qO- --post-data="{\"URL_NAME\":\"$SUB_NAME\",\"URL\":\"$UPLOAD_DATA\"}" --header="Content-Type: application/json" $SUB_URL)
  fi
}

# main
main() {
  cleanup_files
  initialize_downloads
  my_config
  run_processes
}
main

# tail -f /dev/null
