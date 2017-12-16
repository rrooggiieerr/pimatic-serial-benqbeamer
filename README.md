pimatic-serial-benqbeamer
=================

Pimatic Plugin that supports sending commands to BenQ Beamers over the serial port.

Configuration
-------------

Add the plugin to the plugin section:

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
