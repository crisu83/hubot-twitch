{Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, Response} = require "hubot"

irc = require "irc"
TwitchClient = require "./twitch-client"

class Twitch extends Adapter
  constructor: (robot) ->
    super robot
    @configure()
    @logger = robot.logger
    @channels = []

  configure: ->
    unless process.env.HUBOT_TWITCH_USERNAME
      throw new Error "HUBOT_TWITCH_USERNAME not set; try export HUBOT_TWITCH_USERNAME=myusername"
    unless process.env.HUBOT_TWITCH_PASSWORD
      throw new Error "HUBOT_TWITCH_PASSWORD not set; try export HUBOT_TWITCH_PASSWORD=mypassword"

    @options =
      nick: process.env.HUBOT_TWITCH_USERNAME
      password: process.env.HUBOT_TWITCH_PASSWORD
      server: process.env.HUBOT_TWITCH_SERVER || "irc.chat.twitch.tv"
      port: process.env.HUBOT_TWITCH_PORT || 6667
      realName: process.env.HUBOT_TWITCH_REALNAME || "Hubot Twitch"
      twitchClientId: process.env.HUBOT_TWITCH_CLIENT_ID
      twitchClientSecret: process.env.HUBOT_TWITCH_CLIENT_SECRET
      twitchRedirectUri: process.env.HUBOT_TWITCH_REDIRECT_URI
      owners: process.env.HUBOT_TWITCH_OWNERS?.split "," || []
      channels: process.env.HUBOT_TWITCH_CHANNELS?.split "," || []
      debug: process.env.HUBOT_TWITCH_DEBUG || false
      delay: process.env.HUBOT_TWITCH_DELAY || 1100

    @robot.name = @options.nick

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
    @joinChannels()
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

    if parseInt(@options.delay) isnt 0
      clientOptions["floodProtection"] = true
      clientOptions["floodProtectionDelay"] = parseInt(@options.delay)

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

    client.send("raw CAP REQ :twitch.tv/commands")
    client.send("raw CAP REQ :twitch.tv/membership")
#    client.send("raw CAP REQ :twitch.tv/tags")

    @ircClient = client

  createTwitchClient: ->
    clientId = @options.twitchClientId
    clientSecret = @options.twitchClientSecret
    redirectUri = @options.twitchRedirectUri
    client = new TwitchClient clientId, clientSecret, redirectUri, @robot
    @twitchClient = client

  joinChannels: ->
    for channel in @options.channels
      @join channel

  checkAccess: (nick) ->
    access = @options.owners.indexOf(nick) isnt -1
    @logger.info "access check for #{nick} (#{access})"
    access

  join: (channel) ->
    success = false
    unless @active channel
      success = true
      @ircClient.join channel, =>
        @channels.push channel
        @logger.info "joined #{channel}"
    success

  part: (channel) ->
    success = false
    if @active channel
      success = true
      @ircClient.part channel, =>
        @channels.splice @channels.indexOf(channel), 1
        @logger.info "left #{channel}"
    success

  active: (channel) ->
    @channels.indexOf(channel) isnt -1

  onError: (message) =>
    @logger.error "ERROR: #{message.command}: #{message.args.join(' ')}"

  onJoin: (channel, nick, message) =>
    @logger.info "#{nick} joined #{channel}"
    @logger.debug "message=#{JSON.stringify message}"
    user = @createUser channel, nick
    @receive new EnterMessage user

  onKick: (channel, nick, from, reason, message) =>
    @logger.info "#{from} kicked #{nick} from #{channel}; '#{reason}'"
    @logger.debug "message=#{JSON.stringify message}"

  onMessage: (nick, channel, text, message) =>
    @logger.info "#{nick} sent message to #{channel}: '#{text}'"
    @logger.debug "message=#{JSON.stringify message}"
    user = @createUser channel, nick
    @receive new TextMessage user, text

  onNames: (channel, nicks) =>
    @logger.info "names #{JSON.stringify nicks}"

  onNotice: (nick, channel, text, message) =>
    @logger.info "#{nick} sent notice to #{channel}: '#{text}'"
    @logger.debug "message=#{JSON.stringify message}"

  onPart: (channel, nick, reason, message) =>
    @logger.info "#{nick} left #{channel}"
    @logger.debug "message=#{JSON.stringify message}"
    user = @createUser channel, nick
    @receive new LeaveMessage user

  onQuit: (nick, reason, channels, message) =>
    @logger.info "#{nick} quit #{channels.join ", "}; '#{reason}'"
    @logger.debug "message=#{JSON.stringify message}"
    for channel in channels
      user = @createUser '', nick
      msg = new LeaveMessage user
      msg.text = reason
      @receive msg

  createUser: (channel, nick) ->
    @logger.info "user #{nick} created for #{channel}"
    user = @robot.brain.userForId nick
    user.name = nick
    user.room = channel
    user

exports.use = (robot) ->
  new Twitch robot
