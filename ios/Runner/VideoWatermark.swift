import AVFoundation
import CoreGraphics
import CoreImage
import CoreText
import Foundation
#if canImport(Flutter)
import Flutter
import UIKit
#endif

/// Imprime la marca de agua (fecha, hora, coordenadas y enlace de Maps) en un
/// video y lo reduce a 720p en una sola pasada, con AVFoundation.
///
/// Reemplaza al plugin video_compress. No depende de Flutter para poder
/// probarse en la Mac; el canal está en `VideoWatermarkPlugin`, abajo.
final class VideoWatermarker {
  enum Failure: LocalizedError {
    case noVideoTrack
    case cannotExport
    case export(String)

    var errorDescription: String? {
      switch self {
      case .noVideoTrack: return "El archivo no tiene pista de video"
      case .cannotExport: return "El sistema no puede exportar este video"
      case .export(let message): return message
      }
    }
  }

  private let ciContext = CIContext()
  private var session: AVAssetExportSession?

  /// Avance de 0 a 1 mientras exporta.
  var progress: Float { session?.progress ?? 0 }

  func cancel() { session?.cancelExport() }

  func process(
    input: URL,
    output: URL,
    lines: [String],
    maxShortSide: CGFloat,
    location: (lat: Double, lng: Double)?,
    completion: @escaping (Result<URL, Error>) -> Void
  ) {
    let asset = AVURLAsset(url: input)
    asset.loadValuesAsynchronously(forKeys: ["tracks", "duration"]) { [self] in
      var error: NSError?
      guard asset.statusOfValue(forKey: "tracks", error: &error) == .loaded,
            let track = asset.tracks(withMediaType: .video).first
      else {
        completion(.failure(error ?? Failure.noVideoTrack))
        return
      }

      // Tamaño tal como se ve (un video vertical del iPhone viene acostado
      // con una rotación en preferredTransform).
      let rect = CGRect(origin: .zero, size: track.naturalSize).applying(track.preferredTransform)
      let upright = CGSize(width: abs(rect.width), height: abs(rect.height))
      guard upright.width > 0, upright.height > 0 else {
        completion(.failure(Failure.noVideoTrack))
        return
      }
      let shortSide = min(upright.width, upright.height)
      let scale = shortSide > maxShortSide ? maxShortSide / shortSide : 1
      let render = CGSize(width: Self.even(upright.width * scale), height: Self.even(upright.height * scale))
      let overlay = Self.overlay(lines: lines, frame: render)
      let context = ciContext

      // Con filtros de Core Image cada cuadro llega ya derecho; sólo se escala
      // y se le pone encima la franja.
      let composition = AVMutableVideoComposition(asset: asset) { request in
        var frame = request.sourceImage
        let extent = frame.extent
        frame = frame
          .transformed(by: CGAffineTransform(translationX: -extent.origin.x, y: -extent.origin.y))
          .transformed(by: CGAffineTransform(scaleX: render.width / extent.width, y: render.height / extent.height))
        if let overlay { frame = overlay.composited(over: frame) }
        request.finish(with: frame.cropped(to: CGRect(origin: .zero, size: render)), context: context)
      }
      composition.renderSize = render

      // El preset de calidad alta no vuelve a escalar: respeta renderSize,
      // también en vertical.
      guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
        completion(.failure(Failure.cannotExport))
        return
      }
      try? FileManager.default.removeItem(at: output)
      session.outputURL = output
      session.outputFileType = .mp4
      session.shouldOptimizeForNetworkUse = true
      session.videoComposition = composition
      if let location {
        let item = AVMutableMetadataItem()
        item.identifier = .quickTimeMetadataLocationISO6709
        item.dataType = kCMMetadataBaseDataType_UTF8 as String
        item.value = String(format: "%+08.4f%+09.4f/", location.lat, location.lng) as NSString
        session.metadata = [item]
      }
      self.session = session
      session.exportAsynchronously {
        switch session.status {
        case .completed:
          completion(.success(output))
        default:
          try? FileManager.default.removeItem(at: output)
          completion(.failure(Failure.export(session.error?.localizedDescription ?? "Exportación cancelada")))
        }
      }
    }
  }

  private static func even(_ v: CGFloat) -> CGFloat { max(2, (v / 2).rounded() * 2) }

  /// Franja semitransparente con los renglones, del mismo estilo que la de
  /// las fotos (`drawWatermark` en watermark.dart): ~50 % del ancho (75 % en
  /// vertical), abajo a la izquierda, enlace en azul claro.
  static func overlay(lines: [String], frame: CGSize) -> CIImage? {
    guard !lines.isEmpty, frame.width > 0 else { return nil }
    let colors = [CGColor(red: 1, green: 1, blue: 1, alpha: 1), CGColor(red: 150 / 255, green: 200 / 255, blue: 1, alpha: 1)]

    func line(_ text: String, size: CGFloat, color: CGColor) -> CTLine {
      let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
      let attributes = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color] as CFDictionary
      return CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, text as CFString, attributes)!)
    }

    // Ancho del texto a 40 pt para sacar el tamaño que ocupa la parte deseada.
    let base: CGFloat = 40
    let widest = lines.map { CGFloat(CTLineGetTypographicBounds(line($0, size: base, color: colors[0]), nil, nil, nil)) }.max() ?? 1
    // En vertical la franja ocupa más del ancho para que el enlace se lea.
    let portrait = frame.height > frame.width
    let share: CGFloat = lines.count > 1 ? (portrait ? 0.75 : 0.5) : (portrait ? 0.6 : 0.45)
    let target = min(frame.width * share, frame.width - 8)
    let size = max(8, target / (widest / base + 0.75))
    let pad = size * 0.375
    let lineHeight = size * 1.2
    let width = Int(ceil(widest * size / base + pad * 2))
    let height = Int(ceil(lineHeight * CGFloat(lines.count) + pad))

    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 150 / 255))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
    let ascent = CTFontGetAscent(font), descent = CTFontGetDescent(font)
    for (i, text) in lines.enumerated() {
      let ctLine = line(text, size: size, color: colors[min(i, colors.count - 1)])
      // Origen de Core Graphics abajo: se cuenta desde arriba y se invierte.
      let baselineFromTop = pad / 2 + CGFloat(i) * lineHeight + (lineHeight - ascent - descent) / 2 + ascent
      ctx.textPosition = CGPoint(x: pad, y: CGFloat(height) - baselineFromTop)
      CTLineDraw(ctLine, ctx)
    }
    guard let image = ctx.makeImage() else { return nil }
    let margin = (frame.width * 0.015).rounded()
    // Core Image también cuenta desde abajo: (margen, margen) es la esquina
    // inferior izquierda.
    return CIImage(cgImage: image).transformed(by: CGAffineTransform(translationX: margin, y: margin))
  }
}

#if canImport(Flutter)
/// Canal `solaris/video`: `process` recibe id, input, output, lines,
/// maxShortSide y opcionalmente lat/lng; contesta la ruta del video o un
/// error. Mientras trabaja manda `progress` con id y value (0–1).
final class VideoWatermarkPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel
  private var jobs: [String: VideoWatermarker] = [:]

  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "solaris/video", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(VideoWatermarkPlugin(channel: channel), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "process" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let args = call.arguments as? [String: Any],
          let id = args["id"] as? String,
          let input = args["input"] as? String,
          let output = args["output"] as? String
    else {
      result(FlutterError(code: "args", message: "Faltan datos para procesar el video", details: nil))
      return
    }
    let lines = args["lines"] as? [String] ?? []
    let maxShortSide = CGFloat((args["maxShortSide"] as? NSNumber)?.doubleValue ?? 720)
    var location: (lat: Double, lng: Double)?
    if let lat = (args["lat"] as? NSNumber)?.doubleValue, let lng = (args["lng"] as? NSNumber)?.doubleValue {
      location = (lat, lng)
    }

    let job = VideoWatermarker()
    jobs[id] = job

    // Si la app pasa a segundo plano, iOS da unos segundos para terminar.
    var background = UIBackgroundTaskIdentifier.invalid
    background = UIApplication.shared.beginBackgroundTask(withName: "solaris-video") {
      job.cancel()
    }
    let timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self, weak job] _ in
      guard let job else { return }
      self?.channel.invokeMethod("progress", arguments: ["id": id, "value": Double(job.progress)])
    }

    job.process(
      input: URL(fileURLWithPath: input),
      output: URL(fileURLWithPath: output),
      lines: lines,
      maxShortSide: maxShortSide,
      location: location
    ) { [weak self] outcome in
      DispatchQueue.main.async {
        timer.invalidate()
        self?.jobs[id] = nil
        if background != .invalid {
          UIApplication.shared.endBackgroundTask(background)
          background = .invalid
        }
        switch outcome {
        case .success(let url):
          result(url.path)
        case .failure(let error):
          result(FlutterError(code: "video", message: error.localizedDescription, details: nil))
        }
      }
    }
  }
}
#endif
