express = require 'express'
request = require 'request'

port = 3003

app = express()
app.use express.logger 'dev'

app.set 'views', 'views'
app.set 'view engine', 'toffee'

app.use express.favicon()
app.use express.cookieParser 'this should be a hard to guess super sekret password ermagherd'
app.use express.session()
app.use express.bodyParser()

# Middleware to make sure a user is logged in before allowing them to access the page.
# You could improve this by setting a redirect URL to the login page, and then redirecting back
# after they've authenticated.
restrict = (req, res, next) ->
  return next() if req.session.user
  res.redirect '/login.html'

app.post '/auth', (req, res, next) ->
  return next(new Error 'No assertion in body') unless req.body.assertion

  # Persona has given us an assertion, which needs to be verified. The easiest way to verify it
  # is to get mozilla's public verification service to do it.
  #
  # The audience field is hardcoded, and does not use the HTTP headers or anything. See:
  # https://developer.mozilla.org/en-US/docs/Persona/Security_Considerations
  request.post 'https://verifier.login.persona.org/verify'
    form:
      audience:"localhost:#{port}"
      assertion:req.body.assertion
    (err, _, body) ->
      return next(err) if err

      try
        data = JSON.parse body
      catch e
        return next(e)

      return next(new Error data.reason) unless data.status is 'okay'

      # Login worked. Session is regenerated to avoid fixation attacks.
      req.session.regenerate ->
        req.session.user = data.email
        res.redirect '/'

# / is restricted. If you use the restrict middleware, req.session.user will contain the
# user's email address.
app.get '/', restrict, (req, res) ->
  res.render 'index', email:req.session.user

# We need to do 2 things during logout:
# - Delete the user's logged in status from their session object (ie, record they've been
#   logged out on the server)
# - Tell persona they've been logged out in the browser.
app.get '/logout', (req, res, next) ->
  delete req.session.user
  res.redirect '/login.html'

app.use express.static "#{__dirname}/public"

app.listen port
console.log "Listening on http://localhost:#{port}/"
