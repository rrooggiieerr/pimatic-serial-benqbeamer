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
    _volume = null
    _mute = false

    attributes:
      state:
        description: "The current state of the beamer"
        type: t.boolean
        labels: ['on', 'off']
      volume:
        description: "the volume of the beamer"
        type: t.string
      source:
        description: "the input source of the beamer"
        type: t.string

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
      changeStateTo:
        description: "Changes the beamer to on or off"
        params:
          state:
            type: t.boolean
      getState:
        description: "Returns the current state of the beamer"
        returns:
          state:
            type: t.boolean
      volume:
        description: "Change volume of player"


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

      #clearInterval @_checkPowerStateInterval
      # Check power state of beamer every 30 seconds
      @_checkPowerStateInterval = setInterval =>
        @sendCommand 'pow=?'
      , 30000

    _responseHandler: (data) ->
      data = data.replace(/[^a-zA-Z0-9*#=> ]+/g, '');
      if data == ''
        # Empty
        env.logger.debug 'Response is empty'
        # Send the next command from the queue, if any
        #@waitingForResponse = false
        #@sendCommand()
      else if data[0] == '>'
        # Prompt
        env.logger.debug 'Response is prompt'
        # Send the next command from the queue, if any
        #@waitingForResponse = false
        #@sendCommand()
      else if data[0] == '*'
        # Remove * and #
        data = data.substring(1, data.length - 1)
        switch data
          when 'Illegal format'
            env.logger.error 'Command format %s not vallid', @_lastCommand
          when 'Unsupported item'
            env.logger.error 'Command %s not supported', @_lastCommand
          when 'Block item'
            env.logger.error 'Command %s not executed', @_lastCommand
          else
            data = data.toUpperCase()
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
                  @emit 'source', @_source
                when 'MUTE'
                  env.logger.debug 'Mute: %s', value
                  @_mute = value
                when 'VOL'
                  env.logger.debug 'Volume: %s', value
                  @_volume = parseInt value
                  @emit 'volume', @_volume
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
                  if @_supportedCommands[@_model]
                    commands = @_supportedCommands[@_model]
                  else
                    commands = @_supportedCommands['all']
                  env.logger.debug commands
                  # Request the status for each command
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
      else
        env.logger.error 'Unknown response: %s', data
        env.logger.debug 'data[0] = "%s"', data.charCodeAt(0)

    sendCommand: (command) ->
      # If command is empty send a command from the queue
      if !command
        if @_commandQueue.length > 0 && !@waitingForResponse
          @waitingForResponse = true

          @_clearCommandTimeout()
          env.logger.debug 'Setting command timeout to 10 seconds'
          @_commandTimeout = setTimeout @_resetCommandTimeout, 10000

          env.logger.debug 'Sending command from the queue: %s', @_commandQueue[0]
          @_lastCommand = @_commandQueue[0]
          super('\r*' + @_lastCommand + '#\r')
          @_commandQueue.shift()
        else if @_commandQueue.length == 0
          env.logger.debug 'No commands left in the queue'
          @_clearCommandTimeout()
        else if @waitingForResponse
          env.logger.debug 'Waiting for response of previous command'
      # If there are still commands in the queue, add the command to the end of the queue
      else
        command = command.toLowerCase()
        #ToDo Check if the command is valid for this model
        env.logger.debug 'Command queue length: %s', @_commandQueue.length
        if @_commandQueue.length > 0
          env.logger.debug 'Commands still waiting in the queue'
          env.logger.debug 'Adding command to the queue: %s', command
          @_commandQueue.push command
        else if @waitingForResponse
          env.logger.debug 'Waiting for response of previous command'
          env.logger.debug 'Adding command to the queue: %s', command
          @_commandQueue.push command
        # Else send the command directly to the device
        else
          @waitingForResponse = true

          @_clearCommandTimeout()
          env.logger.debug 'Setting command timeout to 10 seconds'
          @_commandTimeout = setTimeout @_resetCommandTimeout, 10000

          env.logger.debug 'Sending command: %s', command
          @_lastCommand = command
          super('\r*' + @_lastCommand + '#\r')

    _clearCommandTimeout: () ->
      if @_commandTimeout
        env.logger.debug 'Clearing command timeout'
        clearTimeout @_commandTimeout
        @_commandTimeout = null

    _resetCommandTimeout: () =>
      env.logger.debug 'Resetting command timeout'
      @waitingForResponse = false
      @sendCommand()

    # Returns a promise
    turnOn: -> @changeStateTo on

    # Returns a promise
    turnOff: -> @changeStateTo off

    # Returns a promise that is fulfilled when done.
    changeStateTo: (state) ->
      assert state is on or state is off
      switch state
        when on
          @sendCommand @onCommand
        when off
          @sendCommand @offCommand

    mute: () ->
      @sendCommand 'mute=on'

    unMute: () ->
      @sendCommand 'mute=off'

    setVolume: (volume) ->

    setSource: (source) ->
      source = source.toLowerCase()
      if source in ['rgb', 'rgb2', 'ypbr', 'dvia', 'dvid', 'hdmi', 'hdmi2', 'vid', 'svid', 'network', 'usbdisplay', 'usbreader']
        @sendCommand 'sour=%s', source

    getVolume: ()  -> Promise.resolve(@_volume)
    getSource: ()  -> Promise.resolve(@_source)

    destroy: () ->
      super()

  _ = require 'lodash'
  M = env.matcher

  class ChangeInputActionProvider extends env.actions.ActionProvider
    constructor: (@framework) ->

    parseAction: (input, context) =>
      # Get all devices which have a send method
      sendDevices = _(@framework.deviceManager.devices).values().filter(
        (device) => device.hasAction('sendCommand')
      ).value()

      device = null
      command = null
      match = null

      # Match action
      # send "<command>" to <device>
      m = M(input, context)
        .match('send ')
        .match('command ', optional: yes)
        .matchStringWithVars((m, _command) ->
          m.match(' to ')
            .matchDevice(sendDevices, (m, _device) ->
              device = _device
              command = _command
              match =  m.getFullMatch()
            )
        )

      # Does the action match with our syntax?
      if match?
        assert device?
        assert command?
        assert typeof match is 'string'
        return {
          token: match
          nextInput: input.substring match.length
          actionHandler: new SendCommandActionHandler @framework, device, command
        }
      return null

  return new SerialBenQBeamerPlugin
