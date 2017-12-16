module.exports = (env) ->
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  t = env.require('decl-api').types

  class SerialBenQBeamerPlugin extends env.plugins.Plugin
    init: (app, @framework, @config) =>
      deviceConfigDef = require('./device-config-schema')
      @framework.deviceManager.registerDeviceClass('SerialBenQBeamerController', {
        configDef: deviceConfigDef.SerialBenQBeamerController,
        createCallback: (config, lastState) =>
          device = new SerialBenQBeamerController(config, lastState)
          return device
      })

  class SerialBenQBeamerController extends env.devices.SerialSwitch
    attributes:
     state:
        description: "The current state of the switch"
        type: t.boolean
        labels: ['on', 'off']

    actions:
      sendCommand:
        description: 'The command to send to the serial device'
        params:
          command:
            type: t.string
      turnOn:
        description: "Turns the beamer on"
      turnOff:
        description: "Turns the beamer off"
      getState:
        description: "Returns the current state of the switch"
        returns:
          state:
            type: t.boolean

    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name

      config = {}
      config.dataBits = 8
      config.parity = 'none'
      config.stopBits = 1
      config.flowControl = false
      config.replaceHex = false
      config.autoOpen = false
      config.onCommand = 'pow=on'
      #config.onCommand = 'pow=?'
      config.offCommand = 'pow=off'
      config.parserDelimiter = '\r'

      super(config, lastState)

      # Supported commands per moddel except the modelname command
      @_supportedCommands = {
        'all': [ 'pow', 'sour', 'mute', 'vol', 'micvol', 'audiosour', 'appmod', 'con', 'bri', 'color', 'sharp', 'ct', 'asp', 'bc', 'qas', 'pp', 'directpower', 'autopower', 'standbynet', 'standbymic', 'standbymnt', 'baud', 'ltim', 'ltim2', 'lampm', 'blank', 'freeze', '3d', 'rr', 'ins', 'lpsaver', 'prjlogincode', 'broadcasting', 'amxdd', 'macaddr', 'highaltitude' ]
        'W1110': [ 'pow', 'sour', 'mute', 'vol', 'appmod', 'con', 'bri', 'color', 'sharp', 'ct', 'asp', 'bc', 'qas', 'pp', 'baud', 'ltim', 'lampm', 'blank', '3d', 'highaltitude' ]
      }

      @_commandQueue = []

    _onOpen: () ->
      @sendCommand 'modelname=?'

    _responseHandler: (data) ->
      data = data.trim()
      if data[0] == '*'
        # Remove * and #
        data = data.substring(1, data.length - 1)
        switch data
          when 'Block item'
            env.logger.error 'Command %s not executed', @_lastCommand
          when 'Unsupported item'
            env.logger.error 'Command %s not supported', @_lastCommand
          else
            split = data.split '='
            if split.length == 2
              key = split[0]
              value = split[1]
              switch key
                when 'POW'
                  env.logger.debug 'Power: %s', value
                  if value == 'ON'
                    @_setState on
                  else if value == 'OFF'
                    @_setState off
                when 'SOUR'
                  env.logger.debug 'Source: %s', value
                  @_source = value
                when 'MUTE'
                  env.logger.debug 'Mute: %s', value
                  @_mute = value
                when 'VOL'
                  env.logger.debug 'Volume: %s', value
                  @_volume = value
                when 'APPMOD'
                  env.logger.debug 'Mode: %s', value
                when 'CON'
                  env.logger.debug 'Contrast: %s', value
                when 'BRI'
                  env.logger.debug 'Brightness: %s', value
                when 'COLOR'
                  env.logger.debug 'Color: %s', value
                when 'SHARP'
                  env.logger.debug 'Sharpness: %s', value
                when 'CT'
                  env.logger.debug 'Color temperature: %s', value
                when 'ASP'
                  env.logger.debug 'Aspect ratio: %s', value
                when 'BC'
                  env.logger.debug 'Brilliant color: %s', value
                when 'QAS'
                  env.logger.debug 'Quick auto search: %s', value
                when 'PP'
                  env.logger.debug 'Projector Position: %s', value
                when 'DIRECTPOWER'
                  env.logger.debug 'Direct power: %s', value
                when 'BAUD'
                  env.logger.debug 'Baud rate: %s', value
                when 'LTIM'
                  env.logger.debug 'Lamp time: %s', value
                when 'LAMPM'
                  env.logger.debug 'Lamp mode: %s', value
                when 'MODELNAME'
                  env.logger.debug 'Model name: %s', value
                  @_model = value
                  # Ok, now we know the model name and we can assign the supported commands
                  commands = @_supportedCommands[@_model]
                  env.logger.debug commands
                  for key in commands
                    @sendCommand key + '=?'
                when 'BLANK'
                  env.logger.debug 'Blank: %s', value
                when '3D'
                  env.logger.debug '3D sync: %s', value
                when 'HIGHALTITUDE'
                  env.logger.debug 'High Altitude mode: %s', value
                else
                  env.logger.error 'Unknown key: %s=%s', key, value
            else
              env.logger.error 'Unknown response: %s', data
        # Send the next command from the queue, if any
        @waitingForResponse = false
        @sendCommand()
      else if data[0] != '>'
        env.logger.error 'Unknown response: %s', data

    sendCommand: (command) ->
      # If command is empty send a command from the queue
      if !command
        if @_commandQueue.length > 0 && !@waitingForResponse
          @waitingForResponse = true
          env.logger.debug 'Sending command from the queue: %s', @_commandQueue[0]
          super('\r*' + @_commandQueue[0] + '#\r')
          @_commandQueue.shift()
        else if @_commandQueue.length == 0
          env.logger.debug 'No commands left in the queue'
        else if @waitingForResponse
          env.logger.debug 'Waiting for response of previous command'
      # If there are still commands in the queue, add the command to the end of the queue
      else
        #ToDo Check if the command is valid for this model
        if @_commandQueue.length > 0 || @waitingForResponse
          env.logger.debug 'Adding command to the queue: %s', command
          @_commandQueue.push command
        # Else send the command directly to the device
        else
          @waitingForResponse = true
          env.logger.debug 'Sending command: %s', command
          @_lastCommand = command
          super('\r*' + command + '#\r')

    # Returns a promise that is fulfilled when done.
    changeStateTo: (state) ->
      switch state
        when on
          @sendCommand @onCommand
        when off
          @sendCommand @offCommand

    destroy: () ->
      super()

  return new SerialBenQBeamerPlugin
