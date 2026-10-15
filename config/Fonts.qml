pragma Singleton
import QtQuick

QtObject {
    readonly property FontLoader poppins: FontLoader {
        source: "../assets/Poppins-Medium.ttf"
    }
    readonly property FontLoader poppinsSB: FontLoader {
        source: "../assets/Poppins-SemiBold.ttf"
    }
    readonly property FontLoader poppinsB: FontLoader {
        source: "../assets/Poppins-Bold.ttf"
    }
}
