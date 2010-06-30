# Require core modules.
fs:          require 'fs'
sys:         require 'sys'
url:         require 'url'
http:        require 'http'
{Buffer}:    require 'buffer'
querystring: require 'querystring'

### The Pixel Ping server

# The in-memory hit store.
store: {}

# Record an incoming hit from a remote pixel.
record: (params) ->
  return unless key: params.query?.key
  store[key]: or 0
  store[key]: +  1

# Serialize the current store, and start a fresh one.
serialize: ->
  data:  {json: JSON.stringify(store)}
  store: {}
  data.secret: config.secret if config.secret
  querystring.stringify data

# Flush the store to be saved by an external API.
flush: ->
  log store
  return unless config.endpoint
  data: serialize()
  endHeaders['Content-Length']: data.length
  request: endpoint.request 'POST', endParams.pathname, endHeaders
  request.write data
  request.end()
  sys.puts '--- flushed ---'

# Log the contents of the hits to stdout.
log: (hash) ->
  for key, hits of hash
    sys.puts "$key:\t$hits"

# Create the web server.
server: http.createServer (req, res) ->
  params: url.parse req.url, true
  if params.pathname is '/pixel.gif'
    res.writeHead 200, pixelHeaders
    res.end pixel
  else
    res.writeHead 404, emptyHeaders
    res.end ''
  record params

### Configuration

# Load the configuration, tracking pixel, and remote endpoint.
configPath:   process.argv[2] or (__dirname + '/../config.json')
config:       JSON.parse fs.readFileSync(configPath).toString()
pixel:        new Buffer(43);
pixelHeaders: {'Content-Type': 'image/gif', 'Content-Disposition': 'inline', 'Content-Length': '43'}
emptyHeaders: {'Content-Type': 'text/html', 'Content-Length': '0'}
pixel.write fs.readFileSync(__dirname + '/pixel.gif', 'binary'), 'binary', 0
if config.endpoint
  sys.puts    "Flushing hits to $config.endpoint"
  endParams:  url.parse config.endpoint
  endpoint:   http.createClient endParams.port || 80, endParams.host
  endHeaders: {host : endParams.host, 'Content-Type': 'application/x-www-form-urlencoded'}

# Don't let exceptions kill the server.
process.addListener 'uncaughtException', (err) ->
  sys.puts "Uncaught Exception: ${err}"

### Startup

# Start the server listening, and the periodic flush.
server.listen config.port, config.host
setInterval flush, config.interval * 1000