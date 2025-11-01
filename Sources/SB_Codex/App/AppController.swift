import AppKit
import Foundation

@MainActor
final class AppController {
    private let permissionManager = PermissionManager()
    private var cursorMonitor: CursorMonitor?
    private var captureScheduler: CaptureScheduler
    private let screenshotCapturer = ScreenshotCapturer()
    private let contextProvider = SystemContextProvider()
    private let configurationLoader = ConfigurationLoader()
    private let aiOrchestrator: AIOrchestrator
    private let providerDescriptor: String
    private var configuration: AppConfiguration
    private let textAnalyzer = TextAnalyzer()
    private var permissionAlertDisplayed = false
    private var isRequestInFlight = false
    private var lastCursorLocation: CGPoint?
    private var lastCaptureMetadata: CaptureMetadata?
    private var lastForegroundBundleIdentifier: String?
    private var sessionPromptTokens = 0
    private var sessionCompletionTokens = 0
    private var sessionTotalTokens = 0
    private var lastTokenUsage: TokenUsage?
    private var currentMode: InteractionMode

    private(set) var isActive: Bool = false {
        didSet {
            if oldValue != isActive {
                stateChangeHandler?(isActive)
            }
        }
    }

    var commentaryHandler: ((Result<AIResponse, Error>) -> Void)?
    var stateChangeHandler: ((Bool) -> Void)?
    var modeChangeHandler: ((InteractionMode) -> Void)?
    var providerSummary: String { providerDescriptor }
    var appConfiguration: AppConfiguration { configuration }
    var latestCursorLocation: CGPoint? { lastCursorLocation }
    var latestCaptureMetadata: CaptureMetadata? { lastCaptureMetadata }
    var interactionMode: InteractionMode { currentMode }
    var tokenUsageStats: TokenUsageStats? {
        guard sessionTotalTokens > 0 else { return nil }
        return TokenUsageStats(
            last: lastTokenUsage,
            totalPromptTokens: sessionPromptTokens,
            totalCompletionTokens: sessionCompletionTokens,
            totalTokens: sessionTotalTokens
        )
    }

    init() {
        configurationLoader.ensureDirectoryExists()

        let configuration = configurationLoader.load()
        self.configuration = configuration

        if let apiKey = configuration.openAIAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty {
            let model = configuration.openAIModel?.trimmingCharacters(in: .whitespacesAndNewlines)
            let baseURLString = configuration.openAIBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines)
            let modelName = model?.isEmpty == false ? model! : "gpt-4o-mini"
            let baseURL = baseURLString.flatMap(URL.init(string:)) ?? URL(string: "https://api.openai.com/v1")!
            aiOrchestrator = AIOrchestrator(provider: OpenAIProvider(apiKey: apiKey, model: modelName, baseURL: baseURL))
            Logger.info("Using OpenAI provider for commentary.")
            providerDescriptor = "OpenAI (\(modelName))"
        } else {
            aiOrchestrator = AIOrchestrator(provider: LocalAIProvider())
            Logger.warning("No OpenAI API key configured. Using mock responses.")
            providerDescriptor = "Mock offline"
        }
        let initialMode = configuration.interactionMode ?? .casual
        currentMode = initialMode
        captureScheduler = CaptureScheduler(configuration: AppController.schedulerConfiguration(for: initialMode))
    }

    func start() {
        guard !isActive else { return }
        Logger.info("Starting capture pipeline.")

        let status = permissionManager.currentStatus()
        if !status.allGranted {
            let updatedStatus = permissionManager.requestMissingPermissions()
            if !updatedStatus.allGranted {
                presentPermissionReminder(for: updatedStatus)
                Logger.warning("Required permissions missing; capture pipeline remains inactive.")
                return
            }
        }

        captureScheduler.reset()
        lastForegroundBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        isActive = true
        let monitor = CursorMonitor { [weak self] snapshot in
            Task { @MainActor [weak self] in
                self?.handle(cursorSnapshot: snapshot)
            }
        }
        cursorMonitor = monitor
        monitor.start()
    }

    func stop() {
        guard isActive else { return }
        Logger.info("Stopping capture pipeline.")
        cursorMonitor?.stop()
        cursorMonitor = nil
        captureScheduler.reset()
        isActive = false
    }

    func toggle() {
        if isActive {
            stop()
        } else {
            start()
        }
    }

    private func handle(cursorSnapshot: CursorSnapshot) {
        guard isActive else { return }
        lastCursorLocation = cursorSnapshot.location
        let currentBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if currentBundleIdentifier != lastForegroundBundleIdentifier {
            captureScheduler.reset()
            lastForegroundBundleIdentifier = currentBundleIdentifier
        }
        guard captureScheduler.register(snapshot: cursorSnapshot) else { return }
        guard !isRequestInFlight else {
            Logger.info("Skipping capture; a previous request is still processing.")
            return
        }

        isRequestInFlight = true

        do {
            let screenSize = primaryScreenSize()
            let scale = primaryScreenScale()
            let artifact = try screenshotCapturer.capture(around: cursorSnapshot.location, screenSize: screenSize, scale: scale)
            let metadata = contextProvider.metadata(for: cursorSnapshot.location, screenSize: screenSize)
            let hotspots = textAnalyzer.recognizeText(in: artifact.image, screenRect: artifact.screenRect)
            let enrichedMetadata = metadata.updatingHotspots(hotspots)
            self.lastCaptureMetadata = enrichedMetadata
            let orchestrator = aiOrchestrator
            let mode = currentMode

            Task(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                do {
                    let response = try await orchestrator.requestCommentary(for: artifact, metadata: enrichedMetadata, mode: mode)
                    self.recordTokenUsage(response.usage)
                    self.dispatchCommentary(result: .success(response))
                } catch {
                    self.dispatchCommentary(result: .failure(error))
                }
                self.isRequestInFlight = false
            }
        } catch {
            isRequestInFlight = false
            dispatchCommentary(result: .failure(error))
        }
    }

    private func primaryScreenSize() -> CGSize {
        if let frame = NSScreen.main?.frame {
            return frame.size
        }
        return CGSize(width: 1440, height: 900)
    }

    private func primaryScreenScale() -> CGFloat {
        NSScreen.main?.backingScaleFactor ?? 1
    }

    private func dispatchCommentary(result: Result<AIResponse, Error>) {
        commentaryHandler?(result)
    }

    func updateMode(_ mode: InteractionMode) {
        guard mode != currentMode else { return }
        currentMode = mode
        configuration.interactionMode = mode
        configurationLoader.save(configuration)
        captureScheduler = CaptureScheduler(configuration: AppController.schedulerConfiguration(for: mode))
        captureScheduler.reset()
        sessionPromptTokens = 0
        sessionCompletionTokens = 0
        sessionTotalTokens = 0
        lastTokenUsage = nil
        Logger.info("Interaction mode switched to \(mode.rawValue).")
        modeChangeHandler?(mode)
    }

    private func recordTokenUsage(_ usage: TokenUsage?) {
        guard let usage else { return }
        lastTokenUsage = usage
        sessionPromptTokens += usage.promptTokens
        sessionCompletionTokens += usage.completionTokens
        sessionTotalTokens += usage.totalTokens
    }

    private static func schedulerConfiguration(for mode: InteractionMode) -> CaptureSchedulerConfiguration {
        switch mode {
        case .casual:
            return .default
        case .focus:
            return CaptureSchedulerConfiguration(
                minimumInterval: 12,
                maximumInterval: 90,
                minimumMovement: 60
            )
        case .accessibility:
            return CaptureSchedulerConfiguration(
                minimumInterval: 6,
                maximumInterval: 75,
                minimumMovement: 40
            )
        }
    }

    private func presentPermissionReminder(for status: PermissionStatus) {
        guard !permissionAlertDisplayed else { return }
        permissionAlertDisplayed = true

        let alert = NSAlert()
        alert.messageText = "Permissions Needed"
        var informativeText: [String] = []
        if !status.screenRecordingGranted {
            informativeText.append("• Enable Screen Recording for this app in System Settings → Privacy & Security → Screen Recording.")
        }
        if !status.accessibilityGranted {
            informativeText.append("• Enable Accessibility access for this app in System Settings → Privacy & Security → Accessibility.")
        }
        alert.informativeText = informativeText.joined(separator: "\n")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "OK")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
