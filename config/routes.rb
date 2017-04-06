RedmineApp::Application.routes.draw do
  if Rails::VERSION::MAJOR >= 4
    get 'bbb', :controller => :bbb, :action => :start
  else
    match 'bbb', :controller => :bbb, :action => :start
  end

  get 'bbb/:action', :controller => :bbb
end
