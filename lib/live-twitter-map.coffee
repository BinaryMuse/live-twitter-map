fs      = require 'fs'
sys     = require 'sys'
path    = require 'path'
express = require 'express'
io      = require 'socket.io'
twitter = require 'twitter-node'

exports.LiveTwitterMap = class LiveTwitterMap
  constructor: (user, pass, port) ->
    @create_web_server port
    @create_twitter_streamer user, pass

    # Number of tweets processed
    @count   = 0
    # Time in seconds since the server started
    @time    = 0
    # Backlog of tweets to send to the clients
    @backlog = []

  create_web_server: (port) =>
    public = path.join path.dirname(fs.realpathSync(__filename)), './public'
    # Set up the Express web server
    app = express.createServer()
    app.configure ->
      app.use express.static public
    # The client web page
    app.get '/', (req, res) ->
      res.sendfile path.join public, "client.htm"
    app.listen port

    # Attach Socket.IO to the web server
    @socket = io.listen app

  create_twitter_streamer: (user, pass) =>
    # Create the Twitter streaming connection
    @twit = new twitter.TwitterNode
      user:     user
      password: pass
      # Search for Geo-tagged tweets in the US
      locations: [-127, 25, -58, 49]

    # Listen to our Twitter stream for tweets
    # Process them only if tweet.coordinates exists
    @twit.addListener 'tweet', (tweet) =>
      if tweet.coordinates?
        @backlog.push
          lat:   tweet.coordinates.coordinates[1]
          lon:   tweet.coordinates.coordinates[0]
          text:  tweet.text
          user:  tweet.user.screen_name
          image: tweet.user.profile_image_url
        sys.puts "#{++@count} #{@format_time @time} -- @#{tweet.user.screen_name}: #{tweet.text}"
    @twit.addListener 'limit', (limit) ->
      sys.puts "LIMIT: #{sys.inspect limit}"
    @twit.addListener 'delete', (del) ->
      sys.puts "DELETE: #{sys.inspect del}"
    @twit.addListener 'end', (resp) =>
      sys.puts "END: #{resp.statusCode}"
      if resp.statusCode == 200
        @twit.stream()
      else
        setTimeout (=> @twit.stream()), 5 * 60 * 1000

  run: =>
    # Start the timer
    setInterval (=> @time++), 1000
    # Start reading from the Streaming API
    @twit.stream()
    # Send new tweets to the client every 1/4 second
    setInterval @broadcast_tweets, 250

  # Send the tweet backlog to the clients and reset the backlog
  broadcast_tweets: =>
    @socket.broadcast tweets: @backlog
    @backlog = []

  # Format the time in a M:SS format
  format_time: (seconds) ->
    minutes = Math.floor seconds / 60
    seconds = seconds - (minutes * 60)
    seconds = "0#{seconds}" if seconds < 10
    "#{minutes}:#{seconds}"
