pimatic-serial-benqbeamer
=================

Pimatic Plugin that supports sending commands to BenQ Beamers over the serial port.

BenQ beamers and flat pannels with a serial port can support one of three protocols. This plugin supports beamers which are of the P series but probalby also others.

This are the protocol details:
2400 baud 8N1
```
<CR>*<key>=<value>#<CR>
```
Where <CR> is a Cariage Return

Examples:
Power on   : <CR>*pow=on#<CR>
Power off  : <CR>*pow=off#<CR>
Source HDMI: <CR>*sour=hdmi#<CR>

This plugin already handles the Cariage Return, pre and postfix of the commands, so they should not be included when sending a command using a rule.

Commands can be send to the device from Pimatic rules, like:
```
when <something>
then send command "<command>" to <device>
```

Known to work:
W1110

Not tested but use te same protocol according to the documentation:
Others in the P Series

Not supported:
RP552
RP552H
RP840G
RP653
RP703
RP750
RP750K
RP652
RP702
RP790S
RP705H

Please let me know if your beamer is also supported by this plugin so I can improve the overview of supportd devices.

Configuration
-------------

If you don't have the serial plugin add it to the plugin section:

```
    {
      "plugin": "serial",
      active": true
    },
```

Then add the plugin to the plugin section:

```
    {
      "plugin": "serial-benqbeamer"
    },
```

Then add the device entry for your device into the devices section:

```
    {
      "id": "benq-beamer",
      "class": "SerialBenQBeamerControler",
      "name": "BenQ Beamer",
      "serialport": "/dev/ttyUSB0"
    }
```

Then you can add the items into the mobile frontend
# pimatic-serial-benqbeamer
