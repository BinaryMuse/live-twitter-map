This is a small project I put together to experiment with the Twitter Streaming API. It pulls in all the Tweets in (approximately) the continental United States and displays them in real time on a map.

Demo
====

I've taken down the live demo due to bandwidth limitations. Please see the instructions below to get this running on your own computer!

Getting it to Work for You
==========================

You can run this on your own if you have Node.js installed.

1. Clone the repository
2. Install the dependencies:

        npm install

3. Run the server using your Twitter credentials:

        TWITTER_USER=YourUsername TWITTER_PASS=your_password ./bin/twimap.js

By default the server binds to port 8080, so you can check it out at [http://localhost:8080](http://localhost:8080).
