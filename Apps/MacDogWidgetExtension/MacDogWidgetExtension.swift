import MacDogWidget
import SwiftUI
import WidgetKit

@main
struct MacDogWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        MacDogStatusWidget(appGroupIdentifier: "group.com.dhseo.macdog.MacDog")
    }
}
