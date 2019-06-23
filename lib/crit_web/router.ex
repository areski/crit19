defmodule CritWeb.Router do
  use CritWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CritWeb do
    pipe_through :browser

    get "/", PageController, :index
    resources "/users", UserController, except: [:delete]
  end

  
  # Other scopes may use custom stacks.
  # scope "/api", CritWeb do
  #   pipe_through :api
  # end
end
