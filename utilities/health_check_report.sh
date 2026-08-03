#!/bin/bash
# health_check_report.sh - Generate comprehensive health check report
# Usage: ./health_check_report.sh [--format html|text|json] [--output file] [--email recipient]

set -euo pipefail

FORMAT="html"
OUTPUT=""
EMAIL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --format) FORMAT="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --email) EMAIL="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

OUTPUT_FILE="${OUTPUT:-/tmp/health_report_$(date +%Y%m%d_%H%M%S).$FORMAT}"
HOSTNAME=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M:%S')

generate_html() {
    cat <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Health Check Report - $HOSTNAME</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 40px; background: #fafafa; }
        .container { max-width: 1000px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #1a1a2e; border-bottom: 3px solid #16213e; padding-bottom: 10px; }
        h2 { color: #16213e; margin-top: 30px; }
        .meta { color: #666; margin-bottom: 30px; }
        .section { margin-bottom: 25px; }
        .metric { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #eee; }
        .metric:last-child { border-bottom: none; }
        .metric-label { color: #555; }
        .metric-value { font-weight: 600; }
        .status-ok { color: #28a745; }
        .status-warn { color: #ffc107; }
        .status-crit { color: #dc3545; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #eee; }
        th { background: #f8f9fa; font-weight: 600; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee; color: #999; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🏥 System Health Check Report</h1>
        <div class="meta">
            <strong>Host:</strong> $HOSTNAME | <strong>Date:</strong> $DATE | <strong>Uptime:</strong> $(uptime -p)
        </div>
        
        <div class="section">
            <h2>💾 Disk Usage</h2>
            <table>
                <tr><th>Mount</th><th>Size</th><th>Used</th><th>Avail</th><th>Use%</th><th>Status</th></tr>
EOF
    df -hP | tail -n +2 | while read -r line; do
        MOUNT=$(echo "$line" | awk '{print $6}')
        SIZE=$(echo "$line" | awk '{print $2}')
        USED=$(echo "$line" | awk '{print $3}')
        AVAIL=$(echo "$line" | awk '{print $4}')
        USE=$(echo "$line" | awk '{print $5}')
        USE_NUM=$(echo "$USE" | sed 's/%//')
        
        if [[ $USE_NUM -ge 90 ]]; then
            CLASS="status-crit"
        elif [[ $USE_NUM -ge 75 ]]; then
            CLASS="status-warn"
        else
            CLASS="status-ok"
        fi
        
        cat <<ROW
                <tr><td>$MOUNT</td><td>$SIZE</td><td>$USED</td><td>$AVAIL</td><td>$USE</td><td class="$CLASS">$([[ $USE_NUM -ge 90 ]] && echo "Critical" || [[ $USE_NUM -ge 75 ]] && echo "Warning" || echo "OK")</td></tr>
ROW
    done
    
    cat <<EOF
            </table>
        </div>
        
        <div class="section">
            <h2>🧠 Memory</h2>
EOF
    free -h | awk 'NR==2{printf "        <div class=\"metric\"><span class=\"metric-label\">Total</span><span class=\"metric-value\">%s</span></div>\n        <div class=\"metric\"><span class=\"metric-label\">Used</span><span class=\"metric-value\">%s</span></div>\n        <div class=\"metric\"><span class=\"metric-label\">Free</span><span class=\"metric-value\">%s</span></div>\n        <div class=\"metric\"><span class=\"metric-label\">Available</span><span class=\"metric-value\">%s</span></div>\n", $2, $3, $4, $7}'
    
    cat <<EOF
        </div>
        
        <div class="section">
            <h2>⚡ CPU</h2>
EOF
    LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    CORES=$(nproc)
    LOAD_PER_CORE=$(echo "scale=2; $LOAD / $CORES" | bc)
    
    if (( $(echo "$LOAD_PER_CORE > 2" | bc -l) )); then
        CPU_CLASS="status-crit"
    elif (( $(echo "$LOAD_PER_CORE > 1" | bc -l) )); then
        CPU_CLASS="status-warn"
    else
        CPU_CLASS="status-ok"
    fi
    
    cat <<EOF
            <div class="metric"><span class="metric-label">Load Average</span><span class="metric-value $CPU_CLASS">$LOAD (per core: $LOAD_PER_CORE)</span></div>
            <div class="metric"><span class="metric-label">Cores</span><span class="metric-value">$CORES</span></div>
        </div>
        
        <div class="section">
            <h2>🐳 Docker</h2>
EOF
    if command -v docker &>/dev/null; then
        RUNNING=$(docker ps -q | wc -l)
        TOTAL=$(docker ps -aq | wc -l)
        UNHEALTHY=$(docker ps --filter "health=unhealthy" -q | wc -l)
        
        cat <<EOF
            <div class="metric"><span class="metric-label">Running</span><span class="metric-value">$RUNNING</span></div>
            <div class="metric"><span class="metric-label">Total</span><span class="metric-value">$TOTAL</span></div>
            <div class="metric"><span class="metric-label">Unhealthy</span><span class="metric-value $([[ $UNHEALTHY -gt 0 ]] && echo "status-crit" || echo "status-ok")">$UNHEALTHY</span></div>
EOF
    else
        echo "            <div class=\"metric\"><span class=\"metric-label\">Status</span><span class=\"metric-value\">Not installed</span></div>"
    fi
    
    cat <<EOF
        </div>
        
        <div class="section">
            <h2>🌡️ Temperatures</h2>
            <table>
                <tr><th>Device</th><th>Temperature</th><th>Status</th></tr>
EOF
    lsblk -d -n -o NAME | while read -r disk; do
        TEMP=$(smartctl -A "/dev/$disk" 2>/dev/null | grep -i "Temperature_Celsius" | awk '{print $10}' || echo "")
        if [[ -n "$TEMP" && "$TEMP" =~ ^[0-9]+$ ]]; then
            if [[ $TEMP -ge 55 ]]; then
                TEMP_CLASS="status-crit"
            elif [[ $TEMP -ge 45 ]]; then
                TEMP_CLASS="status-warn"
            else
                TEMP_CLASS="status-ok"
            fi
            cat <<ROW
                <tr><td>$disk</td><td>${TEMP}°C</td><td class="$TEMP_CLASS">$([[ $TEMP -ge 55 ]] && echo "Critical" || [[ $TEMP -ge 45 ]] && echo "Warning" || echo "OK")</td></tr>
ROW
        fi
    done
    
    cat <<EOF
            </table>
        </div>
        
        <div class="section">
            <h2>🔧 Services</h2>
            <table>
                <tr><th>Service</th><th>Status</th><th>Enabled</th></tr>
EOF
    for svc in docker sshd nginx smbd nfs-server; do
        if systemctl list-unit-files | grep -q "^$svc.service"; then
            STATUS=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")
            ENABLED=$(systemctl is-enabled "$svc" 2>/dev/null || echo "disabled")
            STATUS_CLASS=$([[ "$STATUS" == "active" ]] && echo "status-ok" || echo "status-crit")
            cat <<ROW
                <tr><td>$svc</td><td class="$STATUS_CLASS">$STATUS</td><td>$ENABLED</td></tr>
ROW
        fi
    done
    
    cat <<EOF
            </table>
        </div>
        
        <div class="footer">
            Generated by health_check_report.sh on $HOSTNAME at $DATE
        </div>
    </div>
</body>
</html>
EOF
}

generate_text() {
    cat <<EOF
=== System Health Check Report ===
Host: $HOSTNAME
Date: $DATE
Uptime: $(uptime -p)

--- Disk Usage ---
$(df -hP | tail -n +2 | awk '{printf "  %-20s %5s %5s %5s %5s %s\n", $6, $2, $3, $4, $5, ($5+0>=90?"CRITICAL":($5+0>=75?"WARNING":"OK"))}')

--- Memory ---
$(free -h | awk 'NR==2{printf "  Total: %s, Used: %s, Free: %s, Available: %s\n", $2, $3, $4, $7}')

--- CPU ---
Load: $(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//') ($(nproc) cores)

--- Docker ---
$(if command -v docker &>/dev/null; then echo "  Running: $(docker ps -q | wc -l), Total: $(docker ps -aq | wc -l), Unhealthy: $(docker ps --filter "health=unhealthy" -q | wc -l)"; else echo "  Not installed"; fi)

--- Temperatures ---
$(lsblk -d -n -o NAME | while read -r disk; do TEMP=$(smartctl -A "/dev/$disk" 2>/dev/null | grep -i "Temperature_Celsius" | awk '{print $10}' || echo ""); [[ -n "$TEMP" ]] && echo "  $disk: ${TEMP}°C"; done)

--- Services ---
$(for svc in docker sshd nginx smbd nfs-server; do if systemctl list-unit-files | grep -q "^$svc.service"; then STATUS=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive"); ENABLED=$(systemctl is-enabled "$svc" 2>/dev/null || echo "disabled"); echo "  $svc: $STATUS ($ENABLED)"; fi; done)
EOF
}

generate_json() {
    cat <<EOF
{
  "host": "$HOSTNAME",
  "date": "$DATE",
  "uptime": "$(uptime -p)",
  "disk": [
EOF
    df -hP | tail -n +2 | while read -r line; do
        MOUNT=$(echo "$line" | awk '{print $6}')
        SIZE=$(echo "$line" | awk '{print $2}')
        USED=$(echo "$line" | awk '{print $3}')
        AVAIL=$(echo "$line" | awk '{print $4}')
        USE=$(echo "$line" | awk '{print $5}')
        echo "    {\"mount\":\"$MOUNT\",\"size\":\"$SIZE\",\"used\":\"$USED\",\"avail\":\"$AVAIL\",\"use\":\"$USE\"},"
    done | sed '$s/,$//'
    
    cat <<EOF
  ],
  "memory": {
    "total": "$(free -h | awk 'NR==2{print $2}')",
    "used": "$(free -h | awk 'NR==2{print $3}')",
    "free": "$(free -h | awk 'NR==2{print $4}')",
    "available": "$(free -h | awk 'NR==2{print $7}')"
  },
  "cpu": {
    "load": "$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')",
    "cores": $(nproc)
  },
  "docker": {
    "running": $(docker ps -q | wc -l 2>/dev/null || echo 0),
    "total": $(docker ps -aq | wc -l 2>/dev/null || echo 0),
    "unhealthy": $(docker ps --filter "health=unhealthy" -q | wc -l 2>/dev/null || echo 0)
  },
  "services": {
EOF
    FIRST=true
    for svc in docker sshd nginx smbd nfs-server; do
        if systemctl list-unit-files | grep -q "^$svc.service"; then
            STATUS=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")
            ENABLED=$(systemctl is-enabled "$svc" 2>/dev/null || echo "disabled")
            [[ "$FIRST" == true ]] && FIRST=false || echo ","
            echo "    \"$svc\": {\"status\":\"$STATUS\",\"enabled\":\"$ENABLED\"}"
        fi
    done
    
    cat <<EOF
  }
}
EOF
}

case $FORMAT in
    html) generate_html > "$OUTPUT_FILE" ;;
    text) generate_text > "$OUTPUT_FILE" ;;
    json) generate_json > "$OUTPUT_FILE" ;;
    *) echo "Unknown format: $FORMAT"; exit 1 ;;
esac

echo "Report generated: $OUTPUT_FILE"

if [[ -n "$EMAIL" ]]; then
    if command -v mail &>/dev/null; then
        if [[ "$FORMAT" == "html" ]]; then
            mail -s "Health Check Report - $HOSTNAME" -a "Content-Type: text/html" "$EMAIL" < "$OUTPUT_FILE"
        else
            mail -s "Health Check Report - $HOSTNAME" "$EMAIL" < "$OUTPUT_FILE"
        fi
        echo "Report emailed to $EMAIL"
    fi
fi