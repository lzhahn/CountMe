//
//  ToastView.swift
//  CountMe
//
//  Reusable toast notification component for success and error messages
//

import SwiftUI

/// Toast notification style
enum ToastStyle {
    case success
    case error
    case info
    case warning
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        case .warning: return .orange
        }
    }
}

/// Toast notification view for displaying temporary messages
struct ToastView: View {
    let message: String
    let style: ToastStyle
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: style.icon)
                .foregroundColor(style.color)
                .font(.title3)
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
}

/// View modifier for displaying toast notifications
struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let style: ToastStyle
    let duration: TimeInterval
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isPresented {
                    ToastView(message: message, style: style)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation {
                                    isPresented = false
                                }
                            }
                        }
                        .padding(.top, 8)
                }
            }
    }
}

extension View {
    /// Displays a toast notification
    /// - Parameters:
    ///   - isPresented: Binding to control toast visibility
    ///   - message: Message to display
    ///   - style: Toast style (success, error, info, warning)
    ///   - duration: How long to display the toast (default 2.5 seconds)
    func toast(
        isPresented: Binding<Bool>,
        message: String,
        style: ToastStyle = .info,
        duration: TimeInterval = 2.5
    ) -> some View {
        modifier(ToastModifier(
            isPresented: isPresented,
            message: message,
            style: style,
            duration: duration
        ))
    }
}

// MARK: - Preview

#Preview("Success Toast") {
    VStack {
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
    .overlay(alignment: .top) {
        ToastView(message: "Custom meal saved successfully!", style: .success)
            .padding(.top, 50)
    }
}

#Preview("Error Toast") {
    VStack {
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
    .overlay(alignment: .top) {
        ToastView(message: "Unable to save custom meal. Please try again.", style: .error)
            .padding(.top, 50)
    }
}

#Preview("Warning Toast") {
    VStack {
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
    .overlay(alignment: .top) {
        ToastView(message: "AI parsing may be incomplete. Please review carefully.", style: .warning)
            .padding(.top, 50)
    }
}
