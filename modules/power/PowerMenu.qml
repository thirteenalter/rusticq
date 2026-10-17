import Quickshell
import QtQuick
import Quickshell.Hyprland
import "../../config"
import "../../components"

// qmllint disable uncreatable-type
PanelWindow {
    id: barWindow
    color: "transparent"
    width: 320
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        right: true
    }

    margins {
        top: 50
        right: 10
    }

    HyprlandFocusGrab {
        active: true

        // Daftarkan jendela ini agar menerima input eksklusif
        windows: [barWindow]

        // KUNCI UTAMA: Ketika area di luar jendela di-klik, matikan loader-nya!
        // onCleared: {
        //     if (typeof powerMenuLoader !== "undefined") {
        //         powerMenuLoader.active = false;
        //     }
        // }
    }

    // =========================================================
    // Komponen tombol reusable, dipakai lewat Repeater di bawah.
    // Sebelumnya ada 6 blok Rectangle+Column+MouseArea yang
    // isinya nyaris identik — sekarang cukup satu definisi.
    // =========================================================
    component PowerButton: Rectangle {
        id: btn

        property string icon: ""
        property string label: ""
        property var onActivated: function () {}

        width: buttonGrid.itemWidth
        height: buttonGrid.itemHeight
        radius: 12
        color: mouse.containsMouse ? Theme.accent : Theme.surface
        border.color: Theme.surface
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 6

            Icon {
                icon: btn.icon
                color: mouse.containsMouse ? Theme.background : Theme.foreground
                font.pixelSize: Fonts.scale(24)
                anchors.horizontalCenter: parent.horizontalCenter
                scale: mouse.containsMouse ? 1.12 : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutBack
                    }
                }
            }

            Text {
                text: btn.label
                color: mouse.containsMouse ? Theme.background : Theme.foreground
                font.pixelSize: Fonts.scale(12)
                font.weight: Font.Medium
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.onActivated()
        }
    }

    Rectangle {
        id: card
        color: Theme.background
        radius: 18

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: contentLayout.height + contentLayout.anchors.margins * 2

        border.color: Theme.surface
        border.width: 1

        // Animasi kemunculan halus saat panel dibuka
        opacity: 0
        scale: 0.96
        transformOrigin: Item.Top

        Component.onCompleted: {
            opacity = 1;
            scale = 1;
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: contentLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 20

            // Header Minimalis dengan Aksen Teks
            Row {
                width: parent.width
                spacing: 8

                // Indikator garis kecil aksen modern
                Rectangle {
                    width: 4
                    height: 20
                    color: Theme.accent
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "Power Menu"
                    color: Theme.foreground
                    font.pixelSize: Fonts.scale(18)
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // --- GRID LAYOUT FULL WIDTH ---
            Grid {
                id: buttonGrid
                columns: 2
                spacing: 10
                width: parent.width

                readonly property real itemWidth: (width - spacing) / columns
                readonly property real itemHeight: 90
                readonly property int rowCount: Math.ceil(repeater.count / columns)
                height: (itemHeight * rowCount) + (spacing * (rowCount - 1))

                // Data tombol. Tambah/hapus/ubah urutan tombol cukup di sini,
                // tidak perlu duplikasi markup lagi.
                property var actions: [
                    {
                        icon: "\ue899",
                        label: "Lock",
                        run: function () {
                            console.log("Eksekusi lockscreen");
                        }
                    },
                    {
                        icon: "\ue1c3",
                        label: "Screensaver",
                        run: function () {
                            console.log("Eksekusi screensaver");
                        }
                    },
                    {
                        icon: "\ue8ac",
                        label: "Shutdown",
                        run: function () {
                            console.log("Eksekusi shutdown");
                        }
                    },
                    {
                        icon: "\uf053",
                        label: "Reboot",
                        run: function () {
                            console.log("Eksekusi reboot");
                        }
                    },
                    {
                        icon: "\uef44",
                        label: "Suspend",
                        run: function () {
                            console.log("Eksekusi suspend");
                        }
                    },
                    {
                        icon: "\ue9ba",
                        label: "Logout",
                        run: function () {
                            console.log("Eksekusi logout");
                        }
                    }
                ]

                Repeater {
                    id: repeater
                    model: buttonGrid.actions

                    PowerButton {
                        icon: modelData.icon
                        label: modelData.label
                        onActivated: modelData.run
                    }
                }
            }
        }
    }
}
