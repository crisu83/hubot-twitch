request = require "request"

class TwitchClient
  API_URL: "https://api.twitch.tv/kraken"

  constructor: (@clientId, @clientSecret) ->

  api: (options, cb) ->
    options.url = @API_URL + options.url
    options.json = true
    request options, (error, response, body) ->
      cb error, response, body

  auth: () ->
    # todo: implement

  follows: (channel, cb) ->
    options =
      method: "get"
      url: "/channels/#{channel}/follows"
    @api options, cb

module.exports = TwitchClient
