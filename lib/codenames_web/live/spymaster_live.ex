defmodule CodenamesWeb.SpymasterLive do
  use CodenamesWeb, :live_view

  alias Codenames.{Game, Games}

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    code = String.upcase(code)

    if Games.exists?(code) do
      if connected?(socket),
        do: Phoenix.PubSub.subscribe(Codenames.PubSub, Game.topic(code))

      {:ok,
       socket
       |> assign(code: code, page_title: "Spymaster · " <> code)
       |> assign_game(Games.state(code))}
    else
      {:ok,
       socket
       |> put_flash(:error, "No game found with code #{code}")
       |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_info({:game_updated, state, _meta}, socket) do
    {:noreply, assign_game(socket, state)}
  end

  defp assign_game(socket, game) do
    cards =
      [game.words, game.assignments, game.revealed]
      |> Enum.zip()
      |> Enum.with_index()
      |> Enum.map(fn {{word, kind, revealed}, i} ->
        %{index: i, word: word, kind: kind, revealed: revealed}
      end)

    assign(socket, game: game, cards: cards)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

    <div class="h-dvh w-screen overflow-hidden bg-stone-100 dark:bg-stone-900 flex flex-col p-2 sm:p-3 gap-2">
      <div class="flex items-center justify-between gap-2 shrink-0">
        <div class="text-base sm:text-xl font-black tracking-[0.2em] text-stone-700 dark:text-stone-300">
          {@code}
        </div>

        <div
          :if={!@game.winner}
          class={[
            "text-xs sm:text-sm font-black px-3 py-1 rounded-full uppercase tracking-wider",
            team_pill_class(@game.current_turn)
          ]}
        >
          {to_string(@game.current_turn)} turn
        </div>

        <div
          :if={@game.winner}
          class={[
            "text-xs sm:text-sm font-black px-3 py-1 rounded-full uppercase tracking-wider",
            team_pill_class(@game.winner)
          ]}
        >
          {to_string(@game.winner)} won
        </div>

        <.link navigate={~p"/board/#{@code}"} class="btn btn-xs sm:btn-sm btn-outline">
          Board
        </.link>
      </div>

      <div class="flex items-center justify-around text-xs sm:text-sm font-black shrink-0 px-2">
        <span class="text-red-700">RED · {Game.remaining(@game, :red)}</span>
        <span class="text-stone-500">NEUTRAL · {neutral_remaining(@game)}</span>
        <span class="text-blue-800">BLUE · {Game.remaining(@game, :blue)}</span>
      </div>

      <div class="flex-1 min-h-0 grid grid-cols-5 grid-rows-5 gap-1.5">
        <div
          :for={card <- @cards}
          class={[
            "rounded-md flex items-center justify-center font-black uppercase text-center px-0.5 leading-none",
            "text-[clamp(0.5rem,2.5vw,1rem)] tracking-tight",
            card_color(card.kind),
            card.revealed && "opacity-25"
          ]}
        >
          <span class="text-balance">{card.word}</span>
        </div>
      </div>
    </div>
    """
  end

  defp neutral_remaining(game) do
    game.assignments
    |> Enum.zip(game.revealed)
    |> Enum.count(fn {a, r} -> a == :neutral and not r end)
  end

  defp card_color(:red), do: "bg-red-600 text-white"
  defp card_color(:blue), do: "bg-blue-700 text-white"
  defp card_color(:neutral), do: "bg-amber-200 text-amber-900"
  defp card_color(:assassin), do: "bg-zinc-900 text-white"

  defp team_pill_class(:red), do: "bg-red-600 text-white"
  defp team_pill_class(:blue), do: "bg-blue-700 text-white"
end
