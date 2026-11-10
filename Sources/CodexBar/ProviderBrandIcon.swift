import AppKit
import CodexBarCore

@MainActor
enum ProviderBrandIcon {
    enum Style: Hashable {
        case monochrome
        case brand
    }

    private static let size = NSSize(width: 18, height: 18)
    private static var cache: [Style: [UsageProvider: NSImage]] = [:]

    /// Lazy-loaded resource bundle for provider icons.
    private static let resourceBundle: Bundle = {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return Bundle.module
        }
        for name in ["CodexBar_CodexBar", "CodexBarLite_CodexBar"] {
            if let bundleURL = Bundle.main.url(forResource: name, withExtension: "bundle"),
               let bundle = Bundle(url: bundleURL)
            {
                return bundle
            }
        }
        return Bundle.main
    }()

    private static func findResourceURL(name: String, ext: String) -> URL? {
        if let url = self.resourceBundle.url(forResource: name, withExtension: ext) {
            return url
        }
        if let url = self.resourceBundle.url(forResource: name, withExtension: ext, subdirectory: "Resources") {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Resources") {
            return url
        }
        if let url = Bundle.module.url(forResource: name, withExtension: ext) {
            return url
        }
        if let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources") {
            return url
        }
        return nil
    }

    static func image(for provider: UsageProvider, style: Style = .monochrome) -> NSImage? {
        if let cached = self.cache[style]?[provider] {
            return cached
        }

        let baseName = ProviderDescriptorRegistry.descriptor(for: provider).branding.iconResourceName
        // Only explicitly curated brand assets have reliable original colors. Existing provider
        // SVGs are often white silhouettes, so they must remain templates in both appearances.
        // Providers can share a monochrome resource while representing different products.
        let brandResourceName = "Brand-ProviderIcon-" + provider.rawValue
        let brandImage: NSImage? = style == .brand ? ["svg", "png"].lazy.compactMap { fileExtension in
            self.findResourceURL(name: brandResourceName, ext: fileExtension)
                .flatMap { NSImage(contentsOf: $0) }
        }.first : nil
        guard let image = brandImage ?? self.findResourceURL(name: baseName, ext: "svg")
            .flatMap({ NSImage(contentsOf: $0) }) else { return nil }

        image.size = self.size
        image.isTemplate = brandImage == nil
        self.cache[style, default: [:]][provider] = image
        return image
    }

    static func resetCacheForTesting() {
        self.cache.removeAll()
    }
}
