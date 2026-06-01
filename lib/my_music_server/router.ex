defmodule MyMusicServer.Router do
  @moduledoc """
  HTTP router for the music server.
  """
  use Plug.Router
  require Logger
  alias Core.Workers.JobQueue

  plug(Plug.Logger, log: :info)
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason,
    length: 100_000_000
  )

  plug(Plug.Telemetry, event_prefix: [:server, :http])
  plug(:dispatch)

  import Core.HTTP.BaseRouter

  add_root_route()
  add_health_route()
  add_stats_route()
  add_job_routes()

  get "/songs" do
    songs = MyMusicServer.Library.all_songs()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(songs))
  end

  get "/songs/:id" do
    case MyMusicServer.Library.get_song(id) do
      {:ok, song} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(song))

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{error: "Song not found"}))
    end
  end

  post "/songs" do
    case conn.body_params do
      %{"file" => %Plug.Upload{} = upload, "title" => title, "artist" => artist} ->
        {:ok, song_id, path} = MyMusicServer.Storage.save_upload(upload)

        song = %{
          "id" => song_id,
          "title" => title,
          "artist" => artist,
          "file_path" => path,
          "format" => Path.extname(upload.filename),
          "uploaded_at" => DateTime.utc_now(),
          "status" => "processing"
        }

        MyMusicServer.Library.add_song(song)

        JobQueue.submit(%{
          "task" => "extract_metadata",
          "song_id" => song_id
        })

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(201, Jason.encode!(%{message: "Song uploaded", song_id: song_id}))

      %{"file" => %Plug.Upload{}} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: "Missing 'title' or 'artist' fields"}))

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: "Missing 'file' upload"}))
    end
  end

  delete "/songs/:id" do
    case MyMusicServer.Library.get_song(id) do
      {:ok, song} ->
        MyMusicServer.Storage.delete_file(song["file_path"])
        MyMusicServer.Library.remove_song(id)
        send_resp(conn, 204, "")

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{error: "Song not found"}))
    end
  end

  post "/songs/:id/transcode" do
    case MyMusicServer.Library.get_song(id) do
      {:ok, song} ->
        target_format = conn.body_params["format"] || ".mp3"

        JobQueue.submit(%{
          "task" => "transcode",
          "song_id" => id,
          "input_path" => song["file_path"],
          "target_format" => target_format
        })

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(202, Jason.encode!(%{message: "Transcode job queued", song_id: id}))

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{error: "Song not found"}))
    end
  end

  post "/songs/:id/waveform" do
    case MyMusicServer.Library.get_song(id) do
      {:ok, song} ->
        JobQueue.submit(%{
          "task" => "generate_waveform",
          "song_id" => id,
          "input_path" => song["file_path"]
        })

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(202, Jason.encode!(%{message: "Waveform job queued", song_id: id}))

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{error: "Song not found"}))
    end
  end

  post "/songs/:id/hls" do
    case MyMusicServer.Library.get_song(id) do
      {:ok, song} ->
        JobQueue.submit(%{
          "task" => "generate_hls",
          "song_id" => id,
          "input_path" => song["file_path"]
        })

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(202, Jason.encode!(%{message: "HLS generation queued", song_id: id}))

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{error: "Song not found"}))
    end
  end

  get "/songs/:id/stream.m3u8" do
    hls_dir =
      Path.join(Application.get_env(:my_music_server, :upload_dir, "uploads"), "#{id}_hls")

    playlist_path = Path.join(hls_dir, "playlist.m3u8")

    if File.exists?(playlist_path) do
      conn
      |> put_resp_content_type("application/vnd.apple.mpegurl")
      |> send_file(200, playlist_path)
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        404,
        Jason.encode!(%{
          error: "HLS playlist not found. Generate it first with POST /songs/:id/hls"
        })
      )
    end
  end

  get "/songs/:id/stream/:segment" do
    hls_dir =
      Path.join(Application.get_env(:my_music_server, :upload_dir, "uploads"), "#{id}_hls")

    segment_path = Path.join(hls_dir, segment)

    if File.exists?(segment_path) do
      conn
      |> put_resp_content_type("video/mp2t")
      |> send_file(200, segment_path)
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(404, Jason.encode!(%{error: "Segment not found"}))
    end
  end

  get "/songs/:id/download" do
    case MyMusicServer.Library.get_song(id) do
      {:ok, song} ->
        if File.exists?(song["file_path"]) do
          conn
          |> put_resp_content_type(MIME.from_path(song["file_path"]))
          |> put_resp_header(
            "content-disposition",
            "attachment; filename=\"#{Path.basename(song["file_path"])}\""
          )
          |> send_file(200, song["file_path"])
        else
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(404, Jason.encode!(%{error: "File not found on disk"}))
        end

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{error: "Song not found"}))
    end
  end

  post "/songs/:id/play" do
    case MyMusicServer.Library.get_song(id) do
      {:ok, song} ->
        MyMusicServer.Player.play(id)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{message: "Now playing", song: song}))

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{error: "Song not found"}))
    end
  end

  post "/player/stop" do
    MyMusicServer.Player.stop()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{message: "Playback stopped"}))
  end

  get "/player/current" do
    case MyMusicServer.Player.current() do
      nil ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{current: nil, status: "idle"}))

      song_id ->
        {:ok, song} = MyMusicServer.Library.get_song(song_id)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{current: song, status: "playing"}))
    end
  end

  get "/playlists" do
    playlists = MyMusicServer.PlaylistManager.all()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(playlists))
  end

  get "/playlists/:id" do
    case MyMusicServer.PlaylistManager.get(id) do
      {:ok, playlist} ->
        songs =
          playlist.song_ids
          |> Enum.map(fn sid ->
            case MyMusicServer.Library.get_song(sid) do
              {:ok, song} -> song
              _ -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        enriched = Map.put(playlist, :songs, songs)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(enriched))

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{error: "Playlist not found"}))
    end
  end

  post "/playlists" do
    case conn.body_params do
      %{"name" => name, "song_ids" => song_ids} when is_list(song_ids) ->
        {:ok, playlist} = MyMusicServer.PlaylistManager.create(name, song_ids)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(201, Jason.encode!(playlist))

      %{"name" => name} ->
        {:ok, playlist} = MyMusicServer.PlaylistManager.create(name, [])

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(201, Jason.encode!(playlist))

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: "Missing 'name' field"}))
    end
  end

  put "/playlists/:id" do
    case conn.body_params do
      %{"song_ids" => song_ids} when is_list(song_ids) ->
        case MyMusicServer.PlaylistManager.update(id, song_ids) do
          {:ok, playlist} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, Jason.encode!(playlist))

          {:error, :not_found} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(404, Jason.encode!(%{error: "Playlist not found"}))
        end

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: "Missing 'song_ids' array"}))
    end
  end

  delete "/playlists/:id" do
    case MyMusicServer.PlaylistManager.delete(id) do
      :ok ->
        send_resp(conn, 204, "")

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{error: "Playlist not found"}))
    end
  end

  get "/events" do
    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> put_resp_header("cache-control", "no-cache")
    |> put_resp_header("connection", "keep-alive")
    |> send_chunked(200)
    |> stream_events()
  end

  get "/admin" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, MyMusicServer.AdminDashboard.html())
  end

  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "Not found"}))
  end

  defp stream_events(conn) do
    MyMusicServer.EventBus.subscribe(:jobs)

    conn =
      case Plug.Conn.chunk(conn, "event: connected\ndata: \"\"\n\n") do
        {:ok, conn} -> conn
        {:error, :closed} -> conn
      end

    loop_and_stream(conn)
  end

  defp loop_and_stream(conn) do
    receive do
      {:bus_event, payload} ->
        data = Jason.encode!(payload)
        event = Map.get(payload, :event, "update")

        case Plug.Conn.chunk(conn, "event: #{event}\ndata: #{data}\n\n") do
          {:ok, conn} -> loop_and_stream(conn)
          {:error, :closed} -> conn
        end
    after
      30_000 ->
        case Plug.Conn.chunk(conn, ":keep-alive\n\n") do
          {:ok, conn} -> loop_and_stream(conn)
          {:error, :closed} -> conn
        end
    end
  end
end
