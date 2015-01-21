class Config
  STORAGE_KEY: "twitch.config"

  constructor: (@robot) ->

  get: (key) ->
    data = @load()
    value = data[key]
    @robot.logger.info "Config.get: #{@STORAGE_KEY}.#{key} (#{value})"
    value

  set: (key, value) ->
    data = @load()
    old = data[key]
    data[key] = value
    unless @save data
      @robot.logger.error "ERROR: Failed to save config."
    @robot.logger.info "Config.set: #{@STORAGE_KEY}.#{key} = #{value} (#{old})"

  remove: (key) ->
    data = @load()
    value = data[key]
    delete data[key]
    @robot.logger.info "Config.remove: #{@STORAGE_KEY}.#{key} (#{value})"

  load: ->
    @robot.brain[@STORAGE_KEY] || {}

  save: (data) ->
    @robot.brain[@STORAGE_KEY] = data

module.exports = Config
