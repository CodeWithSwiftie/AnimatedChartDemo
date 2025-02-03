import UIKit
import Combine

public protocol Chart {
    associatedtype Configuration: ChartAppearance
    var configuration: Configuration { get }
    var cursorLabelProvider: ((ChartPoint) -> String?)? { get }
    var cursorEvent: AnyPublisher<ChartCursorEvent, Never> { get }
    
    func updateChart(with newPoints: [ChartPoint], animated: Bool, completion: (() -> Void)?)
    func presentationView() -> UIView
}
