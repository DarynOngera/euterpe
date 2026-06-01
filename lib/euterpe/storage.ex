defmodule Euterpe.Storage do
  @moduledoc """
  Handles file uploads and storage.
  """

  def save_upload(%Plug.Upload{path: tmp_path, filename: original_filename}) do
    upload_dir = Application.get_env(:euterpe, :upload_dir, "uploads")
    File.mkdir_p!(upload_dir)

    ext = Path.extname(original_filename)
    song_id = generate_id()
    filename = "#{song_id}#{ext}"
    dest_path = Path.join(upload_dir, filename)

    File.cp!(tmp_path, dest_path)

    {:ok, song_id, dest_path}
  end

  def delete_file(path) do
    if File.exists?(path) do
      File.rm!(path)
    end

    :ok
  end

  defp generate_id do
    System.unique_integer([:positive]) |> Integer.to_string()
  end
end
