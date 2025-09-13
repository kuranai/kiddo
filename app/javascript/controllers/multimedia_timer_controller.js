import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "timer",
    "startButton",
    "stopButton",
    "progressBar",
    "progressText",
    "remainingTime",
    "usedTime",
    "dailyAllowance",
    "warningMessage",
    "sessionStatus",
    "internetStatus"
  ]

  static values = {
    userId: Number,
    remainingMinutes: Number,
    dailyAllowance: Number,
    usedMinutes: Number,
    isActive: Boolean,
    updateUrl: String,
    startUrl: String,
    stopUrl: String,
    autoRefreshInterval: { type: Number, default: 60000 } // 1 minute default
  }

  static classes = [
    "active",
    "inactive",
    "warning",
    "danger",
    "success"
  ]

  connect() {
    console.log("Multimedia timer controller connected")

    // Initialize timer state
    this.isRunning = this.isActiveValue
    this.remainingSeconds = this.remainingMinutesValue * 60
    this.intervalId = null
    this.updateIntervalId = null

    // Set up initial display
    this.updateDisplay()
    this.updateProgressBar()
    this.updateButtonStates()

    // Start automatic updates if session is active
    if (this.isRunning) {
      this.startTimer()
    }

    // Set up periodic server sync
    this.startPeriodicSync()

    // Set up visibility change handling (pause when tab is hidden)
    document.addEventListener('visibilitychange', this.handleVisibilityChange.bind(this))

    // Set up beforeunload warning for active sessions
    window.addEventListener('beforeunload', this.handleBeforeUnload.bind(this))
  }

  disconnect() {
    console.log("Multimedia timer controller disconnected")

    // Clean up timers
    this.stopTimer()
    this.stopPeriodicSync()

    // Remove event listeners
    document.removeEventListener('visibilitychange', this.handleVisibilityChange.bind(this))
    window.removeEventListener('beforeunload', this.handleBeforeUnload.bind(this))
  }

  // Start multimedia session
  startSession() {
    console.log("Starting multimedia session")

    this.showLoadingState("Starting session...")

    fetch(this.startUrlValue, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({
        user_id: this.userIdValue
      })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        // Update local state
        this.isRunning = true
        this.remainingSeconds = data.remaining_minutes * 60
        this.updateUsedMinutes(data.used_minutes || 0)

        // Start the timer
        this.startTimer()
        this.updateDisplay()
        this.updateButtonStates()
        this.clearWarning()

        // Show success message
        this.showSuccessMessage("Session started! Timer is now running.")

        console.log("Session started successfully")
      } else {
        this.showErrorMessage(data.error || "Failed to start session")
      }
    })
    .catch(error => {
      console.error("Error starting session:", error)
      this.showErrorMessage("Network error - please try again")
    })
    .finally(() => {
      this.hideLoadingState()
    })
  }

  // Stop multimedia session
  stopSession() {
    console.log("Stopping multimedia session")

    this.showLoadingState("Stopping session...")

    fetch(this.stopUrlValue, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({
        user_id: this.userIdValue
      })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        // Update local state
        this.isRunning = false
        this.remainingSeconds = data.remaining_minutes * 60
        this.updateUsedMinutes(data.used_minutes)

        // Stop the timer
        this.stopTimer()
        this.updateDisplay()
        this.updateButtonStates()
        this.clearWarning()

        // Show success message
        this.showSuccessMessage("Session stopped. Time saved to your daily usage.")

        console.log("Session stopped successfully")
      } else {
        this.showErrorMessage(data.error || "Failed to stop session")
      }
    })
    .catch(error => {
      console.error("Error stopping session:", error)
      this.showErrorMessage("Network error - please try again")
    })
    .finally(() => {
      this.hideLoadingState()
    })
  }

  // Start the countdown timer
  startTimer() {
    if (this.intervalId) {
      clearInterval(this.intervalId)
    }

    this.intervalId = setInterval(() => {
      if (this.remainingSeconds > 0) {
        this.remainingSeconds--
        this.updateDisplay()
        this.updateProgressBar()
        this.checkForWarnings()
      } else {
        // Time expired
        this.handleTimeExpired()
      }
    }, 1000)

    console.log("Timer started")
  }

  // Stop the countdown timer
  stopTimer() {
    if (this.intervalId) {
      clearInterval(this.intervalId)
      this.intervalId = null
    }

    console.log("Timer stopped")
  }

  // Handle time expiration
  handleTimeExpired() {
    console.log("Time expired!")

    this.stopTimer()
    this.isRunning = false
    this.remainingSeconds = 0

    this.updateDisplay()
    this.updateButtonStates()
    this.showDangerMessage("Your multimedia time has expired for today!")

    // Auto-stop the session
    this.stopSession()
  }

  // Update the display elements
  updateDisplay() {
    const minutes = Math.floor(this.remainingSeconds / 60)
    const seconds = this.remainingSeconds % 60
    const timeString = `${minutes}:${seconds.toString().padStart(2, '0')}`

    // Update remaining time display
    if (this.hasRemainingTimeTarget) {
      this.remainingTimeTarget.textContent = timeString
    }

    // Update main timer display
    if (this.hasTimerTarget) {
      this.timerTarget.textContent = timeString

      // Update timer styling based on remaining time
      this.timerTarget.classList.remove(...this.dangerClasses, ...this.warningClasses, ...this.successClasses)

      if (this.remainingSeconds <= 60) { // Last minute
        this.timerTarget.classList.add(...this.dangerClasses)
      } else if (this.remainingSeconds <= 300) { // Last 5 minutes
        this.timerTarget.classList.add(...this.warningClasses)
      } else {
        this.timerTarget.classList.add(...this.successClasses)
      }
    }

    // Update session status
    if (this.hasSessionStatusTarget) {
      this.sessionStatusTarget.textContent = this.isRunning ? "Active" : "Stopped"
      this.sessionStatusTarget.classList.toggle("text-green-600", this.isRunning)
      this.sessionStatusTarget.classList.toggle("text-gray-600", !this.isRunning)
    }
  }

  // Update progress bar
  updateProgressBar() {
    if (!this.hasProgressBarTarget || !this.dailyAllowanceValue) return

    const totalSeconds = this.dailyAllowanceValue * 60
    const usedSeconds = totalSeconds - this.remainingSeconds
    const percentage = Math.min((usedSeconds / totalSeconds) * 100, 100)

    this.progressBarTarget.style.width = `${percentage}%`

    // Update progress bar color based on usage
    this.progressBarTarget.classList.remove('bg-green-500', 'bg-yellow-500', 'bg-red-500')

    if (percentage >= 90) {
      this.progressBarTarget.classList.add('bg-red-500')
    } else if (percentage >= 70) {
      this.progressBarTarget.classList.add('bg-yellow-500')
    } else {
      this.progressBarTarget.classList.add('bg-green-500')
    }

    // Update progress text
    if (this.hasProgressTextTarget) {
      this.progressTextTarget.textContent = `${percentage.toFixed(1)}% used`
    }
  }

  // Update button states
  updateButtonStates() {
    if (this.hasStartButtonTarget) {
      this.startButtonTarget.disabled = this.isRunning || this.remainingSeconds <= 0
      this.startButtonTarget.classList.toggle('opacity-50', this.startButtonTarget.disabled)
    }

    if (this.hasStopButtonTarget) {
      this.stopButtonTarget.disabled = !this.isRunning
      this.stopButtonTarget.classList.toggle('opacity-50', this.stopButtonTarget.disabled)
    }
  }

  // Check for and display warnings
  checkForWarnings() {
    const minutes = Math.floor(this.remainingSeconds / 60)

    if (this.remainingSeconds === 60) { // 1 minute warning
      this.showWarningMessage("⚠️ Only 1 minute remaining!")
      this.flashTimer()
    } else if (this.remainingSeconds === 300) { // 5 minute warning
      this.showWarningMessage("⚠️ Only 5 minutes remaining!")
    } else if (this.remainingSeconds === 900) { // 15 minute warning
      this.showWarningMessage("⚠️ 15 minutes remaining!")
    }
  }

  // Flash the timer for urgent warnings
  flashTimer() {
    if (!this.hasTimerTarget) return

    let flashCount = 0
    const flashInterval = setInterval(() => {
      this.timerTarget.style.opacity = this.timerTarget.style.opacity === '0.3' ? '1' : '0.3'
      flashCount++

      if (flashCount >= 6) { // Flash 3 times
        clearInterval(flashInterval)
        this.timerTarget.style.opacity = '1'
      }
    }, 300)
  }

  // Start periodic sync with server
  startPeriodicSync() {
    this.updateIntervalId = setInterval(() => {
      this.syncWithServer()
    }, this.autoRefreshIntervalValue)
  }

  // Stop periodic sync
  stopPeriodicSync() {
    if (this.updateIntervalId) {
      clearInterval(this.updateIntervalId)
      this.updateIntervalId = null
    }
  }

  // Sync state with server
  syncWithServer() {
    if (!this.updateUrlValue) return

    fetch(this.updateUrlValue, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      }
    })
    .then(response => response.json())
    .then(data => {
      // Update state from server
      const serverRemaining = data.remaining_minutes * 60
      const timeDiff = Math.abs(this.remainingSeconds - serverRemaining)

      // Only sync if there's a significant difference (more than 30 seconds)
      if (timeDiff > 30) {
        console.log("Syncing timer with server:", serverRemaining)
        this.remainingSeconds = serverRemaining
        this.updateDisplay()
        this.updateProgressBar()
      }

      // Update running state
      if (this.isRunning !== data.is_active) {
        this.isRunning = data.is_active
        if (this.isRunning) {
          this.startTimer()
        } else {
          this.stopTimer()
        }
        this.updateButtonStates()
      }

      // Update internet status
      this.updateInternetStatus(data.internet_enabled)
    })
    .catch(error => {
      console.warn("Sync failed:", error)
    })
  }

  // Handle visibility changes (tab switching)
  handleVisibilityChange() {
    if (document.hidden) {
      // Tab is hidden - reduce update frequency
      this.stopPeriodicSync()
      this.updateIntervalId = setInterval(() => {
        this.syncWithServer()
      }, this.autoRefreshIntervalValue * 3) // Every 3 minutes when hidden
    } else {
      // Tab is visible - resume normal updates
      this.stopPeriodicSync()
      this.startPeriodicSync()
      this.syncWithServer() // Immediate sync when returning to tab
    }
  }

  // Handle page unload warning
  handleBeforeUnload(event) {
    if (this.isRunning) {
      event.preventDefault()
      event.returnValue = "You have an active multimedia session. Leaving this page won't stop your timer."
      return event.returnValue
    }
  }

  // Update internet status display
  updateInternetStatus(enabled) {
    if (!this.hasInternetStatusTarget) return

    this.internetStatusTarget.textContent = enabled ? "Connected" : "Blocked"
    this.internetStatusTarget.classList.toggle("text-green-600", enabled)
    this.internetStatusTarget.classList.toggle("text-red-600", !enabled)
  }

  // Update used minutes display
  updateUsedMinutes(usedMinutes) {
    this.usedMinutesValue = usedMinutes

    if (this.hasUsedTimeTarget) {
      const hours = Math.floor(usedMinutes / 60)
      const mins = usedMinutes % 60
      const timeString = hours > 0 ? `${hours}h ${mins}m` : `${mins}m`
      this.usedTimeTarget.textContent = timeString
    }
  }

  // Message display methods
  showLoadingState(message) {
    if (this.hasWarningMessageTarget) {
      this.warningMessageTarget.className = "text-blue-600 font-medium"
      this.warningMessageTarget.textContent = message
    }
  }

  hideLoadingState() {
    if (this.hasWarningMessageTarget) {
      this.clearWarning()
    }
  }

  showSuccessMessage(message) {
    if (this.hasWarningMessageTarget) {
      this.warningMessageTarget.className = "text-green-600 font-medium"
      this.warningMessageTarget.textContent = message

      // Clear success message after 5 seconds
      setTimeout(() => this.clearWarning(), 5000)
    }
  }

  showWarningMessage(message) {
    if (this.hasWarningMessageTarget) {
      this.warningMessageTarget.className = "text-yellow-600 font-medium"
      this.warningMessageTarget.textContent = message
    }
  }

  showDangerMessage(message) {
    if (this.hasWarningMessageTarget) {
      this.warningMessageTarget.className = "text-red-600 font-bold"
      this.warningMessageTarget.textContent = message
    }
  }

  showErrorMessage(message) {
    if (this.hasWarningMessageTarget) {
      this.warningMessageTarget.className = "text-red-600 font-medium"
      this.warningMessageTarget.textContent = `Error: ${message}`

      // Clear error message after 10 seconds
      setTimeout(() => this.clearWarning(), 10000)
    }
  }

  clearWarning() {
    if (this.hasWarningMessageTarget) {
      this.warningMessageTarget.textContent = ""
    }
  }

  // Action methods for button clicks
  start() {
    this.startSession()
  }

  stop() {
    this.stopSession()
  }

  refresh() {
    this.syncWithServer()
  }
}