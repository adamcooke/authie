# Authie

[![CI](https://github.com/adamcooke/authie/actions/workflows/ci.yml/badge.svg)](https://github.com/adamcooke/authie/actions/workflows/ci.yml) [![Gem Version](https://badge.fury.io/rb/authie.svg)](https://badge.fury.io/rb/authie) [![Coverage](https://img.shields.io/codeclimate/coverage/adamcooke/authie.svg?logo=code%20climate)](https://codeclimate.com/github/adamcooke/authie)

This is a Rails library which provides applications with a database-backed user
sessions. This ensures that user sessions can be invalidated from the server and
users activity can be easily tracked.

The "traditional" way of simply setting a user ID in your session is insecure
and unwise. If you simply do something like the example below, it means that anyone
with access to the session cookie can login as the user whenever and wherever they wish.

To clarify: while by default Rails session cookies are encrypted, there is
nothing to allow them to be invalidated if someone were to "steal" an encrypted
cookie from an authenticated user. This could be stolen using a MITM attack or
simply by stealing it directly from their browser when they're off getting a coffee.

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
gem 'authie', '~> 3.1'
```

You will then need add the database tables Authie needs to your database. You
should copy Authie's migrations and then migrate.

```
rake authie:install:migrations
rake db:migrate
```

## Usage

Authie is just a session manager and doesn't provide any functionality for your authentication or User models. Your `User` model should implement any methods needed to authenticate a username & password.

### Creating a new session

When a user has been authenticated, you can simply set `current_user` to the user
you wish to login. You may have a method like this in a controller.

```ruby
class AuthenticationController < ApplicationController

  skip_before_action :login_required

  def login
    if request.post?
      if user = User.authenticate(params[:username], params[:password])
        create_auth_session(user)
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

  before_action :login_required

  private

  def login_required
    return if logged_in?

    redirect_to login_path, :alert => "You must login to view this resource"
  end

end
```

### Accessing the current user (and session)

There are a few controller methods which you can call which will return information about the current session:

* `current_user` - returns the currently logged in user
* `auth_session` - returns the current auth session
* `logged_in?` - returns a true if there's a session or false if no user is logged in

### Catching session errors

If there is an issue with an auth session, an error will be raised which you need
to catch within your application. The errors which will be raised are:

* `Authie::Session::InactiveSession` - is raised when a session has been de-activated.
* `Authie::Session::ExpiredSession` - is raised when a session expires.
* `Authie::Session::BrowserMismatch` - is raised when the browser ID provided does
  not match the browser ID associated with the session token provided.
* `Authie::Session::HostMismatch` - is raised when the session is used on a hostname
  that does not match that which created the session

The easiest way to rescue these to use a `rescue_from`. For example:

```ruby
class ApplicationController < ActionController::Base

  rescue_from Authie::Session::ValidityError, :with => :auth_session_error

  private

  def auth_session_error
    redirect_to login_path, :alert => "Your session is no longer valid. Please login again to continue..."
  end

end
```

### Logging out

In order to invalidate a session you can simply invalidate it.

```ruby
def logout
  auth_session.invalidate
  redirect_to login_path, :notice => "Logged out successfully."
end
```

### Default session length

By default, a session will last for however long it is being actively used in
browser. If the user stops using your application, the session will last for
12 hours before becoming invalid. You can change this:

```ruby
Authie.config.session_inactivity_timeout = 2.hours
```

This does not apply if the session is marked as persistent. See below.

### Persisting sessions

In some cases, you may wish users to have a permanent sessions. In this case,
you should ask users after they have logged in if they wish to "persist" their
session across browser restarts. If they do wish to do this, just do something
like this:

```ruby
def persist_session
  auth_session.persist
  redirect_to root_path, :notice => "You will now be remembered!"
end
```

By default, persistent sessions will last for 2 months before requring the user
logs in again. You can increase (or decrease) this if needed:

```ruby
Authie.config.persistent_session_length = 12.months
```

### Accessing all user sessions

If you want to provide users with a list of their sessions, you can access all
active sessions for a user. The best way to do this will be to add a `has_many`
association to your User model.

```ruby
class User < ActiveRecord::Base
  has_many :sessions, :class_name => 'Authie::SessionModel', :as => :user, :dependent => :destroy
end
```

### Storing additional data in the user session

If you need to store additional information in your database-backed database
session, then you can use the following methods to achieve this:

```ruby
auth_session.set :two_factor_seen_at, Time.now
auth_session.get :two_factor_seen_at
```

### Invalidating all but current session

You may wish to allow users to easily invalidate all sessions which aren't their
current one. Some applications invalidate old sessions whenever a user changes
their password. The `invalidate_others!` method can be called on any
`Authie::Session` object and will invalidate all sessions which aren't itself.

```ruby
def change_password
  if @user.change_password(params[:new_password])
    auth_session.invalidate_others!
  end
end
```

### Sudo functions

In some applications, you may want to require that the user has recently provided
their password to you before executing certain sensitive actions. Authie provides
some methods which can help you keep track of when a user last provided their
password in a session and whether you need to prompt them before continuing.

```ruby
# When the user logs into your application, run the see_password method to note
# that we have just seen their password.
def login
  if user = User.authenticate(params[:username], params[:password])
    create_auth_session(user)
    auth_session.see_password
    redirect_to root_path
  end
end

# Before executing any dangerous actions, check to see whether the password has
# recently been seen.
def change_password
  if auth_session.recently_seen_password?
    # Allow the user to change their password as normal.
  else
    # Redirect the user a page which allows them to re-enter their password.
    # The method here should verify the password is correct and call the
    # see_password method as above. Once verified, you can return them back to
    # this page.
    redirect_to reauth_path(:return_to => request.fullpath)
  end
end
```

By default, a password will be said to have been recently seen if it has been
seen in the last 10 minutes. You can change this configuration if needed:

```ruby
Authie.config.sudo_timeout = 30.minutes
```

### Working with two factor authentication

Authie provides a couple of methods to help you determine when two factor
authentication is required for a request. Whenever a user logs in and has
enabled two factor authentication, you can mark sessions as being permitted.

You can add the following to your application controller and ensure that it runs
on every request to your application.

```ruby
class ApplicationController < ActionController::Base

  before_action :check_two_factor_auth

  def check_two_factor_auth
    if logged_in? && current_user.has_two_factor_auth? && !auth_session.two_factored?
      # If the user has two factor auth enabled, and we haven't already checked it
      # in this auth session, redirect the user to an action which prompts the user
      # to do their two factor auth check.
      flash[:two_factor_return_path] = request.fullpath
      redirect_to two_factor_auth_path
    end
  end

end
```

Then, on your two factor auth action, you need to ensure that you mark the auth
session as being verified with two factor auth.

```ruby
class LoginController < ApplicationController

  skip_before_action :check_two_factor_auth

  def two_factor_auth
    if user.verify_two_factor_token(params[:token])
      auth_session.mark_as_two_factored
      redirect_to flash[:two_factor_return_path] || root_path, :notice => "Logged in successfully!"
    end
  end

end
```

## Instrumentation/Notification

Authie will publish events to the ActiveSupport::Notification instrumentation system. The following events are published
with the given attributes.

* `set_browser_id.authie` - when a new browser ID is set for a user. Provides `:browser_id` and `:controller` arguments.
* `cleanup.authie` - when session cleanup is run. Provides no arguments.
* `touch.authie` - when a session is touched. Provides `:session` argument.
* `see_password.authie` - when a session sees a password. Provides `:session` argument.
* `mark_as_two_factor.authie` - when a session has two factor credentials provided. Provides `:session` argument.
* `session_start.authie` - when a session is started. Provides `:session` argument.
* `browser_id_mismatch_error.authie` - when a session is validated when the browser ID does not match. Provides `:session` argument.
* `invalid_session_error.authie` - when a session is validated when invalid. Provides `:session` argument.
* `expired_session_error.authie` - when a session is validated when expired. Provides `:session` argument.
* `inactive_session_error.authie` - when a session is validated when inactive. Provides `:session` argument.
* `host_mismatch_error.authie` - when a session is validated and the host does not match. Provides `:session` argument.

## Differences for Authie 4.0

Authie 4.0 introduces a number of changes to the library which are worth noting when upgrading from any version less than 4.

* Authie 4.0 removes the impersonation features which may make a re-appearance in a futre version.
* All previous callback/events have been replaced with standard ActiveSupport instrumentation notifications.
* Various methods on Authie::Session (more commonly known as `auth_session`) have been renamed as follows.
  * `check_security!` is now `validate`
  * `persist!` is now `persist`
  * `invalidate!` is now `invalidate`
  * `touch!` is now `touch`
  * `set_cookie!` is now `set_cookie` and is now a private method and should not be called directly.
  * `see_password!` is now `see_password`
  * `mark_as_two_factored!` is now `mark_as_two_factored`
* A new `Authie::Session#reset_token` has been added which will generate a new token for a session, save it and update the cookie.
* When starting a session using `Authie::Session.start` or `create_auth_session` you can provide the following additional options:
  * `persistent: true` to mark the session as persistent (i.e. give it an expiry time)
  * `see_password: true` to set the password seen timestamp at the same time as creation
* If the `extend_session_expiry_on_touch` config option is set to true (default is false), the expiry time for a persistent session will be extended whenver a session is touched.
* When making a request, the session will be touched **after** the action rather than before. Previously, the `touch_auth_session` method was added before every action and it both validated the session and touched it. Now, there are two separate methods - `validate_auth_session` which is run before every action and `touch_auth_session` runs after every action. If you don't want to touch a session in a request you can either use `skip_around_action :touch_auth-session`  or call `skip_touch_auth_session!` anywhere in the action.
* A new config option called `session_token_length` is available which allows you to change the length of the random token used for sessions (default 64).
