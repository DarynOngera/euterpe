defmodule MyMusicServer.AdminDashboard do
  @moduledoc """
  Pure HTML/CSS/JS admin dashboard served at /admin.
  No external dependencies — entirely self-contained.
  """

  def html do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>MyMusicServer Admin</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: #0f0f0f;
          color: #e0e0e0;
          line-height: 1.6;
        }
        .container { max-width: 1400px; margin: 0 auto; padding: 20px; }
        header {
          border-bottom: 1px solid #333;
          padding-bottom: 20px;
          margin-bottom: 30px;
        }
        h1 { font-size: 2rem; color: #fff; margin-bottom: 5px; }
        .status-line { color: #888; font-size: 0.9rem; }
        .status-line .online { color: #4caf50; }
        .status-line .offline { color: #f44336; }
        .grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
          gap: 20px;
        }
        .card {
          background: #1a1a1a;
          border: 1px solid #333;
          border-radius: 8px;
          padding: 20px;
        }
        .card h2 {
          font-size: 1.1rem;
          color: #fff;
          margin-bottom: 15px;
          padding-bottom: 10px;
          border-bottom: 1px solid #333;
        }
        .metric {
          display: flex;
          justify-content: space-between;
          padding: 8px 0;
          border-bottom: 1px solid #222;
        }
        .metric:last-child { border-bottom: none; }
        .metric-label { color: #888; }
        .metric-value { color: #fff; font-weight: 600; }
        .job-item {
          padding: 10px;
          margin-bottom: 8px;
          border-radius: 4px;
          background: #222;
          font-size: 0.85rem;
        }
        .job-item .job-id { color: #888; font-size: 0.75rem; }
        .job-status {
          display: inline-block;
          padding: 2px 8px;
          border-radius: 3px;
          font-size: 0.75rem;
          font-weight: 600;
          text-transform: uppercase;
        }
        .status-queued { background: #ff9800; color: #000; }
        .status-running { background: #2196f3; color: #fff; }
        .status-done { background: #4caf50; color: #fff; }
        .status-failed { background: #f44336; color: #fff; }
        .status-completed { background: #4caf50; color: #fff; }
        .status-errored { background: #f44336; color: #fff; }
        .status-started { background: #2196f3; color: #fff; }
        .status-claimed { background: #2196f3; color: #fff; }
        .status-retrying { background: #ff9800; color: #000; }
        .log {
          font-family: 'Consolas', 'Monaco', monospace;
          font-size: 0.8rem;
          max-height: 300px;
          overflow-y: auto;
        }
        .log-entry { padding: 4px 0; border-bottom: 1px solid #222; }
        .log-time { color: #666; }
        .controls { display: flex; gap: 10px; margin-top: 15px; }
        button {
          background: #333; color: #fff; border: 1px solid #444;
          padding: 8px 16px; border-radius: 4px; cursor: pointer; font-size: 0.9rem;
        }
        button:hover { background: #444; }
        .player-card { text-align: center; padding: 30px; }
        .player-card .now-playing { font-size: 1.2rem; color: #fff; margin: 10px 0; }
        .player-card .artist { color: #888; font-size: 0.9rem; }
        .pulse {
          display: inline-block; width: 10px; height: 10px;
          border-radius: 50%; background: #4caf50; margin-right: 8px;
          animation: pulse 2s infinite;
        }
        @keyframes pulse {
          0% { opacity: 1; } 50% { opacity: 0.3; } 100% { opacity: 1; }
        }
        .empty { color: #555; font-style: italic; text-align: center; padding: 20px; }
      </style>
    </head>
    <body>
      <div class="container">
        <header>
          <h1>MyMusicServer Admin</h1>
          <div class="status-line">
            <span class="pulse"></span>
            <span id="connection-status" class="online">Connected</span>
            | Uptime: <span id="uptime">0s</span>
            | Port: 5000
          </div>
        </header>

        <div class="grid">
          <div class="card">
            <h2>System Health</h2>
            <div class="metric"><span class="metric-label">Workers</span><span class="metric-value" id="worker-count">-</span></div>
            <div class="metric"><span class="metric-label">Queue Depth</span><span class="metric-value" id="queue-depth">-</span></div>
            <div class="metric"><span class="metric-label">Active Jobs</span><span class="metric-value" id="active-jobs">-</span></div>
            <div class="metric"><span class="metric-label">Total Jobs</span><span class="metric-value" id="total-jobs">-</span></div>
          </div>

          <div class="card">
            <h2>Catalog Stats</h2>
            <div class="metric"><span class="metric-label">Total Songs</span><span class="metric-value" id="total-songs">-</span></div>
            <div class="metric"><span class="metric-label">Total Playlists</span><span class="metric-value" id="total-playlists">-</span></div>
            <div class="metric"><span class="metric-label">Processing</span><span class="metric-value" id="processing-songs">-</span></div>
          </div>

          <div class="card player-card">
            <h2>Now Playing</h2>
            <div id="now-playing" class="empty">No song playing</div>
            <div class="controls">
              <button onclick="fetch('/player/stop', {method: 'POST'})">Stop</button>
              <button onclick="location.reload()">Refresh</button>
            </div>
          </div>

          <div class="card">
            <h2>Live Jobs</h2>
            <div id="live-jobs" class="empty">No active jobs</div>
          </div>

          <div class="card">
            <h2>Recent Events</h2>
            <div id="event-log" class="log">
              <div class="log-entry"><span class="log-time">--:--:--</span> Waiting for events...</div>
            </div>
          </div>

          <div class="card">
            <h2>Job Stats</h2>
            <div class="metric"><span class="metric-label">Queued</span><span class="metric-value" id="stat-queued">-</span></div>
            <div class="metric"><span class="metric-label">Running</span><span class="metric-value" id="stat-running">-</span></div>
            <div class="metric"><span class="metric-label">Done</span><span class="metric-value" id="stat-done">-</span></div>
            <div class="metric"><span class="metric-label">Failed</span><span class="metric-value" id="stat-failed">-</span></div>
          </div>
        </div>
      </div>

      <script>
        const startTime = Date.now();
        function updateUptime() {
          const seconds = Math.floor((Date.now() - startTime) / 1000);
          const mins = Math.floor(seconds / 60);
          const hrs = Math.floor(mins / 60);
          let text = seconds + 's';
          if (mins > 0) text = mins + 'm ' + (seconds % 60) + 's';
          if (hrs > 0) text = hrs + 'h ' + (mins % 60) + 'm';
          document.getElementById('uptime').textContent = text;
        }
        setInterval(updateUptime, 1000);

        async function fetchStats() {
          try {
            const [statsRes, songsRes, playlistsRes, currentRes, jobsRes] = await Promise.all([
              fetch('/stats'), fetch('/songs'), fetch('/playlists'),
              fetch('/player/current'), fetch('/jobs?status=running')
            ]);
            const stats = await statsRes.json();
            const songs = await songsRes.json();
            const playlists = await playlistsRes.json();
            const current = await currentRes.json();
            const runningJobs = await jobsRes.json();

            document.getElementById('stat-queued').textContent = stats.queued || 0;
            document.getElementById('stat-running').textContent = stats.running || 0;
            document.getElementById('stat-done').textContent = stats.done || 0;
            document.getElementById('stat-failed').textContent = stats.failed || 0;
            document.getElementById('queue-depth').textContent = stats.queued || 0;
            document.getElementById('active-jobs').textContent = stats.running || 0;
            document.getElementById('total-jobs').textContent = stats.total || 0;
            document.getElementById('total-songs').textContent = songs.length;
            document.getElementById('total-playlists').textContent = playlists.length;
            document.getElementById('processing-songs').textContent = songs.filter(s => s.status === 'processing').length;

            if (current.current) {
              document.getElementById('now-playing').innerHTML =
                '<div class="now-playing">' + escapeHtml(current.current.title) + '</div>' +
                '<div class="artist">' + escapeHtml(current.current.artist) + '</div>';
            } else {
              document.getElementById('now-playing').innerHTML = '<div class="empty">No song playing</div>';
            }

            const liveJobsEl = document.getElementById('live-jobs');
            if (runningJobs.length > 0) {
              liveJobsEl.innerHTML = runningJobs.map(j =>
                '<div class="job-item">' +
                '<span class="job-status status-running">RUNNING</span> ' +
                '<span class="job-id">#' + j.id + '</span> ' +
                escapeHtml(j.payload && j.payload.task ? j.payload.task : 'job') +
                '</div>'
              ).join('');
            } else {
              liveJobsEl.innerHTML = '<div class="empty">No active jobs</div>';
            }
          } catch (e) { console.error('Stats fetch failed:', e); }
        }

        function escapeHtml(text) {
          if (!text) return '';
          const div = document.createElement('div');
          div.textContent = text;
          return div.innerHTML;
        }

        function addLogEntry(event, data) {
          const log = document.getElementById('event-log');
          const time = new Date().toLocaleTimeString();
          const statusClass = 'status-' + event;
          const entry = document.createElement('div');
          entry.className = 'log-entry';
          entry.innerHTML = '<span class="log-time">' + time + '</span> ' +
            '<span class="job-status ' + statusClass + '">' + event.toUpperCase() + '</span> ' +
            'Job #' + data.job_id + ' ' + (data.task || '');
          log.insertBefore(entry, log.firstChild);
          while (log.children.length > 50) { log.removeChild(log.lastChild); }
        }

        function connectSSE() {
          const es = new EventSource('/events');
          es.onopen = () => {
            document.getElementById('connection-status').textContent = 'Connected';
            document.getElementById('connection-status').className = 'online';
          };
          es.onerror = () => {
            document.getElementById('connection-status').textContent = 'Reconnecting...';
            document.getElementById('connection-status').className = 'offline';
          };
          es.onmessage = (e) => {
            try {
              const data = JSON.parse(e.data);
              if (data.event) { addLogEntry(data.event, data); fetchStats(); }
            } catch (err) { console.log('SSE raw:', e.data); }
          };
        }

        fetchStats();
        setInterval(fetchStats, 5000);
        connectSSE();
      </script>
    </body>
    </html>
    """
  end
end
