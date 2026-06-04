import AppKit
import SwiftUI

struct ResourceMetricBlock: View {
    let title: String
    let systemImage: String
    let value: String
    let details: [String]
    let progress: Double?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(title): \(value)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(details, id: \.self) { detail in
                    Text(detail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let progress {
                    ProgressView(value: progress)
                        .tint(.accentColor)
                        .padding(.top, 2)
                }
            }
        }
    }
}

struct PopoverFormSection<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
    }
}

struct PopoverTabArtwork: View {
    let resourceDirectory: String
    let resourceName: String
    let fallbackSystemImage: String

    var body: some View {
        Group {
            if let image = Self.image(named: resourceName, resourceDirectory: resourceDirectory) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                    Image(systemName: fallbackSystemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private static func image(named resourceName: String, resourceDirectory: String) -> NSImage? {
        if let url = Bundle.main.resourceURL?
            .appendingPathComponent(resourceDirectory, isDirectory: true)
            .appendingPathComponent("\(resourceName).png") {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }

        if let url = Bundle.main.resourceURL?.appendingPathComponent("\(resourceName).png") {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }

        if let url = Bundle.module.url(
            forResource: resourceName,
            withExtension: "png",
            subdirectory: resourceDirectory
        ) {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }

        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "png") else {
            return nil
        }

        return NSImage(contentsOf: url)
    }
}
