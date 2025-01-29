import AppKit

let defaultShaderSource: String = """
  /*
  These are the inputs provided to the shader:

  struct ShaderInput {
    // A texture containing the input screen capture data.
    texture2d<float> inputTexture;
    // The texture coordinates for indexing into inputTexture at the current
    // position.
    float2 texCoord;
  };
  */

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

let predefinedShaders: [String: String] = [
  "Swap red-blue channels": """
  float4 shaderFunction(ShaderInput in) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float4 inputColor = in.inputTexture.sample(s, in.texCoord);
    return float4(inputColor.b, inputColor.g, inputColor.r, inputColor.a);
  }
  """,
  "Grey scale": """
  float4 shaderFunction(ShaderInput in) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float4 inputColor = in.inputTexture.sample(s, in.texCoord);
    float grey = dot(inputColor.rgb, float3(0.299, 0.587, 0.114));
    return float4(grey, grey, grey, inputColor.a);
  }
  """,
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
