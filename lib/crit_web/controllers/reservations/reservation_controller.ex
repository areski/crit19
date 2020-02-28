defmodule CritWeb.Reservations.ReservationController do
  use CritWeb, :controller
  use CritWeb.Controller.Path, :reservation_path
  import CritWeb.Plugs.Authorize
  alias CritWeb.ViewModels.Reservation
  alias Crit.Reservations.{ReservationApi}
  # alias CritWeb.Controller.Common
  alias CritWeb.ViewModels.DateOrDates
  
  plug :must_be_able_to, :make_reservations

  def show(conn, %{"reservation_id" => id}) do
    view_model =
      id
      |> ReservationApi.get!(institution(conn))
      |> Reservation.Show.to_view_model(institution(conn))

    render(conn, "show.html", reservation: view_model)
  end

  def by_dates_form(conn, _params) do
    render(conn, "by_dates_form.html",
      changeset: DateOrDates.starting_changeset(),
      path: path(:by_dates)
    )
  end

  def by_dates(conn, %{"date_or_dates" => params}) do
    {:ok, first_date, last_date} = DateOrDates.to_dates(params, institution(conn))
    reservations =
      ReservationApi.on_dates(first_date, last_date, institution(conn))
      |> Enum.map(&(Reservation.Show.to_view_model(&1, institution(conn))))

    render(conn, "by_dates.html",
      reservations: reservations
    )
  end
  
end