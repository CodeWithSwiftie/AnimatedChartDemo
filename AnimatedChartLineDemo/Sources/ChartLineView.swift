//
//  LineChartView.swift
//  AnimatedChartDemo
//
//  Created by Vlad T. on 03.02.2024.
//  Copyright © 2024 Vlad T. All rights reserved.
//
//  A highly customizable line chart implementation that provides:
//  - Smooth animations for data updates
//  - Interactive touch tracking with cursor
//  - Automatic axis scaling and labeling
//  - Customizable appearance through configuration
//  - Support for single and multiple data points
//  - Grid lines and axis labels
//  - Gesture recognition for user interaction
//
//  Usage example:
//  ```
//  let config = LineChartAppearanceConfiguration()
//  let chartView = LineChartView(configuration: config)
//  chartView.updateChart(with: points)
//  ```
//

// swiftlint:disable file_length
import UIKit
import Combine

/// A custom CALayer subclass responsible for rendering the chart's visual elements.
private final class ChartLayer: CALayer {

    // MARK: - Layer Properties

    let graphLayer = CAShapeLayer()
    var isAnimationEnabled = true

    private let horizontalGridLayer = CAShapeLayer()
    private let verticalGridLayer = CAShapeLayer()
    
    /// Chart appearance configuration with automatic layout updates.
    let configuration: LineChartAppearanceConfiguration
    
    /// Data points to be displayed on the chart with automatic animation.
    var dataPoints: [ChartPoint] = [] {
        didSet { updateGraph(animated: isAnimationEnabled) }
    }
    
    // MARK: - Initialization

    /// Initializes a new instance of ChartLayer.
    /// - Parameter configuration: The configuration for chart appearance.
    init(configuration: LineChartAppearanceConfiguration) {
        self.configuration = configuration
        super.init()
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Configures the initial state of all layers with their visual properties.
    private func setupLayers() {
        // Configure main graph layer.
        graphLayer.fillColor = nil
        graphLayer.strokeColor = configuration.tintColor.cgColor
        graphLayer.lineWidth = configuration.lineWidth
        graphLayer.lineCap = .round
        graphLayer.lineJoin = .round
        graphLayer.frame = bounds
        
        // Configure horizontal grid layer.
        horizontalGridLayer.fillColor = nil
        horizontalGridLayer.strokeColor = configuration.horizontalGridProperties.color.cgColor
        horizontalGridLayer.lineWidth = configuration.horizontalGridProperties.lineWidth
        horizontalGridLayer.isHidden = !configuration.showsHorizontalGridLines
        
        // Configure vertical grid layer.
        verticalGridLayer.fillColor = nil
        verticalGridLayer.strokeColor = configuration.verticalGridProperties.color.cgColor
        verticalGridLayer.lineWidth = configuration.verticalGridProperties.lineWidth
        verticalGridLayer.isHidden = !configuration.showsVerticalGridLines
        
        // Add layers in specific order.
        addSublayer(horizontalGridLayer)
        addSublayer(verticalGridLayer)
        addSublayer(graphLayer)
    }
    
    // MARK: - Layout

    override func layoutSublayers() {
        super.layoutSublayers()
        graphLayer.frame = bounds
        horizontalGridLayer.frame = bounds
        verticalGridLayer.frame = bounds
        
        updateLayoutOfGrid()
        updateGraph(animated: isAnimationEnabled)
    }
    
    /// Updates the grid layout with horizontal and vertical lines.
    private func updateLayoutOfGrid() {
        let horizontalGridPath = UIBezierPath()
        let ySteps: CGFloat = CGFloat(configuration.numberOfVerticalDivisions)
        let yStepSize = bounds.height / CGFloat(ySteps - 1)
        for i in 0..<Int(ySteps) {
            let y = CGFloat(i) * yStepSize
            horizontalGridPath.move(to: CGPoint(x: 0, y: y))
            horizontalGridPath.addLine(to: CGPoint(x: bounds.width, y: y))
        }
        horizontalGridLayer.path = horizontalGridPath.cgPath
        
        let verticalGridPath = UIBezierPath()
        let desiredSpacing: CGFloat = configuration.widthBetweenOfVerticalDivisions
        let numberOfLines = max(2, Int(bounds.width / desiredSpacing))
        let xStepSize = bounds.width / CGFloat(numberOfLines - 1)
        for i in 0...numberOfLines {
            let x = CGFloat(i) * xStepSize
            verticalGridPath.move(to: CGPoint(x: x, y: 0))
            verticalGridPath.addLine(to: CGPoint(x: x, y: bounds.height))
        }
        verticalGridLayer.path = verticalGridPath.cgPath
    }
    
    /// Updates the graph line with optional animation.
    /// - Parameter animated: A Boolean value indicating whether the update should be animated.
    private func updateGraph(animated: Bool = true) {
        guard !dataPoints.isEmpty else { return }
        
        let xPaddingPercentage: CGFloat = 0.01
        let xPadding = bounds.width * xPaddingPercentage
        let effectiveWidth = bounds.width - (2 * xPadding)
        let clampedBounds = bounds.insetBy(dx: configuration.lineWidth / 2, dy: configuration.lineWidth / 2)
        
        // Special case for a single data point.
        if dataPoints.count == 1 {
            let path = UIBezierPath()
            let centerX = bounds.width / 2
            let value = dataPoints[0].value
            let yPadding = value * 0.2
            let yMin = value - yPadding
            let yMax = value + yPadding
            let yScale = bounds.height / (yMax - yMin)
            let yPosition = bounds.height - ((value - yMin) * yScale)
            let maxAllowedRadius = min(bounds.width, bounds.height) * 0.4
            let circleRadius = min(4, maxAllowedRadius)
            path.addArc(withCenter: CGPoint(x: centerX, y: yPosition),
                        radius: circleRadius,
                        startAngle: 0,
                        endAngle: .pi * 2,
                        clockwise: true)
            
            if animated {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                graphLayer.path = path.cgPath
                CATransaction.commit()
            } else {
                graphLayer.path = path.cgPath
            }
            return
        }
        
        // Case for multiple data points.
        let xScale = effectiveWidth / CGFloat(max(1, dataPoints.count - 1))
        let values = dataPoints.map { $0.value }
        let minYValue = values.min() ?? 0.0
        let maxYValue = values.max() ?? 1.0
        
        let yPadding = (maxYValue - minYValue) * 0.05
        let yMin = minYValue - yPadding
        let yMax = maxYValue + yPadding
        let yScale = bounds.height / CGFloat(yMax - yMin)
        
        var points = [CGPoint]()
        for (index, dotPoint) in dataPoints.enumerated() {
            let x = xPadding + (CGFloat(index) * xScale)
            let rawY = bounds.height - ((CGFloat(dotPoint.value) - CGFloat(yMin)) * yScale)
            let y = min(max(rawY, clampedBounds.minY), clampedBounds.maxY)
            points.append(CGPoint(x: x, y: y))
        }
        
        let path = UIBezierPath()
        path.clampedSmoothCurve(through: points, in: clampedBounds)
        
        if animated {
            let animation = pathAnimation(for: path)
            graphLayer.add(animation, forKey: "pathAnimation")
        }
        graphLayer.path = path.cgPath
    }
    
    /// Creates a CABasicAnimation for the provided path.
    /// - Parameter path: The new path for animation.
    /// - Returns: A CABasicAnimation configured for path changes.
    private func pathAnimation(for path: UIBezierPath) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "path")
        animation.fromValue = graphLayer.path ?? path.cgPath
        animation.toValue = path.cgPath
        animation.duration = 0.3
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = true
        return animation
    }
}

/// A custom UIView subclass that displays a line chart with interactive features.
public final class LineChartView: UIView, Chart {
    public typealias Point = ChartPoint
    
    // MARK: - Properties

    /// Chart appearance configuration.
    public let configuration: LineChartAppearanceConfiguration
    /// Provides a label for the cursor based on a chart point.
    public let cursorLabelProvider: ((Point) -> String?)?
    
    /// Publisher that emits cursor events.
    public var cursorEvent: AnyPublisher<ChartCursorEvent, Never> {
        cursorFocusedSubject.eraseToAnyPublisher()
    }
    
    private var isAnimationEnabled = true {
        didSet { chartLayer.isAnimationEnabled = isAnimationEnabled }
    }
    private let cursorFocusedSubject = PassthroughSubject<ChartCursorEvent, Never>()
    
    /// Main layer responsible for drawing the chart.
    private let chartLayer: ChartLayer
    /// Vertical cursor line that follows touch input.
    private let cursorLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.lineWidth = 1
        layer.strokeColor = UIColor.red.cgColor
        layer.lineDashPattern = [2, 4]
        layer.lineCap = .round
        layer.lineDashPhase = 0
        return layer
    }()
    
    /// Dot that follows the chart line during touch tracking.
    private let trackingDotLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.red.cgColor
        layer.strokeColor = UIColor.white.cgColor
        layer.lineWidth = 2.5
        return layer
    }()
    
    private let maskLayer = CAShapeLayer()
    
    /// Layer that shows a hovered state of the chart line.
    private let hoveredLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor.gray.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 3
        layer.lineCap = .round
        layer.lineJoin = .round
        layer.actions = [
            "position": NSNull(),
            "bounds": NSNull(),
        ]
        return layer
    }()
    
    /// Label that displays information about the currently selected point.
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = UIColor.systemGray5.withAlphaComponent(0.95)
        label.textColor = UIColor.label.withAlphaComponent(0.7)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textAlignment = .center
        label.layer.cornerRadius = 16
        label.layer.masksToBounds = true
        label.alpha = 0
        label.numberOfLines = 1
        label.layer.zPosition = 5
        return label
    }()
    
    // MARK: - Private Properties

    private var xLabels: [UILabel] = []
    private var yLabels: [UILabel] = []
    private var dataPoints: [Point] = []
    
    private var bottomChartInset: CGFloat {
        (xLabels.first?.bounds.height ?? 0) + configuration.horizontalLabelsToTopPadding
    }
    
    // MARK: - Initialization

    /// Initializes a new instance of LineChartView.
    /// - Parameters:
    ///   - configuration: The configuration for chart appearance.
    ///   - cursorLabelProvider: Optional closure that returns a cursor label for a given point.
    public init(
        configuration: LineChartAppearanceConfiguration,
        cursorLabelProvider: ((Point) -> String?)? = nil
    ) {
        self.configuration = configuration
        self.cursorLabelProvider = cursorLabelProvider
        chartLayer = ChartLayer(configuration: configuration)
        super.init(frame: .zero)
        setupLayers()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Init(coder:) has not been implemented")
    }
    
    /// Sets up all layers and configures their visual properties.
    private func setupLayers() {
        layer.addSublayer(chartLayer)
        layer.addSublayer(cursorLayer)
        layer.addSublayer(hoveredLayer)
        layer.addSublayer(trackingDotLayer)
        addSubview(infoLabel)
        
        // Configure appearance using provided configuration.
        chartLayer.graphLayer.strokeColor = configuration.tintColor.cgColor
        trackingDotLayer.fillColor = configuration.dotProperties.color.cgColor
        trackingDotLayer.strokeColor = configuration.dotProperties.strokeColor.cgColor
        trackingDotLayer.lineWidth = configuration.dotProperties.strokeWidth
        cursorLayer.strokeColor = configuration.cursorColor.cgColor
        hoveredLayer.strokeColor = configuration.hoverLineColor.cgColor
        hoveredLayer.lineWidth = configuration.lineWidth
        
        infoLabel.backgroundColor = configuration.cursorLabelProperties.backgroundColor
        infoLabel.font = configuration.cursorLabelProperties.font
        infoLabel.textColor = configuration.cursorLabelProperties.foregroundColor
    }
    
    // MARK: - Layout

    override public func layoutSubviews() {
        super.layoutSubviews()
        updateXLabelsLayout()
        updateYLabelsLayout()
    }
    
    override public func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        guard layer == self.layer else { return }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let padding = configuration.padding
        chartLayer.frame = bounds.inset(
            by: .init(
                top: padding.top,
                left: padding.left + calculateWidthOfVerticalLabels(),
                bottom: padding.bottom + bottomChartInset,
                right: padding.right
            )
        )
        CATransaction.commit()
    }
    
    /// Updates the chart with new data points.
    /// - Parameters:
    ///   - newPoints: Array of new data points to display.
    ///   - animated: A Boolean value indicating whether to animate the transition.
    ///   - completion: Callback executed after the update is complete.
    public func updateChart(with newPoints: [Point],
                            animated: Bool = true,
                            completion: (() -> Void)? = nil) {
        isAnimationEnabled = animated
        dataPoints = newPoints
        
        if animated {
            CATransaction.begin()
            CATransaction.setCompletionBlock { [weak self] in
                self?.rebuildLabels(for: newPoints)
                completion?()
            }
            chartLayer.dataPoints = newPoints
            CATransaction.commit()
        } else {
            chartLayer.dataPoints = newPoints
            rebuildLabels(for: newPoints)
        }
    }
    
    public func presentationView() -> UIView {
        self
    }
    
    // MARK: - Cursor Gesture

    /// Sets up gesture recognizers for chart interaction.
    private func setupGestures() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        addGestureRecognizer(panGesture)
    }
    
    /// Handles pan gesture states and updates cursor position.
    /// - Parameter gesture: The pan gesture recognizer.
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        switch gesture.state {
        case .began:
            cursorFocusedSubject.send(.begin)
        case .changed:
            updateCursor(at: location)
        case .ended, .cancelled:
            hideCursor()
        default:
            break
        }
    }
}

// MARK: - Layout of Labels

extension LineChartView {
    
    /// Calculates the width needed for vertical labels based on the maximum value.
    /// - Returns: The width required for vertical labels.
    private func calculateWidthOfVerticalLabels() -> CGFloat {
        guard let maxValue = dataPoints.map({ $0.value }).max() else {
            return 40
        }
        switch maxValue {
        case 0..<100: return 40    // XX.X
        case 100..<1000: return 48 // XXX.X
        case 1000..<10000: return 56 // X,XXX.X
        case 10000..<100000: return 64 // XX,XXX.X
        case 100000..<1000000: return 72 // XXX,XXX.X
        default: return 80
        }
    }
    
    /// Filters data points to fit within available width while maintaining readability.
    private func filterPointsToFit(_ data: [ChartPoint],
                                   availableWidth: CGFloat,
                                   font: UIFont,
                                   minSpacing: CGFloat) -> [ChartPoint] {
        let dateFormatter = configuration.dateFormatter
        let stringWidths = data.map { point -> (ChartPoint, CGFloat) in
            let labelText = dateFormatter.string(from: point.timestamp) as NSString
            let width = labelText.size(withAttributes: [.font: font]).width + minSpacing
            return (point, width)
        }
        let totalWidth = stringWidths.reduce(CGFloat.zero) { $0 + $1.1 }
        if totalWidth <= availableWidth {
            return data
        }
        
        let averageLabelWidth = totalWidth / CGFloat(data.count)
        let maxLabels = Int(availableWidth / averageLabelWidth)
        
        let step = max(Int(ceil(Double(data.count) / Double(maxLabels))), 2)
        var indices = Array(stride(from: 0, to: data.count - 1, by: step))
        if let lastIndex = indices.last, lastIndex != data.count - 1 {
            indices.append(data.count - 1)
        }
        return indices.map { data[$0] }
    }
    
    /// Updates both X and Y axis labels.
    private func rebuildLabels(for dataPoints: [Point]) {
        setupYLabels(for: dataPoints)
        setupXLabels(for: dataPoints)
    }
    
    /// Configures and updates X-axis labels.
    private func setupXLabels(for dataPoints: [ChartPoint]) {
        let padding = configuration.padding
        let verticalLabelsWidth = calculateWidthOfVerticalLabels()
        let availableWidth = bounds.width - padding.left - padding.right - verticalLabelsWidth * 1.5
        let normalizedPoints = filterPointsToFit(dataPoints,
                                                 availableWidth: availableWidth,
                                                 font: configuration.horizontalLabelProperties.font,
                                                 minSpacing: 20)
        let dateFormatter = configuration.dateFormatter
        
        if xLabels.isEmpty {
            xLabels = normalizedPoints.map { point in
                let label = buildLabel(for: dateFormatter.string(from: point.timestamp), isVertical: false)
                addSubview(label)
                return label
            }
            setNeedsLayout()
            layoutIfNeeded()
            return
        }
        
        updateLabelsWithAnimation(oldLabels: xLabels,
                                  newValues: normalizedPoints.map { dateFormatter.string(from: $0.timestamp) },
                                  isVertical: false)
    }
    
    /// Configures and updates Y-axis labels.
    private func setupYLabels(for dataPoints: [ChartPoint]) {
        guard !dataPoints.isEmpty else { return }
        
        let divisions = configuration.numberOfVerticalDivisions
        let yMin: Double
        let yMax: Double
        
        if dataPoints.count == 1 || dataPoints.map({ $0.value }).min() == dataPoints.map({ $0.value }).max() {
            let value = dataPoints[0].value
            let padding = value * 0.2
            yMin = value - padding
            yMax = value + padding
        } else {
            let values = dataPoints.map { $0.value }
            yMin = values.min() ?? 0
            yMax = values.max() ?? 1
        }
        
        let step = (yMax - yMin) / Double(divisions - 1)
        let newValues = (0..<divisions).map { i in
            let value = yMax - (step * Double(i))
            return String(format: "%.1f", value)
        }
        
        if yLabels.isEmpty {
            yLabels = newValues.reversed().map { value in
                let label = buildLabel(for: value, isVertical: true)
                addSubview(label)
                return label
            }
            setNeedsLayout()
            layoutIfNeeded()
            return
        }
        
        updateLabelsWithAnimation(oldLabels: yLabels,
                                  newValues: newValues,
                                  isVertical: true)
    }
    
    /// Animates the transition between old and new labels.
    private func updateLabelsWithAnimation(oldLabels: [UILabel],
                                           newValues: [String],
                                           isVertical: Bool) {
        let snapshots = oldLabels.compactMap { label -> UIView? in
            guard let snapshot = label.snapshotView(afterScreenUpdates: false) else { return nil }
            snapshot.frame = label.frame
            addSubview(snapshot)
            return snapshot
        }
        oldLabels.forEach { $0.removeFromSuperview() }
        
        let isExpanding = newValues.count > oldLabels.count
        let newLabels = newValues.map { value in
            let label = buildLabel(for: value, isVertical: isVertical)
            label.alpha = 0
            label.transform = isVertical ?
                CGAffineTransform(translationX: 0, y: isExpanding ? 10 : 0) :
                CGAffineTransform(translationX: isExpanding ? -10 : 0, y: 0)
            addSubview(label)
            return label
        }
        if isVertical {
            yLabels = newLabels.reversed()
        } else {
            xLabels = newLabels
        }
        setNeedsLayout()
        layoutIfNeeded()
        let animator = UIViewPropertyAnimator(duration: 0.3, curve: .easeInOut) {
            newLabels.forEach {
                $0.alpha = 1
                $0.transform = .identity
            }
            snapshots.forEach { snapshot in
                snapshot.alpha = 0
                snapshot.transform = isVertical ?
                    CGAffineTransform(translationX: 0, y: isExpanding ? -10 : 0) :
                    CGAffineTransform(translationX: isExpanding ? 10 : 0, y: 0)
            }
        }
        animator.addCompletion { _ in
            snapshots.forEach { $0.removeFromSuperview() }
        }
        animator.startAnimation()
    }
    
    /// Creates a label with the specified configuration.
    private func buildLabel(for text: String, isVertical: Bool) -> UILabel {
        let properties = isVertical ? configuration.verticalLabelProperties : configuration.horizontalLabelProperties
        let label = UILabel()
        label.text = text
        label.textColor = properties.textColor
        label.font = properties.font
        label.textAlignment = .center
        label.sizeToFit()
        return label
    }
    
    /// Updates the layout of X-axis labels.
    private func updateXLabelsLayout() {
        let verticalLabelsWidth = calculateWidthOfVerticalLabels()
        let padding = configuration.padding
        let availableWidth = bounds.width - padding.left - padding.right - verticalLabelsWidth
        
        guard xLabels.count > 1 else {
            if let label = xLabels.first {
                let labelWidth = min(availableWidth, label.frame.width)
                let xPosition = verticalLabelsWidth + padding.left + (availableWidth / 2) - (labelWidth / 2)
                label.frame = CGRect(x: xPosition,
                                     y: bounds.height - label.bounds.height,
                                     width: labelWidth,
                                     height: label.frame.height)
            }
            return
        }
        
        let totalSpacing = availableWidth - xLabels.last!.frame.width
        let spacingBetweenLabels = totalSpacing / CGFloat(xLabels.count - 1)
        xLabels.enumerated().forEach { index, label in
            let labelWidth = min(spacingBetweenLabels, label.frame.width)
            let xOffset: CGFloat
            if index == xLabels.count - 1 {
                xOffset = bounds.width - labelWidth - padding.right
            } else {
                xOffset = verticalLabelsWidth + padding.left + (CGFloat(index) * spacingBetweenLabels)
            }
            label.frame = CGRect(origin: CGPoint(x: xOffset, y: bounds.height - label.bounds.height),
                                 size: CGSize(width: labelWidth, height: label.frame.height))
        }
    }
    
    /// Updates the layout of Y-axis labels.
    private func updateYLabelsLayout() {
        guard !yLabels.isEmpty else { return }
        let padding = configuration.padding
        let availableHeight = bounds.height - padding.top - padding.bottom - bottomChartInset
        let yStep = availableHeight / CGFloat(yLabels.count - 1)
        yLabels.enumerated().forEach { index, label in
            let yPosition = bounds.height - (CGFloat(index) * yStep)
            label.frame = CGRect(x: padding.left,
                                 y: yPosition - label.frame.height / 2 - bottomChartInset,
                                 width: label.frame.width,
                                 height: label.frame.height)
        }
    }
}

// MARK: - Cursor Managing

extension LineChartView {
    
    /// Updates cursor position and related visual elements.
    /// - Parameter location: The location of the touch.
    private func updateCursor(at location: CGPoint) {
        if dataPoints.count == 1 {
            let centerX = chartLayer.frame.minX + (chartLayer.frame.width / 2)
            let value = dataPoints[0].value
            
            let yPadding = value * 0.1
            let yMin = value - yPadding
            let yMax = value + yPadding
            let yScale = chartLayer.frame.height / (yMax - yMin)
            let yPosition = chartLayer.frame.maxY - ((value - yMin) * yScale)
            
            let cursorPath = UIBezierPath()
            cursorPath.move(to: CGPoint(x: centerX, y: chartLayer.frame.minY))
            cursorPath.addLine(to: CGPoint(x: centerX, y: chartLayer.frame.maxY))
            cursorLayer.path = cursorPath.cgPath
            
            if cursorLayer.opacity == 0 {
                cursorLayer.opacity = 1
            }
            
            let finalPoint = CGPoint(x: centerX, y: yPosition)
            updateTrackingDot(at: finalPoint)
            
            if let text = cursorLabelProvider?(dataPoints[0]) {
                infoLabel.text = text
                infoLabel.frame = .init(origin: .zero, size: infoLabel.intrinsicContentSize).insetBy(dx: -5, dy: 0)
                let labelX = centerX - infoLabel.frame.width / 2
                infoLabel.frame.origin = CGPoint(x: labelX, y: 0)
                infoLabel.layer.cornerRadius = infoLabel.frame.height / 2
                infoLabel.alpha = 1
                
                cursorFocusedSubject.send(.moved(dataPoints[0]))
            }
            hoveredLayer.opacity = 0
            return
        }
        
        let xOffset = max(chartLayer.frame.minX, min(location.x, chartLayer.frame.maxX))
        let cursorPath = UIBezierPath()
        cursorPath.move(to: CGPoint(x: xOffset, y: chartLayer.frame.minY))
        cursorPath.addLine(to: CGPoint(x: xOffset, y: chartLayer.frame.maxY))
        cursorLayer.path = cursorPath.cgPath
        
        let maskPath = UIBezierPath(rect: CGRect(x: xOffset - chartLayer.frame.minX,
                                                   y: 0,
                                                   width: chartLayer.frame.width - (xOffset - chartLayer.frame.minX),
                                                   height: chartLayer.frame.height))
        maskLayer.path = maskPath.cgPath
        hoveredLayer.mask = maskLayer
        hoveredLayer.path = chartLayer.graphLayer.path
        hoveredLayer.frame = chartLayer.frame
        
        if hoveredLayer.opacity == 0 {
            hoveredLayer.opacity = 1
            cursorLayer.opacity = 1
        }
        
        let relativeX = xOffset - chartLayer.frame.minX
        if let intersectionPoint = findIntersectionPoint(at: relativeX) {
            let finalPoint = CGPoint(x: xOffset, y: intersectionPoint.y + chartLayer.frame.minY)
            updateTrackingDot(at: finalPoint)
        }
        
        let pointIndex = getNearestPointIndex(at: relativeX)
        if let point = dataPoints[safe: pointIndex],
           let text = cursorLabelProvider?(point) {
            infoLabel.text = text
            infoLabel.frame = .init(origin: .zero, size: infoLabel.intrinsicContentSize).insetBy(dx: -5, dy: 0)
            let minX = chartLayer.frame.minX
            let maxX = chartLayer.frame.maxX - infoLabel.frame.width
            let labelX = min(maxX, max(minX, xOffset - infoLabel.frame.width / 2))
            infoLabel.frame.origin.x = labelX
            infoLabel.layer.cornerRadius = infoLabel.frame.height / 2
            infoLabel.alpha = 1
            
            cursorFocusedSubject.send(.moved(point))
        }
    }
    
    /// Finds the intersection point between the vertical line at `targetX` and the chart path.
    /// - Parameter targetX: The x-coordinate relative to chartLayer.
    /// - Returns: The intersection CGPoint if found, otherwise nil.
    private func findIntersectionPoint(at targetX: CGFloat) -> CGPoint? {
        guard let path = chartLayer.graphLayer.path else { return nil }
        var result: CGPoint?
        var previousPoint: CGPoint?
        var lastValidSegment: (start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint)?
        
        path.applyWithBlock { element in
            guard result == nil else { return }
            switch element.pointee.type {
            case .moveToPoint:
                previousPoint = element.pointee.points[0]
            case .addCurveToPoint:
                if let start = previousPoint {
                    let control1 = element.pointee.points[0]
                    let control2 = element.pointee.points[1]
                    let end = element.pointee.points[2]
                    lastValidSegment = (start, control1, control2, end)
                    if targetX <= end.x {
                        if let intersection = findCubicBezierIntersection(x: targetX,
                                                                            p0: start,
                                                                            p1: control1,
                                                                            p2: control2,
                                                                            p3: end,
                                                                            tolerance: 0.5) {
                            result = intersection
                        }
                    }
                }
                previousPoint = element.pointee.points[2]
            default:
                break
            }
        }
        
        if result == nil,
           let lastSegment = lastValidSegment,
           targetX > lastSegment.end.x {
            let maxExtrapolationDistance: CGFloat = 100
            let extrapolationDistance = targetX - lastSegment.end.x
            if extrapolationDistance <= maxExtrapolationDistance {
                let dx = (lastSegment.control2.x - lastSegment.end.x) * 3
                let dy = (lastSegment.control2.y - lastSegment.end.y) * 3
                if dx != 0 {
                    let slope = dy / dx
                    let extrapolatedY = lastSegment.end.y + (slope * (targetX - lastSegment.end.x))
                    result = CGPoint(x: targetX, y: extrapolatedY)
                }
            }
        }
        return result
    }
    
    /// Finds the intersection point on a cubic Bezier curve for a given x-coordinate.
    private func findCubicBezierIntersection(x targetX: CGFloat,
                                             p0: CGPoint,
                                             p1: CGPoint,
                                             p2: CGPoint,
                                             p3: CGPoint,
                                             tolerance: CGFloat) -> CGPoint? {
        let minX = min(p0.x, min(p1.x, min(p2.x, p3.x))) - tolerance
        let maxX = max(p0.x, max(p1.x, max(p2.x, p3.x))) + tolerance
        guard (minX...maxX).contains(targetX) else { return nil }
        
        var lower: CGFloat = 0
        var upper: CGFloat = 1
        let iterations = 12
        
        for _ in 0..<iterations {
            let mid = (lower + upper) / 2
            let point = cubicBezierPoint(t: mid, p0: p0, p1: p1, p2: p2, p3: p3)
            if abs(point.x - targetX) < tolerance {
                return point
            }
            if point.x < targetX {
                lower = mid
            } else {
                upper = mid
            }
        }
        let t = (lower + upper) / 2
        return cubicBezierPoint(t: t, p0: p0, p1: p1, p2: p2, p3: p3)
    }
    
    /// Calculates a point on a cubic Bezier curve for a given t.
    private func cubicBezierPoint(t: CGFloat,
                                  p0: CGPoint,
                                  p1: CGPoint,
                                  p2: CGPoint,
                                  p3: CGPoint) -> CGPoint {
        let mt = 1 - t
        let mt2 = mt * mt
        let mt3 = mt2 * mt
        let t2 = t * t
        let t3 = t2 * t
        return CGPoint(
            x: mt3 * p0.x + 3 * mt2 * t * p1.x + 3 * mt * t2 * p2.x + t3 * p3.x,
            y: mt3 * p0.y + 3 * mt2 * t * p1.y + 3 * mt * t2 * p2.y + t3 * p3.y
        )
    }
    
    /// Updates the position and appearance of the tracking dot.
    /// - Parameter point: The new position for the tracking dot.
    private func updateTrackingDot(at point: CGPoint) {
        let dotSize: CGFloat = configuration.dotProperties.size
        let dotPath = UIBezierPath(ovalIn: CGRect(x: -dotSize / 2,
                                                  y: -dotSize / 2,
                                                  width: dotSize,
                                                  height: dotSize))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackingDotLayer.path = dotPath.cgPath
        trackingDotLayer.position = point
        trackingDotLayer.opacity = 1
        CATransaction.commit()
    }
    
    /// Returns the index of the data point nearest to the given x-coordinate.
    /// - Parameter x: The x-coordinate relative to chartLayer.
    /// - Returns: The index of the nearest data point.
    private func getNearestPointIndex(at x: CGFloat) -> Int {
        guard !dataPoints.isEmpty else { return 0 }
        let xScale = chartLayer.bounds.width / CGFloat(max(1, dataPoints.count - 1))
        let index = Int(round(x / xScale))
        return max(0, min(index, dataPoints.count - 1))
    }
    
    /// Hides all cursor-related visual elements.
    private func hideCursor() {
        cursorLayer.opacity = 0
        infoLabel.alpha = 0
        hoveredLayer.opacity = 0
        trackingDotLayer.opacity = 0
        cursorFocusedSubject.send(.endMoved)
    }
}
// swiftlint:enable file_length
