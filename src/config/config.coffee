#Load dependencies
express = require "express"
csrf = express.csrf()
assets = require "connect-assets"
jsPaths = require "connect-assets-jspaths"
flash = require "connect-flash"
RedisStore = require("connect-redis")(express)
blade = require "blade"
i18n = require "i18next"
logger = require "../utils/logger"

logCategory = "CONFIGURE"
maxAges = 86400000 * 30

boundServices = if process.env.VCAP_SERVICES then JSON.parse(process.env.VCAP_SERVICES) else null

if boundServices
  cfRedis = boundServices["redis-2.2"][0]
  REDIS_DB_HOSTNAME = cfRedis.credentials.hostname
  REDIS_DB_HOST = cfRedis.credentials.host
  REDIS_DB_PORT = cfRedis.credentials.port
  REDIS_DB_NAME =  cfRedis.credentials.name
  REDIS_DB_PASS = cfRedis.credentials.password
else
  REDIS_DB_HOSTNAME = "localhost"
  REDIS_DB_HOST = "127.0.0.1"
  REDIS_DB_PORT = "6379"
  REDIS_DB_NAME = "zmgc-redis"
  REDIS_DB_PASS = null

# Redis session stores
options =
  hosts: [new RedisStore(
    hostname: REDIS_DB_HOSTNAME
    host: REDIS_DB_HOST
    port: REDIS_DB_PORT
    maxAge: 86400000 * 30 # 30 days
  ), new RedisStore(
    hostname: REDIS_DB_HOSTNAME
    host: REDIS_DB_HOST
    port: REDIS_DB_PORT
    maxAge: 86400000 * 30 # 30 days
  )]
  session_secret: "f2e5a67d388ff2090dj7Q2nC53pF"
  cookie:
    maxAge: 86400000 * 1 # 30 days 

module.exports = (app) ->
  multipleRedisSessions = require("connect-multi-redis")(app, express.session)
  logger.info "Configure expressjs", logCategory
  # FIXME use _.each to loop for each dirs and Gzip
  dirs = ["/assets", "/public", "/nowjs", "/locales", "/data/topo"]
  app.configure ->
      app.use assets(build : true)
      jsPaths assets, console.log
      @use(express.favicon(process.cwd() + "/assets/images/favicon.ico", {maxAge:maxAges}))
      .use(express.compress())
      .use(express.static(process.cwd() + "/assets", {maxAge:maxAges}))
      .use(express.static(process.cwd() + "/public", {maxAge:maxAges}))
      .use(express.static(process.cwd() + "/nowjs", {maxAge:maxAges}))
      .use(express.static(process.cwd() + "/locales", {maxAge:maxAges}))
      .use(express.static(process.cwd() + "/data/topo", {maxAge:maxAges}))
      .use(express.logger('dev'))
      .use(express.errorHandler(
            dumpException: true
            showStack: true
      ))

  #  Add template engine
  app.configure ->
    @set("views", process.cwd() + "/views")
    .set("view engine", "blade")
    #.use(stylus.middleware(
    #  src: process.cwd() + "/assets"
    #  compile: compile
    #))

  # FIXME - see if we can do this differently
  app.configure ->
    try
      app.set("chapters", require(process.cwd() + "/data/chapters.json"))
      app.set "languages", require(process.cwd() + "/locales/config.json")
      app.set "translation", require(process.cwd() + "/locales/dev/translation.json")
    catch e
      logger.warn "files not found " + e, logCategory
      app.set("chapters", [])
      app.set "languages", []
      app.set "translation", []
      next()
      return

  # Set sessions and middleware
  app.configure ->
    @use(express.bodyParser())
    .use(express.methodOverride())
    .use(express.cookieParser('90dj7Q2nC53pFj2b0fa81a3f663fd64'))
    .use(multipleRedisSessions(options))
    .use(express.session(
      store: options.hosts[0]
      secret: 'f2e5a67d388ff2090dj7Q2nC53pF'
      cookie:
        maxAge: 86400000 * 30     # 90 days
    ))
    .use (req, res, next) ->
      # Only use CSRF if user is logged in
      if req.session.userId
        csrf req, res, next
      else
        next()
    .use(flash())
    .use(i18n.handle)
    .use(blade.middleware(process.cwd() + "/views"))

  # Save reference to database connection
  #app.configure ->
  #  app.set("db", )
  app
