import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.rikalonikola.dell-g16-awcc-oma"
  ipcTarget: "io.github.rikalonikola.dell-g16-awcc-oma"

  readonly property string awcc: Quickshell.env("HOME") + "/.local/bin/awcc"

  property var info: ({})
  readonly property var temps: info.temps || ({})
  readonly property var fans: info.fans || ([])
  readonly property var rgb: (info.config && info.config.rgb) || ({})
  readonly property var auto: (info.config && info.config.auto) || ({})
  readonly property string profile: info.profile || ""
  readonly property bool onAc: !!(info.power && info.power.ac)
  // ---- custom color picker (hue + saturation bars + hex field)
  property real pickH: 0
  property real pickS: 1
  property bool picking: false
  property int editCount: 0
  readonly property color pickColor: Qt.hsva(pickH, pickS, 1, 1)

  function hex(c) {
    function h(v) { var t = Math.round(v * 255).toString(16); return t.length < 2 ? "0" + t : t }
    return "#" + h(c.r) + h(c.g) + h(c.b)
  }
  function syncPickFromConfig() {
    if (picking || !rgb.color) return
    var c = Qt.color(rgb.color)
    if (c.hsvHue >= 0) pickH = c.hsvHue
    pickS = c.hsvSaturation
  }
  function lightingMode() { return rgb.mode === "spectrum" ? "static" : (rgb.mode || "static") }
  function applyHex(hexColor) { run(["rgb", "mode", lightingMode(), "--color", hexColor.replace("#", "")]) }
  onRgbChanged: syncPickFromConfig()

  // ---- saved keyboard lighting profiles
  readonly property var profilesMap: (info.config && info.config.profiles) || ({})
  readonly property var profileNames: Object.keys(profilesMap).sort(function(a, b) {
    return a.toLowerCase() < b.toLowerCase() ? -1 : 1
  })
  function isActiveProfile(name) {
    var p = profilesMap[name]
    return !!p && rgb.on !== false && rgb.mode === p.mode && rgb.color === p.color && rgb.brightness === p.brightness
  }
  function saveProfile(name) {
    name = name.trim()
    if (name === "") return false
    run(["rgb", "profile", "save", name])
    return true
  }

  readonly property var swatches: ["#ffffff", "#ff3b30", "#ff9500", "#ffd60a", "#34c759", "#00c7be", "#0a84ff", "#af52de", "#ff2d92"]
  readonly property var profileButtons: [
    { id: "quiet", label: "Quiet", icon: "󰒲" },
    { id: "balanced", label: "Balanced", icon: "󰾆" },
    { id: "balanced-performance", label: "Boost", icon: "󰓅" },
    { id: "performance", label: "Max", icon: "󱐋" }
  ]
  readonly property var modeButtons: [
    { id: "static", label: "Static" },
    { id: "breathe", label: "Breathe" },
    { id: "spectrum", label: "Spectrum" }
  ]

  readonly property int fanBoost: {
    if (fans.length === 0) return 0
    var b = fans[0].boost
    return b === null || b === undefined ? 0 : b
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function run(args) {
    actionProc.command = [root.awcc].concat(args)
    actionProc.running = true
  }

  function fmtTemp(v) { return v === undefined ? "—" : v + "°" }

  onOpenedChanged: if (opened) refresh()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: statusProc
    command: [root.awcc, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.info = JSON.parse(text) } catch (e) {}
      }
    }
  }

  Process {
    id: actionProc
    onExited: root.refresh()
  }

  Timer { interval: 2000; running: root.opened; repeat: true; onTriggered: root.refresh() }
  Timer { interval: 15000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot
    // Alienware head logo (Simple Icons, 24x24 path), tinted with the bar foreground.
    iconComponent: Component {
      Item {
        Shape {
          id: logo
          width: 24
          height: 24
          anchors.centerIn: parent
          scale: Math.min(parent.width, parent.height) / 24 * 1.15
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            fillColor: root.bar ? root.bar.foreground : Color.foreground
            strokeColor: "transparent"
            PathSvg { path: "M20.382 9.4054c-.0649-.6486-.1297-1.3622-.2595-2.0108-.1297-.6487-.2594-1.2973-.5189-1.946-.1297-.3243-.2595-.6486-.3892-.908-.1297-.3244-.3243-.5838-.454-.9082-.1946-.2594-.3892-.5838-.5838-.8432-.1946-.2595-.454-.519-.7135-.7135-.454-.3892-.973-.7784-1.5568-1.1027-.5838-.3244-1.2324-.5838-1.881-.7135C13.3765.0649 12.7278 0 12.0143 0c-.7135 0-1.3621.0649-2.0108.2595C9.355.3892 8.7712.6486 8.1874.973c-.6487.3243-1.1676.7135-1.6865 1.1675-.2595.1946-.454.454-.7135.7136l-.5838.7783c-.1297.3244-.3243.5838-.454.9081l-.3892.973c-.1946.6487-.3892 1.2973-.519 1.946-.1297.6486-.1946 1.2973-.2594 2.0108-.0649.7135 0 1.2973 0 1.946 0 .6486.0648 1.2972.1946 2.0107l.1946.973c.0648.3243.1946.6486.3243.973.454 1.2324 1.1676 2.4 1.881 3.5027.3893.5838.7785 1.1027 1.1676 1.6216.3892.519.7784 1.1027 1.2325 1.5568.1946.2594.454.454.7135.7135.2594.1946.519.3892.8432.5837.2595.1946.5838.3244.9081.4541.1298.0649.3244.1297.4541.1297.1946 0 .3243.0649.519.0649.1945 0 .3242 0 .5188-.0649.1946 0 .3244-.0648.454-.1297.3244-.1297.6487-.2595.9082-.454.2595-.1946.5838-.3892.8432-.5838.2595-.1946.519-.454.7136-.7135.454-.519.8432-1.0379 1.2324-1.5568.3892-.519.7784-1.1027 1.1676-1.6216.7135-1.1027 1.427-2.2703 1.881-3.5027.1298-.3244.2595-.6487.3244-.973.0648-.3243.1946-.6486.1946-.973.1297-.6486.1945-1.2973.1945-2.0108 0-.6486 0-1.3621-.0648-2.0108zM4.8144 12.0649s3.6973.8432 6.0973 5.8378c-.0649 0-6.4216-.1297-6.0973-5.8378zm8.3676 5.8378c2.3351-4.9946 6.0973-5.8378 6.0973-5.8378.3243 5.708-6.0973 5.8378-6.0973 5.8378z" }
          }
        }
      }
    }
    tooltipText: root.temps.cpu !== undefined
      ? "CPU " + root.temps.cpu + "°  GPU " + root.temps.gpu + "°  ·  " + root.profile
      : "G16 AWCC-Oma"
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      blocked: root.editCount > 0
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Model notice: this package is made for the Dell G16 ----------
        Rectangle {
          readonly property var model: root.info.model
          visible: !!(model && !(model.supported && model.verified))
          width: parent.width
          height: visible ? modelNotice.implicitHeight + Style.space(16) : 0
          radius: 4
          color: "transparent"
          border.width: 1
          border.color: model && model.supported ? Color.accent : Color.urgent

          Text {
            id: modelNotice
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.space(8)
            wrapMode: Text.WordWrap
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            text: !parent.model ? "" : (parent.model.supported
              ? "Unverified model: " + parent.model.name + ". Run `awcc doctor` in a terminal to check it."
              : parent.model.reason)
          }
        }

        // ---------- Hero: temperatures and fans ----------
        Row {
          width: parent.width
          spacing: Style.space(10)

          Repeater {
            model: [
              { label: "CPU", temp: root.temps.cpu, fan: root.fans.length > 0 ? root.fans[0] : null },
              { label: "GPU", temp: root.temps.gpu, fan: root.fans.length > 1 ? root.fans[1] : null }
            ]
            Column {
              required property var modelData
              width: (parent.width - parent.spacing) / 2
              spacing: Style.space(2)

              Text {
                textFormat: Text.PlainText
                text: modelData.label
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
              }
              Text {
                textFormat: Text.PlainText
                text: root.fmtTemp(modelData.temp)
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.displayLarge
                font.bold: true
              }
              Text {
                textFormat: Text.PlainText
                text: modelData.fan ? modelData.fan.rpm + " rpm" : ""
                color: root.bar.foreground
                opacity: 0.6
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ---------- Thermal profile ----------
        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "THERMAL PROFILE"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Row {
            id: profileRow
            width: parent.width
            spacing: Style.space(6)
            readonly property real cellWidth: (width - spacing * (root.profileButtons.length - 1)) / root.profileButtons.length

            Repeater {
              model: root.profileButtons
              Button {
                required property var modelData
                width: profileRow.cellWidth
                iconText: modelData.icon
                iconSize: Style.font.title
                text: modelData.label
                fontSize: Style.font.bodySmall
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                active: root.profile === modelData.id
                onClicked: root.run(["profile", modelData.id])
              }
            }
          }
        }

        // ---------- Fan boost ----------
        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "FAN BOOST"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Row {
            id: fanRow
            width: parent.width
            spacing: Style.space(6)
            readonly property var steps: [
              { label: "Auto", value: 0 },
              { label: "50%", value: 50 },
              { label: "Max", value: 100 }
            ]
            readonly property real cellWidth: (width - spacing * (steps.length - 1)) / steps.length

            Repeater {
              model: fanRow.steps
              Button {
                required property var modelData
                width: fanRow.cellWidth
                text: modelData.label
                fontSize: Style.font.bodySmall
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                active: Math.abs(root.fanBoost - modelData.value) < 8
                onClicked: root.run(["fan", "all", String(modelData.value)])
              }
            }
          }
        }

        // ---------- Auto profile ----------
        Button {
          width: parent.width
          text: root.auto.enabled
            ? "Auto profile on: " + (root.auto.ac || "") + " on AC, " + (root.auto.battery || "") + " on battery"
            : "Auto profile off (AC / battery)"
          fontSize: Style.font.bodySmall
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
          bordered: true
          active: !!root.auto.enabled
          onClicked: root.run(["auto", root.auto.enabled ? "off" : "on"])
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ---------- Keyboard lighting ----------
        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "KEYBOARD LIGHTING"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Row {
            id: modeRow
            width: parent.width
            spacing: Style.space(6)
            readonly property real cellWidth: (width - spacing * (root.modeButtons.length - 1)) / root.modeButtons.length

            Repeater {
              model: root.modeButtons
              Button {
                required property var modelData
                width: modeRow.cellWidth
                text: modelData.label
                fontSize: Style.font.bodySmall
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                active: root.rgb.on !== false && root.rgb.mode === modelData.id
                onClicked: root.run(["rgb", "mode", modelData.id])
              }
            }
          }

          Row {
            id: swatchRow
            width: parent.width
            spacing: Style.space(6)
            readonly property real size: (width - spacing * (root.swatches.length - 1)) / root.swatches.length

            Repeater {
              model: root.swatches
              Rectangle {
                required property string modelData
                width: swatchRow.size
                height: swatchRow.size
                radius: width / 2
                color: modelData
                border.width: root.rgb.color === modelData ? 2 : 1
                border.color: root.rgb.color === modelData
                  ? root.bar.foreground
                  : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.25)

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.run(["rgb", "mode", root.rgb.mode === "spectrum" ? "static" : (root.rgb.mode || "static"), "--color", parent.modelData.substring(1)])
                }
              }
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(10)

            Rectangle {
              id: pickPreview
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(30)
              height: width
              radius: width / 2
              color: root.pickColor
              border.width: 2
              border.color: root.bar.foreground
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - pickPreview.width - hexField.width - parent.spacing * 2
              spacing: Style.space(8)

              PickBar {
                width: parent.width
                value: root.pickH
                gradientStops: [
                  GradientStop { position: 0.0; color: "#ff0000" },
                  GradientStop { position: 0.17; color: "#ffff00" },
                  GradientStop { position: 0.33; color: "#00ff00" },
                  GradientStop { position: 0.5; color: "#00ffff" },
                  GradientStop { position: 0.67; color: "#0000ff" },
                  GradientStop { position: 0.83; color: "#ff00ff" },
                  GradientStop { position: 1.0; color: "#ff0000" }
                ]
                onMoved: function(v) { root.pickH = v }
                onReleased: function(v) { root.pickH = v; root.applyHex(root.hex(root.pickColor)) }
              }

              PickBar {
                width: parent.width
                value: root.pickS
                gradientStops: [
                  GradientStop { position: 0.0; color: "#ffffff" },
                  GradientStop { position: 1.0; color: Qt.hsva(root.pickH, 1, 1, 1) }
                ]
                onMoved: function(v) { root.pickS = v }
                onReleased: function(v) { root.pickS = v; root.applyHex(root.hex(root.pickColor)) }
              }
            }

            Field {
              id: hexField
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(100)
              placeholderText: "#rrggbb"
              maximumLength: 7
              Binding on text {
                when: !hexField.activeFocus
                value: root.hex(root.pickColor)
              }
              onAccepted: {
                var t = text.trim()
                if (t.charAt(0) !== "#") t = "#" + t
                if (!/^#[0-9a-fA-F]{6}$/.test(t)) return
                var c = Qt.color(t)
                if (c.hsvHue >= 0) root.pickH = c.hsvHue
                root.pickS = c.hsvSaturation
                root.applyHex(t)
                focus = false
              }
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(10)

            Text {
              id: brightLabel
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "Brightness"
              color: root.bar.foreground
              opacity: 0.6
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            PanelSlider {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - brightLabel.implicitWidth - parent.spacing
              bar: root.bar
              minimum: 0
              maximum: 100
              step: 5
              integer: true
              value: root.rgb.on === false ? 0 : (root.rgb.brightness !== undefined ? root.rgb.brightness : 100)
              onReleased: function(v) { root.run(["rgb", "brightness", String(Math.round(v))]) }
            }
          }

          // ---------- Saved profiles
          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "LIGHTING PROFILES"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
            }

            Flow {
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: root.profileNames

                Row {
                  required property string modelData
                  spacing: 2

                  ProfBtn {
                    text: parent.modelData
                    active: root.isActiveProfile(parent.modelData)
                    onClicked: root.run(["rgb", "profile", "apply", parent.modelData])
                  }
                  ProfBtn {
                    text: "✕"
                    onClicked: root.run(["rgb", "profile", "delete", parent.modelData])
                  }
                }
              }
            }

            Text {
              visible: root.profileNames.length === 0
              width: parent.width
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: "No saved profiles yet. Set mode, color and brightness, give it a name and press Save."
              color: root.bar.foreground
              opacity: 0.55
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }

            Row {
              width: parent.width
              spacing: Style.space(6)

              Field {
                id: profileField
                width: parent.width - saveProfileBtn.width - parent.spacing
                placeholderText: "Profile name"
                maximumLength: 24
                onAccepted: if (root.saveProfile(text)) text = ""
              }
              ProfBtn {
                id: saveProfileBtn
                text: "Save current"
                onClicked: if (root.saveProfile(profileField.text)) profileField.text = ""
              }
            }
          }
        }
      }
    }
  }

  component PickBar: Item {
    id: pb
    property real value: 0
    property alias gradientStops: grad.stops
    signal moved(real v)
    signal released(real v)
    implicitHeight: Style.space(20)
    height: implicitHeight

    Rectangle {
      anchors.fill: parent
      radius: height / 2
      border.width: 1
      border.color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.3)
      gradient: Gradient {
        id: grad
        orientation: Gradient.Horizontal
      }
    }

    Rectangle {
      width: pb.height + 2
      height: width
      radius: width / 2
      x: Math.max(0, Math.min(pb.width - width, pb.value * pb.width - width / 2))
      y: -1
      color: "transparent"
      border.width: 2
      border.color: root.bar.foreground
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      function pos(m) { return Math.max(0, Math.min(1, m.x / width)) }
      onPressed: function(m) { root.picking = true; pb.moved(pos(m)) }
      onPositionChanged: function(m) { if (pressed) pb.moved(pos(m)) }
      onReleased: function(m) { pb.released(pos(m)); root.picking = false }
    }
  }

  component ProfBtn: Button {
    fontSize: Style.font.bodySmall
    foreground: root.bar.foreground
    fontFamily: root.bar.fontFamily
    horizontalPadding: Style.spacing.controlPaddingX
    verticalPadding: Style.spacing.controlPaddingY + Style.space(1)
    bordered: true
  }

  component Field: TextField {
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    foreground: root.bar.foreground
    horizontalPadding: Style.spacing.controlGap
    verticalPadding: Style.spacing.controlPaddingY
    onActiveFocusChanged: root.editCount += activeFocus ? 1 : -1
  }
}
