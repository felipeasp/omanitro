import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.felipeasp.omanitro"
  ipcTarget: "io.github.felipeasp.omanitro.panel"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property string deviceModel: "Acer Nitro 5"
  property string cpuModel: "CPU"
  property string gpuModel: "GPU"
  property int cpuTemp: 0
  property int gpuTemp: 0
  property int sysTemp: 0
  property int cpuRpm: 0
  property int gpuRpm: 0
  property string fanMode: "auto"
  property int targetCpu: 50
  property int targetGpu: 50
  property string currentProfile: "balanced"
  property var profileChoices: ["quiet", "balanced", "balanced-performance", "performance"]
  property bool batteryLimiter: false
  property int batteryThreshold: 100
  property bool batteryCalibrating: false
  property int usbCharging: 0
  property bool lcdOverride: false
  property bool backlightTimeout: false
  property bool bootAnimationSound: false
  property string gpuMode: "hybrid"
  property bool gpuAvailable: false

  property bool customFansExpanded: false

  readonly property string helperPath: ("" + Qt.resolvedUrl("scripts/nitro-helper.sh")).replace(/^file:\/\//, "")

  function updateTelemetry(data) {
    if (!data) return
    if (data.device_model) root.deviceModel = data.device_model
    if (data.cpu_model) root.cpuModel = data.cpu_model
    if (data.gpu_model) root.gpuModel = data.gpu_model

    root.fanMode = data.fan_mode || (data.fan && data.fan.mode) || "auto"
    root.targetCpu = Number(data.target_cpu != null ? data.target_cpu : (data.fan && data.fan.target_cpu)) || 50
    root.targetGpu = Number(data.target_gpu != null ? data.target_gpu : (data.fan && data.fan.target_gpu)) || 50
    root.cpuRpm = Number(data.fan1_rpm != null ? data.fan1_rpm : (data.cpu_rpm != null ? data.cpu_rpm : (data.fan && data.fan.cpu_rpm))) || 0
    root.gpuRpm = Number(data.fan2_rpm != null ? data.fan2_rpm : (data.gpu_rpm != null ? data.gpu_rpm : (data.fan && data.fan.gpu_rpm))) || 0
    root.cpuTemp = Number(data.cpu_temp != null ? data.cpu_temp : (data.fan && data.fan.cpu_temp)) || 0
    root.gpuTemp = Number(data.gpu_temp != null ? data.gpu_temp : (data.fan && data.fan.gpu_temp)) || 0
    root.sysTemp = Number(data.sys_temp != null ? data.sys_temp : (data.fan && data.fan.sys_temp)) || 0

    if (typeof data.profile === "string") {
      root.currentProfile = data.profile
    } else if (data.profile && data.profile.current) {
      root.currentProfile = data.profile.current
    } else if (data.current_profile) {
      root.currentProfile = data.current_profile
    }

    if (data.profile_choices && data.profile_choices.length > 0) {
      root.profileChoices = data.profile_choices
    } else if (data.profile && data.profile.choices && data.profile.choices.length > 0) {
      root.profileChoices = data.profile.choices
    }

    root.batteryLimiter = (data.battery_limiter === true || data.battery_limiter === 1 || (data.battery && data.battery.limiter === true))
    root.batteryThreshold = Number(data.battery_threshold != null ? data.battery_threshold : (data.battery && data.battery.threshold)) || (root.batteryLimiter ? 80 : 100)
    root.batteryCalibrating = (data.battery_calibration === true || data.battery_calibration === 1 || (data.battery && data.battery.calibrating === true))

    root.usbCharging = Number(data.usb_charging != null ? data.usb_charging : 0)
    root.lcdOverride = (data.lcd_override === true || data.lcd_override === 1)
    root.backlightTimeout = (data.backlight_timeout === true || data.backlight_timeout === 1)
    root.bootAnimationSound = (data.boot_animation_sound === true || data.boot_animation_sound === 1)

    root.gpuMode = data.gpu_mode || (data.gpu && data.gpu.mode) || "hybrid"
    root.gpuAvailable = data.gpu_available === true || (data.gpu && data.gpu.available === true)
  }

  function requestRefresh() {
    if (root.hostWidget && root.hostWidget.refresh) {
      root.hostWidget.refresh()
    }
  }

  function runHelper(args) {
    if (actionProc.running || !root.helperPath) return
    actionProc.command = [root.helperPath].concat(args)
    actionProc.running = true
  }

  function setFan(mode) {
    if (mode === "auto") {
      runHelper(["fan", "auto"])
    } else if (mode === "max") {
      runHelper(["fan", "max"])
    } else if (mode === "custom") {
      applyCustomFans()
    }
  }

  function applyCustomFans() {
    var cpu = Math.round(cpuSlider.value)
    var gpu = Math.round(gpuSlider.value)
    runHelper(["fan", "set", String(cpu), String(gpu)])
  }

  function setProfile(profile) {
    runHelper(["profile", profile])
  }

  function setBatteryLimit(enable) {
    runHelper(["battery_limit", enable ? "1" : "0"])
  }

  function setBatteryCalibrate(start) {
    runHelper(["battery_calibrate", start ? "1" : "0"])
  }

  function setUsbCharging(val) {
    runHelper(["usb_charging", String(val)])
  }

  function setLcdOverride(enable) {
    runHelper(["lcd_override", enable ? "1" : "0"])
  }

  function setBacklightTimeout(enable) {
    runHelper(["backlight_timeout", enable ? "1" : "0"])
  }

  function setBootSound(enable) {
    runHelper(["boot_sound", enable ? "1" : "0"])
  }

  function setGpu(mode) {
    runHelper(["gpu", mode])
  }

  Process {
    id: actionProc
    onExited: root.requestRefresh()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight)
    focusTarget: keyCatcher

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // 1. Header Hero
        Item {
          id: heroItem
          width: mainColumn.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroCapsule.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: "󰌢"
            color: root.fanMode === "max" ? (root.bar ? root.bar.urgent : Color.urgent) : (root.bar ? root.bar.foreground : Color.foreground)
            font.family: root.fontFamily
            font.pixelSize: Style.font.displayLarge
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(12)
            anchors.right: heroCapsule.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: "OmaNitro"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              text: root.deviceModel.toUpperCase()
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.1
              elide: Text.ElideRight
            }
          }

          BorderSurface {
            id: heroCapsule
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: capsuleText.implicitWidth + Style.space(14)
            implicitHeight: capsuleText.implicitHeight + Style.space(6)
            color: "transparent"
            borderSpec: Border.controlSpec("normal", root.bar ? root.bar.foreground : Color.foreground, Color.accent)
            radius: Style.cornerRadius

            Text {
              id: capsuleText
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: (root.cpuTemp > 0 ? root.cpuTemp + "°C · " : "") + root.currentProfile.toUpperCase()
              color: root.fanMode === "max" ? (root.bar ? root.bar.urgent : Color.urgent) : (root.bar ? root.bar.foreground : Color.foreground)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
        }

        // 2. Telemetry Circular Gauges (CPU & GPU)
        Row {
          id: gaugesRow
          width: mainColumn.width
          spacing: Style.space(10)

          // Left Gauge - CPU
          BorderSurface {
            id: cpuCard
            width: (gaugesRow.width - gaugesRow.spacing) / 2
            implicitHeight: cpuCol.implicitHeight + Style.space(18)
            color: Qt.rgba(0.10, 0.11, 0.16, 0.7)
            borderSpec: Border.controlSpec("normal", root.bar ? root.bar.foreground : Color.foreground, Color.accent)
            radius: Style.cornerRadius

            Column {
              id: cpuCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.topMargin: Style.space(10)
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText
                width: parent.width - Style.space(14)
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.cpuModel !== "" ? root.cpuModel : "CPU Core"
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              Item {
                width: Style.space(110)
                height: Style.space(110)
                anchors.horizontalCenter: parent.horizontalCenter

                Canvas {
                  id: cpuCanvas
                  anchors.fill: parent
                  antialiasing: true

                  property real value: root.cpuRpm
                  property real maxValue: 6000
                  property color trackColor: "#282c3f"
                  property color progressColor: (root.cpuTemp >= 80 || root.cpuRpm >= 5000) ? (root.bar ? root.bar.urgent : Color.urgent) : Color.accent

                  onValueChanged: requestPaint()
                  onProgressColorChanged: requestPaint()

                  onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var w = width
                    var h = height
                    var cx = w / 2
                    var cy = h / 2
                    var strokeWidth = 7
                    var radius = Math.min(cx, cy) - strokeWidth / 2 - 2

                    var startAngle = 0.75 * Math.PI
                    var endAngle = 2.25 * Math.PI

                    ctx.lineWidth = strokeWidth
                    ctx.lineCap = "round"

                    ctx.beginPath()
                    ctx.strokeStyle = trackColor
                    ctx.arc(cx, cy, radius, startAngle, endAngle, false)
                    ctx.stroke()

                    var pct = Math.max(0, Math.min(1, value / maxValue))
                    if (pct > 0.005) {
                      var currentAngle = startAngle + pct * (endAngle - startAngle)
                      ctx.beginPath()
                      ctx.strokeStyle = progressColor
                      ctx.arc(cx, cy, radius, startAngle, currentAngle, false)
                      ctx.stroke()
                    }
                  }
                }

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(1)

                  Text {
                    textFormat: Text.PlainText
                    text: "󰈐"
                    color: (root.cpuTemp >= 80 || root.cpuRpm >= 5000) ? (root.bar ? root.bar.urgent : Color.urgent) : Color.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    anchors.horizontalCenter: parent.horizontalCenter
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: root.cpuRpm > 0 ? String(root.cpuRpm) : "0"
                    color: root.bar ? root.bar.foreground : Color.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.title
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: "RPM"
                    color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                  }
                }
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width - Style.space(14)
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: "CPU: " + (root.cpuTemp > 0 ? root.cpuTemp + "°C" : "—") + (root.sysTemp > 0 ? " · Sys: " + root.sysTemp + "°C" : "")
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.3)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }

          // Right Gauge - GPU
          BorderSurface {
            id: gpuCard
            width: (gaugesRow.width - gaugesRow.spacing) / 2
            implicitHeight: gpuCol.implicitHeight + Style.space(18)
            color: Qt.rgba(0.10, 0.11, 0.16, 0.7)
            borderSpec: Border.controlSpec("normal", root.bar ? root.bar.foreground : Color.foreground, Color.accent)
            radius: Style.cornerRadius

            Column {
              id: gpuCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.topMargin: Style.space(10)
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText
                width: parent.width - Style.space(14)
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.gpuModel !== "" ? root.gpuModel : "Dedicated GPU"
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              Item {
                width: Style.space(110)
                height: Style.space(110)
                anchors.horizontalCenter: parent.horizontalCenter

                Canvas {
                  id: gpuCanvas
                  anchors.fill: parent
                  antialiasing: true

                  property real value: root.gpuRpm
                  property real maxValue: 6000
                  property color trackColor: "#282c3f"
                  property color progressColor: (root.gpuTemp >= 80 || root.gpuRpm >= 5000) ? (root.bar ? root.bar.urgent : Color.urgent) : Color.accent

                  onValueChanged: requestPaint()
                  onProgressColorChanged: requestPaint()

                  onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var w = width
                    var h = height
                    var cx = w / 2
                    var cy = h / 2
                    var strokeWidth = 7
                    var radius = Math.min(cx, cy) - strokeWidth / 2 - 2

                    var startAngle = 0.75 * Math.PI
                    var endAngle = 2.25 * Math.PI

                    ctx.lineWidth = strokeWidth
                    ctx.lineCap = "round"

                    ctx.beginPath()
                    ctx.strokeStyle = trackColor
                    ctx.arc(cx, cy, radius, startAngle, endAngle, false)
                    ctx.stroke()

                    var pct = Math.max(0, Math.min(1, value / maxValue))
                    if (pct > 0.005) {
                      var currentAngle = startAngle + pct * (endAngle - startAngle)
                      ctx.beginPath()
                      ctx.strokeStyle = progressColor
                      ctx.arc(cx, cy, radius, startAngle, currentAngle, false)
                      ctx.stroke()
                    }
                  }
                }

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(1)

                  Text {
                    textFormat: Text.PlainText
                    text: "󰈐"
                    color: (root.gpuTemp >= 80 || root.gpuRpm >= 5000) ? (root.bar ? root.bar.urgent : Color.urgent) : Color.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    anchors.horizontalCenter: parent.horizontalCenter
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: root.gpuRpm > 0 ? String(root.gpuRpm) : "0"
                    color: root.bar ? root.bar.foreground : Color.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.title
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: "RPM"
                    color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                  }
                }
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width - Style.space(14)
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: "GPU: " + (root.gpuTemp > 0 ? root.gpuTemp + "°C" : "—")
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.3)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }
        }

        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        // 3. ACPI Power Profile (4 modes)
        Column {
          width: mainColumn.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "ACPI POWER PROFILES"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.fontFamily
          }

          Row {
            id: profileRow
            width: parent.width
            spacing: Style.space(6)
            readonly property real cellWidth: (width - spacing * 3) / 4

            Button {
              width: profileRow.cellWidth
              iconText: "󰒲"
              text: "Quiet"
              fontSize: Style.font.bodySmall
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.fontFamily
              bordered: true
              active: root.currentProfile === "quiet"
              onClicked: root.setProfile("quiet")
            }

            Button {
              width: profileRow.cellWidth
              iconText: "󰾅"
              text: "Balanced"
              fontSize: Style.font.bodySmall
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.fontFamily
              bordered: true
              active: root.currentProfile === "balanced"
              onClicked: root.setProfile("balanced")
            }

            Button {
              width: profileRow.cellWidth
              iconText: "󰾆"
              text: "Bal-Perf"
              fontSize: Style.font.bodySmall
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.fontFamily
              bordered: true
              active: root.currentProfile === "balanced-performance"
              onClicked: root.setProfile("balanced-performance")
            }

            Button {
              width: profileRow.cellWidth
              iconText: "󰓅"
              text: "Perf"
              fontSize: Style.font.bodySmall
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.fontFamily
              bordered: true
              active: root.currentProfile === "performance"
              onClicked: root.setProfile("performance")
            }
          }
        }

        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        // 4. Cooling & Fans
        Column {
          width: mainColumn.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "COOLING & FANS"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.fontFamily
          }

          Row {
            id: fanModeRow
            width: parent.width
            spacing: Style.space(6)
            readonly property real cellWidth: (width - spacing * 2) / 3

            Button {
              width: fanModeRow.cellWidth
              iconText: "󰈐"
              text: "Auto"
              fontSize: Style.font.bodySmall
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.fontFamily
              bordered: true
              active: root.fanMode === "auto"
              onClicked: root.setFan("auto")
            }

            Button {
              width: fanModeRow.cellWidth
              iconText: "󰈐"
              text: "Max"
              fontSize: Style.font.bodySmall
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.fontFamily
              bordered: true
              active: root.fanMode === "max"
              onClicked: root.setFan("max")
            }

            Button {
              width: fanModeRow.cellWidth
              iconText: "󰒓"
              text: "Custom"
              fontSize: Style.font.bodySmall
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.fontFamily
              bordered: true
              active: root.fanMode === "custom"
              onClicked: root.applyCustomFans()
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(6)
            visible: root.fanMode === "custom" || root.customFansExpanded

            Row {
              width: parent.width
              spacing: Style.space(6)
              Text {
                textFormat: Text.PlainText
                text: "CPU Fan Target"
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
              Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
              Text {
                textFormat: Text.PlainText
                text: Math.round(cpuSlider.value) + "%"
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            PanelSlider {
              id: cpuSlider
              width: parent.width
              bar: root.bar
              minimum: 0
              maximum: 100
              step: 5
              integer: true
              value: root.targetCpu > 0 ? root.targetCpu : 50
              onReleased: function(val) {
                root.targetCpu = Math.round(val)
                if (root.fanMode === "custom") root.applyCustomFans()
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(6)
              Text {
                textFormat: Text.PlainText
                text: "GPU Fan Target"
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
              Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
              Text {
                textFormat: Text.PlainText
                text: Math.round(gpuSlider.value) + "%"
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            PanelSlider {
              id: gpuSlider
              width: parent.width
              bar: root.bar
              minimum: 0
              maximum: 100
              step: 5
              integer: true
              value: root.targetGpu > 0 ? root.targetGpu : 50
              onReleased: function(val) {
                root.targetGpu = Math.round(val)
                if (root.fanMode === "custom") root.applyCustomFans()
              }
            }

            Button {
              width: parent.width
              text: "Apply Custom Speeds (" + Math.round(cpuSlider.value) + "% / " + Math.round(gpuSlider.value) + "%)"
              bordered: true
              fontSize: Style.font.bodySmall
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.fontFamily
              onClicked: root.applyCustomFans()
            }
          }
        }

        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        // 5. Battery Care & USB Power
        Column {
          width: mainColumn.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "BATTERY CARE & USB POWER"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.fontFamily
          }

          Toggle {
            width: parent.width
            label: "Battery Charge Limit (80%)"
            description: root.batteryLimiter ? "Limits charge to 80% to preserve lifespan" : "Charges to full 100% capacity"
            checked: root.batteryLimiter
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.fontFamily
            onClicked: root.setBatteryLimit(!root.batteryLimiter)
          }

          Column {
            width: parent.width
            spacing: Style.space(4)

            Row {
              width: parent.width
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText
                text: "USB Power-off Charging"
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }

              Text {
                textFormat: Text.PlainText
                text: root.usbCharging > 0 ? root.usbCharging + "% Cutoff" : "Disabled"
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            Row {
              id: usbRow
              width: parent.width
              spacing: Style.space(6)
              readonly property real cellWidth: (width - spacing * 3) / 4

              Button {
                width: usbRow.cellWidth
                iconText: "󰚥"
                text: "Off"
                fontSize: Style.font.bodySmall
                foreground: root.bar ? root.bar.foreground : Color.foreground
                fontFamily: root.fontFamily
                bordered: true
                active: root.usbCharging === 0
                onClicked: root.setUsbCharging(0)
              }

              Button {
                width: usbRow.cellWidth
                text: "10%"
                fontSize: Style.font.bodySmall
                foreground: root.bar ? root.bar.foreground : Color.foreground
                fontFamily: root.fontFamily
                bordered: true
                active: root.usbCharging === 10
                onClicked: root.setUsbCharging(10)
              }

              Button {
                width: usbRow.cellWidth
                text: "20%"
                fontSize: Style.font.bodySmall
                foreground: root.bar ? root.bar.foreground : Color.foreground
                fontFamily: root.fontFamily
                bordered: true
                active: root.usbCharging === 20
                onClicked: root.setUsbCharging(20)
              }

              Button {
                width: usbRow.cellWidth
                text: "30%"
                fontSize: Style.font.bodySmall
                foreground: root.bar ? root.bar.foreground : Color.foreground
                fontFamily: root.fontFamily
                bordered: true
                active: root.usbCharging === 30
                onClicked: root.setUsbCharging(30)
              }
            }
          }

          Button {
            width: parent.width
            bordered: true
            text: root.batteryCalibrating ? "Stop Battery Calibration" : "Run Battery Calibration (Factory)"
            fontSize: Style.font.bodySmall
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.fontFamily
            onClicked: root.setBatteryCalibrate(!root.batteryCalibrating)
          }
        }

        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        // 6. Hardware Tweaks
        Column {
          width: mainColumn.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "HARDWARE TWEAKS"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.fontFamily
          }

          Toggle {
            width: parent.width
            label: "LCD Overdrive"
            description: root.lcdOverride ? "3ms Overdrive response time acceleration enabled" : "Standard LCD response time"
            checked: root.lcdOverride
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.fontFamily
            onClicked: root.setLcdOverride(!root.lcdOverride)
          }

          Toggle {
            width: parent.width
            label: "Keyboard Backlight 30s Timeout"
            description: root.backlightTimeout ? "Turns off backlight after 30s of inactivity" : "Backlight remains continuously illuminated"
            checked: root.backlightTimeout
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.fontFamily
            onClicked: root.setBacklightTimeout(!root.backlightTimeout)
          }

          Toggle {
            width: parent.width
            label: "System Boot Sound & Animation"
            description: root.bootAnimationSound ? "Acer Predator / Nitro startup sound enabled" : "Silent startup"
            checked: root.bootAnimationSound
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.fontFamily
            onClicked: root.setBootSound(!root.bootAnimationSound)
          }
        }

        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        // 7. Hybrid GPU (EnvyControl)
        Column {
          width: mainColumn.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "HYBRID GRAPHICS (ENVYCONTROL)"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.fontFamily
          }

          Row {
            id: gpuRow
            width: parent.width
            spacing: Style.space(6)
            readonly property real cellWidth: (width - spacing * 2) / 3

            Button {
              width: gpuRow.cellWidth
              iconText: "󰍹"
              text: "Hybrid"
              fontSize: Style.font.bodySmall
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.fontFamily
              bordered: true
              active: root.gpuMode === "hybrid"
              onClicked: root.setGpu("hybrid")
            }

            Button {
              width: gpuRow.cellWidth
              iconText: "󰢮"
              text: "Integrated"
              fontSize: Style.font.bodySmall
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.fontFamily
              bordered: true
              active: root.gpuMode === "integrated"
              onClicked: root.setGpu("integrated")
            }

            Button {
              width: gpuRow.cellWidth
              iconText: "󰘚"
              text: "Nvidia"
              fontSize: Style.font.bodySmall
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.fontFamily
              bordered: true
              active: root.gpuMode === "nvidia"
              onClicked: root.setGpu("nvidia")
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: !root.gpuAvailable
            width: parent.width
            wrapMode: Text.Wrap
            text: "EnvyControl is not installed. Install via 'yay -S envycontrol' to enable GPU switching."
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
