defmodule MyMusicServer.Application do
  @moduledoc """
  Main application supervisor.
  """
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    port = System.get_env("PORT", "5000") |> String.to_integer()
    upload_dir = Application.get_env(:my_music_server, :upload_dir, "uploads")
    data_dir = Application.get_env(:my_music_server, :data_dir, "data")

    File.mkdir_p!(upload_dir)
    File.mkdir_p!(data_dir)

    prometheus_port =
      Application.get_env(:my_music_server, :telemetry_prometheus, port: 9568)[:port]

    children = [
      MyMusicServer.EventBus,
      Core.Workers.JobQueue,
      {Core.Workers.WorkerPool, worker: MyMusicServer.MusicWorker},
      MyMusicServer.Library,
      MyMusicServer.PlaylistManager,
      MyMusicServer.Player,
      {TelemetryMetricsPrometheus,
       [metrics: Core.Telemetry.Metrics.metrics(), port: prometheus_port]},
      {Plug.Cowboy,
       scheme: :http, plug: MyMusicServer.Router, options: [port: port, ip: {0, 0, 0, 0}]}
    ]

    Logger.info("Starting MyMusicServer on port #{port}")
    Logger.info("http://localhost:#{port}")

    opts = [strategy: :one_for_one, name: MyMusicServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
