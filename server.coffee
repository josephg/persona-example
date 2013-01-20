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

# Restrict access to logged in users
restrict = (req, res, next) ->
  return next() if req.session.user
  res.redirect '/login.html'

app.get '/', restrict, (req, res) ->
  res.render 'index', email:req.session.user
  #  res.end "oh hi #{req.session.user}"

app.post '/auth', (req, res, next) ->
  return next(new Error 'No assertion in body') unless req.body.assertion

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

      # Login worked.
      req.session.regenerate ->
        req.session.user = data.email
        res.redirect '/'

app.get '/logout', (req, res, next) ->
  delete req.session.user
  res.redirect '/login.html'

app.use express.static "#{__dirname}/public"

app.listen port
console.log "http://localhost:#{port}/"
