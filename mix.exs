defmodule Alchemy.Mixfile do
  use Mix.Project

  def project do
    [app: :alchemy,
     description: "Perform experiments in production",
     version: "0.2.0",
     elixir: "~> 1.7",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     package: package(),
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger],
     mod: {Alchemy, []}]
  end

  defp deps do
    [
      {:uuid, "~> 1.1"},
      {:ex_doc, "~> 0.20", only: :dev},
      {:earmark, "~> 1.2", only: :dev}
    ]
  end

  defp package do
    [maintainers: ["Chris Keathley"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/keathley/alchemy"}]
  end

end
