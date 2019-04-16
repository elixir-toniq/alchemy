# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :alchemy,
  publish_module: Alchemy.Publishers.NullPublisher

config :logger, level: :error
