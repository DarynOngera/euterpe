# MyMusicServer API Guide

## Getting Started

```bash
mix run --no-halt
```

Server runs on `http://localhost:5000`.

---

## Core Endpoints

### GET /
Server status.

```bash
curl http://localhost:5000/
```
**Response:** `Server is running`

### GET /health
Health check.

```bash
curl http://localhost:5000/health
```
**Response:**
```json
{"status":"OK"}
```

### GET /stats
Job counts by status.

```bash
curl http://localhost:5000/stats
```
**Response:**
```json
{"queued":2,"running":1,"done":5,"failed":0,"total":8}
```

---

## Job Queue Endpoints

### POST /jobs
Submit a background job.

```bash
curl -X POST http://localhost:5000/jobs \
  -H "Content-Type: application/json" \
  -d '{"payload":{"task":"extract_metadata","song_id":"123"}}'
```
**Response:**
```json
{"message":"Job accepted","job_id":1}
```

### POST /jobs/schedule
Schedule a job for a future time.

```bash
curl -X POST http://localhost:5000/jobs/schedule \
  -H "Content-Type: application/json" \
  -d '{"payload":{"task":"transcode","song_id":"123"},"run_at":"2025-06-03T12:00:00Z"}'
```

### GET /jobs
List jobs. Supports filtering and pagination.

```bash
curl "http://localhost:5000/jobs?status=done&page=1&per_page=10"
```

### GET /jobs/:id
Get a specific job.

```bash
curl http://localhost:5000/jobs/1
```

---

## Songs (Library)

### POST /songs
Upload an audio file. Requires `file`, `title`, and `artist`.

```bash
curl -X POST http://localhost:5000/songs \
  -F "file=@/path/to/song.mp3" \
  -F "title=My Song" \
  -F "artist=My Artist"
```
**Response:**
```json
{"message":"Song uploaded","song_id":"12345"}
```

The upload triggers an `extract_metadata` job automatically.

### GET /songs
List all songs.

```bash
curl http://localhost:5000/songs
```

### GET /songs/:id
Get a specific song.

```bash
curl http://localhost:5000/songs/12345
```

### DELETE /songs/:id
Remove a song from the catalog and delete its file.

```bash
curl -X DELETE http://localhost:5000/songs/12345
```

### GET /songs/:id/download
Download the original audio file.

```bash
curl -O -J http://localhost:5000/songs/12345/download
```

---

## Audio Processing

### POST /songs/:id/transcode
Transcode to a different format. Defaults to `.mp3`.

```bash
curl -X POST http://localhost:5000/songs/12345/transcode \
  -H "Content-Type: application/json" \
  -d '{"format":".ogg"}'
```
**Response:**
```json
{"message":"Transcode job queued","song_id":"12345"}
```

### POST /songs/:id/waveform
Generate a waveform PNG.

```bash
curl -X POST http://localhost:5000/songs/12345/waveform
```
**Response:**
```json
{"message":"Waveform job queued","song_id":"12345"}
```

### POST /songs/:id/hls
Generate HLS streaming segments.

```bash
curl -X POST http://localhost:5000/songs/12345/hls
```

### GET /songs/:id/stream.m3u8
Serve the HLS playlist.

```bash
curl http://localhost:5000/songs/12345/stream.m3u8
```

---

## Playback

### POST /songs/:id/play
Set the current playing song.

```bash
curl -X POST http://localhost:5000/songs/12345/play
```

### POST /player/stop
Stop playback.

```bash
curl -X POST http://localhost:5000/player/stop
```

### GET /player/current
Get currently playing song.

```bash
curl http://localhost:5000/player/current
```
**Response:**
```json
{"current":{"id":"12345","title":"My Song","artist":"My Artist"},"status":"playing"}
```

---

## Playlists

### POST /playlists
Create a playlist.

```bash
curl -X POST http://localhost:5000/playlists \
  -H "Content-Type: application/json" \
  -d '{"name":"My Favorites","song_ids":["12345","67890"]}'
```

### GET /playlists
List all playlists.

```bash
curl http://localhost:5000/playlists
```

### GET /playlists/:id
Get a playlist with full song details.

```bash
curl http://localhost:5000/playlists/1
```

### PUT /playlists/:id
Update a playlist's songs.

```bash
curl -X PUT http://localhost:5000/playlists/1 \
  -H "Content-Type: application/json" \
  -d '{"song_ids":["12345","99999"]}'
```

### DELETE /playlists/:id
Delete a playlist.

```bash
curl -X DELETE http://localhost:5000/playlists/1
```

---

## Background Job Types

These are the `task` values accepted in job payloads:

| Task | Description | Required Fields |
|------|-------------|-----------------|
| `extract_metadata` | Reads audio metadata via ffprobe | `song_id` |
| `transcode` | Converts format via ffmpeg | `song_id`, `input_path`, `target_format` |
| `generate_waveform` | Generates PNG waveform via ffmpeg | `song_id`, `input_path` |
| `generate_hls` | Creates HLS segments + playlist via ffmpeg | `song_id`, `input_path` |

---

## Complete Workflow Example

```bash
# 1. Upload a song
SONG=$(curl -s -X POST http://localhost:5000/songs \
  -F "file=@/path/to/audio.mp3" \
  -F "title=Audio Test" \
  -F "artist=Test Artist")
SONG_ID=$(echo $SONG | jq -r '.song_id')

# 2. Wait for metadata extraction job to complete
sleep 2

# 3. Check song metadata
curl http://localhost:5000/songs/$SONG_ID | jq

# 4. Transcode to OGG
curl -X POST http://localhost:5000/songs/$SONG_ID/transcode \
  -H "Content-Type: application/json" \
  -d '{"format":".ogg"}'

# 5. Generate waveform
curl -X POST http://localhost:5000/songs/$SONG_ID/waveform

# 6. Generate HLS
curl -X POST http://localhost:5000/songs/$SONG_ID/hls

# 7. Create a playlist
curl -X POST http://localhost:5000/playlists \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"My Playlist\",\"song_ids\":[\"$SONG_ID\"]}"

# 8. Start playback
curl -X POST http://localhost:5000/songs/$SONG_ID/play

# 9. Check player status
curl http://localhost:5000/player/current | jq

# 10. List all jobs
curl http://localhost:5000/jobs | jq
```

---

## Data Persistence

- **Catalog** — `data/catalog.json` (songs)
- **Playlists** — `data/playlists.json`
- **Uploads** — `uploads/` directory
- **HLS** — `uploads/{song_id}_hls/` directory
- **Jobs** — in-memory only (lost on restart)

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 5000 | HTTP server port |
| `WORKER_POOL_SIZE` | CPU cores | Number of background workers |
| `UPLOAD_DIR` | uploads | Audio file storage path |
| `DATA_DIR` | data | JSON persistence path |
