import Config

config :alchemy,
  publish_module: Alchemy.Publishers.NullPublisher

config :logger, level: :error
