/**
 * Logger - Lightweight logging utility for the 2048 game.
 *
 * Log levels: DEBUG (0), INFO (1), WARN (2), ERROR (3), NONE (4)
 *
 * Usage:
 *   Logger.info("Game", "Player moved up");
 *   Logger.debug("Grid", "Cell available at", {x: 1, y: 2});
 *   Logger.warn("Storage", "localStorage not supported, using fallback");
 *   Logger.error("Storage", "Failed to parse game state", err);
 *
 * Configuration:
 *   Logger.setLevel("DEBUG");   // Show all logs
 *   Logger.setLevel("WARN");    // Show only warnings and errors
 *   Logger.setLevel("NONE");    // Disable all logging
 */
window.Logger = (function () {
  var LEVELS = {
    DEBUG: 0,
    INFO:  1,
    WARN:  2,
    ERROR: 3,
    NONE:  4
  };

  // Read level from runtime config (injected by entrypoint.sh) or default to INFO
  var configLevel = (window.__CONFIG__ && window.__CONFIG__.LOG_LEVEL) || "INFO";
  var currentLevel = LEVELS.hasOwnProperty(configLevel) ? LEVELS[configLevel] : LEVELS.INFO;

  var DIRECTION_MAP = {
    0: "up",
    1: "right",
    2: "down",
    3: "left"
  };

  function timestamp() {
    return new Date().toISOString();
  }

  function formatArgs(args) {
    return Array.prototype.slice.call(args);
  }

  function sendToServer(levelName, category, message, ts) {
    try {
      var xhr = new XMLHttpRequest();
      xhr.open("POST", "/log", true);
      xhr.setRequestHeader("Content-Type", "application/json");
      xhr.send(JSON.stringify({
        level: levelName,
        category: category,
        message: message,
        timestamp: ts
      }));
    } catch (e) {
      // Fire-and-forget — don't break the app if this fails
    }
  }

  function log(level, levelName, category, args) {
    if (level < currentLevel) return;

    var ts = timestamp();
    var message = formatArgs(args).join(" ");
    var prefix = "[" + ts + "] [" + levelName + "] [" + category + "]";
    var params = [prefix].concat(formatArgs(args));

    // Log to browser console
    switch (level) {
      case LEVELS.ERROR:
        console.error.apply(console, params);
        break;
      case LEVELS.WARN:
        console.warn.apply(console, params);
        break;
      case LEVELS.INFO:
        console.info.apply(console, params);
        break;
      default:
        console.log.apply(console, params);
        break;
    }

    // Forward to server for container logs
    sendToServer(levelName, category, message, ts);
  }

  return {
    LEVELS: LEVELS,
    DIRECTION_MAP: DIRECTION_MAP,

    setLevel: function (levelName) {
      if (LEVELS.hasOwnProperty(levelName)) {
        currentLevel = LEVELS[levelName];
        this.info("Logger", "Log level set to " + levelName);
      }
    },

    getLevel: function () {
      for (var name in LEVELS) {
        if (LEVELS[name] === currentLevel) return name;
      }
    },

    debug: function (category) {
      log(LEVELS.DEBUG, "DEBUG", category, Array.prototype.slice.call(arguments, 1));
    },

    info: function (category) {
      log(LEVELS.INFO, "INFO", category, Array.prototype.slice.call(arguments, 1));
    },

    warn: function (category) {
      log(LEVELS.WARN, "WARN", category, Array.prototype.slice.call(arguments, 1));
    },

    error: function (category) {
      log(LEVELS.ERROR, "ERROR", category, Array.prototype.slice.call(arguments, 1));
    }
  };
})();
