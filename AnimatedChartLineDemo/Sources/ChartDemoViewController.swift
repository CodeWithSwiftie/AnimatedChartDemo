//
//  ChartDemoViewController.swift
//  AnimatedChartDemo
//
//  Created by Vlad T. on 03.02.2024.
//  Copyright © 2024 Vlad T. All rights reserved.
//
//  Demo view controller showcasing LineChartView capabilities
//

import UIKit

final class ChartDemoViewController: UIViewController {
    
    private let chartView: LineChartView
    private var updateTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        var configuration = LineChartAppearanceConfiguration()
        configuration.showsVerticalGridLines = false
        configuration.dateFormatter.dateFormat = "HH:mm"
        configuration.padding.right = 0
        configuration.hoverLineColor = .systemGray5
        
        chartView = LineChartView(configuration: configuration) { point in
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "\(formatter.string(from: point.timestamp)), \(String(format: "%.1f", point.value))"
        }
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startDemoSequence()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        // Add title label
        let titleLabel = UILabel()
        titleLabel.text = "Interactive Chart Demo"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        stackView.addArrangedSubview(titleLabel)
        
        // Add chart view
        chartView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(chartView)
        
        // Add description label
        let descriptionLabel = UILabel()
        descriptionLabel.text = "Touch and drag to explore data points"
        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.textAlignment = .center
        stackView.addArrangedSubview(descriptionLabel)
        
        // Add reset button
        let resetButton = UIButton(type: .system)
        resetButton.setTitle("Reset Demo", for: .normal)
        resetButton.addTarget(self, action: #selector(resetDemo), for: .touchUpInside)
        stackView.addArrangedSubview(resetButton)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            chartView.heightAnchor.constraint(equalToConstant: 300)
        ])
    }
    
    // MARK: - Demo Logic
    
    private func startDemoSequence() {
        // Initial state
        chartView.updateChart(with: generateRandomDotPoints(count: 3))
        
        // Define update sequence
        let updates: [(delay: TimeInterval, count: Int)] = [
            (delay: 1.0, count: 1),
            (delay: 3.0, count: 24),
            (delay: 5.0, count: 48),
            (delay: 7.0, count: 96),
            (delay: 9.0, count: 1),
            (delay: 11.0, count: 24)
        ]
        
        // Schedule updates
        for update in updates {
            DispatchQueue.main.asyncAfter(deadline: .now() + update.delay) { [weak self] in
                self?.chartView.updateChart(
                    with: self?.generateRandomDotPoints(
                        count: update.count,
                        volatility: 1.0
                    ) ?? []
                )
            }
        }
    }
    
    @objc private func resetDemo() {
        // Cancel any pending updates
        updateTimer?.invalidate()
        updateTimer = nil
        
        // Restart demo sequence
        startDemoSequence()
    }
    
    // MARK: - Helper Methods
    
    private func generateRandomDotPoints(
        count: Int,
        startDate: Date = Date(),
        minValue: Double = 0,
        maxValue: Double = 100,
        volatility: Double = 5.0
    ) -> [ChartPoint] {
        var points: [ChartPoint] = []
        let calendar = Calendar.current
        var currentValue = Double.random(in: minValue...maxValue)
        
        for i in 0..<count {
            let change = Double.random(in: -volatility...volatility)
            currentValue = max(minValue, min(maxValue, currentValue + change))
            let date = calendar.date(
                byAdding: .minute,
                value: i * 30,
                to: startDate
            ) ?? startDate
            let point = ChartPoint(value: currentValue, timestamp: date)
            points.append(point)
        }
        
        return points
    }
}

// MARK: - Preview Provider

#if DEBUG
@available(iOS 17.0, *)
#Preview {
    ChartDemoViewController()
}
#endif
