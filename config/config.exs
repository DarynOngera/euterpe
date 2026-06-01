import Config

config :my_music_server,
  worker_pool_size:
    String.to_integer(System.get_env("WORKER_POOL_SIZE", "#{System.schedulers_online()}")),
  upload_dir: System.get_env("UPLOAD_DIR", "uploads"),
  data_dir: System.get_env("DATA_DIR", "data")

# Prometheus metrics endpoint
config :my_music_server, :telemetry_prometheus, port: 9568
