reds = require "reds"
shortid = require "shortid"

class Memory
  STORAGE_KEY: "twitch.memory"

  constructor: (@robot) ->
    @search = reds.createSearch "things";
    @recall()

  recall: ->
    data = @load()
    num = 0
    for id, thing of data
      @index thing, id
      num++
    @robot.logger.info "Memory.recall: #{num} things recalled"

  index: (thing, id) ->
    @search.index thing, id

  tell: (thing) ->
    data = @load()
    id = @generateId()
    data[id] = thing
    @index thing, id
    unless @save data
      @robot.logger.error "ERROR: Failed to learn a new thing."
    @robot.logger.info "Memory.tell: learned that '#{thing}'"

  ask: (query, cb) ->
    data = @load()
    @robot.logger.info "Memory.ask: searching for '#{query}'"
    @search.query(query).end (error, ids) =>
      throw new Error error if error
      answer = null
      if ids.length isnt 0
        key = ids[0]
        answer = data[key]
        @robot.logger.info "Memory.ask: answer to '#{query}' is '#{answer}' (#{key})"
      else
        @robot.logger.info "Memory.ask: failed to find answer in result #{result}"
        @robot.logger.debug "ids=#{ids} data=#{data}"
      cb answer

  generateId: ->
    shortid.generate()

  load: ->
    @robot.brain[@STORAGE_KEY] || {}

  save: (data) ->
    @robot.brain[@STORAGE_KEY] = data

module.exports = Memory
