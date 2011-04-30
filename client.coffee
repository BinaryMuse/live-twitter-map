$ ->
  # Initialize the counter to zero
  window.counter             = 0
  # Reference to the currently-auto-opened info window, if any
  window.current_info_window = null
  # Percent chance that a tweet will auto-open if none are showing
  window.auto_show_chance    = 10

  # Create our Google Map object
  start_location = new google.maps.LatLng(40, -95)
  map_options =
    zoom: 5
    center: start_location
    mapTypeId: google.maps.MapTypeId.HYBRID
  window.Map = new google.maps.Map(document.getElementById('map_canvas'), map_options)

  # Roll a random percent chance
  random_percent = ->
    Math.floor Math.random() * 101

  # Update the counter in the lower-right
  update_counter = (count) ->
    $("#counter").html("#{count}")

  disconnected = ->
    $("#title").html("DISCONNECTED<br />Please refresh the page.")
    $("#title").css("color", "#ff0000")

  # Remove a marker from the map
  remove_marker = (marker) ->
    if marker.auto_info?
      window.current_info_window = null
    marker.setMap null

  # Add a marker to the map
  add_marker = (lat, lng, user, image, tweet, timeout = null) ->
    goog_image = new google.maps.MarkerImage(image, new google.maps.Size(48, 48))
    shadow_image = new google.maps.MarkerImage(
      '/map_shadow.png', null,
      null, new google.maps.Point(18, 26))
    marker = new google.maps.Marker
      position: new google.maps.LatLng(lat, lng)
      map: window.Map
      title: user
      icon: goog_image
      shadow: shadow_image
    infowindow = new google.maps.InfoWindow
      content: "<div class='info'>" +
        "<img src='#{image}' align='left'>" +
        "<a href='http://twitter.com/#{user}' target='_blank'>@#{user}</a>: #{tweet}" +
        "</div>"
      disableAutoPan: true
      maxWidth: 350
    google.maps.event.addListener marker, 'click', ->
      infowindow.open marker.map, marker
      if marker.timeout?
        clearTimeout marker.timeout
        marker.timeout = setTimeout (-> remove_marker(marker)), timeout
    if window.current_info_window == null && random_percent() < window.auto_show_chance
      infowindow.open marker.map, marker
      marker.auto_info = true
      window.current_info_window = true
    if timeout?
      marker.timeout = setTimeout (-> remove_marker(marker)), timeout

  # Start our Socket.IO socket
  socket = new io.Socket
  socket.connect()
  socket.on 'message', (data) ->
    # When tweets come in, iterate over them and add a marker to the map for 10 seconds
    for obj in data.tweets
      console.log "Found an object"
      lat   = obj.lat
      lon   = obj.lon
      user  = obj.user
      text  = obj.text
      image = obj.image
      add_marker lat, lon, user, image, text, 10000
      window.counter++
    update_counter(window.counter)
  socket.on 'disconnect', ->
    disconnected()
