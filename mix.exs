defmodule Alchemy.Mixfile do
  use Mix.Project

  def project do
    [
      app: :alchemy,
      description: "Perform experiments in production",
      version: "1.0.0-dev",
      elixir: "~> 1.7",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      package: package(),
      deps: deps(),
      docs: docs(),
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.20", only: :dev},
      {:earmark, "~> 1.2", only: :dev}
    ]
  end

  defp package do
    [
      maintainers: ["Chris Keathley"],
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/keathley/alchemy"}
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_url: "https://github.com/keathley/alchemy",
    ]
  end
end
