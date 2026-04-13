// Wait till the browser is ready to render the game (avoids glitches)
window.requestAnimationFrame(function () {
  Logger.info("App", "2048 application starting");
  new GameManager(4, KeyboardInputManager, HTMLActuator, LocalStorageManager);
  Logger.info("App", "2048 application ready");
});
