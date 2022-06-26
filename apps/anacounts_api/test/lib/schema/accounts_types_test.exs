defmodule AnacountsAPI.Schema.AccountsTypesTest do
  use AnacountsAPI.ConnCase

  import Anacounts.AuthFixtures
  import Anacounts.AccountsFixtures
  import AnacountsAPI.Helpers.Tests, only: [test_logged_in: 2]

  alias Anacounts.Accounts

  describe "query: book" do
    @book_query """
    query Book($id: ID!) {
      book(id: $id) {
        id
        name
        insertedAt
        members {
          id
          role
        }
      }
    }
    """

    setup :setup_user_fixture
    setup :setup_log_user_in

    setup :setup_book_fixture

    test "returns the book information", %{conn: conn, book: book, user: user} do
      conn =
        post(conn, "/", %{
          "query" => @book_query,
          "variables" => %{"id" => book.id}
        })

      assert json_response(conn, 200) == %{
               "data" => %{
                 "book" => %{
                   "id" => to_string(book.id),
                   "name" => valid_book_name(),
                   "insertedAt" => NaiveDateTime.to_iso8601(book.inserted_at),
                   "members" => [
                     %{
                       "id" => to_string(user.id),
                       "role" => "creator"
                     }
                   ]
                 }
               }
             }
    end

    test "returns an error if the book does not exist", %{conn: conn} do
      conn =
        post(conn, "/", %{
          "query" => @book_query,
          "variables" => %{"id" => "0"}
        })

      assert json_response(conn, 200) == %{
               "data" => %{"book" => nil},
               "errors" => [
                 %{
                   "locations" => [%{"column" => 3, "line" => 2}],
                   "message" => "Not found",
                   "path" => ["book"]
                 }
               ]
             }
    end

    test "returns an error if the book does not belong to the user", %{conn: conn} do
      other_user = user_fixture()
      other_book = book_fixture(other_user)

      conn =
        post(conn, "/", %{
          "query" => @book_query,
          "variables" => %{"id" => other_book.id}
        })

      assert json_response(conn, 200) == %{
               "data" => %{"book" => nil},
               "errors" => [
                 %{
                   "locations" => [%{"column" => 3, "line" => 2}],
                   "message" => "Not found",
                   "path" => ["book"]
                 }
               ]
             }
    end

    test_logged_in(@book_query, %{"id" => "0"})
  end

  describe "mutation: create_book" do
    @create_book_mutation """
    mutation CreateBook($attrs: BookInput!) {
      createBook(attrs: $attrs) {
        id
        name
        insertedAt
        members {
          id
          role
        }
      }
    }
    """

    setup :setup_user_fixture
    setup :setup_log_user_in

    test "create a new book", %{conn: conn, user: user} do
      conn =
        post(conn, "/", %{
          "query" => @create_book_mutation,
          "variables" => %{"attrs" => valid_book_attributes()}
        })

      user_id = to_string(user.id)

      assert %{
               "data" => %{
                 "createBook" => %{
                   "id" => book_id,
                   "name" => _book_name,
                   "insertedAt" => _inserted_at,
                   "members" => [
                     %{
                       "id" => ^user_id,
                       "role" => "creator"
                     }
                   ]
                 }
               }
             } = json_response(conn, 200)

      assert Accounts.get_book_of_user(book_id, user)
    end

    test_logged_in(@create_book_mutation, %{"attrs" => valid_book_attributes()})
  end

  describe "mutation: delete_book" do
    @delete_book_mutation """
    mutation DeleteBook($id: ID!) {
      deleteBook(id: $id) {
        id
      }
    }
    """

    setup :setup_user_fixture
    setup :setup_log_user_in

    setup :setup_book_fixture

    test "deletes the book", %{conn: conn, book: book} do
      conn =
        post(conn, "/", %{
          "query" => @delete_book_mutation,
          "variables" => %{"id" => book.id}
        })

      assert json_response(conn, 200) == %{
               "data" => %{"deleteBook" => %{"id" => to_string(book.id)}}
             }
    end

    test "errors with `:not_found` if it does not exist", %{conn: conn} do
      conn =
        post(conn, "/", %{
          "query" => @delete_book_mutation,
          "variables" => %{"id" => 0}
        })

      assert json_response(conn, 200) == %{
               "data" => %{"deleteBook" => nil},
               "errors" => [
                 %{
                   "locations" => [%{"column" => 3, "line" => 2}],
                   "message" => "Not found",
                   "path" => ["deleteBook"]
                 }
               ]
             }
    end

    test "errors with `:not_found` if it does not belong to the user", %{conn: conn} do
      remote_user = user_fixture()
      book = book_fixture(remote_user)

      conn =
        post(conn, "/", %{
          "query" => @delete_book_mutation,
          "variables" => %{"id" => book.id}
        })

      assert json_response(conn, 200) == %{
               "data" => %{"deleteBook" => nil},
               "errors" => [
                 %{
                   "locations" => [%{"column" => 3, "line" => 2}],
                   "message" => "Not found",
                   "path" => ["deleteBook"]
                 }
               ]
             }
    end

    test "not authorized if the user does not have right", %{conn: conn, book: book} do
      other_user = user_fixture()
      _other_member = book_member_fixture(book, other_user)

      conn = log_user_in(conn, other_user)

      conn =
        post(conn, "/", %{
          "query" => @delete_book_mutation,
          "variables" => %{"id" => book.id}
        })

      assert json_response(conn, 200) == %{
               "data" => %{"deleteBook" => nil},
               "errors" => [
                 %{
                   "locations" => [%{"column" => 3, "line" => 2}],
                   "message" => "Unauthorized",
                   "path" => ["deleteBook"]
                 }
               ]
             }
    end

    test_logged_in(@delete_book_mutation, %{"id" => "0"})
  end

  describe "mutation: invite_user" do
    @invite_user_mutation """
    mutation InviteUser($book_id: ID!, $email: String!) {
      inviteUser(book_id: $book_id, email: $email) {
        role
      }
    }
    """

    setup :setup_user_fixture
    setup :setup_log_user_in

    setup :setup_book_fixture
    setup :setup_book_member_fixture

    # XXX In the end, `invite_user` will only send an invite
    # Tests will need to be updated

    test "responds with the new book member", %{conn: conn, book: book} do
      remote_user = user_fixture()

      conn =
        post(conn, "/", %{
          "query" => @invite_user_mutation,
          "variables" => %{"book_id" => book.id, "email" => remote_user.email}
        })

      assert json_response(conn, 200) == %{
               "data" => %{
                 "inviteUser" => %{
                   "role" => "member"
                 }
               }
             }
    end

    test "does not allow users without rights to send invitations", %{
      conn: conn,
      book: book,
      book_member_user: book_member_user
    } do
      # XXX In the end, `invite_user` will only send an invite
      # `another_user` won't be necessary anymore
      another_user = user_fixture()

      conn = log_user_in(conn, book_member_user)

      conn =
        post(conn, "/", %{
          "query" => @invite_user_mutation,
          "variables" => %{"book_id" => book.id, "email" => another_user.email}
        })

      assert json_response(conn, 200) == %{
               "data" => %{"inviteUser" => nil},
               "errors" => [
                 %{
                   "locations" => [%{"column" => 3, "line" => 2}],
                   "message" => "Unauthorized",
                   "path" => ["inviteUser"]
                 }
               ]
             }
    end

    # XXX In the end, `invite_user` will only send an invite
    # These are tests to write once the mutation actually sends invitations

    # test "sends an email with invitation link"
    # test "allows to invite non registered users"

    test_logged_in(@invite_user_mutation, %{"book_id" => "0", "email" => "anacounts@example.com"})
  end
end
