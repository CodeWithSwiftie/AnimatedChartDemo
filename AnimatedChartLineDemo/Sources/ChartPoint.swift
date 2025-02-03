//
//  ChartPoint.swift
//  AnimatedChartDemo
//
//  Created by Vlad T. on 03.02.2024.
//  Copyright © 2024 Vlad T. All rights reserved.
//
//  Data model representing a single point on the chart
//

import Foundation

public struct ChartPoint: Hashable {
    public let value: Double
    public let timestamp: Date
    
    public init(value: Double, timestamp: Date) {
        self.value = value
        self.timestamp = timestamp
    }
}

public enum ChartCursorEvent {
    case moved(_ point: ChartPoint)
    case begin, endMoved
}

extension ChartCursorEvent: Equatable {
    public static func == (lhs: ChartCursorEvent, rhs: ChartCursorEvent) -> Bool {
        switch (lhs, rhs) {
        case (.moved(let lhsPoint), .moved(let rhsPoint)):
            return lhsPoint == rhsPoint
        case (.begin, .begin): return true
        case (.endMoved, .endMoved): return true
        default: return false
        }
    }
}
