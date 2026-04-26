defmodule CodenamesWeb.BoardLive do
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
       |> assign(code: code, page_title: "Board · " <> code)
       |> assign_game(Games.state(code))}
    else
      {:ok,
       socket
       |> put_flash(:error, "No game found with code #{code}")
       |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("reveal", %{"index" => index}, socket) do
    Games.reveal(socket.assigns.code, String.to_integer(index))
    {:noreply, socket}
  end

  def handle_event("end_turn", _params, socket) do
    Games.end_turn(socket.assigns.code)
    {:noreply, socket}
  end

  def handle_event("restart", _params, socket) do
    Games.restart(socket.assigns.code)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:game_updated, state, meta}, socket) do
    {:noreply,
     socket
     |> assign_game(state)
     |> push_meta_event(meta)
     |> push_tension(state)}
  end

  defp push_tension(socket, state) do
    push_event(socket, "tension_check", %{
      red: Game.remaining(state, :red),
      blue: Game.remaining(state, :blue),
      winner: state.winner && to_string(state.winner)
    })
  end

  defp push_meta_event(socket, %{event: :reveal} = meta) do
    push_event(socket, "card_revealed", %{
      index: meta.index,
      kind: to_string(meta.kind),
      guessing_team: to_string(meta.guessing_team),
      winner: meta.winner && to_string(meta.winner),
      winning_reason: meta.winning_reason && to_string(meta.winning_reason)
    })
  end

  defp push_meta_event(socket, %{event: :end_turn, current_turn: turn}),
    do: push_event(socket, "turn_ended", %{current_turn: to_string(turn)})

  defp push_meta_event(socket, %{event: :restart}),
    do: push_event(socket, "game_restarted", %{})

  defp push_meta_event(socket, _), do: socket

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

    <div class={[
      "h-dvh w-screen overflow-hidden bg-stone-100 dark:bg-stone-900 flex flex-col p-3 sm:p-4 lg:p-6 gap-3 sm:gap-4 lg:gap-5",
      "ring-[10px] ring-inset transition-[box-shadow] duration-300",
      !@game.winner && @game.current_turn == :red && "ring-red-700 cursor-red",
      !@game.winner && @game.current_turn == :blue && "ring-blue-800 cursor-blue",
      @game.winner && "ring-stone-300"
    ]}>
      <div class="flex items-center justify-between gap-3 shrink-0">
        <div class="flex items-center gap-3 sm:gap-5">
          <div class="text-2xl sm:text-3xl lg:text-4xl font-black tracking-[0.3em] text-stone-700 dark:text-stone-300">
            {@code}
          </div>
          <div
            :if={!@game.winner}
            class={[
              "text-2xl sm:text-3xl lg:text-5xl font-black px-5 sm:px-7 lg:px-9 py-1.5 sm:py-2 lg:py-3 rounded-full uppercase tracking-wider shadow-lg",
              team_pill_class(@game.current_turn)
            ]}
          >
            {to_string(@game.current_turn)} team
          </div>
        </div>

        <div class="flex items-center gap-3 sm:gap-5 text-3xl sm:text-5xl lg:text-7xl font-black tabular-nums">
          <div class="text-red-700">{Game.remaining(@game, :red)}</div>
          <div class="text-stone-400 text-xl sm:text-3xl">·</div>
          <div class="text-blue-800">{Game.remaining(@game, :blue)}</div>
        </div>

        <div class="flex gap-2">
          <button
            :if={!@game.winner}
            phx-click="end_turn"
            class="btn btn-outline btn-sm sm:btn-md lg:btn-lg"
          >
            End Turn
          </button>
          <.link
            navigate={~p"/spymaster/#{@code}"}
            data-confirm="Are you the spymaster? Don't peek if not!"
            class="btn btn-secondary btn-sm sm:btn-md lg:btn-lg"
          >
            Spymaster
          </.link>
        </div>
      </div>

      <div class="flex-1 min-h-0 grid grid-cols-5 grid-rows-5 gap-2 sm:gap-3 lg:gap-4">
        <button
          :for={card <- @cards}
          id={"card-#{card.index}"}
          phx-click="reveal"
          phx-value-index={card.index}
          disabled={card.revealed || @game.winner != nil}
          class={[
            "card relative rounded-xl select-none",
            !card.revealed && "hover:scale-[1.02] active:scale-95 transition-transform duration-150 cursor-pointer",
            card.revealed && "cursor-default"
          ]}
        >
          <div class={["card-inner absolute inset-0 rounded-xl", card.revealed && "is-flipped"]}>
            <div class={[
              "card-face card-front rounded-xl",
              "bg-amber-50 text-stone-800 shadow-md font-black uppercase",
              "text-[clamp(0.625rem,3.2vw,5rem)] tracking-tight leading-none p-1"
            ]}>
              <span class="text-balance">{card.word}</span>
            </div>
            <div class={[
              "card-face card-back rounded-xl shadow-inner font-black uppercase",
              "text-[clamp(0.625rem,3.2vw,5rem)] tracking-tight leading-none p-1",
              card_color(card.kind)
            ]}>
              <span class="text-balance">{card.word}</span>
            </div>
          </div>
        </button>
      </div>
    </div>

    <div
      :if={@game.winner}
      class={[
        "winner-overlay fixed inset-0 z-50 flex items-center justify-center backdrop-blur-sm p-6",
        @game.winner == :red && "bg-red-900/75",
        @game.winner == :blue && "bg-blue-900/75"
      ]}
    >
      <div class="winner-content text-center space-y-6">
        <div class="text-7xl sm:text-8xl lg:text-9xl font-black text-white drop-shadow-2xl uppercase tracking-tight">
          {to_string(@game.winner)} wins
        </div>
        <div :if={@game.winning_reason == :assassin} class="text-2xl sm:text-3xl text-white/90 font-medium">
          the other team picked the assassin
        </div>
        <button phx-click="restart" class="btn btn-lg text-xl">
          New Round
        </button>
      </div>
    </div>
    """
  end

  defp card_color(:red), do: "bg-red-700 text-red-50"
  defp card_color(:blue), do: "bg-blue-800 text-blue-50"
  defp card_color(:neutral), do: "bg-stone-300 text-stone-700"
  defp card_color(:assassin), do: "bg-zinc-900 text-zinc-200"

  defp team_pill_class(:red), do: "bg-red-700 text-white"
  defp team_pill_class(:blue), do: "bg-blue-800 text-white"
end
