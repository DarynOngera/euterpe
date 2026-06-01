defmodule Euterpe.PublicPage do
  @moduledoc """
  Public-facing SPA for browsing, playing, uploading, and managing music.
  Served at GET /player. Pure HTML/CSS/JS, zero dependencies.
  """

  def html do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <title>Euterpe — Player</title>
      <style>
        :root {
          --bg: #0a0a0a;
          --surface: #141414;
          --surface-hover: #1e1e1e;
          --border: #2a2a2a;
          --text: #e8e8e8;
          --text-muted: #888;
          --accent: #1db954;
          --accent-hover: #1ed760;
          --danger: #e22134;
          --warning: #f5a623;
          --info: #4a90d9;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }
        html, body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
          background: var(--bg);
          color: var(--text);
          height: 100%;
          overflow: hidden;
        }

        #app { display: flex; flex-direction: column; height: 100vh; overflow: hidden; }

        .top-bar {
          display: flex; align-items: center; justify-content: space-between;
          padding: 12px 20px; background: var(--surface); border-bottom: 1px solid var(--border); z-index: 100;
        }
        .logo { font-size: 1.3rem; font-weight: 700; color: var(--accent); letter-spacing: -0.5px; }
        .top-actions { display: flex; gap: 10px; }

        .main-layout { display: flex; flex: 1; overflow: hidden; }

        .sidebar {
          width: 260px; background: var(--surface); border-right: 1px solid var(--border);
          display: flex; flex-direction: column; overflow: hidden; transition: transform 0.2s;
        }
        .sidebar-section { padding: 16px; border-bottom: 1px solid var(--border); }
        .sidebar-title {
          font-size: 0.75rem; text-transform: uppercase; letter-spacing: 1px;
          color: var(--text-muted); margin-bottom: 12px;
        }
        .nav-item {
          display: flex; align-items: center; gap: 12px; padding: 8px 12px;
          border-radius: 6px; cursor: pointer; font-size: 0.9rem; transition: background 0.15s;
        }
        .nav-item:hover, .nav-item.active { background: var(--surface-hover); }
        .nav-item svg { width: 20px; height: 20px; fill: currentColor; opacity: 0.7; }
        .nav-item.active { color: var(--accent); }
        .nav-item.active svg { opacity: 1; }

        .playlist-item {
          display: flex; align-items: center; gap: 10px; padding: 6px 12px;
          border-radius: 4px; cursor: pointer; font-size: 0.85rem;
          color: var(--text-muted); transition: all 0.15s;
        }
        .playlist-item:hover, .playlist-item.active { color: var(--text); background: var(--surface-hover); }

        .content { flex: 1; overflow-y: auto; padding: 24px; scroll-behavior: smooth; }
        .content-header {
          display: flex; align-items: center; justify-content: space-between; margin-bottom: 24px;
        }
        .content-title { font-size: 1.8rem; font-weight: 700; }
        .search-box {
          background: var(--surface); border: 1px solid var(--border); border-radius: 20px;
          padding: 8px 16px; color: var(--text); font-size: 0.9rem; width: 240px; outline: none;
        }
        .search-box:focus { border-color: var(--accent); }
        .search-box::placeholder { color: var(--text-muted); }

        .song-grid {
          display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 20px;
        }
        .song-card {
          background: var(--surface); border-radius: 8px; padding: 16px; cursor: pointer;
          transition: background 0.15s, transform 0.15s; position: relative;
        }
        .song-card:hover { background: var(--surface-hover); transform: translateY(-2px); }
        .song-card-thumb {
          width: 100%; aspect-ratio: 1; background: linear-gradient(135deg, #1a1a1a, #2a2a2a);
          border-radius: 6px; margin-bottom: 12px; display: flex; align-items: center; justify-content: center;
          position: relative; overflow: hidden;
        }
        .song-card-thumb .waveform-placeholder { width: 60%; height: 40%; opacity: 0.3; }
        .play-overlay {
          position: absolute; inset: 0; background: rgba(0,0,0,0.5);
          display: flex; align-items: center; justify-content: center;
          opacity: 0; transition: opacity 0.2s;
        }
        .song-card:hover .play-overlay { opacity: 1; }
        .play-btn {
          width: 48px; height: 48px; border-radius: 50%; background: var(--accent); border: none;
          display: flex; align-items: center; justify-content: center; cursor: pointer;
          transition: transform 0.15s, background 0.15s;
        }
        .play-btn:hover { transform: scale(1.1); background: var(--accent-hover); }
        .play-btn svg { width: 20px; height: 20px; fill: #000; margin-left: 3px; }
        .song-card-title {
          font-size: 0.95rem; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
          margin-bottom: 4px;
        }
        .song-card-artist {
          font-size: 0.8rem; color: var(--text-muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
        }
        .song-card-meta {
          display: flex; align-items: center; gap: 8px; margin-top: 8px;
          font-size: 0.75rem; color: var(--text-muted);
        }
        .song-card-meta .badge {
          background: var(--border); padding: 2px 6px; border-radius: 3px; font-size: 0.7rem;
        }
        .song-actions-btn {
          position: absolute; top: 8px; right: 8px; background: rgba(0,0,0,0.6);
          border: none; color: var(--text); width: 28px; height: 28px; border-radius: 50%;
          cursor: pointer; display: flex; align-items: center; justify-content: center;
          opacity: 0; transition: opacity 0.15s; z-index: 10;
        }
        .song-card:hover .song-actions-btn { opacity: 1; }
        .song-actions-btn:hover { background: rgba(0,0,0,0.9); color: var(--accent); }

        .player-bar {
          height: 80px; background: var(--surface); border-top: 1px solid var(--border);
          display: flex; align-items: center; padding: 0 20px; gap: 20px; z-index: 100;
        }
        .player-track {
          display: flex; align-items: center; gap: 12px; width: 280px; min-width: 200px;
        }
        .player-thumb {
          width: 48px; height: 48px; background: var(--border); border-radius: 4px; flex-shrink: 0;
          display: flex; align-items: center; justify-content: center; font-size: 0.7rem; color: var(--text-muted);
        }
        .player-info { overflow: hidden; }
        .player-title { font-size: 0.9rem; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .player-artist { font-size: 0.8rem; color: var(--text-muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

        .player-controls {
          display: flex; flex-direction: column; align-items: center; flex: 1; gap: 6px;
        }
        .control-buttons { display: flex; align-items: center; gap: 16px; }
        .ctrl-btn {
          background: none; border: none; color: var(--text-muted); cursor: pointer; padding: 4px;
          display: flex; align-items: center; justify-content: center; transition: color 0.15s;
        }
        .ctrl-btn:hover { color: var(--text); }
        .ctrl-btn svg { width: 20px; height: 20px; fill: currentColor; }
        .ctrl-btn.main { color: var(--text); }
        .ctrl-btn.main svg { width: 32px; height: 32px; }

        .progress-container {
          display: flex; align-items: center; gap: 8px; width: 100%; max-width: 600px;
        }
        .time-label { font-size: 0.7rem; color: var(--text-muted); width: 36px; text-align: center; }
        .progress-bar {
          flex: 1; height: 4px; background: var(--border); border-radius: 2px;
          cursor: pointer; position: relative;
        }
        .progress-fill {
          height: 100%; background: var(--accent); border-radius: 2px; width: 0%; position: relative;
        }
        .progress-fill::after {
          content: ''; position: absolute; right: -6px; top: 50%; transform: translateY(-50%);
          width: 12px; height: 12px; background: var(--text); border-radius: 50%; opacity: 0;
          transition: opacity 0.15s;
        }
        .progress-bar:hover .progress-fill::after { opacity: 1; }

        .player-extras {
          display: flex; align-items: center; gap: 12px; width: 200px; justify-content: flex-end;
        }
        .volume-slider {
          width: 80px; height: 4px; background: var(--border); border-radius: 2px;
          cursor: pointer; position: relative;
        }
        .volume-fill { height: 100%; background: var(--accent); border-radius: 2px; width: 70%; }

        /* ===== Modals ===== */
        .modal-overlay {
          position: fixed; inset: 0; background: rgba(0,0,0,0.7);
          display: none; align-items: center; justify-content: center;
          z-index: 200; backdrop-filter: blur(4px);
        }
        .modal-overlay.show { display: flex; }
        .modal {
          background: var(--surface); border: 1px solid var(--border); border-radius: 12px;
          padding: 24px; width: 90%; max-width: 520px; max-height: 85vh; overflow-y: auto;
        }
        .modal-header {
          display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px;
        }
        .modal-title { font-size: 1.2rem; font-weight: 700; }
        .modal-close {
          background: none; border: none; color: var(--text-muted); font-size: 1.5rem;
          cursor: pointer; line-height: 1;
        }
        .modal-body { margin-bottom: 20px; }
        .modal-footer { display: flex; gap: 10px; justify-content: flex-end; }

        .drop-zone {
          border: 2px dashed var(--border); border-radius: 8px; padding: 40px 20px;
          text-align: center; color: var(--text-muted); transition: all 0.2s; cursor: pointer;
        }
        .drop-zone.dragover {
          border-color: var(--accent); background: rgba(29, 185, 84, 0.05); color: var(--text);
        }
        .drop-zone svg { width: 40px; height: 40px; fill: currentColor; margin-bottom: 12px; opacity: 0.5; }
        .form-group { margin-bottom: 16px; }
        .form-label { display: block; font-size: 0.85rem; color: var(--text-muted); margin-bottom: 6px; }
        .form-input {
          width: 100%; background: var(--bg); border: 1px solid var(--border); border-radius: 6px;
          padding: 10px 12px; color: var(--text); font-size: 0.9rem; outline: none;
        }
        .form-input:focus { border-color: var(--accent); }
        .btn {
          background: var(--accent); color: #000; border: none; border-radius: 20px;
          padding: 10px 24px; font-size: 0.9rem; font-weight: 600; cursor: pointer;
          transition: background 0.15s; display: inline-flex; align-items: center; gap: 6px;
        }
        .btn:hover { background: var(--accent-hover); }
        .btn.full { width: 100%; justify-content: center; }
        .btn.secondary { background: var(--border); color: var(--text); }
        .btn.secondary:hover { background: var(--surface-hover); }
        .btn.danger { background: var(--danger); color: #fff; }
        .btn.danger:hover { background: #ff4d5e; }
        .btn:disabled { opacity: 0.5; cursor: not-allowed; }
        .btn-spinner {
          width: 16px; height: 16px; border: 2px solid rgba(0,0,0,0.3);
          border-top-color: #000; border-radius: 50%; animation: spin 0.8s linear infinite;
        }
        @keyframes spin { to { transform: rotate(360deg); } }

        /* ===== Detail Modal ===== */
        .detail-meta {
          display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: 12px;
          margin: 16px 0; padding: 16px; background: var(--bg); border-radius: 8px;
        }
        .detail-meta-item { text-align: center; }
        .detail-meta-label { font-size: 0.7rem; color: var(--text-muted); text-transform: uppercase; }
        .detail-meta-value { font-size: 1rem; font-weight: 600; margin-top: 4px; }
        .detail-actions {
          display: flex; flex-wrap: wrap; gap: 8px; margin-top: 16px;
        }
        .detail-actions .btn { padding: 8px 16px; font-size: 0.8rem; border-radius: 16px; }

        /* ===== Queue Drawer ===== */
        .queue-drawer {
          position: fixed; right: 0; top: 0; bottom: 80px; width: 320px;
          background: var(--surface); border-left: 1px solid var(--border);
          transform: translateX(100%); transition: transform 0.2s; z-index: 120;
          display: flex; flex-direction: column;
        }
        .queue-drawer.open { transform: translateX(0); }
        .queue-header {
          padding: 16px; border-bottom: 1px solid var(--border);
          display: flex; align-items: center; justify-content: space-between;
        }
        .queue-title { font-weight: 600; }
        .queue-list { flex: 1; overflow-y: auto; padding: 8px; }
        .queue-item {
          display: flex; align-items: center; gap: 10px; padding: 8px;
          border-radius: 6px; cursor: pointer; transition: background 0.15s;
        }
        .queue-item:hover { background: var(--surface-hover); }
        .queue-item.active { color: var(--accent); }
        .queue-item .q-num { width: 24px; text-align: center; font-size: 0.8rem; color: var(--text-muted); }
        .queue-item .q-info { flex: 1; overflow: hidden; }
        .queue-item .q-title { font-size: 0.85rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .queue-item .q-artist { font-size: 0.75rem; color: var(--text-muted); }

        /* ===== Toast Notifications ===== */
        .toast-container {
          position: fixed; top: 20px; right: 20px; z-index: 300;
          display: flex; flex-direction: column; gap: 10px;
        }
        .toast {
          background: var(--surface); border: 1px solid var(--border); border-radius: 8px;
          padding: 14px 18px; min-width: 300px; max-width: 400px;
          box-shadow: 0 8px 24px rgba(0,0,0,0.4); animation: toastIn 0.3s ease;
          display: flex; align-items: flex-start; gap: 12px;
        }
        .toast.removing { animation: toastOut 0.3s ease forwards; }
        @keyframes toastIn {
          from { transform: translateX(100%); opacity: 0; }
          to { transform: translateX(0); opacity: 1; }
        }
        @keyframes toastOut {
          from { transform: translateX(0); opacity: 1; }
          to { transform: translateX(100%); opacity: 0; }
        }
        .toast-icon { font-size: 1.2rem; flex-shrink: 0; }
        .toast-content { flex: 1; }
        .toast-title { font-weight: 600; font-size: 0.9rem; margin-bottom: 2px; }
        .toast-msg { font-size: 0.8rem; color: var(--text-muted); }
        .toast-actions { display: flex; gap: 8px; margin-top: 8px; }
        .toast-actions a, .toast-actions button {
          font-size: 0.8rem; color: var(--accent); background: none; border: none;
          cursor: pointer; text-decoration: none; padding: 0;
        }
        .toast-close {
          background: none; border: none; color: var(--text-muted); cursor: pointer;
          font-size: 1rem; padding: 0;
        }

        /* ===== Empty State ===== */
        .empty-state {
          text-align: center; padding: 60px 20px; color: var(--text-muted);
        }
        .empty-state svg { width: 64px; height: 64px; fill: currentColor; opacity: 0.3; margin-bottom: 16px; }

        /* ===== Playlist View ===== */
        .playlist-detail { display: none; }
        .playlist-detail.show { display: block; }
        .song-row {
          display: grid; grid-template-columns: 48px 1fr 120px 100px 40px;
          align-items: center; gap: 12px; padding: 10px 16px; border-radius: 6px;
          cursor: pointer; transition: background 0.15s;
        }
        .song-row:hover { background: var(--surface); }
        .song-row .num { color: var(--text-muted); font-size: 0.85rem; text-align: center; }
        .song-row .row-title { font-size: 0.9rem; font-weight: 500; }
        .song-row .row-artist { font-size: 0.8rem; color: var(--text-muted); }
        .song-row .row-duration { font-size: 0.8rem; color: var(--text-muted); text-align: right; }
        .song-row .row-actions { text-align: center; }

        /* ===== Dropdown ===== */
        .dropdown {
          position: relative; display: inline-block;
        }
        .dropdown-menu {
          display: none; position: absolute; bottom: 100%; right: 0;
          background: var(--surface); border: 1px solid var(--border); border-radius: 8px;
          min-width: 180px; padding: 8px 0; z-index: 50; box-shadow: 0 8px 24px rgba(0,0,0,0.4);
        }
        .dropdown-menu.show { display: block; }
        .dropdown-item {
          padding: 8px 16px; font-size: 0.85rem; cursor: pointer; transition: background 0.15s;
          display: flex; align-items: center; gap: 8px;
        }
        .dropdown-item:hover { background: var(--surface-hover); }

        /* ===== Mobile ===== */
        .mobile-menu-btn {
          display: none; background: none; border: none; color: var(--text);
          font-size: 1.5rem; cursor: pointer;
        }
        @media (max-width: 768px) {
          .sidebar { position: fixed; left: 0; top: 0; bottom: 0; z-index: 150; transform: translateX(-100%); }
          .sidebar.open { transform: translateX(0); }
          .mobile-menu-btn { display: block; }
          .song-grid { grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); }
          .player-track { width: auto; flex: 1; }
          .player-extras { display: none; }
          .content { padding: 16px; }
          .search-box { width: 160px; }
          .queue-drawer { width: 100%; }
        }
        .sidebar-backdrop {
          display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 140;
        }
        .sidebar-backdrop.show { display: block; }
      </style>
    </head>
    <body>
      <div id="app">
        <div class="top-bar">
          <div style="display:flex;align-items:center;gap:12px;">
            <button class="mobile-menu-btn" onclick="toggleSidebar()">&#9776;</button>
            <div class="logo">Euterpe</div>
          </div>
          <div class="top-actions">
            <button class="btn" onclick="openUpload()">+ Upload</button>
          </div>
        </div>

        <div class="main-layout">
          <aside class="sidebar" id="sidebar">
            <div class="sidebar-section">
              <div class="sidebar-title">Library</div>
              <div class="nav-item active" onclick="showView('songs')" id="nav-songs">
                <svg viewBox="0 0 24 24"><path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/></svg>
                Songs
              </div>
              <div class="nav-item" onclick="showView('playlists')" id="nav-playlists">
                <svg viewBox="0 0 24 24"><path d="M15 6H3v2h12V6zm0 4H3v2h12v-2zM3 16h8v-2H3v2zM17 6v8.18c-.31-.11-.65-.18-1-.18-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3V8h3V6h-5z"/></svg>
                Playlists
              </div>
            </div>
            <div class="sidebar-section" style="flex:1;overflow-y:auto;">
              <div class="sidebar-title">Your Playlists</div>
              <div id="sidebar-playlists"></div>
              <div style="margin-top:12px;">
                <button class="btn secondary full" onclick="openCreatePlaylist()" style="padding:8px;font-size:0.8rem;">+ New Playlist</button>
              </div>
            </div>
          </aside>
          <div class="sidebar-backdrop" id="sidebar-backdrop" onclick="toggleSidebar()"></div>

          <main class="content" id="content">
            <div id="view-songs">
              <div class="content-header">
                <div class="content-title">All Songs</div>
                <input type="text" class="search-box" placeholder="Search songs..." id="search-input" oninput="filterSongs()">
              </div>
              <div class="song-grid" id="song-grid"></div>
              <div class="empty-state" id="songs-empty" style="display:none;">
                <svg viewBox="0 0 24 24"><path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/></svg>
                <div>No songs yet. Upload your first track!</div>
              </div>
            </div>

            <div id="view-playlists" style="display:none;">
              <div class="content-header">
                <div class="content-title">Playlists</div>
              </div>
              <div id="playlists-grid"></div>
            </div>

            <div class="playlist-detail" id="playlist-detail">
              <div class="content-header">
                <div>
                  <div class="content-title" id="pl-detail-name">Playlist</div>
                  <div style="color:var(--text-muted);font-size:0.85rem;margin-top:4px;" id="pl-detail-meta"></div>
                </div>
                <div style="display:flex;gap:10px;">
                  <button class="btn" onclick="playPlaylist()">Play All</button>
                  <button class="btn secondary" onclick="showView('playlists')">Back</button>
                </div>
              </div>
              <div id="pl-detail-songs"></div>
            </div>
          </main>
        </div>

        <!-- Bottom Player -->
        <div class="player-bar">
          <div class="player-track">
            <div class="player-thumb" id="player-thumb"></div>
            <div class="player-info">
              <div class="player-title" id="player-title">No song selected</div>
              <div class="player-artist" id="player-artist">--</div>
            </div>
          </div>

          <div class="player-controls">
            <div class="control-buttons">
              <button class="ctrl-btn" onclick="playerPrev()" title="Previous">
                <svg viewBox="0 0 24 24"><path d="M6 6h2v12H6zm3.5 6l8.5 6V6z"/></svg>
              </button>
              <button class="ctrl-btn main" onclick="playerToggle()" id="play-pause-btn" title="Play/Pause">
                <svg viewBox="0 0 24 24" id="play-icon"><path d="M8 5v14l11-7z"/></svg>
                <svg viewBox="0 0 24 24" id="pause-icon" style="display:none;"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>
              </button>
              <button class="ctrl-btn" onclick="playerNext()" title="Next">
                <svg viewBox="0 0 24 24"><path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z"/></svg>
              </button>
            </div>
            <div class="progress-container">
              <span class="time-label" id="current-time">0:00</span>
              <div class="progress-bar" id="progress-bar" onclick="seek(event)">
                <div class="progress-fill" id="progress-fill"></div>
              </div>
              <span class="time-label" id="total-time">0:00</span>
            </div>
          </div>

          <div class="player-extras">
            <button class="ctrl-btn" onclick="toggleQueue()" title="Queue">
              <svg viewBox="0 0 24 24"><path d="M4 10h12v2H4zm0-4h12v2H4zm0 8h8v2H4zm10 0v6l5-3z"/></svg>
            </button>
            <div class="volume-slider" onclick="setVolume(event)">
              <div class="volume-fill" id="volume-fill"></div>
            </div>
          </div>
        </div>
      </div>

      <!-- Queue Drawer -->
      <div class="queue-drawer" id="queue-drawer">
        <div class="queue-header">
          <div class="queue-title">Queue</div>
          <button class="modal-close" onclick="toggleQueue()">&times;</button>
        </div>
        <div class="queue-list" id="queue-list"></div>
      </div>

      <!-- Upload Modal -->
      <div class="modal-overlay" id="upload-modal">
        <div class="modal">
          <div class="modal-header">
            <div class="modal-title">Upload Song</div>
            <button class="modal-close" onclick="closeUpload()">&times;</button>
          </div>
          <div class="drop-zone" id="drop-zone" onclick="document.getElementById('file-input').click()">
            <svg viewBox="0 0 24 24"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM14 13v4h-4v-4H7l5-5 5 5h-3z"/></svg>
            <div>Drag & drop audio files here</div>
            <div style="font-size:0.8rem;margin-top:8px;">or click to browse</div>
          </div>
          <div id="file-selected" style="margin-top:12px;font-size:0.85rem;color:var(--text-muted);display:none;"></div>
          <input type="file" id="file-input" accept="audio/*" style="display:none;" onchange="handleFileSelect(event)">
          <div style="margin-top:16px;">
            <div class="form-group">
              <label class="form-label">Title</label>
              <input type="text" class="form-input" id="upload-title" placeholder="Song title">
            </div>
            <div class="form-group">
              <label class="form-label">Artist</label>
              <input type="text" class="form-input" id="upload-artist" placeholder="Artist name">
            </div>
            <button class="btn full" id="upload-btn" onclick="doUpload()">Upload</button>
          </div>
        </div>
      </div>

      <!-- Song Detail Modal -->
      <div class="modal-overlay" id="detail-modal">
        <div class="modal" style="max-width:480px;">
          <div class="modal-header">
            <div class="modal-title" id="detail-title">Song</div>
            <button class="modal-close" onclick="closeDetail()">&times;</button>
          </div>
          <div class="modal-body" id="detail-body"></div>
          <div class="modal-footer" id="detail-footer"></div>
        </div>
      </div>

      <!-- Create Playlist Modal -->
      <div class="modal-overlay" id="playlist-modal">
        <div class="modal" style="max-width:360px;">
          <div class="modal-header">
            <div class="modal-title">New Playlist</div>
            <button class="modal-close" onclick="closeCreatePlaylist()">&times;</button>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label class="form-label">Name</label>
              <input type="text" class="form-input" id="playlist-name" placeholder="Playlist name">
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn secondary" onclick="closeCreatePlaylist()">Cancel</button>
            <button class="btn" id="create-pl-btn" onclick="doCreatePlaylist()">Create</button>
          </div>
        </div>
      </div>

      <!-- Waveform Image Modal -->
      <div class="modal-overlay" id="waveform-modal" onclick="closeWaveform()">
        <div class="modal" style="max-width:700px;background:transparent;border:none;" onclick="event.stopPropagation()">
          <div class="modal-header" style="border:none;">
            <div class="modal-title">Waveform</div>
            <button class="modal-close" onclick="closeWaveform()">&times;</button>
          </div>
          <div id="waveform-container" style="text-align:center;"></div>
        </div>
      </div>

      <!-- Toast Container -->
      <div class="toast-container" id="toast-container"></div>

      <audio id="audio-player" preload="metadata"></audio>

      <script>
        // ===== State =====
        let songs = [];
        let playlists = [];
        let queue = [];
        let queueIndex = -1;
        let currentSong = null;
        let isPlaying = false;
        let audio = document.getElementById('audio-player');
        let currentView = 'songs';
        let selectedFile = null;
        let currentPlaylistDetail = null;
        let jobResults = {};

        // ===== Init =====
        async function init() {
          await loadSongs();
          await loadPlaylists();
          renderSongs();
          renderPlaylists();
          setupAudioEvents();
          setupSSE();
          setupDragDrop();
          audio.volume = 0.7;
        }

        // ===== API Helpers =====
        async function api(method, path, body = null) {
          const opts = { method, headers: {} };
          if (body) {
            if (body instanceof FormData) {
              opts.body = body;
            } else {
              opts.headers['Content-Type'] = 'application/json';
              opts.body = JSON.stringify(body);
            }
          }
          const res = await fetch(path, opts);
          if (!res.ok) {
            const err = await res.json().catch(() => ({}));
            throw new Error(err.error || `HTTP ${res.status}`);
          }
          if (res.status === 204) return null;
          return res.json();
        }

        async function loadSongs() {
          songs = await api('GET', '/songs');
        }

        async function loadPlaylists() {
          playlists = await api('GET', '/playlists');
        }

        // ===== Rendering =====
        function renderSongs(filter = '') {
          const grid = document.getElementById('song-grid');
          const empty = document.getElementById('songs-empty');
          const term = filter.toLowerCase();
          const filtered = songs.filter(s =>
            (s.title || '').toLowerCase().includes(term) ||
            (s.artist || '').toLowerCase().includes(term)
          );

          if (filtered.length === 0) {
            grid.innerHTML = '';
            empty.style.display = songs.length === 0 ? 'block' : 'none';
            if (songs.length > 0) empty.innerHTML = '<div>No songs match your search</div>';
            return;
          }
          empty.style.display = 'none';

          grid.innerHTML = filtered.map(song => {
            const duration = song.metadata && song.metadata.duration ? formatTime(song.metadata.duration) : '--:--';
            return `
              <div class="song-card" onclick="playSong('${song.id}')">
                <button class="song-actions-btn" onclick="event.stopPropagation(); openDetail('${song.id}')" title="Actions">
                  <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor"><path d="M12 8c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm0 2c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0 6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z"/></svg>
                </button>
                <div class="song-card-thumb">
                  <svg class="waveform-placeholder" viewBox="0 0 100 40">
                    ${Array.from({length:20},(_,i)=>`<rect x="${i*5}" y="${20-Math.random()*16}" width="3" height="${Math.random()*32}" rx="1.5" fill="currentColor"/>`).join('')}
                  </svg>
                  <div class="play-overlay">
                    <button class="play-btn" onclick="event.stopPropagation(); playSong('${song.id}')">
                      <svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>
                    </button>
                  </div>
                </div>
                <div class="song-card-title">${esc(song.title)}</div>
                <div class="song-card-artist">${esc(song.artist)}</div>
                <div class="song-card-meta">
                  <span class="badge">${esc((song.format || '').replace('.', '').toUpperCase())}</span>
                  <span>${duration}</span>
                  <span style="${song.status === 'ready' ? 'color:var(--accent)' : 'color:var(--warning)'};">${song.status || 'unknown'}</span>
                </div>
              </div>
            `;
          }).join('');
        }

        function renderPlaylists() {
          const sidebar = document.getElementById('sidebar-playlists');
          sidebar.innerHTML = playlists.map(pl => `
            <div class="playlist-item ${currentPlaylistDetail === pl.id ? 'active' : ''}" onclick="showPlaylist('${pl.id}')">
              <span>${esc(pl.name)}</span>
              <span style="margin-left:auto;font-size:0.75rem;color:var(--text-muted);">${pl.song_ids ? pl.song_ids.length : 0}</span>
            </div>
          `).join('');

          const grid = document.getElementById('playlists-grid');
          if (grid) {
            grid.innerHTML = playlists.map(pl => `
              <div class="song-card" onclick="showPlaylist('${pl.id}')" style="max-width:240px;">
                <div class="song-card-thumb" style="background:linear-gradient(135deg,#1a1a2e,#16213e);">
                  <svg viewBox="0 0 24 24" style="width:48px;height:48px;opacity:0.5;fill:currentColor;"><path d="M15 6H3v2h12V6zm0 4H3v2h12v-2zM3 16h8v-2H3v2zM17 6v8.18c-.31-.11-.65-.18-1-.18-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3V8h3V6h-5z"/></svg>
                </div>
                <div class="song-card-title">${esc(pl.name)}</div>
                <div class="song-card-artist">${pl.song_ids ? pl.song_ids.length : 0} songs</div>
              </div>
            `).join('');
          }
        }

        // ===== Detail Modal =====
        function openDetail(songId) {
          const song = songs.find(s => s.id === songId);
          if (!song) return;

          document.getElementById('detail-title').textContent = song.title || 'Song';

          const meta = song.metadata || {};
          const duration = meta.duration ? formatTime(meta.duration) : '--:--';
          const bitrate = meta.bitrate ? `${Math.round(meta.bitrate / 1000)} kbps` : '--';
          const sampleRate = meta.sample_rate ? `${meta.sample_rate} Hz` : '--';
          const channels = meta.channels ? (meta.channels === 2 ? 'Stereo' : `${meta.channels}ch`) : '--';
          const fmt = meta.format_name || (song.format || '').replace('.', '').toUpperCase() || '--';

          document.getElementById('detail-body').innerHTML = `
            <div style="font-size:1.1rem;color:var(--text-muted);margin-bottom:16px;">${esc(song.artist || 'Unknown artist')}</div>
            <div class="detail-meta">
              <div class="detail-meta-item"><div class="detail-meta-label">Duration</div><div class="detail-meta-value">${duration}</div></div>
              <div class="detail-meta-item"><div class="detail-meta-label">Bitrate</div><div class="detail-meta-value">${bitrate}</div></div>
              <div class="detail-meta-item"><div class="detail-meta-label">Sample Rate</div><div class="detail-meta-value">${sampleRate}</div></div>
              <div class="detail-meta-item"><div class="detail-meta-label">Channels</div><div class="detail-meta-value">${channels}</div></div>
              <div class="detail-meta-item"><div class="detail-meta-label">Format</div><div class="detail-meta-value">${fmt}</div></div>
              <div class="detail-meta-item"><div class="detail-meta-label">Status</div><div class="detail-meta-value" style="${song.status === 'ready' ? 'color:var(--accent)' : 'color:var(--warning)'};">${song.status || 'unknown'}</div></div>
            </div>
            <div class="detail-actions">
              <button class="btn" onclick="playSong('${song.id}'); closeDetail();">Play</button>
              <button class="btn secondary" onclick="addToQueue('${song.id}')">Add to Queue</button>
              <div class="dropdown">
                <button class="btn secondary" onclick="toggleDropdown('add-pl-dropdown')">Add to Playlist &#9662;</button>
                <div class="dropdown-menu" id="add-pl-dropdown">
                  ${playlists.length === 0 ? '<div class="dropdown-item">No playlists</div>' : playlists.map(pl => `
                    <div class="dropdown-item" onclick="addSongToPlaylist('${pl.id}', '${song.id}')">${esc(pl.name)}</div>
                  `).join('')}
                </div>
              </div>
              <button class="btn secondary" onclick="queueTranscode('${song.id}')">Transcode</button>
              <button class="btn secondary" onclick="queueWaveform('${song.id}')">Waveform</button>
              <button class="btn secondary" onclick="queueHLS('${song.id}')">HLS Stream</button>
              <button class="btn secondary" onclick="window.open('/songs/${song.id}/download')">Download</button>
              <button class="btn danger" onclick="deleteSong('${song.id}')">Delete</button>
            </div>
            ${jobResults[song.id] ? `<div style="margin-top:16px;padding:12px;background:var(--bg);border-radius:6px;font-size:0.85rem;"><strong>Jobs:</strong> ${Object.entries(jobResults[song.id]).map(([k,v]) => `${k}: ${v.status}${v.path ? ' <a href="'+v.path+'" target="_blank" style="color:var(--accent)">Open</a>' : ''}`).join(', ')}</div>` : ''}
          `;

          document.getElementById('detail-modal').classList.add('show');
        }

        function closeDetail() {
          document.getElementById('detail-modal').classList.remove('show');
          document.querySelectorAll('.dropdown-menu').forEach(d => d.classList.remove('show'));
        }

        function toggleDropdown(id) {
          document.querySelectorAll('.dropdown-menu').forEach(d => { if (d.id !== id) d.classList.remove('show'); });
          document.getElementById(id).classList.toggle('show');
        }
        document.addEventListener('click', e => {
          if (!e.target.closest('.dropdown')) document.querySelectorAll('.dropdown-menu').forEach(d => d.classList.remove('show'));
        });

        // ===== Actions =====
        function addToQueue(id) {
          const song = songs.find(s => s.id === id);
          if (!song || queue.find(q => q.id === id)) return;
          queue.push(song);
          renderQueue();
          showToast('success', 'Added to queue', song.title);
          closeDetail();
        }

        async function addSongToPlaylist(plId, songId) {
          try {
            const pl = await api('GET', `/playlists/${plId}`);
            const ids = [...(pl.song_ids || []), songId];
            await api('PUT', `/playlists/${plId}`, { song_ids: ids });
            showToast('success', 'Added to playlist', '');
            await loadPlaylists();
            renderPlaylists();
          } catch (err) {
            showToast('error', 'Failed to add', err.message);
          }
        }

        async function queueTranscode(id) {
          try {
            await api('POST', `/songs/${id}/transcode`, { format: '.mp3' });
            showToast('info', 'Transcode queued', 'Job will process in background');
            closeDetail();
          } catch (err) {
            showToast('error', 'Failed to queue transcode', err.message);
          }
        }

        async function queueWaveform(id) {
          try {
            await api('POST', `/songs/${id}/waveform`);
            showToast('info', 'Waveform queued', 'PNG will be generated in background');
            closeDetail();
          } catch (err) {
            showToast('error', 'Failed to queue waveform', err.message);
          }
        }

        async function queueHLS(id) {
          try {
            await api('POST', `/songs/${id}/hls`);
            showToast('info', 'HLS queued', 'Streaming segments will be generated');
            closeDetail();
          } catch (err) {
            showToast('error', 'Failed to queue HLS', err.message);
          }
        }

        async function deleteSong(id) {
          const song = songs.find(s => s.id === id);
          if (!song) return;
          if (!confirm(`Delete "${song.title}" by ${song.artist}? This cannot be undone.`)) return;
          try {
            await api('DELETE', `/songs/${id}`);
            showToast('success', 'Deleted', song.title);
            closeDetail();
            await loadSongs();
            renderSongs();
          } catch (err) {
            showToast('error', 'Failed to delete', err.message);
          }
        }

        // ===== Playback =====
        async function playSong(id, addToQueue = true) {
          const song = songs.find(s => s.id === id);
          if (!song) return;
          currentSong = song;

          document.getElementById('player-title').textContent = song.title || 'Unknown';
          document.getElementById('player-artist').textContent = song.artist || 'Unknown artist';
          document.getElementById('player-thumb').textContent = (song.format || '').replace('.', '').toUpperCase();

          const hlsUrl = `/songs/${id}/stream.m3u8`;
          try {
            const hlsCheck = await fetch(hlsUrl, { method: 'HEAD' });
            if (hlsCheck.ok) {
              audio.src = hlsUrl;
            } else {
              audio.src = `/songs/${id}/download`;
            }
          } catch {
            audio.src = `/songs/${id}/download`;
          }

          audio.play();
          isPlaying = true;
          updatePlayButton();
          api('POST', `/songs/${id}/play`).catch(() => {});

          if (addToQueue && !queue.find(q => q.id === id)) {
            queue.push(song);
            queueIndex = queue.length - 1;
          }
          renderQueue();
        }

        function playerToggle() {
          if (!currentSong) return;
          if (isPlaying) { audio.pause(); isPlaying = false; }
          else { audio.play(); isPlaying = true; }
          updatePlayButton();
        }

        function updatePlayButton() {
          document.getElementById('play-icon').style.display = isPlaying ? 'none' : 'block';
          document.getElementById('pause-icon').style.display = isPlaying ? 'block' : 'none';
        }

        function playerPrev() {
          if (queueIndex > 0) { queueIndex--; playSong(queue[queueIndex].id, false); }
        }

        function playerNext() {
          if (queueIndex < queue.length - 1) { queueIndex++; playSong(queue[queueIndex].id, false); }
        }

        function setupAudioEvents() {
          audio.addEventListener('timeupdate', () => {
            const pct = audio.duration ? (audio.currentTime / audio.duration) * 100 : 0;
            document.getElementById('progress-fill').style.width = pct + '%';
            document.getElementById('current-time').textContent = formatTime(audio.currentTime);
            document.getElementById('total-time').textContent = formatTime(audio.duration || 0);
          });
          audio.addEventListener('ended', () => { playerNext(); });
        }

        function seek(e) {
          if (!audio.duration) return;
          const rect = e.currentTarget.getBoundingClientRect();
          const pct = (e.clientX - rect.left) / rect.width;
          audio.currentTime = pct * audio.duration;
        }

        function setVolume(e) {
          const rect = e.currentTarget.getBoundingClientRect();
          const pct = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
          audio.volume = pct;
          document.getElementById('volume-fill').style.width = (pct * 100) + '%';
        }

        // ===== Queue =====
        function toggleQueue() {
          document.getElementById('queue-drawer').classList.toggle('open');
          renderQueue();
        }

        function renderQueue() {
          const list = document.getElementById('queue-list');
          if (queue.length === 0) {
            list.innerHTML = '<div class="empty-state" style="padding:20px;">Queue is empty</div>';
            return;
          }
          list.innerHTML = queue.map((song, i) => `
            <div class="queue-item ${i === queueIndex ? 'active' : ''}" onclick="playQueueItem(${i})">
              <div class="q-num">${i === queueIndex ? (isPlaying ? '▶' : '⏸') : i + 1}</div>
              <div class="q-info">
                <div class="q-title">${esc(song.title)}</div>
                <div class="q-artist">${esc(song.artist)}</div>
              </div>
              <button class="ctrl-btn" onclick="event.stopPropagation(); removeQueueItem(${i})" title="Remove">
                <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>
              </button>
            </div>
          `).join('');
        }

        function playQueueItem(i) {
          queueIndex = i;
          playSong(queue[i].id, false);
        }

        function removeQueueItem(i) {
          queue.splice(i, 1);
          if (i < queueIndex) queueIndex--;
          if (queueIndex >= queue.length) queueIndex = queue.length - 1;
          renderQueue();
        }

        // ===== Upload =====
        function openUpload() { document.getElementById('upload-modal').classList.add('show'); }
        function closeUpload() {
          document.getElementById('upload-modal').classList.remove('show');
          selectedFile = null;
          document.getElementById('file-selected').style.display = 'none';
          document.getElementById('upload-title').value = '';
          document.getElementById('upload-artist').value = '';
          document.getElementById('upload-btn').disabled = false;
          document.getElementById('upload-btn').innerHTML = 'Upload';
        }

        function handleFileSelect(e) {
          const file = e.target.files[0];
          if (file) {
            selectedFile = file;
            document.getElementById('file-selected').textContent = `Selected: ${file.name}`;
            document.getElementById('file-selected').style.display = 'block';
            if (!document.getElementById('upload-title').value) {
              document.getElementById('upload-title').value = file.name.replace(/\.[^/.]+$/, '');
            }
          }
        }

        function setupDragDrop() {
          const dz = document.getElementById('drop-zone');
          dz.addEventListener('dragover', e => { e.preventDefault(); dz.classList.add('dragover'); });
          dz.addEventListener('dragleave', () => dz.classList.remove('dragover'));
          dz.addEventListener('drop', e => {
            e.preventDefault();
            dz.classList.remove('dragover');
            const file = e.dataTransfer.files[0];
            if (file) {
              selectedFile = file;
              document.getElementById('file-selected').textContent = `Selected: ${file.name}`;
              document.getElementById('file-selected').style.display = 'block';
              if (!document.getElementById('upload-title').value) {
                document.getElementById('upload-title').value = file.name.replace(/\.[^/.]+$/, '');
              }
            }
          });
        }

        async function doUpload() {
          if (!selectedFile) { showToast('warning', 'No file selected', 'Please select an audio file'); return; }
          const title = document.getElementById('upload-title').value.trim();
          const artist = document.getElementById('upload-artist').value.trim();
          if (!title) { showToast('warning', 'Missing title', 'Please enter a song title'); return; }
          if (!artist) { showToast('warning', 'Missing artist', 'Please enter an artist name'); return; }

          const form = new FormData();
          form.append('file', selectedFile);
          form.append('title', title);
          form.append('artist', artist);

          const btn = document.getElementById('upload-btn');
          btn.disabled = true;
          btn.innerHTML = '<span class="btn-spinner"></span> Uploading...';

          try {
            await api('POST', '/songs', form);
            showToast('success', 'Uploaded!', `${title} will be processed`);
            closeUpload();
            setTimeout(async () => { await loadSongs(); renderSongs(); }, 1000);
          } catch (err) {
            showToast('error', 'Upload failed', err.message);
            btn.disabled = false;
            btn.innerHTML = 'Upload';
          }
        }

        // ===== Views =====
        function showView(view) {
          currentView = view;
          currentPlaylistDetail = null;
          document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
          document.getElementById('nav-' + view).classList.add('active');

          document.getElementById('view-songs').style.display = view === 'songs' ? 'block' : 'none';
          document.getElementById('view-playlists').style.display = view === 'playlists' ? 'block' : 'none';
          document.getElementById('playlist-detail').classList.remove('show');

          if (view === 'songs') renderSongs();
          if (view === 'playlists') renderPlaylists();
        }

        async function showPlaylist(id) {
          currentPlaylistDetail = id;
          try {
            const pl = await api('GET', `/playlists/${id}`);
            document.getElementById('pl-detail-name').textContent = pl.name;
            document.getElementById('pl-detail-meta').textContent = `${pl.songs ? pl.songs.length : 0} songs`;

            const container = document.getElementById('pl-detail-songs');
            if (!pl.songs || pl.songs.length === 0) {
              container.innerHTML = '<div class="empty-state">No songs in this playlist</div>';
            } else {
              container.innerHTML = pl.songs.map((song, i) => `
                <div class="song-row" onclick="playSong('${song.id}')">
                  <div class="num">${i + 1}</div>
                  <div>
                    <div class="row-title">${esc(song.title)}</div>
                    <div class="row-artist">${esc(song.artist)}</div>
                  </div>
                  <div class="row-duration">${song.metadata && song.metadata.duration ? formatTime(song.metadata.duration) : '--:--'}</div>
                  <div class="row-actions">
                    <button class="ctrl-btn" onclick="event.stopPropagation(); openDetail('${song.id}')" title="Actions">
                      <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor"><path d="M12 8c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm0 2c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0 6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z"/></svg>
                    </button>
                  </div>
                </div>
              `).join('');
            }

            document.getElementById('view-songs').style.display = 'none';
            document.getElementById('view-playlists').style.display = 'none';
            document.getElementById('playlist-detail').classList.add('show');
            renderPlaylists();
          } catch (err) {
            showToast('error', 'Failed to load playlist', err.message);
          }
        }

        function playPlaylist() {
          const container = document.getElementById('pl-detail-songs');
          const rows = container.querySelectorAll('.song-row');
          if (rows.length === 0) return;
          queue = [];
          rows.forEach(row => {
            const id = row.getAttribute('onclick').match(/playSong\('(.+?)'\)/)[1];
            const song = songs.find(s => s.id === id);
            if (song) queue.push(song);
          });
          queueIndex = 0;
          playSong(queue[0].id, false);
          renderQueue();
        }

        // ===== Playlist Creation =====
        function openCreatePlaylist() {
          document.getElementById('playlist-modal').classList.add('show');
          document.getElementById('playlist-name').value = '';
          document.getElementById('playlist-name').focus();
        }
        function closeCreatePlaylist() {
          document.getElementById('playlist-modal').classList.remove('show');
        }

        async function doCreatePlaylist() {
          const name = document.getElementById('playlist-name').value.trim();
          if (!name) { showToast('warning', 'Empty name', 'Please enter a playlist name'); return; }

          const btn = document.getElementById('create-pl-btn');
          btn.disabled = true;
          btn.innerHTML = '<span class="btn-spinner"></span>';

          try {
            await api('POST', '/playlists', { name, song_ids: [] });
            showToast('success', 'Playlist created', name);
            closeCreatePlaylist();
            await loadPlaylists();
            renderPlaylists();
          } catch (err) {
            showToast('error', 'Failed to create playlist', err.message);
          } finally {
            btn.disabled = false;
            btn.innerHTML = 'Create';
          }
        }

        // ===== Search =====
        function filterSongs() {
          const term = document.getElementById('search-input').value;
          renderSongs(term);
        }

        // ===== Toasts =====
        function showToast(type, title, message, actions = []) {
          const container = document.getElementById('toast-container');
          const icons = { success: '✓', error: '✕', warning: '⚠', info: 'ℹ' };
          const toast = document.createElement('div');
          toast.className = 'toast';
          toast.innerHTML = `
            <div class="toast-icon">${icons[type] || '•'}</div>
            <div class="toast-content">
              <div class="toast-title">${esc(title)}</div>
              <div class="toast-msg">${esc(message)}</div>
              ${actions.length ? `<div class="toast-actions">${actions.map(a => `<a href="${a.href}" ${a.download ? 'download' : ''} target="_blank">${esc(a.label)}</a>`).join('')}</div>` : ''}
            </div>
            <button class="toast-close" onclick="this.parentElement.remove()">&times;</button>
          `;
          container.appendChild(toast);
          setTimeout(() => {
            toast.classList.add('removing');
            setTimeout(() => toast.remove(), 300);
          }, type === 'error' ? 8000 : 5000);
        }

        // ===== SSE =====
        function setupSSE() {
          const es = new EventSource('/events');
          es.onmessage = e => {
            try {
              const data = JSON.parse(e.data);
              if (!data.event) return;

              if (data.event === 'completed') {
                const r = data.result || {};
                if (r.song_id) {
                  if (!jobResults[r.song_id]) jobResults[r.song_id] = {};
                  jobResults[r.song_id][r.task] = { status: 'done', path: r.output_path || r.waveform_path || r.playlist_path };
                }

                if (r.task === 'extract_metadata') {
                  showToast('success', 'Metadata ready', `Song #${r.song_id} processed`);
                  setTimeout(async () => { await loadSongs(); renderSongs(); }, 500);
                } else if (r.task === 'transcode') {
                  showToast('success', 'Transcode complete', 'New file ready', [
                    { href: r.output_path, label: 'Download', download: true }
                  ]);
                } else if (r.task === 'generate_waveform') {
                  showToast('success', 'Waveform ready', 'PNG generated', [
                    { href: r.waveform_path, label: 'View' }
                  ]);
                  setTimeout(() => {
                    document.getElementById('waveform-container').innerHTML = `<img src="${r.waveform_path}" style="max-width:100%;border-radius:8px;" alt="Waveform">`;
                    document.getElementById('waveform-modal').classList.add('show');
                  }, 500);
                } else if (r.task === 'generate_hls') {
                  showToast('success', 'HLS ready', 'Streaming available', [
                    { href: `/songs/${r.song_id}/stream.m3u8`, label: 'Play Stream' }
                  ]);
                }
              } else if (data.event === 'errored' || data.event === 'failed') {
                showToast('error', 'Job failed', `Job #${data.job_id}${data.error ? ': ' + data.error : ''}`);
              } else if (data.event === 'queued') {
                showToast('info', 'Job queued', `${data.task || 'job'} #${data.job_id}`);
              }
            } catch {}
          };
        }

        function closeWaveform() {
          document.getElementById('waveform-modal').classList.remove('show');
        }

        // ===== Mobile =====
        function toggleSidebar() {
          document.getElementById('sidebar').classList.toggle('open');
          document.getElementById('sidebar-backdrop').classList.toggle('show');
        }

        // ===== Utilities =====
        function formatTime(seconds) {
          if (!seconds || isNaN(seconds)) return '0:00';
          const m = Math.floor(seconds / 60);
          const s = Math.floor(seconds % 60);
          return `${m}:${s.toString().padStart(2, '0')}`;
        }

        function esc(str) {
          if (!str) return '';
          const div = document.createElement('div');
          div.textContent = str;
          return div.innerHTML;
        }

        init();
      </script>
    </body>
    </html>
    """
  end
end
