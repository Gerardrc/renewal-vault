import Foundation

struct AttachmentStorage {
    static let shared = AttachmentStorage()

    private var baseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("Attachments", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: folder.path)
        }
        return folder
    }

    func save(data: Data, fileExtension: String) throws -> String {
        let filename = "\(UUID().uuidString).\(fileExtension)"
        let url = baseURL.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        return filename
    }

    func fileURL(relativePath: String) -> URL {
        baseURL.appendingPathComponent(relativePath)
    }
}
