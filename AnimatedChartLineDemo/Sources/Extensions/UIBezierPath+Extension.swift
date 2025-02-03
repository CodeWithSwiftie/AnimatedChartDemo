import UIKit

extension UIBezierPath {
    /// Draws a smooth curve through given points using Catmull-Rom spline converted to cubic Bézier curves, clamping points inside bounds.
    func clampedSmoothCurve(through points: [CGPoint], in bounds: CGRect) {
        // Ensure that there are at least two points.
        guard points.count > 1 else { return }
        
        // Move to the first clamped point.
        move(to: points[0].clamped(in: bounds))
        
        for i in 0 ..< points.count - 1 {
            // Determine neighboring points for Catmull-Rom algorithm.
            let p0 = i > 0 ? points[i - 1] : points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i + 2 < points.count ? points[i + 2] : points[i + 1]
            
            // Calculate control points using Catmull-Rom to cubic Bézier conversion.
            var cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6,
                y: p1.y + (p2.y - p0.y) / 6
            )
            var cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6,
                y: p2.y - (p3.y - p1.y) / 6
            )
            
            // Clamp control points within the provided bounds.
            cp1 = cp1.clamped(in: bounds)
            cp2 = cp2.clamped(in: bounds)
            let clampedP2 = p2.clamped(in: bounds)
            
            // Add the cubic Bézier curve segment.
            addCurve(to: clampedP2, controlPoint1: cp1, controlPoint2: cp2)
        }
    }
}

private extension CGPoint {
    /// Clamps the point within the specified rectangle.
    func clamped(in rect: CGRect) -> CGPoint {
        return CGPoint(
            x: min(max(x, rect.minX), rect.maxX),
            y: min(max(y, rect.minY), rect.maxY)
        )
    }
}
