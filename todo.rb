require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_remaining_count(list)
    list[:todos].select{|todo| !todo[:completed]}.count
    # list[:todos].count{|todo| !todo[:completed]}
  end

  def todos_count(list)
    list[:todos].size
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list)}

    incomplete_lists.each { |list| yield list, lists.index(list)}
    complete_lists.each { |list| yield list, lists.index(list)}
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed]}

    incomplete_todos.each { |todo| yield todo, todos.index(todo)}
    complete_todos.each { |todo| yield todo, todos.index(todo)}
  end
end
before do
  session[:lists] ||= []
end


get "/" do
  redirect "/lists"
end

#view list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# render new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

#view single list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]

  redirect "/lists" if !@list

  erb :list, layout: :layout
end

# Return an error message if name is invalid, otherwise return nil.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters"
  elsif session[:lists].any? {|list| list[:name] == name }
    "List name must be unique"
  end
end

def error_for_todo (name)
  if !(1..100).cover? name.size
    "Todo must be between 1 and 100 characters"
  end
end

#update an existing todo list
post "/lists/:id" do
  list_name = params[:list_name].strip
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]

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

#delete an existing todo list
post "/lists/:id/destroy" do
  session[:lists].delete_at(params[:id].to_i)
  session[:success] = "The list has been deleted."

  redirect "/lists"
end
# create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << {name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end

end

#Edit an existing list
get "/lists/:id/edit" do
  @list = session[:lists][params[:id].to_i]

  erb :edit_list, loayout: :layout
end

# Add a new todo to a list
post "/lists/:list_id/todos" do
  todo = params[:todo].strip
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  error = error_for_todo(todo)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: todo, completed: false} #if params[:todo]
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

#delete an existing todo list
post "/lists/:list_id/todos/:id/destroy" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  todo_id = params[:id].to_i
  @list[:todos].delete_at(todo_id)
  session[:success] = "The todo has been deleted."

  # erb :list, layout: :layout
  redirect "/lists/#{params[:list_id].to_i}"
end

#update the status of a todo
post "/lists/:list_id/todos/:id/edit" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  todo_id = params[:id].to_i
  is_completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = is_completed
  session[:success] = "The todo has been updated."

  redirect "/lists/#{params[:list_id].to_i}"
end

post "/lists/:id/todos/complete_all" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  @todos = @list[:todos]
  if @todos.any?{ |todo| todo[:completed] == false }
    @todos.each { |todo| todo[:completed] = true }
  else
    @todos.each { |todo| todo[:completed] = false }
  end
  session[:success] = "All todos have been updated."
  
  redirect "/lists/#{params[:id].to_i}"
end
