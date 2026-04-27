defmodule CodenamesWeb.Router do
  use CodenamesWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CodenamesWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CodenamesWeb do
    pipe_through :browser

    live "/", HomeLive
    live "/board/:code", BoardLive
    live "/spymaster/:code", SpymasterLive
  end
end
