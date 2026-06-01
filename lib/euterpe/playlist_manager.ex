defmodule Euterpe.PlaylistManager do
  @moduledoc """
  GenServer managing playlists.
  Persists to data/playlists.json.
  """
  use GenServer
  require Logger

  @data_file "data/playlists.json"

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def all do
    GenServer.call(__MODULE__, :all)
  end

  def get(id) do
    GenServer.call(__MODULE__, {:get, id})
  end

  def create(name, song_ids) do
    GenServer.call(__MODULE__, {:create, name, song_ids})
  end

  def update(id, song_ids) do
    GenServer.call(__MODULE__, {:update, id, song_ids})
  end

  def delete(id) do
    GenServer.call(__MODULE__, {:delete, id})
  end

  @impl true
  def init(_) do
    playlists = Euterpe.Persistence.load(@data_file)
    Logger.info("PlaylistManager loaded #{map_size(playlists)} playlists from disk")
    {:ok, playlists}
  end

  @impl true
  def handle_call(:all, _from, playlists) do
    {:reply, Map.values(playlists), playlists}
  end

  @impl true
  def handle_call({:get, id}, _from, playlists) do
    case Map.get(playlists, id) do
      nil -> {:reply, {:error, :not_found}, playlists}
      playlist -> {:reply, {:ok, playlist}, playlists}
    end
  end

  @impl true
  def handle_call({:create, name, song_ids}, _from, playlists) do
    id = System.unique_integer([:positive]) |> Integer.to_string()

    playlist = %{
      id: id,
      name: name,
      song_ids: song_ids,
      created_at: DateTime.utc_now()
    }

    updated = Map.put(playlists, id, playlist)
    persist(updated)
    {:reply, {:ok, playlist}, updated}
  end

  @impl true
  def handle_call({:update, id, song_ids}, _from, playlists) do
    case Map.get(playlists, id) do
      nil ->
        {:reply, {:error, :not_found}, playlists}

      playlist ->
        updated_playlist = Map.put(playlist, :song_ids, song_ids)
        updated = Map.put(playlists, id, updated_playlist)
        persist(updated)
        {:reply, {:ok, updated_playlist}, updated}
    end
  end

  @impl true
  def handle_call({:delete, id}, _from, playlists) do
    updated = Map.delete(playlists, id)
    persist(updated)
    {:reply, :ok, updated}
  end

  defp persist(playlists) do
    Euterpe.Persistence.save(@data_file, playlists)
  end
end
