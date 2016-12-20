require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "pry"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def count_completed_todos(todos)
    todos.select do |todo|
      todo[:completed]
    end.count
  end

  def count_remaining_todos(todos)
    todos.size - count_completed_todos(todos)
  end

  def all_todos_complete?(todos)
    if !todos.empty?
      return count_completed_todos(todos) == todos.size
    end
    false
  end

  def list_class(list)
    "complete" if all_todos_complete?(list)
  end

  def add_orig_index(list)
    orig_index_addon = {}
    orig_idx = 0
    list.each do |key, _|
      orig_index_addon[key] = orig_idx
      orig_idx += 1
    end
    orig_index_addon
  end

  def sort_lists(lists)
    add_orig_index(lists).sort_by do |arr_item|
      item = arr_item.first
      all_todos_complete?(item[:todos]) ? 1 : 0
    end
  end

  def sort_todos(todos)
    add_orig_index(todos).sort_by do |arr_item|
      item = arr_item.first
      item[:completed] ? 1 : 0
    end
  end
end

before do
  session[:lists] ||= []
end

# Return error msg if name invalid. Return nil if name valid.
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "List name must be between 1 and 100 characters"
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique"
  end
end

# Return error msg if name invalid.  Return nil if name valid
def error_for_todo(name)
  if !(1..100).cover?(name.size)
    "Todo must be between 1 and 100 characters"
  end
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Show single list and its todos
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]

  erb :list, layout: :layout
end

# Render the edit list form
get "/lists/:id/edit" do
  list_id = params[:id].to_i
  @list = session[:lists][list_id]

  erb :edit_list, layout: :layout
end

# Update/edit list information
post "/lists/:id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a list
post "/lists/:id/delete" do
  @list_id = params[:id].to_i
  session[:lists].delete_at(@list_id)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Add new todo to list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_name = params[:todo].strip

  error = error_for_todo(todo_name)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: todo_name, completed: false }
    session[:success] = "The todo has been added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from list
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  @list = session[:lists][@list_id]

  @list[:todos].delete_at(todo_id)
  session[:success] = "The todo has been deleted."
  redirect "/lists/#{@list_id}"
end

# Update completion status of todo
post "/lists/:list_id/todos/:todo_id/check" do
  @list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  @list = session[:lists][@list_id]

  is_completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = is_completed

  redirect "/lists/#{@list_id}"
end

# Update all todos as complete
post "/lists/:list_id/todos/complete_all" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All the todos have been completed."
  redirect "/lists/#{@list_id}"
end
