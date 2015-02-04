# Authie

This is a Rails library which provides applications with a database-backed user
sessions. This ensures that user sessions can be invalidated from the server and
users activity can be easily tracked.

The "traditional" way of simply setting a user ID in your session is insecure
and unwise. If you simply do something like the example below, it means that anyone
with access to the session cookie can login as the user whenever and wherever they wish.

```ruby
if user = User.authenticate(params[:username], params[:password])
  # Don't do this...
  session[:user_id] = user.id
  redirect_to root_path, :notice => "Logged in successfully!"
end
```

The design goals behind Authie are:

* Any session can be invalidated instantly from the server without needing to make
  changes to remote cookies.
* We can see who is logged in to our application at any point in time.
* Sessions should automatically expire after a certain period of inactivity.
* Sessions can be either permanent or temporary.

## Installation

As usual, just pop this in your Gemfile:

```ruby
gem 'authie', '~> 1.0.0'
```

You will then need to run your `db:migrate` task to add the Authie sessions table 
to your local database.

```
rake db:migrate
```

## Usage

Authie is just a session manager and doesn't provide any functionality for your authentication or User models. Your `User` model should implement any methods needed to authenticate a username & password.

### Creating a new session

When a user has been authenticated, you can simply set `current_user` to the user
you wish to login. You may have a method like this in a controller.

```ruby
class AuthenticationController < ApplicationController

  skip_before_filter :login_required

  def login
    if request.post?
      if user = User.authenticate(params[:username], params[:password])
        self.current_user = user
        redirect_to root_path
      else
        flash.now[:alert] = "Username/password was invalid"
      end
    end
  end

end
```

### Checking whether user's are logged in

On any subsequent request, you should make sure that your user is logged in.
You may wish to implement a `login_required` controller method which is called 
before every action in your application.

```ruby
class ApplicationController < ActionController::Base
  
  before_filter :login_required
  
  private
  
  def login_required
    unless logged_in?
      redirect_to login_path, :alert => "You must login to view this resource"
    end
  end
  
end
```

### Accessing the current user (and session)

There are a few controller methods which you can call which will return information about the current session:

* `current_user` - returns the currently logged in user
* `auth_session` - returns the current auth session
* `logged_in?` - returns a true if there's a session or false if no user is logged in

### Logging out

In order to invalidate a session you can simply invalidate it.

```ruby
def logout
  auth_session.invalidate!
  redirect_to login_path, :notice => "Logged out successfully."
end
```

### Persisting sessions

In some cases, you may wish users to have a permanent sessions. In this case, you should ask users after they have logged in if they wish to "persist" their session across browser restarts. If they do wish to do this, just do something like this:

```ruby
def persist_session
  auth_session.persist!
  redirect_to root_path, :notice => "You will now be remembered!"
end
```

### Accessing all user sessions

If you want to provide users with a list of their sessions, you can access all active sessions for a user. The best way to do this will be to add a `has_many` association to your User model.

```ruby
class User < ActiveRecord::Base
  has_many :sessions, :class_name => 'Authie::Session', :foreign_key => 'user_id', :dependent => :destroy
end
```

### Storing additional data in the user session

If you need to store additional information in your database-backed database session, then you can use the following methods to achieve this:

```ruby
auth_session.set :two_factor_seen_at, Time.now
auth_session.get :two_factor_seen_at
```
