# ScreenShader: Custom screen color effects for macOS

ScreenShader is a simple macOS utility that applies a user-specified fragment shader (color effect) to the screen. This provides more control than existing apps, which provide a fixed set of color effects.

The app works by taking a live screen capture of the full screen, applying the shader effect, and then rendering it to a full screen overlay in real time. Depending on your machine, this may result in noticeable slowdown or input delay. Feel free to log a Github issue if this is significant on your machine.

## Examples

Swap the red and blue color channels:

![swap red and blue](https://github.com/branpk/ScreenShader/raw/main/images/red_blue_swap.png)

Time and position-dependent waves:

![waves](https://github.com/branpk/ScreenShader/raw/main/images/waves.gif)

## Download

The latest version can be downloaded from the [Releases](https://github.com/branpk/ScreenShader/releases/) page. Download `ScreenShader-x.x.x.zip`, unzip it, and copy it to your Applications folder. (You may also run it from your Downloads folder, but it won't receive updates.)

When you first open the app, it will ask for Screen Recording permissions (since it needs to capture the contents of the screen so that it can re-render with effects applied). To provide these permissions:

1. Open System Settings > Privacy & Security > Screen Recording
2. If ScreenShader is not already listed, press the "+" button and navigate to the app
3. Ensure that the toggle is enabled
4. Open the ScreenShader app again

(If the popup appears again, try removing ScreenShader from the list using the "-" button and adding it again.)

![select effect and activate](https://github.com/branpk/ScreenShader/raw/main/images/screen_recording.png)

## Usage

Clicking on the app icon in the dock will open the Settings window, where you can select a pre-defined effect and activate it by clicking the checkbox:

![select effect and activate](https://github.com/branpk/ScreenShader/raw/main/images/select_activate.png)

The effect should now be visible. You can toggle it without opening the Settings window first by left clicking on the paintbrush icon in the menu bar:

![toggle menu bar icon](https://github.com/branpk/ScreenShader/raw/main/images/toggle.png)

## Platform support

- macOS 13.0 or later
- M1 or later (may work with Intel, but untested)

I have only tested on my own machine, so please log a Github issue if you run into problems!

## License

ScreenShader is licensed under the Apache-2.0 license OR MIT license.
