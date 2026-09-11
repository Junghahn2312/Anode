import Foundation
import Combine
import SwiftUI

@MainActor
public class TraktStore: ObservableObject {
    public static let shared = TraktStore()
    
    @Published public var items: [ContinueWatchingItem] = []
    @Published public var isConnected: Bool = false
    @Published public var username: String = ""
    @Published public var clientId: String = ""
    @Published public var accessToken: String = ""
    @Published public var useSampleData: Bool = true
    @Published public var deviceCode: TraktService.DeviceCodeResponse? = nil
    @Published public var isAuthorizing: Bool = false
    @Published public var authErrorMessage: String? = nil
    @Published public var isSyncing: Bool = false
    
    private let service = TraktService.shared
    private var pollTask: Task<Void, Never>?
    
    public init() {
        loadPreferences()
        Task {
            await refresh()
        }
    }
    
    private func loadPreferences() {
        self.username = UserDefaults.standard.string(forKey: "trakt_username") ?? ""
        self.clientId = UserDefaults.standard.string(forKey: "trakt_client_id") ?? ""
        self.accessToken = UserDefaults.standard.string(forKey: "trakt_access_token") ?? ""
        self.useSampleData = UserDefaults.standard.object(forKey: "trakt_use_sample_data") as? Bool ?? true
        self.isConnected = !self.accessToken.isEmpty
    }
    
    public func savePreferences() {
        UserDefaults.standard.set(username, forKey: "trakt_username")
        UserDefaults.standard.set(clientId, forKey: "trakt_client_id")
        UserDefaults.standard.set(accessToken, forKey: "trakt_access_token")
        UserDefaults.standard.set(useSampleData, forKey: "trakt_use_sample_data")
        self.isConnected = !self.accessToken.isEmpty
    }
    
    public func refresh() async {
        isSyncing = true
        defer { isSyncing = false }
        
        if isConnected && !useSampleData {
            let live = await service.fetchPlaybackProgress()
            if !live.isEmpty {
                self.items = live
                return
            }
        }
        
        // Use sample continue watching data when not connected or enabled
        self.items = await service.samplePlaybackItems()
    }
    
    public func startDeviceAuth() async {
        isAuthorizing = true
        authErrorMessage = nil
        do {
            let code = try await service.requestDeviceCode()
            self.deviceCode = code
            startPolling(deviceCode: code.deviceCode, interval: code.interval, expiresIn: code.expiresIn)
        } catch {
            authErrorMessage = "Could not initialize device code. Check network connection."
            isAuthorizing = false
        }
    }
    
    private func startPolling(deviceCode: String, interval: Int, expiresIn: Int) {
        pollTask?.cancel()
        pollTask = Task {
            let deadline = Date().addingTimeInterval(TimeInterval(expiresIn))
            while Date() < deadline {
                try? await Task.sleep(nanoseconds: UInt64(max(interval, 5)) * 1_000_000_000)
                if Task.isCancelled { return }
                
                if let token = try? await service.pollDeviceToken(deviceCode: deviceCode) {
                    self.accessToken = token.accessToken
                    self.isConnected = true
                    self.isAuthorizing = false
                    self.deviceCode = nil
                    self.savePreferences()
                    await self.refresh()
                    return
                }
            }
            
            self.isAuthorizing = false
            self.authErrorMessage = "Device code expired. Please request a new code."
        }
    }
    
    public func cancelDeviceAuth() {
        pollTask?.cancel()
        pollTask = nil
        isAuthorizing = false
        deviceCode = nil
    }
    
    public func connectManual(username: String, clientId: String, accessToken: String) {
        self.username = username
        self.clientId = clientId
        self.accessToken = accessToken
        self.savePreferences()
        Task {
            await refresh()
        }
    }
    
    public func disconnect() {
        cancelDeviceAuth()
        self.username = ""
        self.accessToken = ""
        self.isConnected = false
        self.savePreferences()
        Task {
            await refresh()
        }
    }
    
    public func toggleSampleData(_ enabled: Bool) {
        self.useSampleData = enabled
        savePreferences()
        Task {
            await refresh()
        }
    }
}
