//
//  BarcodeScannerView.swift
//  CountMe
//
//  View for scanning product barcodes to look up nutritional information
//

import SwiftUI
import SwiftData
import AVFoundation

/// Barcode scanner view that uses the device camera to scan product barcodes
///
/// This view provides:
/// - Camera preview for barcode scanning
/// - Real-time barcode detection
/// - Haptic feedback on successful scan
/// - Manual entry fallback
/// - Permission handling
///
/// Requirements: Food search and entry
struct BarcodeScannerView: View {
    /// The calorie tracker business logic
    @Bindable var tracker: CalorieTracker
    
    /// Controls dismissal of this view
    @Environment(\.dismiss) private var dismiss
    
    /// Scanned barcode value
    @State private var scannedCode: String?
    
    /// Loading state during barcode lookup
    @State private var isLoading: Bool = false
    
    /// Error message to display
    @State private var errorMessage: String?
    
    /// Camera permission status
    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined
    
    /// Controls navigation to manual entry
    @State private var showingManualEntry: Bool = false
    
    /// Search result from barcode lookup
    @State private var searchResult: NutritionSearchResult?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview or permission prompt
                if cameraPermission == .authorized {
                    BarcodeScannerCameraView(
                        scannedCode: $scannedCode,
                        onCodeScanned: handleScannedCode
                    )
                    .ignoresSafeArea()
                } else {
                    permissionView
                }
                
                // Overlay UI
                VStack {
                    Spacer()
                    
                    // Scanning frame indicator
                    if cameraPermission == .authorized && !isLoading {
                        scanningFrameOverlay
                    }
                    
                    Spacer()
                    
                    // Status message
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if cameraPermission == .authorized {
                        instructionView
                    }
                }
                .padding()
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingManualEntry = true
                    } label: {
                        Label("Manual Entry", systemImage: "pencil.circle")
                    }
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView(tracker: tracker)
            }
            .sheet(item: $searchResult) { result in
                ServingAdjustmentView(searchResult: result, tracker: tracker)
            }
            .task {
                await checkCameraPermission()
            }
        }
    }
    
    // MARK: - View Components
    
    /// Permission request view
    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("CountMe needs camera access to scan barcodes. Please grant permission in Settings.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if cameraPermission == .denied {
                Button {
                    openSettings()
                } label: {
                    Label("Open Settings", systemImage: "gear")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    /// Scanning frame overlay
    private var scanningFrameOverlay: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(Color.white, lineWidth: 3)
            .frame(width: 280, height: 200)
            .shadow(color: .black.opacity(0.3), radius: 10)
    }
    
    /// Instruction view
    private var instructionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 40))
                .foregroundColor(.white)
            
            Text("Position barcode within frame")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(20)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }
    
    /// Loading view
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Looking up product...")
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(24)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }
    
    /// Error view
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Product Not Found")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button {
                    errorMessage = nil
                    scannedCode = nil
                } label: {
                    Text("Scan Again")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(.white)
                
                Button {
                    showingManualEntry = true
                } label: {
                    Text("Manual Entry")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    /// Checks camera permission status
    private func checkCameraPermission() async {
        cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
        
        if cameraPermission == .notDetermined {
            cameraPermission = await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
        }
    }
    
    /// Opens app settings
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    /// Handles a scanned barcode
    private func handleScannedCode(_ code: String) {
        // Prevent duplicate scans
        guard scannedCode != code else { return }
        
        scannedCode = code
        isLoading = true
        errorMessage = nil
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        Task {
            do {
                // Search for the barcode
                let results = try await tracker.searchFood(query: code)
                
                await MainActor.run {
                    isLoading = false
                    
                    if let firstResult = results.first {
                        // Show serving adjustment for the found product
                        searchResult = firstResult
                    } else {
                        errorMessage = "No product found for this barcode. Try manual entry instead."
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if let apiError = error as? NutritionAPIError {
                        errorMessage = apiError.errorDescription
                    } else {
                        errorMessage = "Unable to look up product. Please try again or use manual entry."
                    }
                }
            }
        }
    }
}

// MARK: - Camera View

/// Camera view for barcode scanning using AVFoundation
struct BarcodeScannerCameraView: UIViewControllerRepresentable {
    /// Binding to the scanned code
    @Binding var scannedCode: String?
    
    /// Callback when a code is scanned
    let onCodeScanned: (String) -> Void
    
    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let controller = BarcodeScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(scannedCode: $scannedCode, onCodeScanned: onCodeScanned)
    }
    
    class Coordinator: NSObject, BarcodeScannerDelegate {
        @Binding var scannedCode: String?
        let onCodeScanned: (String) -> Void
        
        init(scannedCode: Binding<String?>, onCodeScanned: @escaping (String) -> Void) {
            self._scannedCode = scannedCode
            self.onCodeScanned = onCodeScanned
        }
        
        func didScanBarcode(_ code: String) {
            onCodeScanned(code)
        }
    }
}

// MARK: - Barcode Scanner Delegate

protocol BarcodeScannerDelegate: AnyObject {
    func didScanBarcode(_ code: String)
}

// MARK: - Barcode Scanner View Controller

class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: BarcodeScannerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let captureSession = captureSession, !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let captureSession = captureSession, captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.stopRunning()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else { return }
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .code39]
        } else {
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            delegate?.didScanBarcode(stringValue)
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DailyLog.self, FoodItem.self, configurations: config)
    let context = ModelContext(container)
    
    let dataStore = DataStore(modelContext: context)
    let tracker = CalorieTracker(
        dataStore: dataStore,
        apiClient: NutritionAPIClient(
            consumerKey: "preview",
            consumerSecret: "preview"
        )
    )
    
    BarcodeScannerView(tracker: tracker)
}
