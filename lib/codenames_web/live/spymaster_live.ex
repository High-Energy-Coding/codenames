defmodule CodenamesWeb.SpymasterLive do
  use CodenamesWeb, :live_view

  alias Codenames.{Game, Games}

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    code = String.upcase(code)

    if Games.exists?(code) do
      state = Games.state(code)

      if state.winner do
        # Game's already won — bounce straight to board so we don't show the
        # answers from a finished game while people swap seats.
        {:ok, push_navigate(socket, to: ~p"/board/#{code}")}
      else
        if connected?(socket),
          do: Phoenix.PubSub.subscribe(Codenames.PubSub, Game.topic(code))

        {:ok,
         socket
         |> assign(code: code, page_title: "Spymaster · " <> code)
         |> assign_game(state)}
      end
    else
      {:ok,
       socket
       |> put_flash(:error, "No game found with code #{code}")
       |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_info({:game_updated, state, meta}, socket) do
    cond do
      # Game just ended — flip the spymaster phone over to the board so the
      # answers vanish before anyone sees the next round's colors.
      state.winner ->
        {:noreply, push_navigate(socket, to: ~p"/board/#{socket.assigns.code}")}

      # Belt-and-suspenders: if a new round somehow starts while we're still
      # on the spymaster screen, also bounce to board (don't render new state).
      meta[:event] == :restart ->
        {:noreply, push_navigate(socket, to: ~p"/board/#{socket.assigns.code}")}

      true ->
        {:noreply, assign_game(socket, state)}
    end
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
        <div class="leading-none">
          <div class="text-[9px] sm:text-[10px] font-medium uppercase tracking-[0.25em] text-stone-400 dark:text-stone-500 mb-0.5">
            room code
          </div>
          <div class="text-base sm:text-xl font-black tracking-[0.2em] text-stone-700 dark:text-stone-300">
            {@code}
          </div>
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
            "rounded-md flex items-center justify-center font-black uppercase text-center px-0.5 leading-none tracking-tight",
            word_text_class(card.word),
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

  defp word_text_class(word) do
    case String.length(word) do
      n when n <= 6 -> "text-[clamp(0.5rem,2.5vw,1rem)]"
      n when n <= 8 -> "text-[clamp(0.45rem,2.0vw,0.9rem)]"
      n when n <= 10 -> "text-[clamp(0.4rem,1.6vw,0.75rem)]"
      _ -> "text-[clamp(0.35rem,1.3vw,0.65rem)]"
    end
  end

  defp card_color(:red), do: "bg-red-600 text-white"
  defp card_color(:blue), do: "bg-blue-700 text-white"
  defp card_color(:neutral), do: "bg-amber-200 text-amber-900"
  defp card_color(:assassin), do: "bg-zinc-900 text-white"

  defp team_pill_class(:red), do: "bg-red-600 text-white"
  defp team_pill_class(:blue), do: "bg-blue-700 text-white"
end
