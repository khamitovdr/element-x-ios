@testable import ElementX
import Foundation
import Testing

struct RoundVideoCacheTests {
    @Test
    func urlForNewRecordingUsesMarkerFilename() {
        let cache = RoundVideoCache()
        let url = cache.urlForNewRecording()
        #expect(url.lastPathComponent.hasPrefix(RoundVideoMessage.filenamePrefix))
        #expect(url.pathExtension == "mp4")
        #expect(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
        cache.clearCache()
    }
    
    @Test
    func clearCacheRemovesRecordings() throws {
        let cache = RoundVideoCache()
        let url = cache.urlForNewRecording()
        try Data("test".utf8).write(to: url)
        #expect(FileManager.default.fileExists(atPath: url.path))
        cache.clearCache()
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
}
