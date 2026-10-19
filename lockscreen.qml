// RusticQ dedicated session locker, launched separately from the desktop shell.
// Never load this as part of shell.qml: losing the desktop shell must not unlock.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import "modules/lock"

ShellRoot {
    id: locker
    property bool authenticated: false
    property bool authenticating: false
    property bool awaitingResponse: false
    readonly property bool responseVisible: pam.responseRequired && pam.responseVisible
    property string pendingSecret: ""
    property string feedback: "Enter your account password"
    property bool feedbackIsError: false
    property int failures: 0

    function submit(secret) {
        if (authenticated || secret.length === 0) return;
        if (pam.active && !pam.responseRequired) return;
        if (pam.active && pam.responseRequired) {
            // Second challenge, if the configured PAM stack requests one.
            awaitingResponse = false;
            pam.respond(secret);
            return;
        }
        pendingSecret = secret;
        authenticating = true;
        feedbackIsError = false;
        feedback = "Authenticating securely…";
        if (!pam.start()) {
            pendingSecret = "";
            authenticating = false;
            feedback = "Could not start PAM. Your session remains locked.";
            feedbackIsError = true;
        }
    }

    PamContext {
        id: pam
        // Quickshell's default system login policy. No custom PAM rules are installed.
        config: "login"
        onPamMessage: {
            if (!responseRequired) {
                if (message) locker.feedback = message;
                locker.feedbackIsError = messageIsError;
                return;
            }
            if (locker.pendingSecret.length && !responseVisible) {
                const secret = locker.pendingSecret;
                locker.pendingSecret = "";
                respond(secret);
            } else {
                // An unexpected challenge must be answered by the user, not bypassed.
                locker.pendingSecret = "";
                locker.awaitingResponse = true;
                locker.feedback = message || "Further authentication required";
                locker.feedbackIsError = false;
            }
        }
        onCompleted: result => {
            locker.pendingSecret = "";
            locker.authenticating = false;
            locker.awaitingResponse = false;
            if (result === PamResult.Success && sessionLock.secure) {
                locker.authenticated = true;
                locker.feedback = "Authenticated. Unlocking…";
                locker.feedbackIsError = false;
                sessionLock.locked = false;
            } else {
                locker.failures += 1;
                locker.feedbackIsError = true;
                locker.feedback = result === PamResult.Success
                    ? "Compositor lock not confirmed. Refusing to unlock."
                    : result === PamResult.MaxTries
                    ? "Too many attempts. Authentication unavailable."
                    : result === PamResult.Error
                    ? "Authentication service error. Session remains locked."
                    : "Incorrect password. Please try again.";
            }
        }
        onError: error => {
            locker.pendingSecret = "";
            locker.feedback = "PAM error. Your session remains locked.";
            locker.feedbackIsError = true;
        }
    }
    WlSessionLock {
        id: sessionLock
        locked: true
        RusticQLockSurface {
            controller: locker
        }
    }
    Timer {
        // Finish compositor unlock request before quitting the dedicated process.
        interval: 500
        running: locker.authenticated && !sessionLock.locked
        repeat: false
        onTriggered: Qt.quit()
    }
}
