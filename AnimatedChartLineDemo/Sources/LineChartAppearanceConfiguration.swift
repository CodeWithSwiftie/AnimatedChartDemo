//
//  LineChartAppearanceConfiguration.swift
//  AnimatedChartDemo
//
//  Created by Vlad T. on 03.02.2024.
//  Copyright © 2024 Vlad T. All rights reserved.
//
//  Configuration options for LineChartView appearance
//

import UIKit

/// Configuration model that defines the visual appearance of a line chart
public struct LineChartAppearanceConfiguration: ChartAppearance {
    
    // MARK: - Main Chart Properties
    
    public var lineWidth: CGFloat = 3.5
    public var hoverLineColor: UIColor = .gray
    public var padding: UIEdgeInsets = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 20)
    public var horizontalLabelsToTopPadding: CGFloat = 16
    public var numberOfVerticalDivisions: Int = 5
    public var widthBetweenOfVerticalDivisions: CGFloat = 50
    public var cursorColor: UIColor = .systemRed
    
    public var tintColor: UIColor = .systemIndigo
    public var showsHorizontalGridLines: Bool = true
    public var showsVerticalGridLines: Bool = true
    public var showsCursor: Bool = true
    
    // MARK: - Grid and Label Configurations
    
    public var horizontalGridProperties = GridConfiguration()
    public var horizontalLabelProperties = LabelConfiguration()
    
    public var verticalGridProperties = GridConfiguration()
    public var verticalLabelProperties = LabelConfiguration()
    
    // MARK: - Additional Visual Elements
    
    public var dotProperties = DotProperties()
    public var cursorLabelProperties = CursorLabelProperties()
    
    public let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd"
        return dateFormatter
    }()
    
    /// Configuration for axis labels appearance
    public struct LabelConfiguration {
        public var font: UIFont = .systemFont(ofSize: 13)
        public var textColor: UIColor = .secondaryLabel
        
        public init() { }
    }
    
    /// Configuration for data points appearance
    public struct DotProperties {
        public var size: CGFloat = 10
        public var color: UIColor = .systemIndigo
        public var strokeColor: UIColor = .white
        public var strokeWidth: CGFloat = 2.5
        
        public init() { }
    }
 
    public init() { }
}

public extension LineChartAppearanceConfiguration {
    static let `default`: LineChartAppearanceConfiguration = {
        var configuration = LineChartAppearanceConfiguration()
        configuration.showsVerticalGridLines = false
        configuration.padding = .zero
        configuration.horizontalLabelProperties.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        configuration.verticalLabelProperties.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        configuration.horizontalLabelProperties.textColor = UIColor.systemGray2
        configuration.verticalLabelProperties.textColor = UIColor.systemGray2
        configuration.lineWidth = 3.5
        configuration.hoverLineColor = UIColor.darkGray
        return configuration
    }()
}
