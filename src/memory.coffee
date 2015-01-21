lunr = require "lunr"
shortid = require "shortid"
_ = require "lodash"

class Memory
  STORAGE_KEY: "twitch.memory"

  constructor: (@robot) ->
    @index = lunr ->
      @ref "id"
      @field "body"
      @field "time"

  tell: (thing) ->
    data = @load()
    item = @createItem thing
    @index.add item
    data[item.id] = item.body
    unless @save data
      @robot.logger.error "ERROR: Failed to learn a new thing."
    @robot.logger.info "Memory.tell: learned that '#{thing}' (#{item.id})"

  ask: (query) ->
    data = @load()
    @robot.logger.info "Memory.ask: searching for '#{query}'"
    result = @index.search query
    if result.length isnt 0
      items = []
      for match in result
        items.push data[match.ref]
      items = _.sortBy items, 'time'
      items[0]
    else
      @robot.logger.info "Memory.ask: failed to find answer in result #{JSON.stringify result}"
      @robot.logger.debug "result=#{JSON.stringify result} data=#{JSON.stringify data}"
      null

  createItem: (thing) ->
    item =
      id: shortid.generate()
      body: thing
      time: +new Date()
    item

  load: ->
    @robot.brain[@STORAGE_KEY] || {}

  save: (data) ->
    @robot.brain[@STORAGE_KEY] = data

module.exports = Memory
