defmodule IdeaStartButton.Accounts.UserInterest do
  use Ecto.Schema
  import Ecto.Changeset

  alias IdeaStartButton.Accounts.User
  alias IdeaStartButton.Ideas.Topic

  schema "users_interests" do
    belongs_to :user, User
    belongs_to :topic, Topic

    timestamps()
  end

  @doc false
  def changeset(topic, attrs) do
    topic
    |> cast(attrs, [:user_id, :topic_id])
    |> validate_required([:user_id, :topic_id])
    |> unsafe_validate_unique([:user_id, :topic_id], IdeaStartButton.Repo)
    |> unique_constraint([:user_id, :topic_id])
  end
end
