fs      = require 'fs'
sys     = require 'sys'
path    = require 'path'
http    = require 'http'
express = require 'express'
io      = require 'socket.io'
twitter = require 'ntwitter'

exports.LiveTwitterMap = class LiveTwitterMap
  constructor: (port) ->
    @create_web_server port

    # Number of connected clients
    @clients = 0
    # Number of tweets processed
    @count   = 0
    # Time in seconds since the server started
    @time    = 0
    # Backlog of tweets to send to the clients
    @backlog = []

  create_web_server: (port) =>
    pubDir = path.resolve __dirname + '/public'
    # Set up the Express web server
    app = express()
    app.configure ->
      app.use express.static pubDir
    # The client web page
    app.get '/', (req, res) ->
      res.sendfile path.join pubDir, "client.htm"
    server = http.createServer(app).listen port

    # Attach Socket.IO to the web server
    @socket = io.listen server
    @socket.set 'log level', 1
    @socket.on 'connection', (socket) =>
      console.log "New connection"
      @clients++
      @checkStream()

      socket.on 'disconnect', =>
        @clients--
        @checkStream()

  checkStream: =>
    if @clients > 0 && !@stream?
      @startStream()
    else if @clients <= 0 && @stream
      @stopStream()

  startStream: =>
    # Create the Twitter streaming connection
    console.log "Starting stream"
    @api = new twitter
      consumer_key: process.env.TWITTER_KEY
      consumer_secret: process.env.TWITTER_SECRET
      access_token_key: process.env.TWITTER_TOKEN
      access_token_secret: process.env.TWITTER_TOKEN_SECRET
    @api.verifyCredentials (err, data) ->
      throw err if err?
      console.log "Authenticated with Twitter"
    @api.stream 'statuses/filter', locations: [-127, 25, -58, 49], (stream) =>
      @stream = stream
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
          @checkStream()
        else
          setTimeout (=> @checkStream()), 5 * 60 * 1000

  stopStream: =>
    if @stream?
      console.log "Stopping stream"
      @stream.destroy()
      @stream = null

  run: =>
    # Start the timer
    setInterval (=> @time++), 1000
    # Potentially start reading from the Streaming API
    @checkStream()
    # Send new tweets to the client every 1/4 second
    setInterval @broadcast_tweets, 250

  # Send the tweet backlog to the clients and reset the backlog
  broadcast_tweets: =>
    return unless @clients > 0
    backlog = unescape(encodeURIComponent(JSON.stringify(@backlog)))
    @socket.sockets.emit 'tweets', backlog
    @backlog = []

  # Format the time in a M:SS format
  format_time: (seconds) ->
    minutes = Math.floor seconds / 60
    seconds = seconds - (minutes * 60)
    seconds = "0#{seconds}" if seconds < 10
    "#{minutes}:#{seconds}"
