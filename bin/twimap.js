#!/usr/bin/env node

var path   = require('path');
var fs     = require('fs');
var coffee = require('coffee-script');
var lib    = path.join(path.dirname(fs.realpathSync(__filename)), '../lib');
var app    = require(lib + '/live-twitter-map');

var map = new app.LiveTwitterMap(8080);
map.run();
