import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.felipeasp.omanitro"

  property string deviceModel: "Acer Nitro 5"
  property string cpuModel: "CPU"
  property string gpuModel: "GPU"
  property int cpuTemp: 0
  property int gpuTemp: 0
  property int sysTemp: 0
  property int cpuRpm: 0
  property int gpuRpm: 0
  property string fanMode: "auto"
  property int targetCpu: 0
  property int targetGpu: 0
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
        device_model: root.deviceModel,
        cpu_model: root.cpuModel,
        gpu_model: root.gpuModel,
        cpu_temp: root.cpuTemp,
        gpu_temp: root.gpuTemp,
        sys_temp: root.sysTemp,
        fan1_rpm: root.cpuRpm,
        fan2_rpm: root.gpuRpm,
        cpu_rpm: root.cpuRpm,
        gpu_rpm: root.gpuRpm,
        fan_mode: root.fanMode,
        target_cpu: root.targetCpu,
        target_gpu: root.targetGpu,
        profile: root.currentProfile,
        profile_choices: root.profileChoices,
        battery_limiter: root.batteryLimiter,
        battery_threshold: root.batteryThreshold,
        battery_calibration: root.batteryCalibrating,
        usb_charging: root.usbCharging,
        lcd_override: root.lcdOverride,
        backlight_timeout: root.backlightTimeout,
        boot_animation_sound: root.bootAnimationSound,
        gpu_mode: root.gpuMode,
        gpu_available: root.gpuAvailable
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
      if (data.device_model) root.deviceModel = data.device_model
      if (data.cpu_model) root.cpuModel = data.cpu_model
      if (data.gpu_model) root.gpuModel = data.gpu_model

      root.fanMode = data.fan_mode || (data.fan && data.fan.mode) || "auto"
      root.targetCpu = Number(data.target_cpu != null ? data.target_cpu : (data.fan && data.fan.target_cpu)) || 0
      root.targetGpu = Number(data.target_gpu != null ? data.target_gpu : (data.fan && data.fan.target_gpu)) || 0
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

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰌢"
    slotSize: Style.bar.statusSlot
    foreground: root.fanMode === "max" ? (root.bar ? root.bar.urgent : Color.urgent) : (root.bar ? root.bar.barForeground : Color.foreground)
    tooltipText: (root.cpuTemp > 0 || root.gpuTemp > 0)
      ? ("CPU: " + root.cpuTemp + "°C | GPU: " + root.gpuTemp + "°C\n" + root.currentProfile.toUpperCase() + " • " + root.fanMode.toUpperCase() + " Fans")
      : ("OmaNitro: " + root.deviceModel)

    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.cycleFanMode()
      } else {
        root.togglePanel()
      }
    }
  }
}
