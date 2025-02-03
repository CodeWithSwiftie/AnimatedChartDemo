import UIKit

public struct GridConfiguration {
    public var color: UIColor = UIColor.gray.withAlphaComponent(0.5)
    public var lineWidth: CGFloat = 0.5
}

/// Configuration for information label appearance
public struct CursorLabelProperties {
    public var font = UIFont.systemFont(ofSize: 13)
    public var backgroundColor: UIColor = .systemGray6
    public var foregroundColor: UIColor = .secondaryLabel
    
    public init() { }
}

public protocol ChartAppearance {
    var tintColor: UIColor { get }
    var showsHorizontalGridLines: Bool { get }
    var showsVerticalGridLines: Bool { get }
    var padding: UIEdgeInsets { get }
    var horizontalLabelsToTopPadding: CGFloat { get }
    var numberOfVerticalDivisions: Int { get }
    var widthBetweenOfVerticalDivisions: CGFloat { get }
    var cursorColor: UIColor { get }
    var showsCursor: Bool { get }
    var dateFormatter: DateFormatter { get }
    var horizontalGridProperties: GridConfiguration { get }
    var verticalGridProperties: GridConfiguration { get }
    var cursorLabelProperties: CursorLabelProperties { get }
}
