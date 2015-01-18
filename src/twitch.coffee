# Hubot dependencies
{Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, Response} = require "hubot"

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
      channels: process.env.HUBOT_TWITCH_CHANNELS?.split(",") || []
      server: process.env.HUBOT_TWITCH_SERVER || "irc.twitch.tv"
      port: process.env.HUBOT_TWITCH_PORT || 6667
      realName: process.env.HUBOT_TWITCH_REALNAME || "Hubot Twitch"
      debug: process.env.HUBOT_TWITCH_DEBUG || false

  send: (envelope, strings...) ->
    target = @getTargetFromEnvelope envelope
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
    # note: these are not yet used as authentication is not implemented yet
    clientId = process.env.HUBOT_TWITCH_CLIENT_ID?
    clientSecret = process.env.HUBOT_TWITCH_CLIENT_SECRET?
    client = new TwitchClient clientId, clientSecret
    # todo: do some initialization logic here
    @twitchClient = client

  join: (channel) ->
    @ircClient.join channel =>
      @logger.info "joined #{channel}"
      user = @robot.brain.userForName @robot.name
      @receive new EnterMessage user

  part: (channel) ->
    @ircClient.part channel =>
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

  getTargetFromEnvelope: (envelope) ->
    {user, room} = envelope
    # reply to user in room
    if user?.room then user.room
    # reply directly
    else if user?.name then user.name
    # message to channel
    else if room then room

  createUser: (channel, nick) ->
    @logger.info "Twitch.createUser: #{nick} for #{channel}"
    user = @robot.brain.userForId nick
    user.name = nick
    user.room = channel
    user

exports.use = (robot) ->
  new Twitch robot
