import SwiftUI

// MARK: – Confetti piece

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let xStart: CGFloat     // 0…1 fraction of width
    let xDrift: CGFloat     // horizontal drift in points
    let color: Color
    let size: CGFloat
    let delay: Double
    let duration: Double
    let rotation: Double
    let isRect: Bool
}

private func makeConfetti() -> [ConfettiPiece] {
    let colors: [Color] = [
        .green, .teal, .blue, .purple, .pink, .orange, .yellow,
        Color(red: 0.3, green: 0.9, blue: 0.6),
        Color(red: 1.0, green: 0.4, blue: 0.4)
    ]
    return (0..<90).map { _ in
        ConfettiPiece(
            xStart:   CGFloat.random(in: 0.05...0.95),
            xDrift:   CGFloat.random(in: -60...60),
            color:    colors.randomElement()!,
            size:     CGFloat.random(in: 5...11),
            delay:    Double.random(in: 0...0.8),
            duration: Double.random(in: 1.8...3.2),
            rotation: Double.random(in: 0...720),
            isRect:   Bool.random()
        )
    }
}

// MARK: – Main overlay

struct CelebrationOverlay: View {
    let onDismiss: () -> Void

    @State private var pieces: [ConfettiPiece] = makeConfetti()
    @State private var fallen: Set<UUID> = []
    @State private var checkScale: CGFloat = 0
    @State private var checkOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0
    @State private var messageOffset: CGFloat = 12
    @State private var messageOpacity: Double = 0
    @State private var overlayOpacity: Double = 0
    @Environment(\.appAccent) private var accent

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Backdrop ──────────────────────────────────────
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }

                // ── Confetti ──────────────────────────────────────
                ForEach(pieces) { piece in
                    ConfettiView(piece: piece, height: geo.size.height, fallen: fallen.contains(piece.id))
                        .position(x: geo.size.width * piece.xStart, y: 0)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + piece.delay) {
                                withAnimation(.easeIn(duration: piece.duration)) {
                                    _ = fallen.insert(piece.id)
                                }
                            }
                        }
                }

                // ── Central card ──────────────────────────────────
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 22) {
                        // Animated ring + checkmark
                        ZStack {
                            Circle()
                                .strokeBorder(accent.opacity(0.25), lineWidth: 2)
                                .frame(width: 110, height: 110)
                                .scaleEffect(ringScale)
                                .opacity(ringOpacity)

                            Circle()
                                .fill(accent.opacity(0.12))
                                .frame(width: 90, height: 90)
                                .scaleEffect(checkScale)

                            Image(systemName: "checkmark")
                                .font(.system(size: 38, weight: .bold))
                                .foregroundStyle(accent)
                                .scaleEffect(checkScale)
                                .opacity(checkOpacity)
                        }

                        // Message
                        VStack(spacing: 8) {
                            Text(LocalizedStringKey("celebration.title"))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.primary)

                            Text(LocalizedStringKey("celebration.subtitle"))
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 260)
                        }
                        .offset(y: messageOffset)
                        .opacity(messageOpacity)
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.18), radius: 30, y: 10)
                    )

                    Spacer()
                }
                .padding(.horizontal, 60)
            }
        }
        .opacity(overlayOpacity)
        .onAppear { animate() }
    }

    private func animate() {
        // Fade in overlay
        withAnimation(.easeOut(duration: 0.25)) { overlayOpacity = 1 }

        // Spring checkmark
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.1)) {
            checkScale = 1
            ringScale = 1.15
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
            checkOpacity = 1
            ringOpacity = 1
        }
        // Ring pulse out
        withAnimation(.easeOut(duration: 0.5).delay(0.35)) {
            ringScale = 1.35
            ringOpacity = 0
        }

        // Message slides up
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.25)) {
            messageOffset = 0
            messageOpacity = 1
        }

        // Auto dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) { dismiss() }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.35)) { overlayOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onDismiss() }
    }
}

// MARK: – Single confetti piece

private struct ConfettiView: View {
    let piece: ConfettiPiece
    let height: CGFloat
    let fallen: Bool

    var body: some View {
        Group {
            if piece.isRect {
                RoundedRectangle(cornerRadius: 2)
                    .fill(piece.color.opacity(0.85))
                    .frame(width: piece.size, height: piece.size * 0.5)
            } else {
                Circle()
                    .fill(piece.color.opacity(0.85))
                    .frame(width: piece.size, height: piece.size)
            }
        }
        .rotationEffect(.degrees(fallen ? piece.rotation : 0))
        .offset(x: fallen ? piece.xDrift : 0,
                y: fallen ? height + 20 : -10)
        .opacity(fallen ? 0 : 1)
    }
}
