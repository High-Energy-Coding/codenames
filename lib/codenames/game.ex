defmodule Codenames.Game do
  @moduledoc """
  Per-game GenServer holding the entire state of a single Codenames game in memory.
  Registered in `Codenames.GameRegistry` by its 4-letter code.
  """
  use GenServer

  alias Phoenix.PubSub

  defstruct [
    :code,
    :words,
    :assignments,
    :revealed,
    :starting_team,
    :current_turn,
    :winner,
    :winning_reason
  ]

  @type team :: :red | :blue
  @type kind :: :red | :blue | :neutral | :assassin

  @type t :: %__MODULE__{
          code: String.t(),
          words: [String.t()],
          assignments: [kind],
          revealed: [boolean],
          starting_team: team,
          current_turn: team,
          winner: team | nil,
          winning_reason: :all_found | :assassin | nil
        }

  # ---- public API ----

  def start_link(opts) do
    code = Keyword.fetch!(opts, :code)
    GenServer.start_link(__MODULE__, opts, name: via(code))
  end

  def via(code), do: {:via, Registry, {Codenames.GameRegistry, code}}

  def state(code), do: GenServer.call(via(code), :state)
  def reveal(code, index), do: GenServer.call(via(code), {:reveal, index})
  def end_turn(code), do: GenServer.call(via(code), :end_turn)
  def restart(code), do: GenServer.call(via(code), :restart)

  def topic(code), do: "game:" <> code

  # ---- callbacks ----

  @impl true
  def init(opts) do
    code = Keyword.fetch!(opts, :code)
    words = Keyword.get(opts, :words, Codenames.Words.random_25())
    starting_team = Enum.random([:red, :blue])

    {:ok,
     %__MODULE__{
       code: code,
       words: words,
       assignments: build_assignments(starting_team),
       revealed: List.duplicate(false, 25),
       starting_team: starting_team,
       current_turn: starting_team,
       winner: nil,
       winning_reason: nil
     }}
  end

  @impl true
  def handle_call(:state, _from, state), do: {:reply, state, state}

  def handle_call({:reveal, _idx}, _from, %{winner: w} = state) when not is_nil(w),
    do: {:reply, {:error, :game_over}, state}

  def handle_call({:reveal, idx}, _from, state) when idx in 0..24 do
    if Enum.at(state.revealed, idx) do
      {:reply, {:error, :already_revealed}, state}
    else
      revealed = List.replace_at(state.revealed, idx, true)
      kind = Enum.at(state.assignments, idx)
      {next_turn, winner, reason} = resolve(kind, state.current_turn, state.assignments, revealed)

      new_state = %{
        state
        | revealed: revealed,
          current_turn: next_turn,
          winner: winner,
          winning_reason: reason
      }

      broadcast(new_state, %{
        event: :reveal,
        index: idx,
        kind: kind,
        guessing_team: state.current_turn,
        winner: winner,
        winning_reason: reason
      })

      {:reply, :ok, new_state}
    end
  end

  def handle_call(:end_turn, _from, %{winner: nil} = state) do
    new_state = %{state | current_turn: opposite(state.current_turn)}
    broadcast(new_state, %{event: :end_turn, current_turn: new_state.current_turn})
    {:reply, :ok, new_state}
  end

  def handle_call(:end_turn, _from, state), do: {:reply, {:error, :game_over}, state}

  def handle_call(:restart, _from, state) do
    starting_team = Enum.random([:red, :blue])

    new_state = %__MODULE__{
      code: state.code,
      words: Codenames.Words.random_25(),
      assignments: build_assignments(starting_team),
      revealed: List.duplicate(false, 25),
      starting_team: starting_team,
      current_turn: starting_team,
      winner: nil,
      winning_reason: nil
    }

    broadcast(new_state, %{event: :restart})
    {:reply, :ok, new_state}
  end

  # ---- rules ----

  defp build_assignments(starting_team) do
    other = opposite(starting_team)

    cards =
      List.duplicate(starting_team, 9) ++
        List.duplicate(other, 8) ++
        List.duplicate(:neutral, 7) ++
        [:assassin]

    Enum.shuffle(cards)
  end

  # current = whose turn it is. kind = the kind of the card just revealed.
  defp resolve(:assassin, current, _assignments, _revealed),
    do: {current, opposite(current), :assassin}

  defp resolve(:neutral, current, _assignments, _revealed),
    do: {opposite(current), nil, nil}

  defp resolve(team, current, assignments, revealed) when team in [:red, :blue] do
    winner = if all_team_revealed?(assignments, revealed, team), do: team, else: nil
    reason = if winner, do: :all_found, else: nil
    next_turn = if team == current, do: current, else: opposite(current)
    {next_turn, winner, reason}
  end

  defp all_team_revealed?(assignments, revealed, team) do
    assignments
    |> Enum.zip(revealed)
    |> Enum.all?(fn {a, r} -> a != team or r end)
  end

  defp opposite(:red), do: :blue
  defp opposite(:blue), do: :red

  defp broadcast(state, meta) do
    PubSub.broadcast(Codenames.PubSub, topic(state.code), {:game_updated, state, meta})
  end

  # ---- helpers for views ----

  def remaining(state, team) do
    state.assignments
    |> Enum.zip(state.revealed)
    |> Enum.count(fn {a, r} -> a == team and not r end)
  end
end
