defmodule MyMusicServer.Library do
  @moduledoc """
  GenServer managing the song catalog.
  Persists catalog to data/catalog.json.
  """
  use GenServer
  require Logger

  @data_file "data/catalog.json"

  ## Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def all_songs do
    GenServer.call(__MODULE__, :all_songs)
  end

  def get_song(id) do
    GenServer.call(__MODULE__, {:get_song, id})
  end

  def add_song(song) do
    GenServer.cast(__MODULE__, {:add_song, song})
  end

  def update_song(id, attrs) do
    GenServer.cast(__MODULE__, {:update_song, id, attrs})
  end

  def remove_song(id) do
    GenServer.cast(__MODULE__, {:remove_song, id})
  end

  ## GenServer Callbacks

  @impl true
  def init(_) do
    catalog = MyMusicServer.Persistence.load(@data_file)
    Logger.info("Library loaded #{map_size(catalog)} songs from disk")
    {:ok, catalog}
  end

  @impl true
  def handle_call(:all_songs, _from, catalog) do
    songs = Map.values(catalog)
    {:reply, songs, catalog}
  end

  @impl true
  def handle_call({:get_song, id}, _from, catalog) do
    case Map.get(catalog, id) do
      nil -> {:reply, {:error, :not_found}, catalog}
      song -> {:reply, {:ok, song}, catalog}
    end
  end

  @impl true
  def handle_cast({:add_song, song}, catalog) do
    updated = Map.put(catalog, song["id"], song)
    persist(updated)
    {:noreply, updated}
  end

  @impl true
  def handle_cast({:update_song, id, attrs}, catalog) do
    updated =
      case Map.get(catalog, id) do
        nil -> catalog
        song -> Map.put(catalog, id, Map.merge(song, attrs))
      end

    persist(updated)
    {:noreply, updated}
  end

  @impl true
  def handle_cast({:remove_song, id}, catalog) do
    updated = Map.delete(catalog, id)
    persist(updated)
    {:noreply, updated}
  end

  defp persist(catalog) do
    MyMusicServer.Persistence.save(@data_file, catalog)
  end
end
