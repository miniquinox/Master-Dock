import SwiftUI

public struct LiquidWaveformView: View {
    public let levels: [Float]
    public let averagePower: Float
    public let isRecording: Bool
    
    @State private var phase: Double = 0.0
    
    public init(levels: [Float] = [], averagePower: Float = 0.2, isRecording: Bool = true) {
        self.levels = levels
        self.averagePower = averagePower
        self.isRecording = isRecording
    }
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let width = size.width
                let height = size.height
                let midY = height / 2.0
                
                let time = timeline.date.timeIntervalSinceReferenceDate
                let activePower = CGFloat(max(0.12, averagePower))
                
                // Draw 3 harmonic overlapping liquid wave layers
                drawWave(
                    in: &context,
                    width: width,
                    midY: midY,
                    amplitude: (height * 0.38) * activePower,
                    frequency: 2.2,
                    phase: time * 3.5,
                    colors: [
                        Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.8),
                        Color(red: 0.7, green: 0.3, blue: 1.0).opacity(0.8)
                    ]
                )
                
                drawWave(
                    in: &context,
                    width: width,
                    midY: midY,
                    amplitude: (height * 0.28) * activePower,
                    frequency: 3.4,
                    phase: -time * 2.8 + 1.2,
                    colors: [
                        Color(red: 0.9, green: 0.2, blue: 0.6).opacity(0.65),
                        Color(red: 0.3, green: 0.8, blue: 1.0).opacity(0.65)
                    ]
                )
                
                drawWave(
                    in: &context,
                    width: width,
                    midY: midY,
                    amplitude: (height * 0.18) * activePower,
                    frequency: 4.8,
                    phase: time * 4.2 + 2.5,
                    colors: [
                        Color(red: 0.4, green: 0.9, blue: 0.5).opacity(0.5),
                        Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.5)
                    ]
                )
            }
        }
        .frame(height: 70)
    }
    
    private func drawWave(
        in context: inout GraphicsContext,
        width: CGFloat,
        midY: CGFloat,
        amplitude: CGFloat,
        frequency: CGFloat,
        phase: Double,
        colors: [Color]
    ) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: midY))
        
        let step: CGFloat = 3.0
        for x in stride(from: 0, through: width, by: step) {
            let relativeX = x / width
            // Bell curve envelope so the wave is smooth at the edges
            let envelope = sin(relativeX * .pi)
            let y = midY + sin(relativeX * frequency * 2 * .pi + phase) * amplitude * envelope
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        let gradient = Gradient(colors: colors)
        context.stroke(
            path,
            with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: width, y: 0)),
            style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
        )
    }
}
