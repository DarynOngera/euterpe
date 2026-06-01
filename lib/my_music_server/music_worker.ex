defmodule MyMusicServer.MusicWorker do
  @moduledoc """
  Background job worker for audio processing.
  """
  use GenServer
  require Logger
  alias Core.Workers.JobQueue
  alias Core.Telemetry.Events

  @poll_interval 1_000

  ## Public API

  def start_link(opts \\ []) do
    worker_id = Keyword.get(opts, :id, 1)
    name = :"#{__MODULE__}_#{worker_id}"
    GenServer.start_link(__MODULE__, %{id: worker_id}, name: name)
  end

  ## GenServer Callbacks

  @impl true
  def init(%{id: id} = state) do
    Logger.info("MusicWorker ##{id} started")
    schedule_work()
    {:ok, state}
  end

  @impl true
  def handle_info(:work, state) do
    case JobQueue.claim_next() do
      {:ok, job} -> execute(job, state)
      :empty -> :noop
    end

    schedule_work()
    {:noreply, state}
  end

  ## Private Functions

  defp schedule_work do
    Process.send_after(self(), :work, @poll_interval)
  end

  defp execute(job, %{id: worker_id}) do
    Logger.info("MusicWorker ##{worker_id} executing job #{job.id} (attempt #{job.attempt})")

    :telemetry.execute(
      Events.job_start(),
      %{},
      %{job_id: job.id, attempt: job.attempt, payload: job.payload}
    )

    MyMusicServer.EventBus.publish(:jobs, %{
      event: "started",
      job_id: job.id,
      task: get_task(job.payload),
      worker_id: worker_id,
      attempt: job.attempt
    })

    start_time = System.monotonic_time()

    try do
      result = perform_work(job)
      duration = System.monotonic_time() - start_time
      duration_ms = native_to_ms(duration)

      :telemetry.execute(
        Events.job_stop(),
        %{duration: duration},
        %{job_id: job.id}
      )

      JobQueue.mark_done(job.id, result)

      MyMusicServer.EventBus.publish(:jobs, %{
        event: "completed",
        job_id: job.id,
        task: get_task(job.payload),
        worker_id: worker_id,
        duration_ms: duration_ms,
        result: result
      })

      MyMusicServer.EventBus.publish({:job, job.id}, %{
        event: "completed",
        job_id: job.id,
        duration_ms: duration_ms,
        result: result
      })

      Logger.info("MusicWorker ##{worker_id} completed job #{job.id} in #{duration_ms}ms")
    rescue
      error ->
        duration = System.monotonic_time() - start_time
        duration_ms = native_to_ms(duration)
        message = Exception.message(error)

        :telemetry.execute(
          Events.job_error(),
          %{duration: duration},
          %{job_id: job.id, error: message}
        )

        error_details = %{
          error: message,
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        }

        Logger.error("MusicWorker ##{worker_id} failed job #{job.id}: #{message}")
        JobQueue.mark_failed(job.id, error_details)

        MyMusicServer.EventBus.publish(:jobs, %{
          event: "errored",
          job_id: job.id,
          task: get_task(job.payload),
          worker_id: worker_id,
          duration_ms: duration_ms,
          error: message
        })

        MyMusicServer.EventBus.publish({:job, job.id}, %{
          event: "errored",
          job_id: job.id,
          duration_ms: duration_ms,
          error: message
        })
    end
  end

  defp perform_work(job) do
    case job.payload do
      %{"task" => "extract_metadata", "song_id" => song_id} ->
        extract_metadata_job(song_id)

      %{
        "task" => "transcode",
        "song_id" => song_id,
        "input_path" => input_path,
        "target_format" => format
      } ->
        transcode_job(song_id, input_path, format)

      %{"task" => "generate_waveform", "song_id" => song_id, "input_path" => input_path} ->
        waveform_job(song_id, input_path)

      %{"task" => "generate_hls", "song_id" => song_id, "input_path" => input_path} ->
        hls_job(song_id, input_path)

      _ ->
        %{error: "Unknown task type"}
    end
  end

  defp extract_metadata_job(song_id) do
    case MyMusicServer.Library.get_song(song_id) do
      {:ok, song} ->
        metadata = MyMusicServer.Audio.extract_metadata(song["file_path"])

        MyMusicServer.Library.update_song(song_id, %{
          "metadata" => metadata,
          "status" => "ready"
        })

        %{
          status: "completed",
          task: "extract_metadata",
          song_id: song_id,
          metadata: metadata
        }

      {:error, :not_found} ->
        %{error: "Song not found", song_id: song_id}
    end
  end

  defp transcode_job(song_id, input_path, format) do
    case MyMusicServer.Audio.transcode(input_path, format) do
      {:ok, output_path} ->
        %{
          status: "completed",
          task: "transcode",
          song_id: song_id,
          output_path: output_path,
          format: format
        }

      {:error, reason} ->
        raise "Transcode failed: #{reason}"
    end
  end

  defp waveform_job(song_id, input_path) do
    case MyMusicServer.Audio.generate_waveform(input_path) do
      {:ok, output_path} ->
        %{
          status: "completed",
          task: "generate_waveform",
          song_id: song_id,
          waveform_path: output_path
        }

      {:error, reason} ->
        raise "Waveform generation failed: #{reason}"
    end
  end

  defp hls_job(song_id, input_path) do
    case MyMusicServer.Audio.generate_hls(input_path) do
      {:ok, playlist_path} ->
        %{
          status: "completed",
          task: "generate_hls",
          song_id: song_id,
          playlist_path: playlist_path
        }

      {:error, reason} ->
        raise "HLS generation failed: #{reason}"
    end
  end

  defp native_to_ms(native) do
    System.convert_time_unit(native, :native, :millisecond)
  end

  defp get_task(%{"task" => task}), do: task
  defp get_task(_), do: "unknown"
end
