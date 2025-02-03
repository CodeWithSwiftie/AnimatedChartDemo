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

/// A custom CALayer subclass responsible for rendering the chart's visual elements
private final class ChartLayer: CALayer {

    // MARK: - Layer Properties

    let graphLayer = CAShapeLayer()
    var isAnimationEnabled = true

    private let horizontalGridLayer = CAShapeLayer()
    private let verticalGridLayer = CAShapeLayer()

    /// Chart appearance configuration with automatic layout updates
    let configuration: LineChartAppearanceConfiguration

    /// Data points to be displayed on the chart with automatic animation
    var dataPoints: [ChartPoint] = [] {
        didSet { updateGraph(animated: isAnimationEnabled) }
    }

    // MARK: - Initialization

    init(configuration: LineChartAppearanceConfiguration) {
        self.configuration = configuration
        super.init()
        setupLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Configures the initial state of all layers with their visual properties
    private func setupLayers() {
        // Configure main graph layer
        graphLayer.fillColor = nil
        graphLayer.strokeColor = configuration.tintColor.cgColor
        graphLayer.lineWidth = configuration.lineWidth
        graphLayer.lineCap = .round
        graphLayer.lineJoin = .round
        graphLayer.frame = bounds

        // Configure horizontal grid layer
        horizontalGridLayer.fillColor = nil
        horizontalGridLayer.strokeColor = configuration.horizontalGridProperties.color.cgColor
        horizontalGridLayer.lineWidth = configuration.horizontalGridProperties.lineWidth
        horizontalGridLayer.isHidden = !configuration.showsHorizontalGridLines

        // Configure vertical grid layer
        verticalGridLayer.fillColor = nil
        verticalGridLayer.strokeColor = configuration.verticalGridProperties.color.cgColor
        verticalGridLayer.lineWidth = configuration.verticalGridProperties.lineWidth
        verticalGridLayer.isHidden = !configuration.showsVerticalGridLines

        // Add layers in specific order
        addSublayer(horizontalGridLayer)
        addSublayer(verticalGridLayer)
        addSublayer(graphLayer)
    }

    // MARK: - Layout

    override func layoutSublayers() {
        super.layoutSublayers()

        // Update frames for all layers
        graphLayer.frame = bounds
        horizontalGridLayer.frame = bounds
        verticalGridLayer.frame = bounds

        updateLayoutOfGrid()
        updateGraph(animated: isAnimationEnabled)
    }

    /// Updates the grid layout with horizontal and vertical lines
    private func updateLayoutOfGrid() {
        // Draw horizontal grid lines
        let horizontalGridPath = UIBezierPath()
        let ySteps: CGFloat = CGFloat(configuration.numberOfVerticalDivisions)
        let yStepSize = bounds.height / CGFloat(ySteps - 1)

        for i in 0..<Int(ySteps) {
            let y = CGFloat(i) * yStepSize
            horizontalGridPath.move(to: CGPoint(x: 0, y: y))
            horizontalGridPath.addLine(to: CGPoint(x: bounds.width, y: y))
        }

        horizontalGridLayer.path = horizontalGridPath.cgPath

        // Draw vertical grid lines
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

    /// Updates the graph line with optional animation
    private func updateGraph(animated: Bool = true) {
        guard !dataPoints.isEmpty else { return }

        // Calculate padding and effective width
        let xPaddingPercentage: CGFloat = 0.01
        let xPadding = bounds.width * xPaddingPercentage
        let effectiveWidth = bounds.width - (2 * xPadding)
        
        let clampedBounds = bounds.insetBy(dx: configuration.lineWidth/2, dy: configuration.lineWidth/2)

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

            path.addArc(
                withCenter: CGPoint(x: centerX, y: yPosition),
                radius: circleRadius,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            )
            
            if animated {
                let animation = pathAnimation(for: path)
                graphLayer.add(animation, forKey: "pathAnimation")
            }
            graphLayer.path = path.cgPath
            return
        }

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
               // Ограничиваем координаты Y в пределах слоя
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

    /// Creates a CABasicAnimation for the provided path
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

/// A custom UIView subclass that displays a line chart with interactive features
public final class LineChartView: UIView, Chart {
    public typealias Point = ChartPoint

    // MARK: - Properties

    public let configuration: LineChartAppearanceConfiguration
    public let cursorLabelProvider: ((Point) -> String?)?

    public var cursorEvent: AnyPublisher<ChartCursorEvent, Never> {
        cursorFocusedSubject.eraseToAnyPublisher()
    }

    private var isAnimationEnabled = true {
        didSet { chartLayer.isAnimationEnabled = isAnimationEnabled }
    }

    private let cursorFocusedSubject = PassthroughSubject<ChartCursorEvent, Never>()

    /// Main layer responsible for drawing the chart
    private let chartLayer: ChartLayer

    /// Vertical cursor line that follows touch input
    private let cursorLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.lineWidth = 1
        layer.strokeColor = UIColor.red.cgColor
        layer.lineDashPattern = [2, 2]
        layer.lineCap = .round
        layer.lineDashPhase = 0
        layer.backgroundColor = nil
        return layer
    }()

    /// Dot that follows the chart line during touch tracking
    private let trackingDotLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.red.cgColor
        layer.strokeColor = UIColor.white.cgColor
        layer.lineWidth = 2.5
        return layer
    }()

    private let maskLayer = CAShapeLayer()

    /// Layer that shows hovered state of the chart line
    private let hoveredLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor.gray.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 3
        layer.lineCap = .round
        layer.lineJoin = .round
        layer.backgroundColor = nil
        layer.actions = [
            "position": NSNull(),
            "bounds": NSNull(),
        ]
        return layer
    }()

    /// Label that displays information about the currently selected point
    private let infoLabel: UILabel = {
        let infoLabel = UILabel()
        infoLabel.backgroundColor = UIColor.systemGray5.withAlphaComponent(0.95)
        infoLabel.textColor = .label.withAlphaComponent(0.7)
        infoLabel.font = .systemFont(ofSize: 11, weight: .medium)
        infoLabel.textAlignment = .center
        infoLabel.layer.cornerRadius = 16
        infoLabel.layer.masksToBounds = true
        infoLabel.alpha = 0
        infoLabel.numberOfLines = 1
        infoLabel.layer.zPosition = 5
        return infoLabel
    }()

    // MARK: - Private Properties

    private var xLabels: [UILabel] = []
    private var yLabels: [UILabel] = []
    private var dataPoints: [Point] = []

    private var bottomChartInset: CGFloat {
        (xLabels.first?.bounds.height ?? 0) + configuration.horizontalLabelsToTopPadding
    }

    // MARK: - Initialization

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

    /// Sets up all layers and configures their visual properties
    private func setupLayers() {
        layer.addSublayer(chartLayer)
        layer.addSublayer(cursorLayer)
        layer.addSublayer(hoveredLayer)
        layer.addSublayer(trackingDotLayer)
        addSubview(infoLabel)

        // Configure appearance based on configuration
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

    /// Configures fade-out animation for cursor-related layers
    private func configureCursorLayersAnimation() {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = cursorLayer.opacity
        animation.toValue = 0
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards

        cursorLayer.add(animation, forKey: "opacity")
        hoveredLayer.add(animation, forKey: "opacity")
        infoLabel.layer.add(animation, forKey: "opacity")
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

    /// Updates the chart with new data points
    /// - Parameters:
    ///   - newPoints: Array of new data points to display
    ///   - animated: Whether to animate the transition
    ///   - completion: Callback executed after the update is complete
    public func updateChart(with newPoints: [Point], animated: Bool = true, completion: (() -> Void)? = nil) {
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

    /// Sets up gesture recognizers for chart interaction
    private func setupGestures() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        addGestureRecognizer(panGesture)
    }

    /// Handles pan gesture states and updates cursor position
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

    /// Calculates the width needed for vertical labels based on the maximum value in the dataset
    private func calculateWidthOfVerticalLabels() -> CGFloat {
        guard let maxValue = dataPoints.map({ $0.value }).max() else {
            return 40
        }
        switch maxValue {
        case 0..<100:
            return 40 // XX.X
        case 100..<1000:
            return 48 // XXX.X
        case 1000..<10000:
            return 56 // X,XXX.X
        case 10000..<100000:
            return 64 // XX,XXX.X
        case 100000..<1000000:
            return 72 // XXX,XXX.X
        default:
            return 80
        }
    }

    /// Filters data points to fit within available width while maintaining readability
    private func filterPointsToFit(
        _ data: [ChartPoint],
        availableWidth: CGFloat,
        font: UIFont,
        minSpacing: CGFloat
    ) -> [ChartPoint] {
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

    /// Updates both X and Y axis labels
    private func rebuildLabels(for dataPoints: [Point]) {
        setupYLabels(for: dataPoints, animating: !yLabels.isEmpty && isAnimationEnabled)
        setupXLabels(for: dataPoints)
    }

    /// Configures and updates X-axis labels
    private func setupXLabels(for dataPoints: [ChartPoint]) {
        let padding = configuration.padding
        let verticalLabelsWidth = calculateWidthOfVerticalLabels()
        let availableWidth = bounds.width - padding.left - padding.right - verticalLabelsWidth * 1.5
        let normalizedPoints = filterPointsToFit(
            dataPoints,
            availableWidth: availableWidth,
            font: configuration.horizontalLabelProperties.font,
            minSpacing: 20
        )

        let dateFormatter = configuration.dateFormatter

        // Initialize labels without animation for first setup
        guard !xLabels.isEmpty else {
            xLabels = normalizedPoints.map { point in
                let label = buildLabel(for: dateFormatter.string(from: point.timestamp), isVertical: false)
                addSubview(label)
                return label
            }
            setNeedsLayout()
            layoutIfNeeded()
            return
        }

        updateLabelsWithAnimation(
            oldLabels: xLabels,
            newValues: normalizedPoints.map { dateFormatter.string(from: $0.timestamp) },
            isVertical: false
        )
    }

    /// Configures and updates Y-axis labels
    private func setupYLabels(for dataPoints: [ChartPoint], animating: Bool) {
        guard let minValue = dataPoints.map({ $0.value }).min(),
              let maxValue = dataPoints.map({ $0.value }).max() else { return }
        let divisions = configuration.numberOfVerticalDivisions
        let valueRange = maxValue - minValue
        let step = valueRange / Double(divisions - 1)
        let newValues = (0..<divisions).map { i in
            let value = maxValue - (step * Double(i))
            return String(format: "%.1f", value)
        }
        guard animating else {
            yLabels = newValues.reversed().map { value in
                let label = buildLabel(for: value, isVertical: true)
                addSubview(label)
                return label
            }
            setNeedsLayout()
            layoutIfNeeded()
            return
        }
        updateLabelsWithAnimation(
            oldLabels: yLabels,
            newValues: newValues,
            isVertical: true
        )
    }

    /// Animates the transition between old and new labels
    private func updateLabelsWithAnimation(
        oldLabels: [UILabel],
        newValues: [String],
        isVertical: Bool
    ) {
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
        let animator = UIViewPropertyAnimator(
            duration: 0.3,
            curve: .easeInOut
        ) {
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

    /// Creates a label with specified configuration
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

    /// Updates the layout of X-axis labels
    private func updateXLabelsLayout() {
        let verticalLabelsWidth = calculateWidthOfVerticalLabels()
        let padding = configuration.padding
        let availableWidth = bounds.width - padding.left - padding.right - verticalLabelsWidth

        guard xLabels.count > 1 else {
            if let label = xLabels.first {
                let labelWidth = min(availableWidth, label.frame.width)
                let xPosition = verticalLabelsWidth + padding.left + (availableWidth / 2) - (labelWidth / 2)
                label.frame = CGRect(
                    x: xPosition,
                    y: bounds.height - label.bounds.height,
                    width: labelWidth,
                    height: label.frame.height
                )
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
            label.frame = CGRect(
                origin: CGPoint(x: xOffset, y: bounds.height - label.bounds.height),
                size: CGSize(width: labelWidth, height: label.frame.height)
            )
        }
    }

    /// Updates the layout of Y-axis labels
    private func updateYLabelsLayout() {
        guard !yLabels.isEmpty else { return }
        let padding = configuration.padding
        let availableHeight = bounds.height - padding.top - padding.bottom - bottomChartInset
        let yStep = availableHeight / CGFloat(yLabels.count - 1)
        yLabels.enumerated().forEach { index, label in
            let yPosition = bounds.height - (CGFloat(index) * yStep)
            label.frame = CGRect(
                x: padding.left,
                y: yPosition - (label.frame.height / 2) - bottomChartInset,
                width: label.frame.width,
                height: label.frame.height
            )
        }
    }
}

// MARK: - Cursor Managing

extension LineChartView {

    /// Updates cursor position and related visual elements
    private func updateCursor(at location: CGPoint) {
        // Special case for single point
        if dataPoints.count == 1 {
            let centerX = chartLayer.frame.minX + (chartLayer.frame.width / 2)
            let value = dataPoints[0].value

            // Calculate Y position using similar logic as point rendering
            let yPadding = value * 0.1
            let yMin = value - yPadding
            let yMax = value + yPadding
            let yScale = chartLayer.frame.height / (yMax - yMin)
            let yPosition = chartLayer.frame.maxY - ((value - yMin) * yScale)

            // Draw vertical cursor line
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

        // Original logic for multiple points
        let xOffset = max(chartLayer.frame.minX, min(location.x, chartLayer.frame.maxX))
        let cursorPath = UIBezierPath()
        cursorPath.move(to: CGPoint(x: xOffset, y: chartLayer.frame.minY))
        cursorPath.addLine(to: CGPoint(x: xOffset, y: chartLayer.frame.maxY))
        cursorLayer.path = cursorPath.cgPath

        let maskPath = UIBezierPath(rect: CGRect(
            x: xOffset - chartLayer.frame.minX,
            y: 0,
            width: chartLayer.frame.width - (xOffset - chartLayer.frame.minX),
            height: chartLayer.frame.height
        ))
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
            let finalPoint = CGPoint(
                x: xOffset,
                y: intersectionPoint.y + chartLayer.frame.minY
            )
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

    /// Returns the center point for single data point charts
    private func getSinglePointLocation() -> CGPoint? {
        guard dataPoints.count == 1,
              let path = chartLayer.graphLayer.path else { return nil }
        var boundingBox = path.boundingBox
        boundingBox.origin.y += chartLayer.frame.minY
        return CGPoint(x: boundingBox.midX, y: boundingBox.midY)
    }

    /// Finds intersection point between vertical line and chart path
    private func findIntersectionPoint(at targetX: CGFloat) -> CGPoint? {
        guard let path = chartLayer.graphLayer.path else { return nil }
        var result: CGPoint?
        var previousPoint: CGPoint?
        path.applyWithBlock { element in
            guard result == nil else { return }
            switch element.pointee.type {
            case .moveToPoint:
                previousPoint = element.pointee.points[0]
            case .addLineToPoint:
                if let start = previousPoint {
                    let end = element.pointee.points[0]
                    if let intersection = findLineIntersection(
                        x: targetX,
                        start: start,
                        end: end
                    ) {
                        result = intersection
                    }
                }
                previousPoint = element.pointee.points[0]
            case .addCurveToPoint:
                if let start = previousPoint {
                    let control = element.pointee.points[0]
                    let end = element.pointee.points[1]
                    if let intersection = findCurveIntersection(
                        x: targetX,
                        p0: start,
                        p1: control,
                        p2: end,
                        tolerance: 0.1
                    ) {
                        result = intersection
                    }
                }
                previousPoint = element.pointee.points[1]
            default:
                break
            }
        }
        return result
    }

    /// Finds intersection point between vertical line and line segment
    private func findLineIntersection(x: CGFloat, start: CGPoint, end: CGPoint) -> CGPoint? {
        let minX = min(start.x, end.x) - 0.1
        let maxX = max(start.x, end.x) + 0.1
        guard (minX...maxX).contains(x) else { return nil }
        let t = (x - start.x) / (end.x - start.x)
        let y = start.y + (end.y - start.y) * t
        return CGPoint(x: x, y: y)
    }

    /// Finds intersection point between vertical line and quadratic curve
    private func findCurveIntersection(
        x: CGFloat,
        p0: CGPoint,
        p1: CGPoint,
        p2: CGPoint,
        tolerance: CGFloat
    ) -> CGPoint? {
        let minX = min(p0.x, min(p1.x, p2.x)) - tolerance
        let maxX = max(p0.x, max(p1.x, p2.x)) + tolerance
        guard (minX...maxX).contains(x) else { return nil }
        var lower: CGFloat = 0
        var upper: CGFloat = 1
        for _ in 0..<8 {
            let mid = (lower + upper) / 2
            let point = calculateBezierPoint(t: mid, p0: p0, p1: p1, p2: p2)
            if abs(point.x - x) < tolerance {
                return point
            }
            if point.x < x {
                lower = mid
            } else {
                upper = mid
            }
        }
        let t = (lower + upper) / 2
        return calculateBezierPoint(t: t, p0: p0, p1: p1, p2: p2)
    }

    /// Calculates point on quadratic Bezier curve at parameter t
    private func calculateBezierPoint(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
        let mt = 1 - t
        let mt2 = mt * mt
        let t2 = t * t
        return CGPoint(
            x: mt2 * p0.x + 2 * mt * t * p1.x + t2 * p2.x,
            y: mt2 * p0.y + 2 * mt * t * p1.y + t2 * p2.y
        )
    }

    /// Updates tracking dot position and appearance
    private func updateTrackingDot(at point: CGPoint) {
        let dotSize: CGFloat = configuration.dotProperties.size
        let dotPath = UIBezierPath(
            ovalIn: CGRect(
                x: -dotSize / 2,
                y: -dotSize / 2,
                width: dotSize,
                height: dotSize
            )
        )
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackingDotLayer.path = dotPath.cgPath
        trackingDotLayer.position = point
        trackingDotLayer.opacity = 1
        CATransaction.commit()
    }

    /// Returns index of nearest data point to given x coordinate
    private func getNearestPointIndex(at x: CGFloat) -> Int {
        guard !dataPoints.isEmpty else { return 0 }
        let xScale = chartLayer.bounds.width / CGFloat(max(1, dataPoints.count - 1))
        let index = Int(round(x / xScale))
        return max(0, min(index, dataPoints.count - 1))
    }

    /// Hides all cursor-related visual elements
    private func hideCursor() {
        cursorLayer.opacity = 0
        infoLabel.alpha = 0
        hoveredLayer.opacity = 0
        trackingDotLayer.opacity = 0
        cursorFocusedSubject.send(.endMoved)
    }
}
// swiftlint:enable file_length
