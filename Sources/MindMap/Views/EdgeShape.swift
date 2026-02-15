import SwiftUI

enum BorderSide {
    case top, bottom, left, right
}

struct EdgeShape: View {
    var from: CGPoint
    var to: CGPoint
    var fromSize: CGSize = CGSize(width: 132, height: 44)
    var toSize: CGSize = CGSize(width: 132, height: 44)
    var color: Color = .secondary
    var dash: [CGFloat]? = nil
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil

    private let arrowLength: CGFloat = 10
    private let arrowAngle: CGFloat = .pi / 6
    private let cpDistance: CGFloat = 50
    private let padding: CGFloat = 8

    private var curvePoints: CurvePoints? {
        Self.computeCurve(from: from, to: to, fromSize: fromSize, toSize: toSize, cpDistance: cpDistance, arrowLength: arrowLength)
    }

    var body: some View {
        if let pts = curvePoints {
            let bounds = computeBounds(pts)
            let ox = -bounds.minX
            let oy = -bounds.minY

            let localSourceExit = CGPoint(x: pts.sourceExit.x + ox, y: pts.sourceExit.y + oy)
            let localArrowBase = CGPoint(x: pts.arrowBase.x + ox, y: pts.arrowBase.y + oy)
            let localTip = CGPoint(x: pts.tip.x + ox, y: pts.tip.y + oy)
            let localCp1 = CGPoint(x: pts.cp1.x + ox, y: pts.cp1.y + oy)
            let localCp2 = CGPoint(x: pts.cp2.x + ox, y: pts.cp2.y + oy)

            ZStack {
                Canvas { context, size in
                    let drawColor = isSelected ? Color.accentColor : color

                    var curve = Path()
                    curve.move(to: localSourceExit)
                    curve.addCurve(to: localArrowBase, control1: localCp1, control2: localCp2)

                    var strokeStyle = StrokeStyle(lineWidth: isSelected ? 2.5 : 2, lineCap: .round)
                    if let dash { strokeStyle.dash = dash }
                    context.stroke(curve, with: .color(drawColor), style: strokeStyle)

                    // Arrowhead
                    let left = CGPoint(
                        x: localTip.x - arrowLength * cos(pts.arrowDir - arrowAngle),
                        y: localTip.y - arrowLength * sin(pts.arrowDir - arrowAngle)
                    )
                    let right = CGPoint(
                        x: localTip.x - arrowLength * cos(pts.arrowDir + arrowAngle),
                        y: localTip.y - arrowLength * sin(pts.arrowDir + arrowAngle)
                    )

                    var arrow = Path()
                    arrow.move(to: localTip)
                    arrow.addLine(to: left)
                    arrow.addLine(to: right)
                    arrow.closeSubpath()
                    context.fill(arrow, with: .color(drawColor))
                }
                .allowsHitTesting(false)

                // Invisible thick hit area for tap detection
                if onTap != nil {
                    Path { path in
                        path.move(to: localSourceExit)
                        path.addCurve(to: localArrowBase, control1: localCp1, control2: localCp2)
                    }
                    .stroke(Color.clear, lineWidth: 12)
                    .contentShape(
                        Path { path in
                            path.move(to: localSourceExit)
                            path.addCurve(to: localArrowBase, control1: localCp1, control2: localCp2)
                        }
                        .strokedPath(StrokeStyle(lineWidth: 12, lineCap: .round))
                    )
                    .onTapGesture {
                        onTap?()
                    }
                }
            }
            .frame(width: bounds.width, height: bounds.height)
            .position(x: bounds.midX, y: bounds.midY)
        }
    }

    private func computeBounds(_ pts: CurvePoints) -> CGRect {
        let arrowLeft = CGPoint(
            x: pts.tip.x - arrowLength * cos(pts.arrowDir - arrowAngle),
            y: pts.tip.y - arrowLength * sin(pts.arrowDir - arrowAngle)
        )
        let arrowRight = CGPoint(
            x: pts.tip.x - arrowLength * cos(pts.arrowDir + arrowAngle),
            y: pts.tip.y - arrowLength * sin(pts.arrowDir + arrowAngle)
        )

        let allPoints = [pts.sourceExit, pts.arrowBase, pts.cp1, pts.cp2, pts.tip, arrowLeft, arrowRight]
        let minX = allPoints.map(\.x).min()! - padding
        let minY = allPoints.map(\.y).min()! - padding
        let maxX = allPoints.map(\.x).max()! + padding
        let maxY = allPoints.map(\.y).max()! + padding

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: - Shared geometry

    struct CurvePoints {
        var sourceExit: CGPoint
        var tip: CGPoint
        var arrowBase: CGPoint
        var cp1: CGPoint
        var cp2: CGPoint
        var arrowDir: CGFloat
    }

    static func computeCurve(from: CGPoint, to: CGPoint, fromSize: CGSize, toSize: CGSize, cpDistance: CGFloat, arrowLength: CGFloat) -> CurvePoints? {
        let dx = to.x - from.x
        let dy = to.y - from.y
        guard dx != 0 || dy != 0 else { return nil }

        let angle = atan2(dy, dx)
        let side = sideFromAngle(angle + .pi)
        let sourceSide = sideFromAngle(angle)

        let fromHalfW = fromSize.width / 2
        let fromHalfH = fromSize.height / 2
        let toHalfW = toSize.width / 2
        let toHalfH = toSize.height / 2

        let tip = borderPointForSide(center: to, side: side, halfW: toHalfW, halfH: toHalfH)

        let cp2: CGPoint
        switch side {
        case .top:    cp2 = CGPoint(x: tip.x, y: tip.y - cpDistance)
        case .bottom: cp2 = CGPoint(x: tip.x, y: tip.y + cpDistance)
        case .left:   cp2 = CGPoint(x: tip.x - cpDistance, y: tip.y)
        case .right:  cp2 = CGPoint(x: tip.x + cpDistance, y: tip.y)
        }

        let sourceExit = borderPointForSide(center: from, side: sourceSide, halfW: fromHalfW, halfH: fromHalfH)

        let cp1: CGPoint
        switch sourceSide {
        case .top:    cp1 = CGPoint(x: sourceExit.x, y: sourceExit.y - cpDistance)
        case .bottom: cp1 = CGPoint(x: sourceExit.x, y: sourceExit.y + cpDistance)
        case .left:   cp1 = CGPoint(x: sourceExit.x - cpDistance, y: sourceExit.y)
        case .right:  cp1 = CGPoint(x: sourceExit.x + cpDistance, y: sourceExit.y)
        }

        let arrowDir: CGFloat
        switch side {
        case .top:    arrowDir = .pi / 2
        case .bottom: arrowDir = -.pi / 2
        case .left:   arrowDir = 0
        case .right:  arrowDir = .pi
        }

        let arrowBase = CGPoint(
            x: tip.x - arrowLength * cos(arrowDir),
            y: tip.y - arrowLength * sin(arrowDir)
        )

        return CurvePoints(sourceExit: sourceExit, tip: tip, arrowBase: arrowBase, cp1: cp1, cp2: cp2, arrowDir: arrowDir)
    }

    static func sideFromAngle(_ angle: CGFloat) -> BorderSide {
        let a = angle < 0 ? angle + 2 * .pi : angle
        if a < .pi / 4 || a >= 7 * .pi / 4 {
            return .right
        } else if a < 3 * .pi / 4 {
            return .bottom
        } else if a < 5 * .pi / 4 {
            return .left
        } else {
            return .top
        }
    }

    static func borderPointForSide(center: CGPoint, side: BorderSide, halfW: CGFloat, halfH: CGFloat) -> CGPoint {
        switch side {
        case .top:    return CGPoint(x: center.x, y: center.y - halfH)
        case .bottom: return CGPoint(x: center.x, y: center.y + halfH)
        case .left:   return CGPoint(x: center.x - halfW, y: center.y)
        case .right:  return CGPoint(x: center.x + halfW, y: center.y)
        }
    }
}
