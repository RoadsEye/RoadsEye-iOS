import SwiftUI
import Combine

struct SettingsMenu: View {
    // MARK: - Properties
    @ObservedObject private var viewModel = SettingsViewModel.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("selectedAppearance") private var selectedAppearance: String = "System"
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.09) : .white
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.15) : Color(.systemGray6)
    }
    
    private let accentColor = Color(red: 0.0, green: 0.68, blue: 1.0)
    
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                Picker("Settings Tab", selection: $selectedTab) {
                    Text("General").tag(0)
                    Text("Storage").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(cardBackgroundColor)
                        .padding(.horizontal, 16)
                )
                
                ScrollView {
                    if selectedTab == 0 {
                        generalSettings
                    } else {
                        StorageTab()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme, for: .navigationBar)
        }
        .id("settings_root_\(selectedAppearance)")
        .onAppear {
            customizeSegmentedControlAppearance()
        }
    }

    // MARK: - General Settings (all features available to everyone)
    private var generalSettings: some View {
        LazyVStack(spacing: 20) {
            VideoSettingsSection(
                viewModel: viewModel,
                backgroundColor: backgroundColor,
                cardBackgroundColor: cardBackgroundColor,
                accentColor: accentColor
            )

            AudioSettingsSection(
                viewModel: viewModel,
                backgroundColor: backgroundColor,
                cardBackgroundColor: cardBackgroundColor,
                accentColor: accentColor
            )

            RecordingSettingsSection(
                viewModel: viewModel,
                backgroundColor: backgroundColor,
                cardBackgroundColor: cardBackgroundColor,
                accentColor: accentColor
            )

            UISettingsSection(
                viewModel: viewModel,
                backgroundColor: backgroundColor,
                cardBackgroundColor: cardBackgroundColor,
                accentColor: accentColor
            )

            OtherSettingsSection(
                viewModel: viewModel,
                backgroundColor: backgroundColor,
                cardBackgroundColor: cardBackgroundColor,
                accentColor: accentColor
            )

            InfoSection(
                viewModel: viewModel,
                backgroundColor: backgroundColor,
                cardBackgroundColor: cardBackgroundColor,
                accentColor: accentColor
            )
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }

    private func customizeSegmentedControlAppearance() {
        let segmentedAppearance = UISegmentedControl.appearance()
        segmentedAppearance.selectedSegmentTintColor = UIColor(accentColor)
        segmentedAppearance.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segmentedAppearance.setTitleTextAttributes([.foregroundColor: colorScheme == .dark ? UIColor.white : UIColor.black], for: .normal)
        segmentedAppearance.backgroundColor = UIColor(cardBackgroundColor)
    }
}

// MARK: - Storage Tab
struct StorageTab: View {
    @ObservedObject var settingsViewModel = SettingsViewModel.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var usedMB: Int64 = 0
    @State private var showDeleteAllAlert = false
    @State private var showFolderInstructions = false

    @State private var cacheBytes: Int64 = 0
    @State private var showDeleteCacheAlert = false
    @State private var showRecordingBlockedAlert = false
    @State private var isClearingCache = false
    @State private var cacheClearedMessage: String?

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.09) : .white
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.15) : Color(.systemGray6)
    }
    
    private let accentColor = Color(red: 0.0, green: 0.68, blue: 1.0)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Storage Usage Card
                VStack(spacing: 20) {
                    Text("Storage Usage")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        ProgressView(value: Double(usedMB), total: Double(settingsViewModel.maxStorageMB))
                            .tint(accentColor)
                            .scaleEffect(x: 1, y: 1.8, anchor: .center)
                        
                        HStack {
                            Text("\(usedMB) MB used")
                                .font(.subheadline)
                            Spacer()
                            Text("\(settingsViewModel.maxStorageMB) MB limit")
                                .font(.subheadline)
                        }
                    }
                    .padding()
                    .background(cardBackgroundColor)
                    .cornerRadius(16)
                    
                    HStack(spacing: 16) {
                        Button(action: openRoadsEyeFolder) {
                            Label("Open Videos Folder", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: { showDeleteAllAlert = true }) {
                            Label("Delete All", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .padding(.horizontal)

                // Cache Card
                VStack(spacing: 20) {
                    Text("Cache")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Cached data")
                                .font(.subheadline)
                            Spacer()
                            Text(CacheManager.shared.formattedSize(cacheBytes))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Text(cacheClearedMessage ?? "Temporary files left over from recording and processing. Your saved recordings and clips are not affected.")
                            .font(.caption)
                            .foregroundStyle(cacheClearedMessage == nil ? .secondary : Color.green)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(cardBackgroundColor)
                    .cornerRadius(16)

                    Button(action: {
                        if RecordingManager.shared.isRecording {
                            showRecordingBlockedAlert = true
                        } else {
                            showDeleteCacheAlert = true
                        }
                    }) {
                        HStack {
                            if isClearingCache {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text(isClearingCache ? "Clearing Cache…" : "Delete Cache")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isClearingCache)
                }
                .padding(.horizontal)
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            Task {
                usedMB = await VideoFileManager.shared.calculateRoadsEyeStorageUsage()
                cacheBytes = await CacheManager.shared.calculateCacheSize()
            }
        }
        .alert("Delete All Recordings?", isPresented: $showDeleteAllAlert) {
            Button("Delete All", role: .destructive) {
                Task {
                    let success = await VideoFileManager.shared.deleteAllRoadsEyeFiles(excludeSpecialFolders: true)
                    await VideoFileManager.shared.deleteSavedRecordingsFromPhotoLibrary()
                    if success {
                        usedMB = await VideoFileManager.shared.calculateRoadsEyeStorageUsage()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all normal recordings from the app and your Photo Library. Crash clips and manual clips will be preserved.")
        }
        .alert("Open RoadsEye Folder", isPresented: $showFolderInstructions) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("1. Open the **Files** app on your iPhone\n2. Tap **On My iPhone**\n3. Tap the **RoadsEye** folder\n\nYour videos are saved in:\n• ManualClips\n• CrashClips")
        }
        .alert("Delete Cache?", isPresented: $showDeleteCacheAlert) {
            Button("Delete Cache", role: .destructive) { clearCache() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove \(CacheManager.shared.formattedSize(cacheBytes)) of temporary files. Your saved recordings, manual clips and crash clips will not be deleted.")
        }
        .alert("Recording in Progress", isPresented: $showRecordingBlockedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Stop recording before deleting the cache, so the video currently being written isn't lost.")
        }
    }

    private func clearCache() {
        isClearingCache = true
        cacheClearedMessage = nil

        Task {
            // Never remove the file the recorder is still writing to.
            var excluded: [String] = []
            if let activeURL = RecordingManager.shared.getCurrentRecordingURL() {
                excluded.append(activeURL.path)
            }

            let freed = await CacheManager.shared.clearCache(excluding: excluded)
            cacheBytes = await CacheManager.shared.calculateCacheSize()
            usedMB = await VideoFileManager.shared.calculateRoadsEyeStorageUsage()

            cacheClearedMessage = freed > 0
                ? "Freed \(CacheManager.shared.formattedSize(freed)) of cached data."
                : "Cache is already empty."
            isClearingCache = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    private func openRoadsEyeFolder() {
        VideoFileManager.shared.ensureRoadsEyeFoldersExist()

        // Open the RoadsEye folder directly in the Files app; fall back to
        // the instructions alert if the URL can't be opened.
        let folderURL = VideoFileManager.shared.getRoadsEyeDirectory()
        let sharedDocsPath = folderURL.absoluteString.replacingOccurrences(of: "file://", with: "shareddocuments://")

        if let url = URL(string: sharedDocsPath), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url) { success in
                if !success {
                    showFolderInstructions = true
                }
            }
        } else {
            showFolderInstructions = true
        }
    }
}

// MARK: - Previews
struct SettingsMenu_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsMenu()
        }
    }
}
