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

  property int cpuTemp: 0
  property int gpuTemp: 0
  property int sysTemp: 0
  property int cpuRpm: 0
  property int gpuRpm: 0
  property string fanMode: "auto"
  property int targetCpu: 50
  property int targetGpu: 50
  property string currentProfile: "balanced"
  property var profileChoices: ["quiet", "balanced", "performance"]
  property bool batteryLimiter: false
  property int batteryThreshold: 100
  property bool batteryCalibrating: false
  property string gpuMode: "hybrid"
  property bool gpuAvailable: false

  property bool customFansExpanded: false

  readonly property string helperPath: ("" + Qt.resolvedUrl("scripts/nitro-helper.sh")).replace(/^file:\/\//, "")

  function updateTelemetry(data) {
    if (!data) return
    if (data.fan) {
      root.fanMode = data.fan.mode || "auto"
      root.targetCpu = Number(data.fan.target_cpu) || 50
      root.targetGpu = Number(data.fan.target_gpu) || 50
      root.cpuRpm = Number(data.fan.cpu_rpm) || 0
      root.gpuRpm = Number(data.fan.gpu_rpm) || 0
      root.cpuTemp = Number(data.fan.cpu_temp) || 0
      root.gpuTemp = Number(data.fan.gpu_temp) || 0
      root.sysTemp = Number(data.fan.sys_temp) || 0
    }
    if (data.profile) {
      root.currentProfile = data.profile.current || "balanced"
      if (data.profile.choices && data.profile.choices.length > 0) {
        root.profileChoices = data.profile.choices
      }
    }
    if (data.battery) {
      root.batteryLimiter = data.battery.limiter === true
      root.batteryThreshold = Number(data.battery.threshold) || 100
      root.batteryCalibrating = data.battery.calibrating === true
    }
    if (data.gpu) {
      root.gpuMode = data.gpu.mode || "hybrid"
      root.gpuAvailable = data.gpu.available === true
    }
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
    contentWidth: panel.fittedContentWidth(Style.space(380))
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
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroCapsule.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: "󰈐"
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
              text: "ACER NITRO 5 AN517-54"
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
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
              text: (root.cpuTemp > 0 ? root.cpuTemp + "°C · " : "") + root.fanMode.toUpperCase()
              color: root.fanMode === "max" ? (root.bar ? root.bar.urgent : Color.urgent) : (root.bar ? root.bar.foreground : Color.foreground)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
        }

        // 2. Telemetry Cards (CPU & GPU)
        Row {
          width: parent.width
          spacing: Style.space(10)

          BorderSurface {
            width: (parent.width - parent.spacing) / 2
            implicitHeight: cpuCol.implicitHeight + Style.space(16)
            color: Qt.rgba(0, 0, 0, 0.15)
            borderSpec: Border.controlSpec("normal", root.bar ? root.bar.foreground : Color.foreground, Color.accent)
            radius: Style.cornerRadius

            Column {
              id: cpuCol
              anchors.centerIn: parent
              spacing: Style.space(2)

              Text {
                textFormat: Text.PlainText
                text: "CPU Core"
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.3)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: (root.cpuTemp > 0 ? root.cpuTemp : "—") + "°C"
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: root.cpuRpm > 0 ? root.cpuRpm + " RPM" : "0 RPM"
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.5)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                anchors.horizontalCenter: parent.horizontalCenter
              }
            }
          }

          BorderSurface {
            width: (parent.width - parent.spacing) / 2
            implicitHeight: gpuCol.implicitHeight + Style.space(16)
            color: Qt.rgba(0, 0, 0, 0.15)
            borderSpec: Border.controlSpec("normal", root.bar ? root.bar.foreground : Color.foreground, Color.accent)
            radius: Style.cornerRadius

            Column {
              id: gpuCol
              anchors.centerIn: parent
              spacing: Style.space(2)

              Text {
                textFormat: Text.PlainText
                text: "GPU (RTX 3050)"
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.3)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: (root.gpuTemp > 0 ? root.gpuTemp : "—") + "°C"
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: root.gpuRpm > 0 ? root.gpuRpm + " RPM" : "0 RPM"
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.5)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                anchors.horizontalCenter: parent.horizontalCenter
              }
            }
          }
        }

        InfoPair {
          label: "Motherboard / System"
          value: root.sysTemp > 0 ? root.sysTemp + "°C" : "—"
        }

        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        // 3. Cooling & Fans
        Column {
          width: parent.width
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

        // 4. ACPI Power Profile
        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "ACPI POWER PROFILE"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.fontFamily
          }

          Row {
            id: profileRow
            width: parent.width
            spacing: Style.space(6)
            readonly property real cellWidth: (width - spacing * 2) / 3

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
              active: root.currentProfile === "balanced" || root.currentProfile === "balanced-performance"
              onClicked: root.setProfile("balanced")
            }

            Button {
              width: profileRow.cellWidth
              iconText: "󰓅"
              text: "Performance"
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

        // 5. Battery Care
        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "BATTERY CARE"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.fontFamily
          }

          Toggle {
            width: parent.width
            label: "Battery Charge Limit (80%)"
            description: root.batteryLimiter ? "Limits charge to 80% to preserve lifespan" : "Charges to 100% capacity"
            checked: root.batteryLimiter
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.fontFamily
            onClicked: root.setBatteryLimit(!root.batteryLimiter)
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

        // 6. Hybrid GPU (EnvyControl)
        Column {
          width: parent.width
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

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    InfoLabel { text: label }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    InfoValue { text: value }
  }

  component InfoLabel: Text {
    textFormat: Text.PlainText
    color: root.bar ? root.bar.foreground : Color.foreground
    opacity: 0.6
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    textFormat: Text.PlainText
    color: root.bar ? root.bar.foreground : Color.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
