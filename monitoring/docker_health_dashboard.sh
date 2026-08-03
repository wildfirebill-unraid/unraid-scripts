#!/bin/bash
# docker_health_dashboard.sh - Generate HTML dashboard for Docker container health
# Usage: ./docker_health_dashboard.sh [--output /path/to/dashboard.html] [--refresh N]

set -euo pipefail

OUTPUT="/mnt/user/appdata/docker-dashboard/index.html"
REFRESH=30

while [[ $# -gt 0 ]]; do
    case $1 in
        --output) OUTPUT="$2"; shift 2 ;;
        --refresh) REFRESH="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

mkdir -p "$(dirname "$OUTPUT")"

cat > "$OUTPUT" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Docker Health Dashboard</title>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="REFRESH_INTERVAL">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 20px; background: #f5f5f5; }
        h1 { color: #333; }
        .container { max-width: 1200px; margin: 0 auto; }
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(350px, 1fr)); gap: 20px; }
        .card { background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .card h3 { margin: 0 0 15px 0; padding-bottom: 10px; border-bottom: 1px solid #eee; }
        .status { display: inline-block; padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: bold; }
        .status.running { background: #d4edda; color: #155724; }
        .status.unhealthy { background: #f8d7da; color: #721c24; }
        .status.exited { background: #fff3cd; color: #856404; }
        .status.stopped { background: #e2e3e5; color: #383d41; }
        .metric { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #f0f0f0; }
        .metric:last-child { border-bottom: none; }
        .metric-label { color: #666; }
        .metric-value { font-weight: 600; }
        .progress-bar { height: 8px; background: #eee; border-radius: 4px; overflow: hidden; margin-top: 10px; }
        .progress-fill { height: 100%; border-radius: 4px; transition: width 0.3s; }
        .progress-fill.cpu { background: #007bff; }
        .progress-fill.mem { background: #28a745; }
        .timestamp { color: #999; font-size: 12px; text-align: right; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🐳 Docker Health Dashboard</h1>
        <div class="grid" id="containers"></div>
        <div class="timestamp">Last updated: <span id="timestamp"></span></div>
    </div>
    <script>
        async function fetchData() {
            try {
                const response = await fetch('/api/docker/stats');
                const data = await response.json();
                renderContainers(data);
                document.getElementById('timestamp').textContent = new Date().toLocaleString();
            } catch (e) {
                console.error('Failed to fetch data:', e);
            }
        }
        
        function renderContainers(containers) {
            const grid = document.getElementById('containers');
            grid.innerHTML = '';
            
            containers.forEach(c => {
                const card = document.createElement('div');
                card.className = 'card';
                
                const cpuPercent = parseFloat(c.CPUPerc.replace('%', '')) || 0;
                const memPercent = parseFloat(c.MemPerc.replace('%', '')) || 0;
                
                let statusClass = c.Status.toLowerCase().includes('up') ? 'running' : 
                                  c.Status.toLowerCase().includes('unhealthy') ? 'unhealthy' : 'stopped';
                
                card.innerHTML = `
                    <h3>${c.Names}</h3>
                    <span class="status ${statusClass}">${c.Status}</span>
                    <div class="metric">
                        <span class="metric-label">Image</span>
                        <span class="metric-value">${c.Image}</span>
                    </div>
                    <div class="metric">
                        <span class="metric-label">CPU</span>
                        <span class="metric-value">${c.CPUPerc}</span>
                    </div>
                    <div class="progress-bar">
                        <div class="progress-fill cpu" style="width: ${Math.min(cpuPercent, 100)}%"></div>
                    </div>
                    <div class="metric">
                        <span class="metric-label">Memory</span>
                        <span class="metric-value">${c.MemPerc} (${c.MemUsage})</span>
                    </div>
                    <div class="progress-bar">
                        <div class="progress-fill mem" style="width: ${Math.min(memPercent, 100)}%"></div>
                    </div>
                    <div class="metric">
                        <span class="metric-label">Network I/O</span>
                        <span class="metric-value">${c.NetIO}</span>
                    </div>
                    <div class="metric">
                        <span class="metric-label">Block I/O</span>
                        <span class="metric-value">${c.BlockIO}</span>
                    </div>
                    <div class="metric">
                        <span class="metric-label">PIDs</span>
                        <span class="metric-value">${c.PIDs}</span>
                    </div>
                `;
                grid.appendChild(card);
            });
        }
        
        fetchData();
        setInterval(fetchData, REFRESH_INTERVAL * 1000);
    </script>
</body>
</html>
EOF

sed -i "s/REFRESH_INTERVAL/$REFRESH/g" "$OUTPUT"

echo "Dashboard generated: $OUTPUT"
echo "Note: This dashboard requires a backend API at /api/docker/stats"
echo "You can use a simple Python Flask server or nginx with docker stats JSON output"