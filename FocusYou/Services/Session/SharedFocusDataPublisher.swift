import Foundation
import WidgetKit

protocol SharedFocusDataPublishing {
    func publish(_ data: SharedFocusData)
}

struct SharedFocusDataPublisher: SharedFocusDataPublishing {
    func publish(_ data: SharedFocusData) {
        SharedDataProvider.write(data)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
