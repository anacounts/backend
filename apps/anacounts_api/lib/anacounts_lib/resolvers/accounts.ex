defmodule AnacountsAPI.Resolvers.Accounts do
  @moduledoc """
  Resolve queries and mutations from
  the `AnacountsAPI.Schema.AccountTypes` module.
  """
  use AnacountsAPI, :resolver

  alias Anacounts.Accounts

  ## Accounts queries

  def find_book(_parent, %{id: id}, %{context: %{current_user: user}}) do
    if book = Accounts.get_book(id, user) do
      {:ok, book}
    else
      {:error, :not_found}
    end
  end

  def find_book(_parent, _args, _resolution), do: not_logged_in()

  def find_books(_parent, _args, %{context: %{current_user: user}} = _resolution) do
    {:ok, Accounts.find_user_books(user)}
  end

  def find_books(_parent, _args, _resolution), do: not_logged_in()

  ## Accounts mutations

  def do_create_book(_parent, %{attrs: book_attrs}, %{context: %{current_user: user}}) do
    Accounts.create_book(user, book_attrs)
  end

  def do_create_book(_parent, _args, _resolution), do: not_logged_in()

  def do_delete_book(_parent, %{id: id}, %{context: %{current_user: user}}) do
    book = Accounts.get_book(id, user)

    if is_nil(book) do
      {:error, :not_found}
    else
      Accounts.delete_book(book, user)
    end
  end

  def do_delete_book(_parent, _args, _resolution), do: not_logged_in()
end
