defmodule Codenames.Words do
  @external_resource Path.expand("../../priv/words.txt", __DIR__)

  @words @external_resource
         |> File.read!()
         |> String.split("\n", trim: true)
         |> Enum.map(&String.trim/1)
         |> Enum.reject(&(&1 == ""))

  def all, do: @words

  def random_25, do: Enum.take_random(@words, 25)
end
