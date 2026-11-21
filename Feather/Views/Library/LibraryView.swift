//
//  LibraryView.swift
//  UG Sign
//
//  eSign-style Apps tab. Lists unsigned and signed applications with the
//  same action sheet eSign uses.
//

import SwiftUI
import CoreData
import NimbleViews
import NimbleExtensions
import UniformTypeIdentifiers

// MARK: - View
struct LibraryView: View {
	@StateObject var downloadManager = DownloadManager.shared
	
	@State private var _selectedInfoAppPresenting: AnyApp?
	@State private var _selectedSigningAppPresenting: AnyApp?
	@State private var _selectedInstallAppPresenting: AnyApp?
	@State private var _actionApp: AnyApp?
	@State private var _deletingApp: AnyApp?
	
	@State private var _isImportingPresenting = false
	@State private var _isDownloadingPresenting = false
	@State private var _alertDownloadString = ""
	
	@State private var _searchText = ""
	@State private var _scope: Scope = .unsigned
	@State private var _isSelecting = false
	@State private var _selectedAppUUIDs: Set<String> = []
	
	@State private var _isArchiving = false
	@State private var _archivingText = ""
	@State private var _messageTitle = ""
	@State private var _messageBody: String?
	
	// MARK: Fetch
	@FetchRequest(
		entity: Signed.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
		animation: .snappy
	) private var _signedApps: FetchedResults<Signed>
	
	@FetchRequest(
		entity: Imported.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Imported.date, ascending: false)],
		animation: .snappy
	) private var _importedApps: FetchedResults<Imported>
	
	private var _apps: [AppInfoPresentable] {
		let source: [AppInfoPresentable] = _scope == .signed
			? _signedApps.map { $0 as AppInfoPresentable }
			: _importedApps.map { $0 as AppInfoPresentable }
		
		return source.filter {
			_searchText.isEmpty ||
			(($0.name ?? "").localizedCaseInsensitiveContains(_searchText)) ||
			(($0.identifier ?? "").localizedCaseInsensitiveContains(_searchText))
		}
	}
	
	// MARK: Body
	var body: some View {
		NBNavigationView("", displayMode: .inline) {
			List {
				if _apps.isEmpty {
					Section {
						VStack(spacing: 10) {
							Image(systemName: "square.grid.2x2")
								.font(.system(size: 40))
								.foregroundStyle(.secondary)
							Text(_scope == .signed ? .localized("No Signed Apps") : .localized("No Unsigned Apps"))
								.font(.headline)
							Text(.localized("Import an IPA file to sign and install it."))
								.font(.footnote)
								.foregroundStyle(.secondary)
								.multilineTextAlignment(.center)
						}
						.frame(maxWidth: .infinity)
						.padding(.vertical, 40)
						.listRowBackground(Color.clear)
						.listRowSeparator(.hidden)
					}
				} else {
					ForEach(Array(_apps.enumerated()), id: \.offset) { _, app in
						AppsRowView(
							app: app,
							isSelecting: _isSelecting,
							isSelected: _selectedAppUUIDs.contains(app.uuid ?? "")
						)
						.contentShape(Rectangle())
						.onTapGesture {
							if _isSelecting {
								_toggleSelection(app)
							} else {
								_actionApp = AnyApp(base: app)
							}
						}
						.listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
					}
				}
			}
			.listStyle(.plain)
			.searchable(
				text: $_searchText,
				placement: .navigationBarDrawer(displayMode: .always),
				prompt: .localized("Search")
			)
			.toolbar {
				ToolbarItem(placement: .principal) {
					Picker("", selection: $_scope) {
						Text(.localized("Unsigned")).tag(Scope.unsigned)
						Text(.localized("Signed")).tag(Scope.signed)
					}
					.pickerStyle(.segmented)
					.labelsHidden()
					.frame(width: 210)
				}
				
				ToolbarItem(placement: .topBarLeading) {
					if _isSelecting {
						Button(.localized("Delete"), role: .destructive) { _bulkDelete() }
							.disabled(_selectedAppUUIDs.isEmpty)
					} else {
						Menu {
							_importActions()
						} label: {
							Image(systemName: "plus.circle.fill")
								.font(.system(size: 21))
						}
					}
				}
				
				ToolbarItem(placement: .topBarTrailing) {
					if _isSelecting {
						Button(.localized("Done")) {
							withAnimation(.easeInOut(duration: 0.2)) {
								_isSelecting = false
								_selectedAppUUIDs.removeAll()
							}
						}
						.bold()
					} else {
						Button(.localized("Select")) {
							withAnimation(.easeInOut(duration: 0.2)) {
								_isSelecting = true
							}
						}
					}
				}
			}
			.sheet(item: $_selectedInfoAppPresenting) { app in
				LibraryInfoView(app: app.base)
			}
			.sheet(item: $_selectedInstallAppPresenting) { app in
				InstallPreviewView(app: app.base, isSharing: app.archive)
					.presentationDetents([.height(200)])
					.presentationDragIndicator(.visible)
			}
			.fullScreenCover(item: $_selectedSigningAppPresenting) { app in
				SigningView(app: app.base)
			}
			.sheet(isPresented: $_isImportingPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.ipa, .tipa],
					allowsMultipleSelection: true,
					onDocumentsPicked: { urls in
						for url in urls {
							let id = "UGSignManualDownload_\(UUID().uuidString)"
							let download = downloadManager.startArchive(from: url, id: id)
							try? downloadManager.handlePachageFile(url: url, dl: download)
						}
					}
				)
				.ignoresSafeArea()
			}
			.alert(.localized("Import from URL"), isPresented: $_isDownloadingPresenting) {
				TextField(.localized("URL"), text: $_alertDownloadString)
					.textInputAutocapitalization(.never)
					.keyboardType(.URL)
				Button(.localized("Cancel"), role: .cancel) { _alertDownloadString = "" }
				Button(.localized("OK")) {
					if let url = URL(string: _alertDownloadString) {
						_ = downloadManager.startDownload(from: url, id: "UGSignManualDownload_\(UUID().uuidString)")
					}
				}
			}
			.confirmationDialog(
				_actionApp?.base.name ?? "",
				isPresented: Binding(
					get: { _actionApp != nil },
					set: { if !$0 { _actionApp = nil } }
				),
				titleVisibility: .visible,
				presenting: _actionApp
			) { app in
				Button(.localized("Signature"), systemImage: "signature") {
					_selectedSigningAppPresenting = app
				}
				Button(.localized("Install"), systemImage: "square.and.arrow.down") {
					_selectedInstallAppPresenting = app
				}
				Button(.localized("Extract Dylibs"), systemImage: "puzzlepiece.extension") {
					_extractDylibs(app.base)
				}
				Button(.localized("Details"), systemImage: "info.circle") {
					_selectedInfoAppPresenting = app
				}
				Button(.localized("Share"), systemImage: "square.and.arrow.up") {
					_share(app.base)
				}
				Button(.localized("View file location"), systemImage: "folder") {
					_viewLocation(app.base)
				}
				Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
					_deletingApp = app
				}
				Button(.localized("Cancel"), role: .cancel) {}
			}
			.alert(
				.localized("Delete App"),
				isPresented: Binding(
					get: { _deletingApp != nil },
					set: { if !$0 { _deletingApp = nil } }
				),
				presenting: _deletingApp
			) { app in
				Button(.localized("Delete"), role: .destructive) {
					Storage.shared.deleteApp(for: app.base)
					_deletingApp = nil
				}
				Button(.localized("Cancel"), role: .cancel) {}
			} message: { app in
				Text(.localized("Are you sure you want to delete “%@”?", arguments: app.base.name ?? ""))
			}
			.alert(
				_messageTitle,
				isPresented: Binding(
					get: { _messageBody != nil },
					set: { if !$0 { _messageBody = nil } }
				)
			) {
				Button(.localized("OK"), role: .cancel) {}
			} message: {
				Text(_messageBody ?? "")
			}
			.overlay {
				if _isArchiving {
					ZStack {
						Color.black.opacity(0.45).ignoresSafeArea()
						VStack(spacing: 14) {
							ProgressView().tint(.white)
							Text(_archivingText)
								.font(.subheadline)
								.foregroundStyle(.white)
						}
						.padding(24)
						.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
					}
				}
			}
			.onReceive(NotificationCenter.default.publisher(for: Notification.Name("UGSign.installApp"))) { _ in
				if let latest = _signedApps.first {
					_selectedInstallAppPresenting = AnyApp(base: latest)
				}
			}
		}
	}
}

// MARK: - Scope
extension LibraryView {
	enum Scope: Hashable {
		case unsigned
		case signed
	}
}

// MARK: - Extension: Actions
extension LibraryView {
	@ViewBuilder
	private func _importActions() -> some View {
		Button(.localized("Import from Files"), systemImage: "folder") {
			_isImportingPresenting = true
		}
		Button(.localized("Import from URL"), systemImage: "globe") {
			_isDownloadingPresenting = true
		}
	}
	
	private func _toggleSelection(_ app: AppInfoPresentable) {
		guard let uuid = app.uuid else { return }
		if _selectedAppUUIDs.contains(uuid) {
			_selectedAppUUIDs.remove(uuid)
		} else {
			_selectedAppUUIDs.insert(uuid)
		}
	}
	
	private func _bulkDelete() {
		let all: [AppInfoPresentable] = _signedApps.map { $0 as AppInfoPresentable } + _importedApps.map { $0 as AppInfoPresentable }
		for app in all where _selectedAppUUIDs.contains(app.uuid ?? "") {
			Storage.shared.deleteApp(for: app)
		}
		_selectedAppUUIDs.removeAll()
		_isSelecting = false
	}
	
	private func _viewLocation(_ app: AppInfoPresentable) {
		guard
			let directory = Storage.shared.getUuidDirectory(for: app),
			let url = directory.toSharedDocumentsURL()
		else { return }
		UIApplication.open(url)
	}
	
	private func _share(_ app: AppInfoPresentable) {
		_isArchiving = true
		_archivingText = .localized("Packaging…")
		
		let viewModel = InstallerStatusViewModel(isIdevice: false)
		Task {
			defer {
				_isArchiving = false
			}
			
			do {
				let handler = ArchiveHandler(app: app, viewModel: viewModel)
				try await handler.move()
				let package = try await handler.archive()
				UIActivityViewController.show(activityItems: [package])
			} catch {
				_messageTitle = .localized("Error")
				_messageBody = error.localizedDescription
			}
		}
	}
	
	private func _extractDylibs(_ app: AppInfoPresentable) {
		guard let appDirectory = Storage.shared.getAppDirectory(for: app) else {
			_messageTitle = .localized("Error")
			_messageBody = .localized("The app bundle could not be found.")
			return
		}
		
		let name = app.name ?? "App"
		let destination = URL.documentsDirectory
			.appendingPathComponent("Extracted", isDirectory: true)
			.appendingPathComponent(name, isDirectory: true)
		
		var extracted = 0
		if let enumerator = FileManager.default.enumerator(
			at: appDirectory,
			includingPropertiesForKeys: [.isRegularFileKey],
			options: [.skipsHiddenFiles]
		) {
			for case let fileURL as URL in enumerator where fileURL.pathExtension.lowercased() == "dylib" {
				do {
					try FileManager.default.createDirectoryIfNeeded(at: destination)
					let target = destination.appendingPathComponent(fileURL.lastPathComponent)
					try? FileManager.default.removeItem(at: target)
					try FileManager.default.copyItem(at: fileURL, to: target)
					extracted += 1
				} catch {
					continue
				}
			}
		}
		
		_messageTitle = .localized("Extract Dylibs")
		if extracted > 0 {
			_messageBody = .localized("Extracted %d dylib(s) to Files/Extracted/%@.", arguments: extracted, name)
		} else {
			_messageBody = .localized("No dylibs were found inside this app.")
		}
	}
}

// MARK: - Row
struct AppsRowView: View {
	let app: AppInfoPresentable
	let isSelecting: Bool
	let isSelected: Bool
	
	@State private var _sizeText: String = ""
	
	var body: some View {
		HStack(spacing: 12) {
			if isSelecting {
				Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
					.font(.system(size: 22))
					.foregroundStyle(isSelected ? Color(hex: "#0A84FF") : Color.secondary)
					.transition(.scale.combined(with: .opacity))
			}
			
			FRAppIconView(app: app, size: 58)
			
			VStack(alignment: .leading, spacing: 3) {
				Text(app.name ?? .localized("Unknown"))
					.font(.system(size: 17, weight: .semibold))
					.lineLimit(1)
				
				Text(_subtitle)
					.font(.system(size: 13))
					.foregroundStyle(.secondary)
					.lineLimit(1)
				
				Text(_fileName)
					.font(.system(size: 13))
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
			
			Spacer(minLength: 0)
		}
		.padding(.vertical, 5)
		.task(id: app.uuid) {
			await _loadSize()
		}
	}
	
	private var _subtitle: String {
		var parts: [String] = []
		if let version = app.version, !version.isEmpty {
			parts.append("V\(version)")
		}
		if !_sizeText.isEmpty {
			parts.append(_sizeText)
		}
		if let identifier = app.identifier, !identifier.isEmpty {
			parts.append(identifier)
		}
		return parts.joined(separator: " | ")
	}
	
	private var _fileName: String {
		if let name = app.name, !name.isEmpty {
			return "\(name).ipa"
		}
		return "\(app.uuid ?? "").ipa"
	}
	
	private func _loadSize() async {
		guard let directory = Storage.shared.getUuidDirectory(for: app) else { return }
		let url = directory
		
		let size = await Task.detached(priority: .utility) {
			AppSizeCache.size(of: url)
		}.value
		
		_sizeText = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
	}
}

// MARK: - Size cache
enum AppSizeCache {
	private static var _cache: [String: Int64] = [:]
	private static let _lock = NSLock()
	
	static func size(of directory: URL) -> Int64 {
		_lock.lock()
		if let cached = _cache[directory.path] {
			_lock.unlock()
			return cached
		}
		_lock.unlock()
		
		var total: Int64 = 0
		if let enumerator = FileManager.default.enumerator(
			at: directory,
			includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
			options: [.skipsHiddenFiles]
		) {
			for case let url as URL in enumerator {
				if let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
				   values.isRegularFile == true {
					total += Int64(values.fileSize ?? 0)
				}
			}
		}
		
		_lock.lock()
		_cache[directory.path] = total
		_lock.unlock()
		return total
	}
}
