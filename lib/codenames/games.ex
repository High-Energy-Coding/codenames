defmodule Codenames.Games do
  @moduledoc """
  Public API for managing game lifecycle — creating new games, looking up
  existing ones, and proxying action calls to the right Game GenServer.
  """

  alias Codenames.Game

  @code_alphabet ~c"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  @code_length 4
  @max_attempts 50

  @doc """
  Create a new game and return its 4-letter code. The Game process is started
  under the GameSupervisor and registered in the GameRegistry.
  """
  def create do
    code = generate_unique_code()

    case DynamicSupervisor.start_child(
           Codenames.GameSupervisor,
           {Game, [code: code]}
         ) do
      {:ok, _pid} -> {:ok, code}
      {:error, {:already_started, _}} -> create()
      {:error, reason} -> {:error, reason}
    end
  end

  def exists?(code) when is_binary(code) do
    case Registry.lookup(Codenames.GameRegistry, normalize(code)) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  def state(code), do: Game.state(normalize(code))
  def reveal(code, index), do: Game.reveal(normalize(code), index)
  def end_turn(code), do: Game.end_turn(normalize(code))
  def restart(code), do: Game.restart(normalize(code))

  def normalize(code) when is_binary(code), do: String.upcase(code)

  defp generate_unique_code(attempts \\ 0)

  defp generate_unique_code(attempts) when attempts > @max_attempts,
    do: raise("Could not generate a unique game code after #{@max_attempts} attempts")

  defp generate_unique_code(attempts) do
    code = generate_code()
    if exists?(code), do: generate_unique_code(attempts + 1), else: code
  end

  defp generate_code do
    1..@code_length
    |> Enum.map(fn _ -> Enum.random(@code_alphabet) end)
    |> List.to_string()
  end
end
