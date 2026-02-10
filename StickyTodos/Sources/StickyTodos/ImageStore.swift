import AppKit
import ImageIO

enum ImageStore {
    private static let folderName = "Images"
    private static let thumbnailCache = NSCache<NSString, NSImage>()

    static func saveImage(_ image: NSImage) -> String? {
        guard let data = jpegData(from: image, maxDimension: 1200) else { return nil }
        return saveImageData(data)
    }

    static func saveImageData(_ data: Data) -> String? {
        let filename = UUID().uuidString + ".jpg"
        let url = imagesDirectory.appendingPathComponent(filename)
        do {
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic])
            let key = filename as NSString
            thumbnailCache.removeObject(forKey: key)
            return filename
        } catch {
            return nil
        }
    }

    static func url(for filename: String) -> URL {
        imagesDirectory.appendingPathComponent(filename)
    }

    static func thumbnail(named filename: String, size: CGFloat) -> NSImage? {
        let key = "\(filename)-\(Int(size))" as NSString
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }
        let url = imagesDirectory.appendingPathComponent(filename)
        guard let thumbnail = downsampleImage(at: url, maxPixelSize: Int(size * 2)) else { return nil }
        thumbnailCache.setObject(thumbnail, forKey: key)
        return thumbnail
    }

    static func deleteImage(named filename: String) {
        let url = imagesDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
        thumbnailCache.removeObject(forKey: filename as NSString)
    }

    private static var imagesDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("StickyTodos").appendingPathComponent(folderName)
    }

    private static func jpegData(from image: NSImage, maxDimension: CGFloat) -> Data? {
        guard let tiff = image.tiffRepresentation else { return nil }
        guard let rep = NSBitmapImageRep(data: tiff) else { return nil }
        let maxSide = max(rep.pixelsWide, rep.pixelsHigh)
        let ratio = maxSide > 0 ? min(1, maxDimension / CGFloat(maxSide)) : 1
        let targetSize = NSSize(width: CGFloat(rep.pixelsWide) * ratio, height: CGFloat(rep.pixelsHigh) * ratio)
        guard let scaled = resize(image: image, to: targetSize) else { return nil }
        guard let scaledTiff = scaled.tiffRepresentation, let scaledRep = NSBitmapImageRep(data: scaledTiff) else { return nil }
        return scaledRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }

    private static func resize(image: NSImage, to size: NSSize) -> NSImage? {
        let image = image.copy() as? NSImage ?? image
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    private static func downsampleImage(at url: URL, maxPixelSize: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cgImage, size: .zero)
    }
}
