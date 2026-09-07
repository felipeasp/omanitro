import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.felipeasp.omanitro"

  property int cpuTemp: 0
  property int gpuTemp: 0
  property int sysTemp: 0
  property int cpuRpm: 0
  property int gpuRpm: 0
  property string fanMode: "auto"
  property int targetCpu: 0
  property int targetGpu: 0
  property string currentProfile: "balanced"
  property var profileChoices: ["quiet", "balanced", "performance"]
  property bool batteryLimiter: false
  property int batteryThreshold: 100
  property bool batteryCalibrating: false
  property string gpuMode: "hybrid"
  property bool gpuAvailable: false

  readonly property string helperPath: ("" + Qt.resolvedUrl("scripts/nitro-helper.sh")).replace(/^file:\/\//, "")

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("updateTelemetry" in target) {
      target.updateTelemetry({
        fan: {
          mode: root.fanMode,
          target_cpu: root.targetCpu,
          target_gpu: root.targetGpu,
          cpu_rpm: root.cpuRpm,
          gpu_rpm: root.gpuRpm,
          cpu_temp: root.cpuTemp,
          gpu_temp: root.gpuTemp,
          sys_temp: root.sysTemp
        },
        profile: {
          current: root.currentProfile,
          choices: root.profileChoices
        },
        battery: {
          limiter: root.batteryLimiter,
          threshold: root.batteryThreshold,
          calibrating: root.batteryCalibrating
        },
        gpu: {
          mode: root.gpuMode,
          available: root.gpuAvailable
        }
      })
    }
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) {
      panelLoader.item.toggle()
    }
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.open) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch) {
      panelLoader.item.closeForPopoutSwitch()
    }
  }

  function refresh() {
    if (!root.helperPath || root.helperPath === "") return
    if (!statusPoller.running) {
      statusPoller.command = [root.helperPath, "status"]
      statusPoller.running = true
    }
  }

  function cycleFanMode() {
    if (fanActionProc.running || !root.helperPath) return
    fanActionProc.command = [root.helperPath, "fan", root.fanMode === "max" ? "auto" : "max"]
    fanActionProc.running = true
  }

  function parseStatus(raw) {
    if (!raw) return
    try {
      var data = JSON.parse(raw)
      if (data.fan) {
        root.fanMode = data.fan.mode || "auto"
        root.targetCpu = Number(data.fan.target_cpu) || 0
        root.targetGpu = Number(data.fan.target_gpu) || 0
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

      if (panelLoader.item && panelLoader.item.updateTelemetry) {
        panelLoader.item.updateTelemetry(data)
      }
    } catch (e) {
      // Ignore transient JSON parse errors during quick reads
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Process {
    id: statusPoller
    command: [root.helperPath, "status"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStatus(text)
    }
  }

  Process {
    id: fanActionProc
    onExited: root.refresh()
  }

  Timer {
    interval: Math.max(1000, Number(root.setting("refreshIntervalSec", 2)) * 1000)
    running: true
    repeat: true
    triggeredOnStart: false
    onTriggered: root.refresh()
  }

  Component.onCompleted: {
    Qt.callLater(root.refresh)
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "io.github.felipeasp.omanitro"

    function refresh(): void { root.refresh() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    hasVisualContent: true
    labelVisible: false
    fixedHeight: root.barSize
    fixedWidth: contentRow.implicitWidth + scaledHorizontalMargin * 2
    tooltipText: "OmaNitro: Acer Nitro 5 (" + root.fanMode.toUpperCase() + (root.cpuTemp > 0 ? " · " + root.cpuTemp + "°C" : "") + ")"

    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.cycleFanMode()
      } else {
        root.togglePanel()
      }
    }

    Row {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.space(6)

      Text {
        textFormat: Text.PlainText
        text: "󰈐"
        font.family: button.fontFamily
        font.pixelSize: Style.font.body
        color: root.fanMode === "max" ? (root.bar ? root.bar.urgent : Color.urgent) : (root.bar ? root.bar.barForeground : Color.foreground)
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: (root.cpuTemp > 0 ? root.cpuTemp + "°C" : "") + (root.cpuRpm > 0 ? " " + root.cpuRpm + " rpm" : "")
        font.family: button.fontFamily
        font.pixelSize: Style.font.caption
        color: root.bar ? root.bar.barForeground : Color.foreground
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        visible: root.batteryLimiter
        text: "󰂄80%"
        font.family: button.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        color: Color.accent
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
