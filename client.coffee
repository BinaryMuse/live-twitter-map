$ ->
  # Create our Google Map object
  start_location = new google.maps.LatLng(40, -95)
  map_options =
    zoom: 5
    center: start_location
    mapTypeId: google.maps.MapTypeId.HYBRID
  window.Map = new google.maps.Map(document.getElementById('map_canvas'), map_options)

  # Update the counter in the lower-right
  update_counter = (count) ->
    $("#counter").html("#{count}")

  # Remove a marker from the map
  remove_marker = (marker) ->
    marker.setMap null

  # Add a marker to the map
  add_marker = (lat, lng, user, image, tweet, timeout = null) ->
    goog_image = new google.maps.MarkerImage(image, new google.maps.Size(48, 48))
    marker = new google.maps.Marker
      position: new google.maps.LatLng(lat, lng)
      map: window.Map
      title: user
      icon: goog_image
    infowindow = new google.maps.InfoWindow
      content: "<div class='info'>" +
        "<img src='#{image}' align='left'>" +
        "<a href='http://twitter.com/#{user}' target='_blank'>@#{user}</a>: #{tweet}" + 
        "</div>"
    google.maps.event.addListener marker, 'click', ->
      infowindow.open marker.map, marker
    if timeout?
      setTimeout (-> remove_marker(marker)), timeout

  # Initialize the counter to zero
  counter = 0

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
      counter++
    update_counter(counter)
