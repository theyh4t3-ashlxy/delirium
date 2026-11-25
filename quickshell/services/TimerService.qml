pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root

    property int timerTotal: 300
    property int timerRemaining: 0
    property bool timerRunning: false
    property bool timerPaused: false

    // Pomodoro cycle engine
    property bool pomodoroActive: false
    property string pomodoroPhase: "focus" // focus | break
    property int pomodoroCycles: 0
    property int _pomoFocusMin: 25
    property int _pomoBreakMin: 5

    property int stopwatchElapsed: 0
    property bool stopwatchRunning: false

    signal timerFinished()

    readonly property string timerDisplay: formatSeconds(timerRemaining)
    readonly property string stopwatchDisplay: formatSeconds(stopwatchElapsed)
    readonly property real timerProgress: (timerTotal > 0 && timerRemaining > 0) ? (timerRemaining / timerTotal) : 0

    function formatSeconds(sec) {
        let s = Math.max(0, Math.floor(sec || 0));
        let m = Math.floor(s / 60);
        let remS = s % 60;
        let h = Math.floor(m / 60);
        let remM = m % 60;
        if (h > 0) {
            return (h < 10 ? "0" : "") + h + ":" + (remM < 10 ? "0" : "") + remM + ":" + (remS < 10 ? "0" : "") + remS;
        }
        return (remM < 10 ? "0" : "") + remM + ":" + (remS < 10 ? "0" : "") + remS;
    }

    function startTimer(seconds) {
        let s = (typeof seconds === "number" && seconds > 0) ? seconds : 300;
        pomodoroActive = false;
        timerTotal = s;
        timerRemaining = s;
        timerRunning = true;
        timerPaused = false;
    }

    function startPomodoro(focusMin, breakMin) {
        _pomoFocusMin = Math.max(1, Math.round(focusMin || Settings?.pomodoroFocusMin || 25));
        _pomoBreakMin = Math.max(1, Math.round(breakMin || Settings?.pomodoroBreakMin || 5));
        pomodoroActive = true;
        pomodoroPhase = "focus";
        timerTotal = _pomoFocusMin * 60;
        timerRemaining = timerTotal;
        timerRunning = true;
        timerPaused = false;
    }

    function stopPomodoro() {
        pomodoroActive = false;
        pomodoroPhase = "focus";
        pomodoroCycles = 0;
        resetTimer();
    }

    function pauseTimer() {
        if (timerRunning) {
            timerRunning = false;
            timerPaused = true;
        }
    }

    function resumeTimer() {
        if (timerPaused && timerRemaining > 0) {
            timerRunning = true;
            timerPaused = false;
        }
    }

    function toggleTimer() {
        if (timerRunning) {
            pauseTimer();
        } else if (timerPaused && timerRemaining > 0) {
            resumeTimer();
        } else if (pomodoroActive) {
            startPomodoro(_pomoFocusMin, _pomoBreakMin);
        } else {
            startTimer(timerTotal > 0 ? timerTotal : 300);
        }
    }

    function resetTimer() {
        timerRunning = false;
        timerPaused = false;
        timerRemaining = 0;
        if (pomodoroActive) {
            pomodoroActive = false;
            pomodoroPhase = "focus";
        }
    }

    function addTimerSeconds(addSec) {
        let s = Math.round(addSec || 0);
        if (s <= 0) return;
        if (timerRunning || timerPaused) {
            timerRemaining += s;
            timerTotal += s;
        } else {
            startTimer(s);
        }
    }

    function addTimerMinutes(mins) {
        addTimerSeconds((mins || 1) * 60);
    }

    function startStopwatch() {
        stopwatchRunning = true;
    }

    function pauseStopwatch() {
        stopwatchRunning = false;
    }

    function toggleStopwatch() {
        stopwatchRunning = !stopwatchRunning;
    }

    function resetStopwatch() {
        stopwatchRunning = false;
        stopwatchElapsed = 0;
    }

    Timer {
        id: ticker
        interval: 1000
        repeat: true
        running: root.timerRunning || root.stopwatchRunning
        onTriggered: {
            if (root.timerRunning) {
                if (root.timerRemaining > 1) {
                    root.timerRemaining -= 1;
                } else if (root.pomodoroActive) {
                    if (root.pomodoroPhase === "focus") {
                        root.pomodoroCycles += 1;
                        root.pomodoroPhase = "break";
                        root.timerTotal = root._pomoBreakMin * 60;
                        root.timerRemaining = root.timerTotal;
                        root._sendNotification("Focus Complete", "Take a " + root._pomoBreakMin + "m break (cycle #" + root.pomodoroCycles + ")");
                    } else {
                        root.pomodoroPhase = "focus";
                        root.timerTotal = root._pomoFocusMin * 60;
                        root.timerRemaining = root.timerTotal;
                        root._sendNotification("Break Over", "Back to focus for " + root._pomoFocusMin + "m");
                    }
                    root.timerFinished();
                } else {
                    root.timerRemaining = 0;
                    root.timerRunning = false;
                    root.timerPaused = false;
                    root.timerFinished();
                    root._sendNotification("Timer Finished", "Your timer has completed");
                }
            }
            if (root.stopwatchRunning) {
                root.stopwatchElapsed += 1;
            }
        }
    }

    function _sendNotification(title, body) {
        try {
            Quickshell.execDetached(["notify-send", "-a", "Quickshell", "-i", "alarm", title, body]);
        } catch (e) {}
    }
}
