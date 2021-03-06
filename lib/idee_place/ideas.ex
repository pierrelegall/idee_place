defmodule IdeePlace.Ideas do
  @moduledoc """
  The Ideas context.
  """

  import Ecto.Query, warn: false
  alias IdeePlace.Repo

  alias IdeePlace.Accounts.User
  alias IdeePlace.Ideas.Idea
  alias IdeePlace.Ideas.Topic
  alias IdeePlace.Ideas.UserStarredIdea
  alias IdeePlace.Ideas.UserStarredTopic

  @doc """
  Returns the list of ideas.

  ## Examples

      iex> list_ideas()
      [%Idea{}, ...]

  """
  def list_ideas(opts \\ []) do
    default_opts = [
      preload: [],
      filters: [authors: [], topics: [], user_stars: [], keywords: []],
      page_number: nil,
      page_size: 10
    ]

    opts = Keyword.merge(default_opts, opts)

    query =
      Idea
      |> join(:left, [idea], author in assoc(idea, :author))
      |> join(:left, [idea, _author], topics in assoc(idea, :topics))
      |> join(:left, [idea, _author, _topic], starrer in assoc(idea, :starred_by))
      |> maybe_filter_ideas_by_authors(opts[:filters][:authors])
      |> maybe_filter_ideas_by_topics(opts[:filters][:topics])
      |> maybe_filter_ideas_by_starrer(opts[:filters][:user_stars])
      |> maybe_filter_ideas_by_keywords(opts[:filters][:keywords])
      |> distinct([idea], idea.id)
      |> preload(^opts[:preload])

    if opts[:page_number] do
      query
      |> Repo.paginate(page: opts[:page_number], page_size: opts[:page_size])
    else
      query
      |> Repo.all()
    end
  end

  defp maybe_filter_ideas_by_authors(query, []), do: query

  defp maybe_filter_ideas_by_authors(query, authors) do
    query
    |> where([_idea, author, _topic, _starrer], author.name in ^authors)
  end

  defp maybe_filter_ideas_by_topics(query, []), do: query

  defp maybe_filter_ideas_by_topics(query, topics_name) do
    topics_id =
      Topic
      |> where([topic], topic.name in ^topics_name)
      |> select([topic], topic.id)
      |> Repo.all()

    topics_count = Enum.count(topics_id)

    query
    |> where([_idea, _author, topic, _starrer], topic.id in ^topics_id)
    |> group_by([idea, _author, _topic, _starrer], idea.id)
    |> having([idea, _author, _topic, _starrer], count(idea.id) == ^topics_count)
  end

  defp maybe_filter_ideas_by_starrer(query, []), do: query

  defp maybe_filter_ideas_by_starrer(query, users_name) do
    users_id =
      User
      |> where([user], user.name in ^users_name)
      |> select([user], user.id)
      |> Repo.all()

    query
    |> where([_idea, _author, _topic, starrer], starrer.id in ^users_id)
  end

  defp maybe_filter_ideas_by_keywords(query, []), do: query

  defp maybe_filter_ideas_by_keywords(query, keywords) do
    keywords_string = keywords |> Enum.join("%") |> surround("%")

    query
    |> where(
      [idea, author],
      ilike(idea.title, ^keywords_string) or ilike(idea.description, ^keywords_string)
    )
  end

  defp surround(string, string_to_surround) do
    string_to_surround <> string <> string_to_surround
  end

  @doc """
  Star an idea if for a user.
  """
  def star_idea_for(idea, user)

  def star_idea_for(idea, %User{} = user) do
    star_idea_for(idea, user.id)
  end

  def star_idea_for(%Idea{} = idea, user) do
    star_idea_for(idea.id, user)
  end

  def star_idea_for(idea_id, user_id) do
    user_starred_idea = %UserStarredIdea{
      user_id: user_id,
      idea_id: idea_id
    }

    Repo.insert(user_starred_idea)
  end

  @doc """
  Unstar an idea if for a user.
  """
  def unstar_idea_for(idea, user)

  def unstar_idea_for(idea, %User{} = user) do
    unstar_idea_for(idea, user.id)
  end

  def unstar_idea_for(%Idea{} = idea, user) do
    unstar_idea_for(idea.id, user)
  end

  def unstar_idea_for(idea_id, user_id) do
    user_starred_idea = get_user_starred_idea!(user_id, idea_id)

    Repo.delete(user_starred_idea)
  end

  @doc """
  Get starred ideas ID for a user.
  """
  def idea_is_starred_by(idea, user)

  def idea_is_starred_by(_idea, nil) do
    false
  end

  def idea_is_starred_by(idea, %User{} = user) do
    idea_is_starred_by(idea, user.id)
  end

  def idea_is_starred_by(%Idea{} = idea, user) do
    idea_is_starred_by(idea.id, user)
  end

  def idea_is_starred_by(idea_id, user_id) do
    UserStarredIdea
    |> where([user_starred_idea], user_starred_idea.user_id == ^user_id)
    |> where([user_starred_idea], user_starred_idea.idea_id == ^idea_id)
    |> Repo.exists?()
  end

  @doc """
  Get starred ideas ID for a user.
  """
  def list_starred_ideas_id_for(user)

  def list_starred_ideas_id_for(nil), do: nil

  def list_starred_ideas_id_for(%User{} = user) do
    list_starred_ideas_id_for(user.id)
  end

  def list_starred_ideas_id_for(user_id) do
    Idea
    |> join(:left, [idea], user_starred_idea in assoc(idea, :starred_by))
    |> where([_idea, user], user.id == ^user_id)
    |> select([idea], idea.id)
    |> Repo.all()
  end

  @doc """
  Gets a single idea.

  Raises `Ecto.NoResultsError` if the Idea does not exist.

  ## Examples

      iex> get_idea!(123)
      %Idea{}

      iex> get_idea!(456)
      ** (Ecto.NoResultsError)

  """
  def get_idea!(id, opts \\ []) do
    default_opts = [
      preload: []
    ]
    opts = Keyword.merge(default_opts, opts)

    Repo.one!(
      from idea in Idea,
      where: idea.id == ^id,
      preload: ^opts[:preload]
    )
  end

  @doc """
  Creates a idea.

  ## Examples

      iex> create_idea(%{field: value})
      {:ok, %Idea{}}

      iex> create_idea(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_idea(attrs \\ %{}) do
    %Idea{}
    |> Idea.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a idea.

  ## Examples

      iex> update_idea(idea, %{field: new_value})
      {:ok, %Idea{}}

      iex> update_idea(idea, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_idea(%Idea{} = idea, attrs) do
    idea
    |> Idea.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a idea.

  ## Examples

      iex> delete_idea(idea)
      {:ok, %Idea{}}

      iex> delete_idea(idea)
      {:error, %Ecto.Changeset{}}

  """
  def delete_idea(%Idea{} = idea) do
    Repo.delete(idea)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking idea changes.

  ## Examples

      iex> change_idea(idea)
      %Ecto.Changeset{data: %Idea{}}

  """
  def change_idea(%Idea{} = idea, attrs \\ %{}) do
    Idea.changeset(idea, attrs)
  end

  @doc """
  Returns the list of topics.

  ## Examples

      iex> list_topics()
      [%Topic{}, ...]

  """
  def list_topics(opts \\ []) do
    default_opts = [
      preload: [],
      filters: [keywords: ""],
      page_number: nil,
      page_size: 10
    ]

    opts = Keyword.merge(default_opts, opts)

    query =
      Topic
      |> maybe_filter_topics_by_keywords(opts[:filters][:keywords])
      |> preload(^opts[:preload])

    if opts[:page_number] do
      query
      |> Repo.paginate(page: opts[:page_number], page_size: opts[:page_size])
    else
      query
      |> Repo.all()
    end
  end

  defp maybe_filter_topics_by_keywords(query, ""), do: query

  defp maybe_filter_topics_by_keywords(query, keywords) do
    keywords_string =
      keywords
      |> String.split(" ")
      |> Enum.join("%")
      |> surround("%")

    query
    |> where(
      [topic],
      ilike(topic.name, ^keywords_string)
    )
  end

  @doc """
  Get starred topics ID for a user.
  """
  def list_starred_topics_id_for(user)

  def list_starred_topics_id_for(nil), do: nil

  def list_starred_topics_id_for(%User{} = user) do
    list_starred_topics_id_for(user.id)
  end

  def list_starred_topics_id_for(user_id) do
    Topic
    |> join(:left, [topic], user_starred_topic in assoc(topic, :starred_by))
    |> where([_topic, user], user.id == ^user_id)
    |> select([topic], topic.id)
    |> Repo.all()
  end

  @doc """
  Gets a single topic.

  Raises `Ecto.NoResultsError` if the Topic does not exist.

  ## Examples

      iex> get_topic!(123)
      %Idea{}

      iex> get_topic!(456)
      ** (Ecto.NoResultsError)

  """
  def get_topic!(id, opts \\ []) do
    default_opts = [preload: []]
    opts = Keyword.merge(default_opts, opts)

    Repo.one!(
      from topic in Topic,
        where: topic.id == ^id,
        preload: ^opts[:preload]
    )
  end

  @doc """
  Gets a single topic by name.

  Raises `Ecto.NoResultsError` if the Topic does not exist.

  ## Examples

      iex> get_topic_by_name!("elixir")
      %Idea{}

      iex> get_topic_by_name!("java")
      ** (Ecto.NoResultsError)

  """
  def get_topic_by_name!(name, opts \\ []) do
    default_opts = [preload: []]
    opts = Keyword.merge(default_opts, opts)

    Repo.one!(
      from topic in Topic,
        where: topic.name == ^name,
        preload: ^opts[:preload]
    )
  end

  @doc """
  Gets a single topic by name.

  ## Examples

      iex> get_topic_by_name("elixir")
      {:ok, %Idea{}}

      iex> get_topic_by_name("java")
      {:error, Ecto.NoResultsError}

  """
  def get_topic_by_name(name, opts \\ []) do
    try do
      {:ok, get_topic_by_name!(name, opts)}
    rescue
      Ecto.NoResultsError -> {:error, Ecto.NoResultsError}
      _ -> raise "Not handled error"
    end
  end

  @doc """
  Return true if the topic name exists, else false.

  ## Examples

      iex> topic_name_exists?("elixir")
      true

      iex> topic_name_exists?("java")
      false

  """
  def topic_name_exists?(name) do
    case get_topic_by_name!(name) do
      {:ok, _idea} -> true
      _ -> false
    end
  end

  @doc """
  Creates a topic.

  ## Examples

      iex> create_topic(%{field: value})
      {:ok, %Topic{}}

      iex> create_topic(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_topic(attrs \\ %{}) do
    %Topic{}
    |> Topic.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates or get an existing topic by name.

  ## Examples

      iex> create_or_get_topic("elixir")
      %Topic{name: "elixir"}

  """
  def create_or_get_topic(topic_name) do
    case get_topic_by_name(topic_name) do
      {:ok, topic} -> topic
      _ -> %Topic{name: topic_name}
    end
  end

  @doc """
  Updates a topic.

  ## Examples

      iex> update_topic(idea, %{field: new_value})
      {:ok, %Topic{}}

      iex> update_topic(idea, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_topic(%Topic{} = topic, attrs) do
    topic
    |> Topic.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a topic.

  ## Examples

      iex> delete_topic(topic)
      {:ok, %Topic{}}

      iex> delete_topic(topic)
      {:error, %Ecto.Changeset{}}

  """
  def delete_topic(%Topic{} = topic) do
    Repo.delete(topic)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking topic changes.

  ## Examples

      iex> change_topic(topic)
      %Ecto.Changeset{data: %Topic{}}

  """
  def change_topic(%Topic{} = topic, attrs \\ %{}) do
    Topic.changeset(topic, attrs)
  end

  @doc """
  Returns the list of user starred topics.

  ## Examples

      iex> list_user_starred_topics(2)
      [%UserStarredTopic{}, ...]

  """
  def list_user_starred_topics(user_id) do
    Repo.all(
      from user_starred_topic in UserStarredTopic,
        where: user_starred_topic.user_id == ^user_id,
        preload: [:topic]
    )
  end

  @doc """
  Gets a single user starred idea.

  Raises `Ecto.NoResultsError` if the UserStarredIdea does not exist.

  ## Examples

      iex> get_user_starred_idea!(123, 456)
      %UserStarredIdea{}

      iex> get_user_starred_id!(456, 789)
      ** (Ecto.NoResultsError)

  """
  def get_user_starred_idea!(user_id, idea_id, opts \\ []) do
    default_opts = [preload: []]
    opts = Keyword.merge(default_opts, opts)

    Repo.one!(
      from user_starred_idea in UserStarredIdea,
        where: user_starred_idea.user_id == ^user_id and user_starred_idea.idea_id == ^idea_id,
        preload: ^opts[:preload]
    )
  end
end
