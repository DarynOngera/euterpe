defmodule Core.Telemetry.Metrics do
  alias Telemetry.Metrics

  def metrics do
    [
      Metrics.counter("core.job.count",
        event_name: [:core, :job, :stop]
      ),
      Metrics.counter("core.job.duration_ms",
        event_name: [:core, :job, :stop],
        measurement: :duration,
        unit: {:native, :millisecond}
      )
    ]
  end
end
