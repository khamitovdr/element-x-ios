//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import Combine
import CoreImage
import Foundation
import UIKit

private nonisolated enum InternalRoundVideoRecorderState: Equatable {
    case recording
    case stopped
    case error(RoundVideoRecorderError)
}

/// Records Telegram-style round video messages: front camera + microphone captured via
/// `AVCaptureSession`, every frame centre-cropped to a square and written straight to a
/// 400×400 H.264 mp4 with `AVAssetWriter` — the recorded file is the file that gets sent.
///
/// All mutable state is confined to the serial `dispatchQueue`, which is also the sample
/// buffer delegate queue, hence `@unchecked` (mirrors `AudioRecorder`).
nonisolated class RoundVideoRecorder: NSObject, RoundVideoRecorderProtocol, @unchecked Sendable {
    private let cache: RoundVideoCacheProtocol
    private let dispatchQueue = DispatchQueue(label: "io.element.elementx.round_video_recorder", qos: .userInitiated)
    
    private let actionsSubject: PassthroughSubject<RoundVideoRecorderAction, Never> = .init()
    var actions: AnyPublisher<RoundVideoRecorderAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    // Capture
    private var session: AVCaptureSession?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    
    // Writing
    private var writer: AVAssetWriter?
    private var writerVideoInput: AVAssetWriterInput?
    private var writerAudioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var sessionStartTime: CMTime?
    private var lastVideoTime: CMTime?
    private let ciContext = CIContext()
    
    private var internalState = InternalRoundVideoRecorderState.stopped
    private var stopped = true
    private var recordingCancelled = false
    private var cancellables = Set<AnyCancellable>()
    
    private(set) var cameraPosition: RoundVideoCameraPosition = .front
    private(set) var recordingURL: URL?
    private(set) var recordingDuration: TimeInterval = 0
    var currentTime: TimeInterval = .zero
    
    var captureSession: AVCaptureSession? {
        session
    }
    
    var isRecording: Bool {
        session?.isRunning ?? false
    }
    
    init(cache: RoundVideoCacheProtocol = RoundVideoCache()) {
        self.cache = cache
    }
    
    deinit {
        cache.clearCache()
    }
    
    // MARK: - RoundVideoRecorderProtocol
    
    func startRecording() async {
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            setInternalState(.error(.cameraPermissionNotGranted))
            return
        }
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            setInternalState(.error(.microphonePermissionNotGranted))
            return
        }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            dispatchQueue.async { [weak self] in
                defer { continuation.resume() }
                guard let self else { return }
                do {
                    try startCapture()
                    setInternalState(.recording)
                } catch let error as RoundVideoRecorderError {
                    cleanupCapture()
                    setInternalState(.error(error))
                } catch {
                    MXLog.error("Failed to start round video recording. \(error)")
                    cleanupCapture()
                    setInternalState(.error(.configurationFailure))
                }
            }
        }
    }
    
    func stopRecording() async {
        await withCheckedContinuation { continuation in
            dispatchQueue.async { [weak self] in
                guard let self, !stopped else {
                    continuation.resume()
                    return
                }
                stopped = true
                finishWriting {
                    continuation.resume()
                }
            }
        }
    }
    
    func cancelRecording() async {
        // Raise the flag first so stopping doesn't emit didStopRecording and open the preview.
        await withCheckedContinuation { continuation in
            dispatchQueue.async { [weak self] in
                self?.recordingCancelled = true
                continuation.resume()
            }
        }
        await stopRecording()
        await deleteRecording()
    }
    
    func deleteRecording() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            dispatchQueue.async { [weak self] in
                defer { continuation.resume() }
                guard let self else { return }
                if let recordingURL {
                    try? FileManager.default.removeItem(at: recordingURL)
                    try? FileManager.default.removeItem(at: recordingURL.deletingPathExtension().appendingPathExtension("jpeg"))
                }
                recordingURL = nil
                recordingDuration = 0
                currentTime = 0
            }
        }
    }
    
    func flipCamera() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            dispatchQueue.async { [weak self] in
                defer { continuation.resume() }
                guard let self, let session else { return }
                let newPosition = cameraPosition.flipped
                do {
                    session.beginConfiguration()
                    if let videoDeviceInput {
                        session.removeInput(videoDeviceInput)
                    }
                    try addVideoInput(to: session, position: newPosition)
                    configureVideoConnection()
                    session.commitConfiguration()
                    cameraPosition = newPosition
                } catch {
                    MXLog.error("Failed to flip the camera. \(error)")
                    session.commitConfiguration()
                }
            }
        }
    }
    
    func sendRoundVideo(timelineController: TimelineControllerProtocol) async -> Result<Void, RoundVideoRecorderError> {
        guard let recordingURL else {
            return .failure(.missingRecordingFile)
        }
        return await RoundVideoSender.send(url: recordingURL, duration: recordingDuration, timelineController: timelineController)
    }
    
    // MARK: - Capture setup (dispatchQueue only)
    
    private func startCapture() throws {
        stopped = false
        recordingCancelled = false
        currentTime = 0
        recordingDuration = 0
        sessionStartTime = nil
        lastVideoTime = nil
        
        let url = cache.urlForNewRecording()
        try? FileManager.default.removeItem(at: url)
        recordingURL = url
        
        try setupWriter(outputURL: url)
        
        let session = AVCaptureSession()
        session.sessionPreset = .vga640x480
        self.session = session
        
        try addVideoInput(to: session, position: cameraPosition)
        
        guard let microphone = AVCaptureDevice.default(for: .audio),
              let audioInput = try? AVCaptureDeviceInput(device: microphone),
              session.canAddInput(audioInput) else {
            throw RoundVideoRecorderError.configurationFailure
        }
        session.addInput(audioInput)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: dispatchQueue)
        guard session.canAddOutput(videoOutput) else { throw RoundVideoRecorderError.configurationFailure }
        session.addOutput(videoOutput)
        self.videoOutput = videoOutput
        
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: dispatchQueue)
        guard session.canAddOutput(audioOutput) else { throw RoundVideoRecorderError.configurationFailure }
        session.addOutput(audioOutput)
        
        configureVideoConnection()
        addObservers()
        
        session.startRunning()
    }
    
    private func addVideoInput(to session: AVCaptureSession, position: RoundVideoCameraPosition) throws {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position.avPosition),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            throw RoundVideoRecorderError.configurationFailure
        }
        session.addInput(input)
        videoDeviceInput = input
    }
    
    private func configureVideoConnection() {
        guard let connection = videoOutput?.connection(with: .video) else { return }
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90 // Portrait buffers.
        }
        connection.automaticallyAdjustsVideoMirroring = false
        // Mirror the front camera so the recording matches what the preview shows.
        connection.isVideoMirrored = cameraPosition == .front
    }
    
    private func setupWriter(outputURL: URL) throws {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        let dimension = RoundVideoMessage.dimension
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: dimension,
            AVVideoHeightKey: dimension,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: RoundVideoMessage.videoBitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
            ]
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        
        let attributes: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                                         kCVPixelBufferWidthKey as String: dimension,
                                         kCVPixelBufferHeightKey as String: dimension]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: attributes)
        
        let audioSettings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                                            AVSampleRateKey: 48000,
                                            AVNumberOfChannelsKey: 1,
                                            AVEncoderBitRateKey: RoundVideoMessage.audioBitrate]
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true
        
        guard writer.canAdd(videoInput), writer.canAdd(audioInput) else {
            throw RoundVideoRecorderError.writerFailure
        }
        writer.add(videoInput)
        writer.add(audioInput)
        
        guard writer.startWriting() else {
            throw RoundVideoRecorderError.writerFailure
        }
        
        self.writer = writer
        writerVideoInput = videoInput
        writerAudioInput = audioInput
        pixelBufferAdaptor = adaptor
    }
    
    private func finishWriting(completion: @escaping @Sendable () -> Void) {
        session?.stopRunning()
        removeObservers()
        
        guard let writer, writer.status == .writing, sessionStartTime != nil else {
            cleanupCapture()
            setInternalState(.stopped)
            completion()
            return
        }
        
        writerVideoInput?.markAsFinished()
        writerAudioInput?.markAsFinished()
        
        recordingDuration = currentTime
        
        writer.finishWriting { [weak self] in
            guard let self else {
                completion()
                return
            }
            dispatchQueue.async { [weak self] in
                defer { completion() }
                // Re-read from the stored property rather than capturing the outer
                // `writer` local, which would carry the non-Sendable AVAssetWriter
                // across this @Sendable dispatch closure.
                guard let self, let writer = self.writer else { return }
                if writer.status != .completed {
                    MXLog.error("Round video writer failed: \(String(describing: writer.error))")
                    setInternalState(.error(.writerFailure))
                } else {
                    setInternalState(.stopped)
                }
                cleanupCapture()
            }
        }
    }
    
    private func cleanupCapture() {
        session?.stopRunning()
        session = nil
        videoDeviceInput = nil
        videoOutput = nil
        writer = nil
        writerVideoInput = nil
        writerAudioInput = nil
        pixelBufferAdaptor = nil
        removeObservers()
    }
    
    // MARK: - Internal state
    
    private func setInternalState(_ state: InternalRoundVideoRecorderState) {
        MXLog.debug("round video recorder state: \(internalState) -> \(state)")
        internalState = state
        switch state {
        case .recording:
            actionsSubject.send(.didStartRecording)
        case .stopped:
            if recordingCancelled {
                break
            } else if let recordingURL, recordingDuration > 0 {
                actionsSubject.send(.didStopRecording(url: recordingURL, duration: recordingDuration))
            } else {
                // Nothing usable was written (e.g. stopped before the first frame) —
                // fail so the composer resets instead of waiting for a preview.
                actionsSubject.send(.didFailWithError(error: .writerFailure))
            }
        case .error(let error):
            actionsSubject.send(.didFailWithError(error: error))
        }
    }
    
    // MARK: - Observers
    
    private func addObservers() {
        removeObservers()
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                MXLog.warning("Application will resign active while recording round video.")
                guard let self else { return }
                Task { await self.stopRecording() }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: AVCaptureSession.wasInterruptedNotification)
            .sink { [weak self] _ in
                MXLog.warning("Capture session was interrupted.")
                guard let self else { return }
                Task { await self.stopRecording() }
            }
            .store(in: &cancellables)
    }
    
    private func removeObservers() {
        cancellables.removeAll()
    }
}

// MARK: - Sample buffer handling (called on dispatchQueue)

nonisolated extension RoundVideoRecorder: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !stopped, let writer, writer.status == .writing else { return }
        
        if output is AVCaptureVideoDataOutput {
            processVideoBuffer(sampleBuffer)
        } else {
            processAudioBuffer(sampleBuffer)
        }
    }
    
    private func processVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if sessionStartTime == nil {
            writer?.startSession(atSourceTime: presentationTime)
            sessionStartTime = presentationTime
        }
        
        guard let writerVideoInput, writerVideoInput.isReadyForMoreMediaData,
              let pixelBufferAdaptor, let pool = pixelBufferAdaptor.pixelBufferPool else { return }
        
        var outputBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outputBuffer)
        guard let outputBuffer else { return }
        
        // Centre-crop to a square and scale down to the output dimension.
        let image = CIImage(cvPixelBuffer: imageBuffer)
        let side = min(image.extent.width, image.extent.height)
        let cropRect = CGRect(x: (image.extent.width - side) / 2,
                              y: (image.extent.height - side) / 2,
                              width: side,
                              height: side)
        let scale = CGFloat(RoundVideoMessage.dimension) / side
        let squared = image
            .cropped(to: cropRect)
            .transformed(by: CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        ciContext.render(squared, to: outputBuffer, bounds: CGRect(x: 0, y: 0,
                                                                   width: RoundVideoMessage.dimension,
                                                                   height: RoundVideoMessage.dimension),
                         colorSpace: CGColorSpaceCreateDeviceRGB())
        
        pixelBufferAdaptor.append(outputBuffer, withPresentationTime: presentationTime)
        lastVideoTime = presentationTime
        
        if let sessionStartTime {
            currentTime = presentationTime.seconds - sessionStartTime.seconds
            if currentTime >= RoundVideoMessage.maxDuration {
                MXLog.info("Maximum round video duration reached (\(RoundVideoMessage.maxDuration)s)")
                Task { await stopRecording() }
            }
        }
    }
    
    private func processAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Don't append audio until the writer session has started with the first video frame.
        guard sessionStartTime != nil, let writerAudioInput, writerAudioInput.isReadyForMoreMediaData else { return }
        writerAudioInput.append(sampleBuffer)
    }
}
