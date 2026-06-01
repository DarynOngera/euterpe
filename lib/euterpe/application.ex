defmodule Euterpe.Application do
  @moduledoc """
  Main application supervisor.
  """
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    port = System.get_env("PORT", "5000") |> String.to_integer()
    upload_dir = Application.get_env(:euterpe, :upload_dir, "uploads")
    data_dir = Application.get_env(:euterpe, :data_dir, "data")

    File.mkdir_p!(upload_dir)
    File.mkdir_p!(data_dir)

    prometheus_port =
      Application.get_env(:euterpe, :telemetry_prometheus, port: 9568)[:port]

    children = [
      Euterpe.EventBus,
      Core.Workers.JobQueue,
      {Core.Workers.WorkerPool, worker: Euterpe.MusicWorker},
      Euterpe.Library,
      Euterpe.PlaylistManager,
      Euterpe.Player,
      {TelemetryMetricsPrometheus,
       [metrics: Core.Telemetry.Metrics.metrics(), port: prometheus_port]},
      {Plug.Cowboy,
       scheme: :http, plug: Euterpe.Router, options: [port: port, ip: {0, 0, 0, 0}]}
    ]

    Logger.info("Starting Euterpe on port #{port}")
    Logger.info("http://localhost:#{port}")

    opts = [strategy: :one_for_one, name: Euterpe.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
