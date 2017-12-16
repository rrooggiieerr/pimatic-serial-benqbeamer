module.exports = {
  title: "pimatic-serial-benqbeamer device config schemas"
  SerialBenQBeamerController: {
    title: "BenQ Beamer Controler config options"
    type: "object"
    extensions: ["xLink", "xAttributeOptions"]
    properties:
      serialPort:
        description: "Serialport name (e.g. /dev/ttyUSB0)"
        type: "string"
        default: "/dev/ttyUSB0"
      baudRate:
        description: "Baudrate to use for communicating over serialport (e.g. 9600)"
        type: "integer"
        default: 115200
  }
}
