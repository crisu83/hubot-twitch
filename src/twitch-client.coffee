request = require "request"
qs = require "querystring"

class TwitchClient
  API_URL: "https://api.twitch.tv/kraken"

  constructor: (@clientId, @clientSecret, @redirectUri, @robot) ->

  getAuthUrl: ->
    params =
      response_type: "code"
      client_id: @clientId
      redirect_uri: @redirectUri
    "#{@API_URL}/oauth2/authorize?#{qs.stringify params}"

  auth: (code, cb) ->
    params =
      client_id: @clientId
      client_secret: @clientSecret
      grant_type: "authorization_code"
      redirect_uri: @redirectUri
      code: code
    options =
      method: "post"
      url: "/oauth2/token"
      body: params
    @api options, null, cb

  me: (token, cb) ->
    options =
      url: "/user"
    @api options, token, cb

  follows: (channel, cb) ->
    options =
      url: "/channels/#{channel}/follows"
    @api options, null, cb

  subscriptions: (channel, token, cb) ->
    options =
      url: "/channels/#{channel}/subscriptions"
    @api options, token, cb

  api: (options, token, cb) ->
    options.method = options.method or "get"
    options.headers = options.headers or {}
    options.url = @API_URL + (options.url or '')
    options.json = true
    if token
      options.headers["Authorization"] = "OAuth #{token}"
    @robot.logger.info "TWITCH: Call API: #{options.method} #{options.url}"
    @robot.logger.debug "options=#{JSON.stringify options}"
    request options, (error, response, body) ->
      cb?(error, response, body)

module.exports = TwitchClient
