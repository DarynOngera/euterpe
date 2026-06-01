defmodule MyMusicServer.Audio do
  @moduledoc """
  Wrapper around ffmpeg/ffprobe for audio processing.
  """
  require Logger

  @doc """
  Extract metadata from an audio file using ffprobe.
  Returns a map with metadata.
  """
  def extract_metadata(file_path) do
    args = [
      "-v",
      "quiet",
      "-print_format",
      "json",
      "-show_format",
      "-show_streams",
      file_path
    ]

    case System.cmd("ffprobe", args, stderr_to_stdout: true) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, data} ->
            format = Map.get(data, "format", %{})
            streams = List.first(Map.get(data, "streams", [])) || %{}

            %{
              duration: parse_float(Map.get(format, "duration")),
              bitrate: parse_int(Map.get(format, "bit_rate")),
              sample_rate: parse_int(Map.get(streams, "sample_rate")),
              channels: parse_int(Map.get(streams, "channels")),
              format_name: Map.get(format, "format_name")
            }

          {:error, _} ->
            %{error: "Failed to parse ffprobe output"}
        end

      {error_output, _} ->
        Logger.error("ffprobe failed: #{error_output}")
        %{error: "ffprobe failed", details: error_output}
    end
  end

  @doc """
  Transcode an audio file to a different format.
  Returns the output file path.
  """
  def transcode(input_path, target_format) do
    upload_dir = Application.get_env(:my_music_server, :upload_dir, "uploads")
    base = Path.rootname(Path.basename(input_path))
    output_path = Path.join(upload_dir, "#{base}_transcoded#{target_format}")

    args = [
      "-y",
      "-i",
      input_path,
      output_path
    ]

    case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
      {_output, 0} ->
        {:ok, output_path}

      {error_output, _} ->
        Logger.error("ffmpeg transcode failed: #{error_output}")
        {:error, error_output}
    end
  end

  @doc """
  Generate a waveform PNG image from an audio file.
  Returns the output file path.
  """
  def generate_waveform(input_path) do
    upload_dir = Application.get_env(:my_music_server, :upload_dir, "uploads")
    base = Path.rootname(Path.basename(input_path))
    output_path = Path.join(upload_dir, "#{base}_waveform.png")

    args = [
      "-y",
      "-i",
      input_path,
      "-filter_complex",
      "aformat=channel_layouts=mono,showwavespic=s=640x120",
      "-frames:v",
      "1",
      output_path
    ]

    case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
      {_output, 0} ->
        {:ok, output_path}

      {error_output, _} ->
        Logger.error("ffmpeg waveform failed: #{error_output}")
        {:error, error_output}
    end
  end

  @doc """
  Generate HLS adaptive streaming segments from an audio file.
  Creates a directory with .m3u8 playlist and .ts segments.
  """
  def generate_hls(input_path) do
    upload_dir = Application.get_env(:my_music_server, :upload_dir, "uploads")
    base = Path.rootname(Path.basename(input_path))
    hls_dir = Path.join(upload_dir, "#{base}_hls")
    File.mkdir_p!(hls_dir)

    playlist_path = Path.join(hls_dir, "playlist.m3u8")

    args = [
      "-y",
      "-i",
      input_path,
      "-c:a",
      "aac",
      "-b:a",
      "128k",
      "-f",
      "hls",
      "-hls_time",
      "10",
      "-hls_list_size",
      "0",
      "-hls_segment_filename",
      Path.join(hls_dir, "segment_%03d.ts"),
      playlist_path
    ]

    case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
      {_output, 0} ->
        {:ok, playlist_path}

      {error_output, _} ->
        Logger.error("ffmpeg HLS generation failed: #{error_output}")
        {:error, error_output}
    end
  end

  defp parse_float(nil), do: nil
  defp parse_float(f) when is_float(f), do: f
  defp parse_float(i) when is_integer(i), do: i / 1

  defp parse_float(str) when is_binary(str) do
    case Float.parse(str) do
      {f, _} -> f
      :error -> nil
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(i) when is_integer(i), do: i

  defp parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, _} -> int
      :error -> nil
    end
  end
end
