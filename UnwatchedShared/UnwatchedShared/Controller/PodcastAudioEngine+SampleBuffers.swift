//
//  PodcastAudioEngine+SampleBuffers.swift
//  UnwatchedShared
//

import AVFoundation
import CoreMedia

#if !os(watchOS)
extension PodcastAudioEngine {
    // MARK: - Sample buffers

    /// Fed deinterleaved, the renderer reports no error and renders silence.
    public static func rendererFormat(for format: AVAudioFormat) -> AVAudioFormat? {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: format.sampleRate,
            channels: format.channelCount, interleaved: true
        )
    }

    static func formatDescription(of format: AVAudioFormat) -> CMAudioFormatDescription? {
        var description: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault, asbd: format.streamDescription,
            layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil,
            extensions: nil, formatDescriptionOut: &description
        )
        return status == noErr ? description : nil
    }

    /// Copies the data, so the chunk is free once this returns.
    static func sampleBuffer(
        _ buffer: AVAudioPCMBuffer, at time: CMTime, formatDescription: CMAudioFormatDescription
    ) -> CMSampleBuffer? {
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: time.timescale),
            presentationTimeStamp: time, decodeTimeStamp: .invalid
        )
        var sample: CMSampleBuffer?
        var status = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false, makeDataReadyCallback: nil,
            refcon: nil, formatDescription: formatDescription, sampleCount: CMItemCount(buffer.frameLength),
            sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sample
        )
        guard status == noErr, let sample else { return nil }
        status = CMSampleBufferSetDataBufferFromAudioBufferList(
            sample, blockBufferAllocator: kCFAllocatorDefault, blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, bufferList: buffer.audioBufferList
        )
        return status == noErr ? sample : nil
    }
}
#endif
