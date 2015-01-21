lunr = require "lunr"
shortid = require "shortid"

class Memory
  STORAGE_KEY: "twitch.memory"

  constructor: (@robot) ->
    @index = lunr ->
      @ref 'id'
      @field 'body'

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
    if result.length isnt 0 and data[result[0].ref]
      data[result[0].ref]
    else
      @robot.logger.info "Memory.ask: failed to find answer in result #{JSON.stringify result}"
      @robot.logger.debug "result=#{JSON.stringify result} data=#{JSON.stringify data}"
      null

  createItem: (thing) ->
    item =
      id: shortid.generate()
      body: thing
    item

  load: ->
    @robot.brain[@STORAGE_KEY] || {}

  save: (data) ->
    @robot.brain[@STORAGE_KEY] = data

module.exports = Memory
