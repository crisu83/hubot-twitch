# Hubot dependencies
{Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, Response} = require "hubot"

qs = require "querystring"
express = require "express"
irc = require "irc"
Config = require "./config"
TwitchClient = require "./twitch-client"

class Twitch extends Adapter
  constructor: (robot) ->
    super robot
    @init()
    @logger = robot.logger
    @config = new Config robot

  init: ->
    # todo: check that nick and password has been set
    unless process.env.HUBOT_TWITCH_USERNAME
      throw new Error "HUBOT_TWITCH_USERNAME not set; try export HUBOT_TWITCH_USERNAME=myusername"
    unless process.env.HUBOT_TWITCH_PASSWORD
      throw new Error "HUBOT_TWITCH_PASSWORD not set; try export HUBOT_TWITCH_PASSWORD=mypassword"

    @options =
      nick: process.env.HUBOT_TWITCH_USERNAME
      password: process.env.HUBOT_TWITCH_PASSWORD
      channels: process.env.HUBOT_TWITCH_CHANNELS?.split "," || []
      server: process.env.HUBOT_TWITCH_SERVER || "irc.twitch.tv"
      port: process.env.HUBOT_TWITCH_PORT || 6667
      realName: process.env.HUBOT_TWITCH_REALNAME || "Hubot Twitch"
      twitchClientId: process.env.HUBOT_TWITCH_CLIENT_ID
      twitchRedirectUri: process.env.HUBOT_TWITCH_CLIENT_REDIRECT_URI
      twitchScope: process.env.HUBOT_TWITCH_CLIENT_SCOPE || ""
      debug: process.env.HUBOT_TWITCH_DEBUG || false
      owners: process.env.HUBOT_TWITCH_OWNERS || []

  initApi: ->
    # static pages
    @robot.router.use express.static("#{__dirname}/../public")

    @robot.router.post "/api/twitch/init", (req, res) =>
      unless @options.twitchRedirectUri
        throw new Error "HUBOT_TWITCH_CLIENT_REDIRECT_URI not set; try export=HUBOT_TWITCH_CLIENT_REDIRECT_URI=myredirecturi"
      params =
        response_type: "code"
        client_id: @twitchClientId
        redirect_uri: @twitchRedirectUri
        scope: @twitchScope
      data =
        url: "#{@twitchClient.API_URL}/oauth2/authorize?#{qs.stringify params}"
      res.send data

    # twitch authentication
    @robot.router.get "/api/twitch/auth", (req, res) =>
      code = req.param "code"
      if code
        @logger.info "AUTH: received code #{code}"
        @twitchClient.auth @twitchRedirectUri, code, (error, response, body) =>
          {access_token, scope} = body
          @logger.info "AUTH: received token #{access_token} with scope #{scope}"
          @logger.debug "body=#{JSON.stringify body}"
          @twitchClient.accessToken = access_token
          @emit "authenticated"
        res.send "SUCCESS"
      else
        error = req.param "error"
        res.send "ERROR: #{error}"

  send: (envelope, strings...) ->
    target = envelope.room
    @logger.info "Twitch.send: #{@robot.name} to #{target}: '#{strings.join " "}'"
    @logger.debug "envelope=#{JSON.stringify envelope}"
    for message in strings
      @ircClient.say target, message

  reply: (envelope, strings...) ->
    for message in strings
      @send envelope, "#{envelope.user.name}: #{message}"

  run: ->
    @createIrcClient()
    @createTwitchClient()
    @emit "connected"
    @initApi()

  createIrcClient: ->
    clientOptions =
      userName: @options.nick
      realName: @options.realName
      password: @options.password
      channels: @options.channels
      debug: @options.debug
      port: @options.port

    # see: http://node-irc.readthedocs.org/en/latest/API.html#client
    client = new irc.Client @options.server, @options.nick, clientOptions

    # see: http://node-irc.readthedocs.org/en/latest/API.html#events
    client.addListener "error", @onError
    client.addListener "join", @onJoin
    client.addListener "kick", @onKick
    client.addListener "message", @onMessage
    client.addListener "names", @onNames
    client.addListener "notice", @onNotice
    client.addListener "part", @onPart
    client.addListener "quit", @onQuit

    @ircClient = client

  createTwitchClient: ->
    clientId = process.env.HUBOT_TWITCH_CLIENT_ID
    clientSecret = process.env.HUBOT_TWITCH_CLIENT_SECRET
    client = new TwitchClient clientId, clientSecret, @robot
    @twitchClient = client

  checkAccess: (nick) ->
    access = @options.owners.indexOf(nick) isnt -1
    @logger.info "checking access for #{nick} (#{access})"
    access

  join: (channel) ->
    @ircClient.join channel, =>
      @logger.info "joined #{channel}"
      user = @robot.brain.userForName @robot.name
      @receive new EnterMessage user

  part: (channel) ->
    @ircClient.part channel, =>
      @logger.info "left #{channel}"
      user = @robot.brain.userForName @robot.name
      @receive new LeaveMessage user

  onError: (message) =>
    @logger.error "ERROR: #{message.command}: #{message.args.join(' ')}"

  onJoin: (channel, nick, message) =>
    @logger.info "Twitch.onJoin: #{nick} join #{channel}"
    @logger.debug "message=#{JSON.stringify message}"
    user = @createUser channel, nick
    @receive new EnterMessage user

  onKick: (channel, nick, from, reason, message) =>
    @logger.info "Twitch.onKick: #{from} kicked #{nick} from #{channel}; '#{reason}'"
    @logger.debug "message=#{JSON.stringify message}"

  onMessage: (nick, channel, text, message) =>
    @logger.info "Twitch.onMessage: #{nick} to #{channel}: '#{text}'"
    @logger.debug "message=#{JSON.stringify message}"
    user = @createUser channel, nick
    @receive new TextMessage user, text

  onNames: (channel, nicks) =>
    @logger.info "Twitch.onNames: #{JSON.stringify nicks}"

  onNotice: (nick, channel, text, message) =>
    @logger.info "Twitch.onNotice: #{nick} to #{channel}: '#{text}'"
    @logger.debug "message=#{JSON.stringify message}"

  onPart: (channel, nick, reason, message) =>
    @logger.info "Twitch.onPart: #{nick} left #{channel}"
    @logger.debug "message=#{JSON.stringify message}"
    user = @createUser channel, nick
    @receive new LeaveMessage user

  onQuit: (nick, reason, channels, message) =>
    @logger.info "Twitch.onQuit: #{nick} quit #{channels.join ", "}"
    @logger.debug "message=#{JSON.stringify message}"
    for channel in channels
      user = @createUser '', nick
      msg = new LeaveMessage user
      msg.text = reason
      @receive msg

  createUser: (channel, nick) ->
    @logger.info "Twitch.createUser: #{nick} for #{channel}"
    user = @robot.brain.userForId nick
    user.name = nick
    user.room = channel
    user

exports.use = (robot) ->
  new Twitch robot
