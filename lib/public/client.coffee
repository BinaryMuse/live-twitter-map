$ ->
  # Redefine some google.maps namespaced objects for ease-of-access
  window.MarkerImage = google.maps.MarkerImage
  window.Marker      = google.maps.Marker
  window.Point       = google.maps.Point
  window.LatLng      = google.maps.LatLng
  window.Size        = google.maps.Size
  window.InfoWindow  = google.maps.InfoWindow

  # LiveMap is our "Model"
  class LiveMap
    constructor: (@auto_show_chance, @view) ->
      @counter = 0
      @setup_socket()

    setup_socket: ->
      socket = io.connect()
      socket.on 'tweets', (tweets) =>
        data = JSON.parse(decodeURIComponent(escape(tweets)))
        # Iterate over the array of tweets stored in data.tweets and add them to the map
        for tweet in data
          auto_show = @random_percent() < @auto_show_chance
          lat       = tweet.lat
          lng       = tweet.lon
          user      = tweet.user
          text      = tweet.text
          image     = tweet.image
          @view.add_marker lat, lng, user, image, text, auto_show, 10000
          @counter++
        # Update the view's counter after we've processed *all* the tweets
        @view.update_counter(@counter)
      socket.on 'disconnect', =>
        @view.disconnected()

    random_percent: ->
      # Return a random number between 1 and 100
      Math.floor Math.random() * 100 + 1

  # LiveMapView is our view and handles all the modification of the Google map and HTML
  class LiveMapView
    constructor: (start_location, zoom_level) ->
      options =
        zoom:      zoom_level
        center:    start_location
        mapTypeId: google.maps.MapTypeId.HYBRID
      @map        = new google.maps.Map(document.getElementById('map_canvas'), options)
      @counter    = $ "#counter"
      @title      = $ "#title"
      @infowindow = false # whether or not an InfoWindow is "auto-showing" right now

    update_counter: (count) ->
      @counter.text count

    disconnected: ->
      @title.html "DISCONNECTED<br />Please refresh the page."
      @title.css  "color", "#ff0000"

    marker_for: (lat, lng, user, image) ->
      user_image   = new MarkerImage(image, new Size(48, 48))
      shadow_image = new MarkerImage('/map_shadow.png', null, null, new Point(18, 26))
      marker       = new Marker
        position: new LatLng(lat, lng)
        map:      @map
        title:    user
        icon:     user_image
        shadow:   shadow_image
      marker

    info_window_for: (image, user, tweet) ->
      infowindow = new InfoWindow
        content: "<div class='info'>" +
          "<img src='#{image}' align='left'>" +
          "<a href='http://twitter.com/#{user}' target='_blank'>@#{user}</a>: #{tweet}" +
          "</div>"
        disableAutoPan: true
        maxWidth: 350
      infowindow

    add_marker: (lat, lng, user, image, tweet, autoshow, timeout = null) ->
      marker     = @marker_for lat, lng, user, image
      infowindow = @info_window_for image, user, tweet
      if timeout?
        marker.timeout = setTimeout (=> @remove_marker(marker)), timeout

      # Show the InfoWindow when the marker is clicked
      google.maps.event.addListener marker, 'click', =>
        infowindow.open @map, marker
        if marker.timeout?
          # Reset the timeout for the marker when it's clicked
          clearTimeout marker.timeout
          marker.timeout = setTimeout (=> @remove_marker(marker)), timeout

      # If we've chosen this tweet to auto-show, and one isn't showing, show it
      if autoshow == true && @infowindow == false
        setTimeout (=> infowindow.open @map, marker), 1000 # 1 sec to allow image to load
        marker.auto_infowindow = infowindow
        @infowindow = true

    remove_marker: (marker) ->
      marker.setMap null
      @infowindow = false if marker.auto_infowindow

  # Create a new map with a 10% auto-show chance
  window.view = new LiveMapView new LatLng(20, -20), 3
  window.Map  = new LiveMap 10, view
