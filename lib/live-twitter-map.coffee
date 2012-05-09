fs      = require 'fs'
sys     = require 'sys'
path    = require 'path'
express = require 'express'
io      = require 'socket.io'
twitter = require 'ntwitter'

exports.LiveTwitterMap = class LiveTwitterMap
  constructor: (port) ->
    @create_web_server port

    # Number of tweets processed
    @count   = 0
    # Time in seconds since the server started
    @time    = 0
    # Backlog of tweets to send to the clients
    @backlog = []

  create_web_server: (port) =>
    pubDir = path.join path.dirname(fs.realpathSync(__filename)), './public'
    # Set up the Express web server
    app = express.createServer()
    app.configure ->
      app.use express.static pubDir
    # The client web page
    app.get '/', (req, res) ->
      res.sendfile path.join pubDir, "client.htm"
    app.listen port

    # Attach Socket.IO to the web server
    @socket = io.listen app

  stream: =>
    # Create the Twitter streaming connection
    api = new twitter
      consumer_key: process.env.TWITTER_KEY
      consumer_secret: process.env.TWITTER_SECRET
      access_token_key: process.env.TWITTER_TOKEN
      access_token_secret: process.env.TWITTER_TOKEN_SECRET
    api.verifyCredentials (err, data) ->
      throw err if err?
      console.log "Authenticated with Twitter"
    api.stream 'statuses/filter', locations: [-127, 25, -58, 49], (stream) =>
      stream.on 'error', (err) =>
        throw err
      stream.on 'data', (tweet) =>
        if tweet.coordinates?
          @backlog.push
            lat:   tweet.coordinates.coordinates[1]
            lon:   tweet.coordinates.coordinates[0]
            text:  tweet.text
            user:  tweet.user.screen_name
            image: tweet.user.profile_image_url
          sys.puts "#{++@count} #{@format_time @time} -- @#{tweet.user.screen_name}: #{tweet.text}"
      stream.on 'end', (resp) =>
        sys.puts "END: #{resp.statusCode}"
        if resp.statusCode == 200
          @stream()
        else
          setTimeout (=> @stream()), 5 * 60 * 1000

  run: =>
    # Start the timer
    setInterval (=> @time++), 1000
    # Start reading from the Streaming API
    @stream()
    # Send new tweets to the client every 1/4 second
    setInterval @broadcast_tweets, 250

  # Send the tweet backlog to the clients and reset the backlog
  broadcast_tweets: =>
    backlog = unescape(encodeURIComponent(JSON.stringify(@backlog)))
    @socket.sockets.emit 'tweets', backlog
    @backlog = []

  # Format the time in a M:SS format
  format_time: (seconds) ->
    minutes = Math.floor seconds / 60
    seconds = seconds - (minutes * 60)
    seconds = "0#{seconds}" if seconds < 10
    "#{minutes}:#{seconds}"
