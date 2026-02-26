import AVFoundation
import Flutter
import Foundation

final class PitchTranslatorAudioPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static let frameChannelName = "pt/audio/frames"
  private static let controlChannelName = "pt/audio/control"

  private let engine = AVAudioEngine()
  private let session = AVAudioSession.sharedInstance()
  private let stateQueue = DispatchQueue(label: "pt.audio.ios.state")
  private let emitQueue = DispatchQueue(label: "pt.audio.ios.emit")

  private var eventSink: FlutterEventSink?
  private var dspHandle: OpaquePointer?
  private var isRunning = false
  private var sampleRate: Int32 = 48_000
  private var hopSize: Int32 = 256

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = PitchTranslatorAudioPlugin()

    let control = FlutterMethodChannel(
      name: controlChannelName,
      binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: control)

    let frames = FlutterEventChannel(
      name: frameChannelName,
      binaryMessenger: registrar.messenger())
    frames.setStreamHandler(instance)

    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(instance.onInterruption(_:)),
      name: AVAudioSession.interruptionNotification,
      object: nil)
    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(instance.onRouteChange(_:)),
      name: AVAudioSession.routeChangeNotification,
      object: nil)
    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(instance.onForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    stopCapture()
  }

  func onListen(withArguments _: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments _: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      do {
        try startCapture()
        result(nil)
      } catch {
        result(FlutterError(code: "audio_start_failed", message: error.localizedDescription, details: nil))
      }
    case "stop":
      stopCapture()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startCapture() throws {
    if isRunning { return }

    try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .allowBluetooth])
    try session.setPreferredIOBufferDuration(0.005)
    try session.setPreferredSampleRate(48_000)
    try session.setActive(true, options: .notifyOthersOnDeactivation)

    let format = engine.inputNode.inputFormat(forBus: 0)
    sampleRate = Int32(format.sampleRate)
    hopSize = 256

    dspHandle = pt_dsp_make(sampleRate, hopSize)
    guard dspHandle != nil else {
      throw NSError(domain: "pt.audio", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize DSP handle"])
    }

    engine.inputNode.removeTap(onBus: 0)
    engine.inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(hopSize), format: format) { [weak self] buffer, _ in
      self?.processAudio(buffer: buffer)
    }

    engine.prepare()
    try engine.start()
    isRunning = true
  }

  private func stopCapture() {
    stateQueue.sync {
      guard isRunning else { return }
      engine.inputNode.removeTap(onBus: 0)
      engine.stop()
      pt_dsp_free(dspHandle)
      dspHandle = nil
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      isRunning = false
    }
  }

  private func processAudio(buffer: AVAudioPCMBuffer) {
    guard let sink = eventSink,
          let dsp = dspHandle,
          let channel = buffer.floatChannelData?.pointee else { return }

    let frameCount = Int32(buffer.frameLength)
    let frame = pt_dsp_run(dsp, channel, frameCount)

    emitQueue.async { [weak self] in
      guard self?.isRunning == true else { return }
      sink([
        "timestamp_ms": Int(frame.timestamp_ms),
        "freq_hz": frame.freq_hz.isFinite ? frame.freq_hz : NSNull(),
        "midi_float": frame.midi_float.isFinite ? frame.midi_float : NSNull(),
        "nearest_midi": frame.nearest_midi >= 0 ? frame.nearest_midi : NSNull(),
        "cents_error": frame.cents_error.isFinite ? frame.cents_error : NSNull(),
        "confidence": min(1.0, max(0.0, frame.confidence.isFinite ? frame.confidence : 0.0)),
        "vibrato": [
          "detected": frame.vibrato_detected,
          "rate_hz": frame.vibrato_rate_hz.isFinite ? frame.vibrato_rate_hz : NSNull(),
          "depth_cents": frame.vibrato_depth_cents.isFinite ? frame.vibrato_depth_cents : NSNull(),
        ],
      ])
    }
  }

  @objc private func onInterruption(_ notification: Notification) {
    guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }

    if type == .began {
      stopCapture()
      return
    }

    if type == .ended {
      try? startCapture()
    }
  }

  @objc private func onRouteChange(_ notification: Notification) {
    guard let reasonRaw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else { return }

    if reason == .oldDeviceUnavailable || reason == .newDeviceAvailable {
      stopCapture()
      try? startCapture()
    }
  }

  @objc private func onForeground() {
    if isRunning {
      try? startCapture()
    }
  }
}
