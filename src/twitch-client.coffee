request = require "request"
qs = require "querystring"

class TwitchClient
  API_URL: "https://api.twitch.tv/kraken"

  constructor: (@clientId, @clientSecret, @robot) ->
    @accessToken = null

  api: (options, cb) ->
    options.method = options.method || "get"
    options.headers = {}
    options.url = @API_URL + options.url
    options.json = true
    if @accessToken
      options.headers["Authorization"] = "OAuth #{@accessToken}"
    @robot.logger.info "TWITCH: Call API: #{options.method} #{options.url}"
    @robot.logger.debug "options=#{JSON.stringify options}"
    console.log options.headers
    request options, (error, response, body) ->
      if cb
        cb error, response, body

  auth: (redirectUri, code, cb) ->
    params =
      client_id: @clientId
      client_secret: @clientSecret
      grant_type: "authorization_code"
      redirect_uri: redirectUri
      code: code
    options =
      method: "post"
      url: "/oauth2/token"
      body: params
    @api options, cb

  follows: (channel, cb) ->
    options =
      url: "/channels/#{channel}/follows"
    @api options, cb

  subscriptions: (channel, cb) ->
    options =
      url: "/channels/#{channel}/subscriptions"
    @api options, cb

module.exports = TwitchClient
