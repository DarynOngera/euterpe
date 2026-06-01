# Euterpe

A **production-ready music server** built on Elixir/OTP, featuring real-time audio processing, adaptive streaming, and full observability.

Forked from [ElixirServerCore](https://github.com/DarynOngera/ElixirServerCore), this server demonstrates how the core framework extends into domain-specific applications with minimal core changes.

---

## Features

- **Audio Upload & Cataloging** — Upload WAV, MP3, FLAC, OGG with automatic metadata extraction
- **Background Processing** — Transcoding, waveform generation, and HLS streaming via ffmpeg
- **Real-Time Job Progress** — Server-Sent Events (SSE) push live job status to clients
- **HLS Adaptive Streaming** — HTTP Live Streaming for browser playback
- **Playlist Management** — Full CRUD with song enrichment
- **Playback State** — Simple now-playing API
- **Admin Dashboard** — Real-time HTML dashboard at `/admin`
- **Prometheus Metrics** — Scrapable metrics at `http://localhost:9568/metrics`
- **JSON Persistence** — Catalog and playlists survive restarts
- **OTP Supervision** — Fault-tolerant architecture with automatic recovery

---

## Architecture

```
Client ──HTTP──▶ Router
                      │
                      ├── JobQueue (GenServer)
                      │   ├── Queue: Job IDs
                      │   └── Jobs: Job Data Map
                      │
                      ├── WorkerPool (Supervisor)
                      │   └── MusicWorker xN (GenServer)
                      │       └── ffmpeg / ffprobe
                      │
                      ├── Library (GenServer) ──▶ data/catalog.json
                      ├── PlaylistManager (GenServer) ──▶ data/playlists.json
                      ├── Player (GenServer)
                      ├── EventBus (Registry)
                      └── Telemetry ──▶ Prometheus (port 9568)
```

---

## Quick Start

### Requirements

- Elixir 1.14+
- Erlang/OTP 26+
- ffmpeg + ffprobe installed

### Setup

```bash
cd ElixirServerCore
mix deps.get
mix compile
```

### Run

```bash
mix run --no-halt
```

- API: `http://localhost:5000`
- **Public Player UI: `http://localhost:5000/player`**
- Admin Dashboard: `http://localhost:5000/admin`
- Prometheus Metrics: `http://localhost:9568/metrics`

---

## API Endpoints

### Core

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Server status |
| GET | `/health` | Health check (OK / DEGRADED) |
| GET | `/stats` | Job counts by status |
| GET | `/events` | **SSE** — real-time job events |
| GET | `/admin` | HTML admin dashboard |
| GET | `/player` | **Public music player UI** |

### Jobs

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/jobs` | Submit a job |
| POST | `/jobs/schedule` | Schedule a future job |
| GET | `/jobs` | List jobs (filter, paginate) |
| GET | `/jobs/:id` | Get specific job |

### Songs

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/songs` | Upload audio file |
| GET | `/songs` | List all songs |
| GET | `/songs/:id` | Get song details |
| DELETE | `/songs/:id` | Remove song |
| GET | `/songs/:id/download` | Download original file |
| POST | `/songs/:id/transcode` | Queue transcode job |
| POST | `/songs/:id/waveform` | Queue waveform job |
| POST | `/songs/:id/hls` | **Queue HLS generation** |
| GET | `/songs/:id/stream.m3u8` | **HLS playlist** |
| GET | `/songs/:id/stream/:segment` | **HLS segment** |

### Player

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/songs/:id/play` | Set now playing |
| POST | `/player/stop` | Stop playback |
| GET | `/player/current` | Get current song |

### Playlists

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/playlists` | List all |
| POST | `/playlists` | Create |
| GET | `/playlists/:id` | Get with songs |
| PUT | `/playlists/:id` | Update songs |
| DELETE | `/playlists/:id` | Delete |

---

## Real-Time Events (SSE)

Connect to `GET /events` to receive live job updates:

```bash
curl http://localhost:5000/events
```

**Events emitted:**

| Event | When | Payload |
|-------|------|---------|
| `queued` | Job submitted | `{job_id, task}` |
| `claimed` | Worker picked up job | `{job_id, task, attempt}` |
| `started` | Worker begins execution | `{job_id, task, worker_id, attempt}` |
| `completed` | Job finished successfully | `{job_id, task, duration_ms, result}` |
| `errored` | Job raised exception | `{job_id, task, duration_ms, error}` |
| `failed` | Job permanently failed | `{job_id, task, reason}` |
| `retrying` | Job scheduled for retry | `{job_id, task, retry_in_ms}` |

**JavaScript usage:**
```javascript
const es = new EventSource('http://localhost:5000/events');
es.onmessage = (e) => {
  const data = JSON.parse(e.data);
  console.log('Job', data.job_id, data.event);
};
```

---

## HLS Streaming Workflow

```bash
# 1. Upload a song
SONG=$(curl -s -X POST http://localhost:5000/songs \
  -F "file=@song.mp3" -F "title=Song" -F "artist=Artist")
SONG_ID=$(echo $SONG | jq -r '.song_id')

# 2. Wait for metadata extraction, then generate HLS
curl -X POST http://localhost:5000/songs/$SONG_ID/hls

# 3. Poll jobs until HLS is done
curl http://localhost:5000/jobs

# 4. Stream in browser
# <audio controls src="http://localhost:5000/songs/$SONG_ID/stream.m3u8"></audio>
# Or use hls.js for wider browser support
```

---

## Admin Dashboard

Open `http://localhost:5000/admin` in a browser to see:

- **System Health** — Worker count, queue depth, active jobs
- **Catalog Stats** — Total songs, playlists, processing count
- **Now Playing** — Current playback with stop control
- **Live Jobs** — Currently running jobs with status badges
- **Recent Events** — Live event log from SSE stream
- **Job Stats** — Queued / Running / Done / Failed counts

All data updates in real-time via SSE + polling.

---

## Public Player UI

Open `http://localhost:5000/player` for the full-featured music player interface. No build step, no external dependencies — pure HTML/CSS/JS served directly by the server.

### Features

- **Browse & Search** — Grid view of all songs with live search filtering
- **Persistent Bottom Player** — Play/pause, previous/next, progress scrubber, volume control
- **Playback Queue** — Slide-out queue drawer; add songs, reorder by clicking, remove items
- **Drag & Drop Upload** — Drop audio files into the modal, or click to browse; title auto-fills from filename
- **Song Detail Modal** — Click the ⋮ menu on any song card to see:
  - Full metadata (duration, bitrate, sample rate, channels, format)
  - **Play**, **Add to Queue**, **Add to Playlist**
  - **Transcode** — queue format conversion
  - **Waveform** — generate PNG visualization
  - **HLS Stream** — generate adaptive streaming segments
  - **Download** — get the original file
  - **Delete** — remove from catalog (with confirmation)
- **Playlist Management** — Create playlists, add songs via dropdown, remove songs, play all
- **Real-Time Job Toasts** — When you queue transcode/waveform/HLS, a toast appears on completion with action links:
  - Transcode done → **"Download"** button
  - Waveform done → **"View"** button (opens image overlay)
  - HLS done → **"Play Stream"** button
- **Mobile Responsive** — Collapsible sidebar, touch-friendly controls, adaptive grid

### Using the Player

1. **Upload** — Click "+ Upload", drag an audio file, enter title/artist (title auto-fills), click Upload
2. **Play** — Click any song card, or the green play overlay on hover
3. **Queue** — Open a song's detail modal → "Add to Queue", then open the queue drawer from the bottom player
4. **Transcode** — Detail modal → "Transcode"; wait for toast with Download link
5. **Waveform** — Detail modal → "Waveform"; toast opens the PNG in an overlay
6. **HLS** — Detail modal → "HLS Stream"; toast provides the stream URL
7. **Playlist** — Sidebar "+ New Playlist" → enter name → click song's "Add to Playlist"

---

## Background Job Types

| Task | Description |
|------|-------------|
| `extract_metadata` | ffprobe: duration, bitrate, sample rate, channels |
| `transcode` | ffmpeg: convert to target format |
| `generate_waveform` | ffmpeg: generate PNG waveform |
| `generate_hls` | ffmpeg: create HLS segments + playlist |

---

## Observability

### Prometheus Metrics

Scrape `http://localhost:9568/metrics`:

```
core_job_count{event_name="core_job_stop"} 42
core_job_duration_ms{event_name="core_job_stop"} 15
server_http_request_count{event_name="server_http_stop"} 128
```

### Telemetry Events

- `[:server, :http, :start]` — HTTP request started
- `[:server, :http, :stop]` — HTTP request completed
- `[:core, :job, :start]` — Job execution started
- `[:core, :job, :stop]` — Job execution completed
- `[:core, :job, :error]` — Job execution failed

---

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `PORT` | 5000 | HTTP server port |
| `WORKER_POOL_SIZE` | CPU cores | Background worker count |
| `UPLOAD_DIR` | uploads | Audio file storage |
| `DATA_DIR` | data | JSON persistence directory |

---

## Persistence

- **Catalog** — `data/catalog.json` (songs with metadata)
- **Playlists** — `data/playlists.json`
- **Uploads** — `uploads/` directory
- **HLS** — `uploads/{song_id}_hls/` directory
- **Jobs** — in-memory only (ephemeral)

---

## Testing

```bash
# Run tests
mix test

# Run with coverage
mix test --cover
```

---

## Complete Workflow Example

```bash
# 1. Upload
SONG=$(curl -s -X POST http://localhost:5000/songs \
  -F "file=@/path/to/song.mp3" \
  -F "title=My Song" \
  -F "artist=My Artist")
SONG_ID=$(echo $SONG | jq -r '.song_id')

# 2. Wait for metadata, then check song
curl http://localhost:5000/songs/$SONG_ID | jq

# 3. Transcode to OGG
curl -X POST http://localhost:5000/songs/$SONG_ID/transcode \
  -H "Content-Type: application/json" \
  -d '{"format":".ogg"}'

# 4. Generate waveform
curl -X POST http://localhost:5000/songs/$SONG_ID/waveform

# 5. Generate HLS for streaming
curl -X POST http://localhost:5000/songs/$SONG_ID/hls

# 6. Create playlist
curl -X POST http://localhost:5000/playlists \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Favorites\",\"song_ids\":[\"$SONG_ID\"]}"

# 7. Play
curl -X POST http://localhost:5000/songs/$SONG_ID/play

# 8. Check admin dashboard in browser
# open http://localhost:5000/admin

# 9. Watch real-time events
curl http://localhost:5000/events
```

---

## License

MIT License — forked from ElixirServerCore

---

## Maintainer

**DarynOngera**

For issues or feature requests, open an issue on GitHub.
