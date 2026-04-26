defmodule CodenamesWeb.HomeLive do
  use CodenamesWeb, :live_view

  alias Codenames.Games

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, code_input: "", error: nil)}
  end

  @impl true
  def handle_event("create", _params, socket) do
    {:ok, code} = Games.create()
    {:noreply, push_navigate(socket, to: ~p"/board/#{code}")}
  end

  def handle_event("join_change", %{"code" => code}, socket) do
    sanitized =
      code |> String.upcase() |> String.replace(~r/[^A-Z]/, "") |> String.slice(0, 4)

    {:noreply, assign(socket, code_input: sanitized, error: nil)}
  end

  def handle_event("join_board", %{"code" => code}, socket),
    do: do_join(socket, code, :board)

  def handle_event("join_spymaster", %{"code" => code}, socket),
    do: do_join(socket, code, :spymaster)

  defp do_join(socket, code, role) do
    code = code |> String.trim() |> String.upcase()

    cond do
      String.length(code) != 4 ->
        {:noreply, assign(socket, error: "Code must be 4 letters")}

      not Games.exists?(code) ->
        {:noreply, assign(socket, error: "No game found with code #{code}")}

      true ->
        path =
          case role do
            :board -> ~p"/board/#{code}"
            :spymaster -> ~p"/spymaster/#{code}"
          end

        {:noreply, push_navigate(socket, to: path)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

    <div class="h-dvh w-screen overflow-hidden flex items-center justify-center p-6 bg-stone-100 dark:bg-stone-900">
      <div class="w-full max-w-md space-y-8">
        <div class="text-center">
          <h1 class="text-5xl sm:text-7xl font-black tracking-tight">CODENAMES</h1>
          <p class="mt-3 text-base-content/60 text-xs tracking-[0.3em] uppercase">
            two teams · one assassin · don't peek
          </p>
        </div>

        <button
          phx-click="create"
          class="btn btn-primary btn-block btn-lg text-xl h-16"
        >
          New Game
        </button>

        <div class="divider text-base-content/40 text-xs uppercase tracking-[0.3em]">or join</div>

        <form phx-change="join_change" phx-submit="join_spymaster" class="space-y-3">
          <input
            type="text"
            name="code"
            value={@code_input}
            maxlength="4"
            autocomplete="off"
            autocapitalize="characters"
            spellcheck="false"
            placeholder="ABCD"
            class="input input-bordered input-lg w-full text-center text-4xl font-bold tracking-[0.5em] uppercase h-20"
          />

          <div class="grid grid-cols-2 gap-2">
            <button
              type="button"
              phx-click="join_board"
              phx-value-code={@code_input}
              disabled={String.length(@code_input) != 4}
              class="btn btn-lg btn-outline"
            >
              Board
            </button>
            <button
              type="submit"
              disabled={String.length(@code_input) != 4}
              class="btn btn-lg btn-secondary"
            >
              Spymaster
            </button>
          </div>

          <p :if={@error} class="text-error text-sm text-center">{@error}</p>
        </form>
      </div>
    </div>
    """
  end
end
