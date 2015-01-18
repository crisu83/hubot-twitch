class Config
  STORAGE_KEY: "twitch.config"

  VALID_KEYS: ["show_greet", "show_follows"]

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

  exists: (key) ->
    @VALID_KEYS.indexOf key isnt -1

  load: () ->
    @robot.brain[@STORAGE_KEY] || {}

  save: (data) ->
    @robot.brain[@STORAGE_KEY] = data

module.exports = Config
