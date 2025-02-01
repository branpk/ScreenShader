import AppKit

let defaultShaderSource: String = """
  /**************************************************************

  These are the inputs provided to the shader:

  struct ShaderInput {
    // A texture containing the input screen capture data.
    texture2d<float> inputTexture;
    // The texture coordinates for indexing into inputTexture at the current
    // position. The origin is at the top left of the screen.
    float2 texCoord;
    // The current position in pixels, with (0,0) at the bottom left of the
    // screen.
    float2 screenPosition;
    // The screen size in pixels.
    float2 screenSize;
    // The current position of the mouse cursor in pixels, with (0,0) at
    // the bottom left of the screen.
    float2 mousePosition;
    // The elapsed time since the system started in seconds.
    float time;
  };

  Additional utility functions:

  float2 texToScreen(float2 texCoord, float2 screenSize)
  float2 screenToTex(float2 screenPosition, float2 screenSize)

  **************************************************************/

  // Don't change the name or signature of this function:
  float4 shaderFunction(ShaderInput in) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float4 inputColor = in.inputTexture.sample(s, in.texCoord);

    float4 resultColor = float4(
      inputColor.r,
      inputColor.g,
      inputColor.b,
      inputColor.a
    );

    return resultColor;
  }
  """

let predefinedShaders: [(String, String)] = [
  (
    "Swap red-blue channels",
    """
    float4 shaderFunction(ShaderInput in) {
      constexpr sampler s(address::clamp_to_edge, filter::linear);
      float4 inputColor = in.inputTexture.sample(s, in.texCoord);
      return float4(inputColor.b, inputColor.g, inputColor.r, inputColor.a);
    }
    """
  ),
  (
    "Grey scale",
    """
    float4 shaderFunction(ShaderInput in) {
      constexpr sampler s(address::clamp_to_edge, filter::linear);
      float4 inputColor = in.inputTexture.sample(s, in.texCoord);
      float grey = dot(inputColor.rgb, float3(0.299, 0.587, 0.114));
      return float4(grey, grey, grey, inputColor.a);
    }
    """
  ),
  (
    "Waves",
    """
    struct Wave {
      float angle;
      float speed;
      float amp;
      float freq;
      float flatness;
    };

    float waveHeight(Wave wave, float2 pos, float t) {
      float2 dir = float2(cos(wave.angle), sin(wave.angle));
      float phase = 2.0 * M_PI_F * wave.freq * (t - dot(pos, dir) / wave.speed);

      float r = sin(phase);
      r = (r + 1.0) * 0.5;
      r = pow(r, wave.flatness);
      return r * wave.amp;
    }

    float2 waveGradient(Wave wave, float2 pos, float t) {
        float2 dir = float2(cos(wave.angle), sin(wave.angle));
        float phase = 2.0 * M_PI_F * wave.freq * (t - dot(pos, dir) / wave.speed);

        float r = sin(phase);
        r = (r + 1.0) * 0.5;

        float dr_dp = 0.5 * cos(phase);
        float dpow_dr = wave.flatness * pow(r, wave.flatness - 1.0);
        float dphase = -2.0 * M_PI_F * wave.freq / wave.speed;

        float dr_dpos = dpow_dr * dr_dp * dphase;
        return wave.amp * dr_dpos * dir;
    }

    float4 shaderFunction(ShaderInput in) {
      constexpr sampler s(address::clamp_to_edge, filter::linear);

      Wave waves[] = {
        Wave {
          .angle = 2 * M_PI_F * 0.6,
          .speed = 0.5,
          .amp = 0.5,
          .freq = 0.5,
          .flatness = 1, //0.9,
        },
        Wave {
          .angle = 2 * M_PI_F * 0.9,
          .speed = 0.5,
          .amp = 0.4,
          .freq = 0.8,
          .flatness = 1, //0.7,
        },
        Wave {
          .angle = 2 * M_PI_F * 0.05,
          .speed = 0.7,
          .amp = 0.2,
          .freq = 1.2,
          .flatness = 1, //0.8,
        },
      };

      float2 pos = in.screenPosition / 300;

      float height = 0;
      float2 grad = 0;
      for (Wave wave : waves) {
        height += waveHeight(wave, pos, in.time);
        grad += waveGradient(wave, pos, in.time);
      }

      float2 screenOffset = float2(0, -20) * height;
      float2 texCoord = screenToTex(in.screenPosition + screenOffset, in.screenSize);

      float4 color = in.inputTexture.sample(s, texCoord);

      float lighting = 1 + dot(grad, float2(-1, -1)) * 0.05;

      return float4(lighting * color.rgb, 1);
    }
    """
  ),
]

class Config: Codable {
  var configVersion: Int = 1
  var effects: Effects = Effects()
  var targetFPS: Int = 60

  static func getFileURL() -> URL {
    let fileManager = FileManager.default
    let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
      .first!
    let directory = appSupportDir.appendingPathComponent("ScreenShader", isDirectory: true)

    if !fileManager.fileExists(atPath: directory.path) {
      try? fileManager.createDirectory(
        at: directory, withIntermediateDirectories: true, attributes: nil)
    }

    return directory.appendingPathComponent("config.json")
  }

  func save() {
    do {
      let fileURL = Config.getFileURL()
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      let data = try encoder.encode(self)
      try data.write(to: fileURL)
      print("Saved config to \(fileURL)")
    } catch {
      print("Failed to save config: \(error)")
    }
  }

  static func load() -> Config {
    let fileURL = getFileURL()
    var config: Config
    if !FileManager.default.fileExists(atPath: fileURL.path) {
      print("No config file found at \(fileURL)")
      config = Config()
    } else {
      do {
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        config = try decoder.decode(Config.self, from: data)
        print("Loaded config from \(fileURL)")
      } catch {
        fatalError("Failed to load config: \(error)")
      }
    }

    if config.effects.effectList().isEmpty {
      for (name, shader) in predefinedShaders {
        let effect = config.effects.new()
        config.effects.setName(effect: effect, newName: name)
        config.effects.setShader(effect: effect, shader: shader)
      }
    }

    return config
  }
}

class Effects: Codable {
  private var nextEffectNumber: Int = 1
  private var effects: [UUID] = []
  private var deletedEffects: [UUID] = []
  private var effectToName: [UUID: String] = [:]
  private var effectToShader: [UUID: String] = [:]
  private var effectToActive: [UUID: Bool] = [:]
  private var mostRecentActiveEffect: UUID? = nil

  func effectList() -> [UUID] {
    return self.effects
  }

  func new() -> UUID {
    let newEffectID = UUID()
    let newEffectName = "Effect \(self.nextEffectNumber)"
    self.nextEffectNumber += 1

    self.effects.append(newEffectID)
    self.effectToName[newEffectID] = newEffectName
    self.effectToShader[newEffectID] = defaultShaderSource
    self.effectToActive[newEffectID] = false

    return newEffectID
  }

  func delete(effect: UUID) {
    if let index = self.effects.firstIndex(of: effect) {
      self.effects.remove(at: index)
      self.deletedEffects.append(effect)
      if self.mostRecentActiveEffect == effect {
        self.mostRecentActiveEffect = nil
      }
    }
  }

  func getName(effect: UUID) -> String {
    return self.effectToName[effect]!
  }

  func setName(effect: UUID, newName: String) {
    self.effectToName[effect] = newName
  }

  func isActive(effect: UUID) -> Bool {
    return self.effectToActive[effect]!
  }

  func setActive(effect: UUID, active: Bool) {
    if active {
      for otherEffect in self.effects {
        self.effectToActive[otherEffect] = false
      }
      self.mostRecentActiveEffect = effect
    }
    self.effectToActive[effect] = active
  }

  func toggleActive(effect: UUID) {
    let active = self.isActive(effect: effect)
    self.setActive(effect: effect, active: !active)
  }

  func getShader(effect: UUID) -> String {
    return self.effectToShader[effect]!
  }

  func setShader(effect: UUID, shader: String) {
    self.effectToShader[effect] = shader
  }

  func getActiveEffect() -> UUID? {
    for effect in self.effects {
      if self.isActive(effect: effect) {
        return effect
      }
    }
    return nil
  }

  func getMostRecentActiveEffect() -> UUID? {
    return self.mostRecentActiveEffect
  }

  func anyEffectActive() -> Bool {
    return self.getActiveEffect() != nil
  }

  func deactivateAll() {
    for effect in self.effects {
      self.setActive(effect: effect, active: false)
    }
  }

  func activateDefault() {
    if let mostRecentActiveEffect = self.mostRecentActiveEffect {
      self.setActive(effect: mostRecentActiveEffect, active: true)
    } else if self.effects.count > 0 {
      self.setActive(effect: self.effects.first!, active: true)
    }
  }
}
