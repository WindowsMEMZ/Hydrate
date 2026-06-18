//
//  LyricsTranscriber.swift
//  Hydrate
//
//  Created by memz233 on 6/11/26.
//

import OSLog
import Speech
import Alamofire
import Foundation
import AVFoundation
import AudioToolbox

final class LyricsTranscriber {
    let player: AVPlayer
    private var transcriber: SpeechTranscriber!
    
    init(for player: AVPlayer) async {
        self.player = player
        
        if let locale = await SpeechTranscriber.supportedLocale(
            equivalentTo: .init(identifier: "ja")
        ) {
            self.transcriber = .init(
                locale: locale,
                preset: .progressiveTranscription
            )
        } else {
            os_log(.fault, """
            Failed to find a supported locale for SpeechTranscriber \
            equivalent to 'ja'
            """)
        }
    }
    
    deinit {
        player.currentItem?.audioMix = nil
    }
    
    static func ensureAssets(
        progress: UnsafeMutablePointer<Progress?>? = nil
    ) async throws {
        if let locale = await SpeechTranscriber.supportedLocale(
            equivalentTo: .init(identifier: "ja")
        ) {
            let transcriber = SpeechTranscriber(
                locale: locale,
                preset: .progressiveTranscription
            )
            if let request = try await AssetInventory.assetInstallationRequest(
                supporting: [transcriber]
            ) {
                progress?.pointee = request.progress
                try await request.downloadAndInstall()
            }
        } else {
            os_log(.fault, """
            Failed to find a supported locale for SpeechTranscriber \
            equivalent to 'ja'
            """)
        }
    }
    
    // MARK: - Realtime transcribing
    
    private var _processingFormat: AudioStreamBasicDescription?
    private var _analyzerConverter: AnalyzerInputConverter?
    private var _audioBufferStream = AsyncStream.makeStream(
        of: AnalyzerInput.self
    )
    private var transcriptionResultCallbacks: [
        (SpeechTranscriber.Result) -> Void
    ] = []
    
    /// Start transcrbing if needed, then receive results.
    ///
    /// - Parameter receiveResult:
    ///     A closure that receives transcriber's results.
    ///
    /// If transcribing process is not started, this function starts one
    /// and doesn't return before it becoming inactive.
    /// Otherwise, this function registers your `receiveResult` closure
    /// and returns immediately.
    ///
    /// Canceling the task of the first call to this function
    /// or deinitializing `LyricsTranscriber` class stops transcribing.
    func transcribe(
        receiveResult: @escaping (SpeechTranscriber.Result) -> Void
    ) async throws {
        var needsInitialize = true
        if !transcriptionResultCallbacks.isEmpty {
            needsInitialize = false
        }
        transcriptionResultCallbacks.append(receiveResult)
        if !needsInitialize { return }
        
        try ensureTranscriber()
        
        let format = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber]
        )!
        _analyzerConverter = AnalyzerInputConverter(analyzerFormat: format)
        
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: Unmanaged.passUnretained(self).toOpaque(),
            init: { _, clientInfo, storageOut in
                storageOut.pointee = clientInfo
            },
            finalize: { _ in },
            prepare: { tap, _, format in
                let storage = MTAudioProcessingTapGetStorage(tap)
                let client = Unmanaged<LyricsTranscriber>.fromOpaque(storage)
                    .takeUnretainedValue()
                client._processingFormat = format.pointee
            },
            unprepare: { _ in },
            process: {
                tap,
                numberFrames,
                flags,
                bufferListInOut,
                numberFramesOut,
                flagsOut in
                
                let status = MTAudioProcessingTapGetSourceAudio(
                    tap,
                    numberFrames,
                    bufferListInOut,
                    flagsOut,
                    nil,
                    numberFramesOut
                )
                
                if status == noErr {
                    let storage = MTAudioProcessingTapGetStorage(tap)
                    let client = Unmanaged<LyricsTranscriber>
                        .fromOpaque(storage)
                        .takeUnretainedValue()
                    client._appendBufferStream(
                        bufferList: bufferListInOut
                    )
                }
            }
        )
        
        var tap: MTAudioProcessingTap?
        MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &tap
        )
        if let tap {
            let inputParameters = AVMutableAudioMixInputParameters(
                track: try? await player.currentItem?.asset
                    .loadTracks(withMediaType: .audio).first
            )
            inputParameters.audioTapProcessor = tap
            
            let audioMix = AVMutableAudioMix()
            audioMix.inputParameters = [inputParameters]
            await MainActor.run {
                player.currentItem?.audioMix = audioMix
            }
        }
        
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.start(inputSequence: _audioBufferStream.stream)
        
        for try await result in transcriber.results {
            for callback in transcriptionResultCallbacks {
                callback(result)
            }
        }
    }
    
    private func _appendBufferStream(
        bufferList: UnsafeMutablePointer<AudioBufferList>
    ) {
        guard var _format = _processingFormat else {
            os_log(.fault, "processingFormat is unexpectedly absent")
            return
        }
        let format = AVAudioFormat(streamDescription: &_format)!
        
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            bufferListNoCopy: bufferList
        )!
        if let inputs = try? _analyzerConverter?.convert(buffer, at: nil) {
            for input in inputs {
                _audioBufferStream.continuation.yield(input)
            }
        }
    }
    
    // MARK: - Stream transcribing
    func transcribeStream(
        _ url: URL,
        receiveResult: (SpeechTranscriber.Result) -> Void
    ) async throws {
        // We don't use the class transcriber here to make multiple calls
        // to this function works well.
        let transcriber: SpeechTranscriber
        if let locale = await SpeechTranscriber.supportedLocale(
            equivalentTo: .init(identifier: "ja")
        ) {
            transcriber = .init(
                locale: locale,
                preset: .progressiveTranscription
            )
        } else {
            throw TranscriberError.transcriberNotAvailable
        }
        
        final class ProcedureData {
            var audioStreamingFormat = AudioStreamBasicDescription()
            var audioFileStream: AudioFileStreamID?
            var analyzerConverter: AnalyzerInputConverter?
            var audioBufferStream = AsyncStream.makeStream(
                of: AnalyzerInput.self
            )
        }
        let procedureDataPtr = UnsafeMutablePointer<ProcedureData>
            .allocate(capacity: 1)
        procedureDataPtr.initialize(to: ProcedureData())
        defer {
            procedureDataPtr.deinitialize(count: 1)
            procedureDataPtr.deallocate()
        }
        
        let format = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber]
        )!
        procedureDataPtr.pointee.analyzerConverter = AnalyzerInputConverter(
            analyzerFormat: format
        )
        
        let dataStream = AsyncStream.makeStream(of: Data.self)
        defer { dataStream.continuation.finish() }
        var magicContinuation: CheckedContinuation<Data, any Error>?
        
        AF.streamRequest(url, headers: globalRequestHeaders)
            .responseStream { stream in
                switch stream.event {
                case .stream(let data):
                    if let continuation = magicContinuation {
                        magicContinuation = nil
                        continuation.resume(returning: data.get())
                    }
                    dataStream.continuation.yield(with: data)
                case .complete(let completion):
                    if let error = completion.error,
                       let continuation = magicContinuation {
                        magicContinuation = nil
                        continuation.resume(throwing: error)
                    }
                }
            }
        
        let _firstData: Data = try await withCheckedThrowingContinuation {
            continuation in
            
            magicContinuation = continuation
        }
        let fileTypeHint = try { () -> AudioFileTypeID in
            let magic = Array(_firstData.prefix(4))
            switch magic {
            case let x where x.starts(with: [0x49, 0x44, 0x33])
                || x.starts(with: [0xFF, 0xFB])
                || x.starts(with: [0xFF, 0xF3])
                || x.starts(with: [0xFF, 0xF2]):
                return kAudioFileMP3Type
            case [0x52, 0x49, 0x46, 0x46]:
                return kAudioFileWAVEType
            case [0x66, 0x4C, 0x61, 0x43]:
                return kAudioFileFLACType
            case [0x46, 0x4F, 0x52, 0x4D]:
                return kAudioFileAIFFType
            default:
                os_log(.fault, """
                Pre-Transcriber failed to recognize audio stream file type: \
                \(magic.map { String(format: "0x%02X", $0) }.joined(separator: " ")) \
                (\(magic.map {
                    (32...126).contains($0)
                    ? String(Unicode.Scalar($0))
                    : "."
                }.joined()))
                """)
                throw TranscriberError.unsupportedType
            }
        }()
        
        AudioFileStreamOpen(
            UnsafeMutableRawPointer(procedureDataPtr),
            { clientData, audioFileStream, propertyID, flags in
                let data = clientData.bindMemory(
                    to: ProcedureData.self,
                    capacity: 1
                ).pointee
                
                guard let fileStream = data.audioFileStream else { return }
                
                if propertyID == kAudioFileStreamProperty_DataFormat {
                    var format = AudioStreamBasicDescription()
                    var size = UInt32(MemoryLayout.size(ofValue: format))
                    AudioFileStreamGetProperty(
                        fileStream,
                        propertyID,
                        &size,
                        &format
                    )
                    data.audioStreamingFormat = format
                }
            },
            {
                clientData,
                numberBytes,
                numberPackets,
                inputData,
                packetDescriptions in
                
                let data = clientData.bindMemory(
                    to: ProcedureData.self,
                    capacity: 1
                ).pointee
                
                guard let packetDescriptions, let format = AVAudioFormat(
                    streamDescription: &data.audioStreamingFormat
                ) else { return }
                
                let buffer = AVAudioCompressedBuffer(
                    format: format,
                    packetCapacity: numberPackets,
                    maximumPacketSize: Int(numberBytes)
                )
                buffer.byteLength = numberBytes
                buffer.packetCount = numberPackets
                buffer.data.copyMemory(
                    from: inputData,
                    byteCount: Int(numberBytes)
                )
                if let bufferDesc = buffer.packetDescriptions {
                    bufferDesc.initialize(
                        from: packetDescriptions,
                        count: Int(numberPackets)
                    )
                }
                
                if let inputs = try? data.analyzerConverter?
                    .convert(buffer, at: nil) {
                    for input in inputs {
                        data.audioBufferStream.continuation.yield(input)
                    }
                }
            },
            fileTypeHint,
            &procedureDataPtr.pointee.audioFileStream
        )
        defer {
            if let id = procedureDataPtr.pointee.audioFileStream {
                AudioFileStreamClose(id)
            }
        }
        
        let parsingStreamDataTask = Task {
            guard let fileStream = procedureDataPtr.pointee.audioFileStream
            else { return }
            
            for await data in dataStream.stream {
                if _slowPath(Task.isCancelled) {
                    return
                }
                
                data.withUnsafeBytes { ptr in
                    if let baseAddr = ptr.baseAddress {
                        let result = AudioFileStreamParseBytes(
                            fileStream,
                            UInt32(data.count),
                            baseAddr,
                            []
                        )
                        if _slowPath(result != noErr) {
                            os_log(.fault, """
                            Audio file stream failed to parse bytes \
                            at \(Int(bitPattern: baseAddr))
                            """)
                        }
                    }
                }
            }
        }
        defer { parsingStreamDataTask.cancel() }
        
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.start(
            inputSequence: procedureDataPtr.pointee.audioBufferStream.stream
        )
        
        for try await result in transcriber.results {
            if Task.isCancelled {
                return
            }
            
            receiveResult(result)
        }
    }
    
    private func ensureTranscriber() throws(TranscriberError) {
        if transcriber == nil {
            throw .transcriberNotAvailable
        }
    }
    
    enum TranscriberError: Error {
        case transcriberNotAvailable
        case unsupportedType
    }
}

extension AVMutableAudioMix: @retroactive @unchecked Sendable {}
