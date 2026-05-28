import Flutter
import UIKit
import AVFoundation
import SoundAnalysis

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let clapStreamHandler = ClapEventStreamHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let clapEvents = FlutterEventChannel(
        name: "hand_camera/clap_events",
        binaryMessenger: controller.binaryMessenger
      )
      clapEvents.setStreamHandler(clapStreamHandler)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

private protocol ClapDetector {
  func stop()
}

private final class ClapEventStreamHandler: NSObject, FlutterStreamHandler {
  private var detector: ClapDetector?

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    if #available(iOS 15.0, *) {
      let detector = SoundAnalysisClapDetector(eventSink: events)
      self.detector = detector
      detector.start()
      return nil
    }

    return FlutterError(
      code: "unsupported_ios_version",
      message: "SoundAnalysis built-in classifier requires iOS 15 or later.",
      details: nil
    )
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    detector?.stop()
    detector = nil
    return nil
  }
}

@available(iOS 15.0, *)
private final class SoundAnalysisClapDetector: NSObject, ClapDetector, SNResultsObserving {
  private let audioEngine = AVAudioEngine()
  private let analysisQueue = DispatchQueue(label: "hand_camera.sound_analysis")
  private let eventSink: FlutterEventSink
  private var streamAnalyzer: SNAudioStreamAnalyzer?
  private var request: SNClassifySoundRequest?
  private var lastTriggerDate = Date.distantPast

  private let triggerCooldown: TimeInterval = 4
  private let minimumConfidence: Double = 0.35
  private let clapIdentifiers = [
    "clapping",
    "applause",
    "hands",
    "finger_snapping",
    "finger snapping",
    "snap",
  ]

  init(eventSink: @escaping FlutterEventSink) {
    self.eventSink = eventSink
    super.init()
  }

  func start() {
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers])
      try audioSession.setActive(true, options: [])

      let inputNode = audioEngine.inputNode
      let inputFormat = inputNode.outputFormat(forBus: 0)
      let analyzer = SNAudioStreamAnalyzer(format: inputFormat)
      let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
      request.windowDuration = CMTimeMakeWithSeconds(0.5, preferredTimescale: 48_000)
      request.overlapFactor = 0.75
      try analyzer.add(request, withObserver: self)

      inputNode.removeTap(onBus: 0)
      inputNode.installTap(
        onBus: 0,
        bufferSize: 8_192,
        format: inputFormat
      ) { [weak self] buffer, audioTime in
        self?.analysisQueue.async {
          self?.streamAnalyzer?.analyze(buffer, atAudioFramePosition: audioTime.sampleTime)
        }
      }

      streamAnalyzer = analyzer
      self.request = request
      audioEngine.prepare()
      try audioEngine.start()
    } catch {
      eventSink(
        FlutterError(
          code: "sound_analysis_start_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  func stop() {
    audioEngine.inputNode.removeTap(onBus: 0)
    audioEngine.stop()
    streamAnalyzer?.removeAllRequests()
    streamAnalyzer = nil
    request = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
  }

  func request(_ request: SNRequest, didProduce result: SNResult) {
    guard let result = result as? SNClassificationResult,
          let classification = result.classifications.first else {
      return
    }

    let identifier = classification.identifier.lowercased()
    let confidence = classification.confidence
    let isClap = clapIdentifiers.contains { identifier.contains($0) }
    guard isClap, confidence >= minimumConfidence else {
      return
    }

    let now = Date()
    guard now.timeIntervalSince(lastTriggerDate) >= triggerCooldown else {
      return
    }

    lastTriggerDate = now
    DispatchQueue.main.async { [eventSink] in
      eventSink([
        "label": classification.identifier,
        "confidence": confidence,
      ])
    }
  }

  func request(_ request: SNRequest, didFailWithError error: Error) {
    DispatchQueue.main.async { [eventSink] in
      eventSink(
        FlutterError(
          code: "sound_analysis_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  func requestDidComplete(_ request: SNRequest) {}
}
