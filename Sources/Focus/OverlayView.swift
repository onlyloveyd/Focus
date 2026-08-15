import SwiftUI

struct OverlayView: View {
    @ObservedObject var model: OverlayModel
    @FocusState private var reasonFocused: Bool

    var body: some View {
        ZStack {
            Color.clear
            VStack(spacing: 22) {
                if let icon = model.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 92, height: 92)
                } else {
                    Image(systemName: "app.dashed")
                        .resizable()
                        .frame(width: 92, height: 92)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Text(model.titleText)
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.white)

                Text(model.subtitleText)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.55))

                VStack(spacing: 14) {
                    TextField(model.copy.placeholder, text: $model.reason)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 380)
                        .font(.system(size: 15))
                        .focused($reasonFocused)
                        .onSubmit { model.submitTapped() }

                    HStack(spacing: 16) {
                        Button {
                            model.abortTapped()
                        } label: {
                            Text(model.copy.abortTitle)
                                .foregroundStyle(.white)
                                .frame(minWidth: 110)
                        }
                        .keyboardShortcut(.cancelAction)
                        .buttonStyle(.bordered)
                        .tint(.white.opacity(0.85))

                        Button {
                            model.submitTapped()
                        } label: {
                            Text(model.remaining > 0
                                 ? model.copy.submitCountdown(model.remaining)
                                 : model.copy.submitTitle)
                                .frame(minWidth: 110)
                        }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .disabled(!model.canSubmit)
                    }

                    Text(model.hint)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(EdgeInsets(top: 26, leading: 30, bottom: 22, trailing: 30))
                .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.08)))
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                reasonFocused = true
            }
        }
    }
}
