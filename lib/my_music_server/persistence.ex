defmodule MyMusicServer.Persistence do
  @moduledoc """
  Simple JSON file persistence helper.
  """

  def load(path) do
    if File.exists?(path) do
      case File.read!(path) |> Jason.decode() do
        {:ok, data} -> data
        {:error, _} -> %{}
      end
    else
      %{}
    end
  end

  def save(path, data) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(data, pretty: true))
    :ok
  end
end
