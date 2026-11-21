//
//  FileListView.swift
//  UG Sign
//
//  eSign-style file browser for the app's Documents directory.
//

import SwiftUI
import NimbleViews
import NimbleExtensions
import UniformTypeIdentifiers
import CoreData

// MARK: - Model
struct FileItem: Identifiable, Hashable {
	let url: URL
	let name: String
	let isDirectory: Bool
	let size: Int64
	let date: Date?
	
	var id: String { url.path }
	var pathExtension: String { url.pathExtension.lowercased() }
	
	var kind: String {
		if isDirectory { return .localized("Folder") }
		if pathExtension.isEmpty { return .localized("File") }
		return pathExtension.uppercased()
	}
	
	var subtitle: String {
		if isDirectory {
			let count = (try? FileManager.default.contentsOfDirectory(atPath: url.path).count) ?? 0
			return .localized("%d items", arguments: count)
		}
		
		let sizeText = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
		if let date {
			let formatter = DateFormatter()
			formatter.dateFormat = "HH:mm:ss"
			return "\(sizeText)   \(formatter.string(from: date))"
		}
		return sizeText
	}
	
	var icon: String {
		if isDirectory { return "folder.fill" }
		switch pathExtension {
		case "ipa", "tipa":	return "app.fill"
		case "zip":			return "doc.zipper"
		case "deb":			return "shippingbox.fill"
		case "dylib":		return "puzzlepiece.extension.fill"
		case "p12":			return "key.fill"
		case "mobileprovision": return "checkmark.seal.fill"
		case "plist":		return "list.bullet.rectangle.fill"
		case "png", "jpg", "jpeg", "webp": return "photo.fill"
		default:			return "doc.fill"
		}
	}
	
	var iconColor: Color {
		if isDirectory { return Color(hex: "#0A84FF") }
		switch pathExtension {
		case "ipa", "tipa":	return Color(hex: "#0A84FF")
		case "zip":			return Color(hex: "#FF9F0A")
		case "deb":			return Color(hex: "#A2845E")
		case "dylib":		return Color(hex: "#BF5AF2")
		case "p12":			return Color(hex: "#30D158")
		case "mobileprovision": return Color(hex: "#30D158")
		case "plist":		return Color(hex: "#8E8E93")
		case "png", "jpg", "jpeg", "webp": return Color(hex: "#FF375F")
		default:			return Color(hex: "#8E8E93")
		}
	}
	
	var isInstallable: Bool {
		!isDirectory && (pathExtension == "ipa" || pathExtension == "tipa")
	}
}

// MARK: - View
struct FileListView: View {
	@State private var _path: [URL] = []
	@State private var _searchText = ""
	@State private var _items: [FileItem] = []
	@State private var _isImportingPresenting = false
	@State private var _isNewFolderPresenting = false
	@State private var _newFolderName = ""
	@State private var _selectedItem: FileItem?
	@State private var _infoItem: FileItem?
	@State private var _deletingItem: FileItem?
	@State private var _signingApp: AnyApp?
	@State private var _installApp: AnyApp?
	@State private var _isPreparingPackage = false
	@State private var _preparingText = ""
	@State private var _errorMessage: String?
	
	private let _root = URL.documentsDirectory
	
	// MARK: Body
	var body: some View {
		NavigationStack(path: $_path) {
			_content(for: _root)
				.navigationDestination(for: URL.self) { url in
					_content(for: url)
				}
		}
		.fullScreenCover(item: $_signingApp) { app in
			SigningView(app: app.base)
		}
		.sheet(item: $_installApp) { app in
			InstallPreviewView(app: app.base, isSharing: app.archive)
				.presentationDetents([.height(200)])
				.presentationDragIndicator(.visible)
		}
		.onReceive(NotificationCenter.default.publisher(for: Notification.Name("UGSign.installApp"))) { _ in
			let request = NSFetchRequest<Signed>(entityName: "Signed")
			request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
			request.fetchLimit = 1
			if let app = try? Storage.shared.context.fetch(request).first {
				_installApp = AnyApp(base: app)
			}
		}
	}
	
	// MARK: Content
	@ViewBuilder
	private func _content(for directory: URL) -> some View {
		let visible = _filteredItems
		
		List {
			if visible.isEmpty {
				Section {
					VStack(spacing: 10) {
						Image(systemName: "folder")
							.font(.system(size: 38))
							.foregroundStyle(.secondary)
						Text(_searchText.isEmpty ? .localized("No Files") : .localized("No Results"))
							.font(.headline)
						Text(.localized("Import an IPA, certificate or any other file to get started."))
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
				ForEach(visible) { item in
					_row(item)
						.listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
						.swipeActions(edge: .trailing) {
							Button(role: .destructive) {
								_deletingItem = item
							} label: {
								Label(.localized("Delete"), systemImage: "trash")
							}
							
							if !item.isDirectory {
								Button {
									UIActivityViewController.show(activityItems: [item.url])
								} label: {
									Label(.localized("Share"), systemImage: "square.and.arrow.up")
								}
								.tint(Color(hex: "#0A84FF"))
							}
						}
				}
			}
		}
		.listStyle(.plain)
		.navigationTitle(directory == _root ? .localized("File List") : directory.lastPathComponent)
		.navigationBarTitleDisplayMode(.inline)
		.searchable(
			text: $_searchText,
			placement: .navigationBarDrawer(displayMode: .always),
			prompt: .localized("Search")
		)
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Menu {
					Button(.localized("Import File"), systemImage: "square.and.arrow.down") {
						_isImportingPresenting = true
					}
					Button(.localized("New Folder"), systemImage: "folder.badge.plus") {
						_newFolderName = ""
						_isNewFolderPresenting = true
					}
					Divider()
					Button(.localized("Open in Files"), systemImage: "folder") {
						if let url = directory.toSharedDocumentsURL() {
							UIApplication.open(url)
						}
					}
				} label: {
					Image(systemName: "ellipsis.circle.fill")
						.font(.system(size: 21))
						.foregroundStyle(.secondary)
				}
			}
		}
		.onAppear { _reload(directory) }
		.onChange(of: directory) { _ in _reload(directory) }
		.sheet(isPresented: $_isImportingPresenting) {
			FileImporterRepresentableView(
				allowedContentTypes: [.item],
				allowsMultipleSelection: true,
				onDocumentsPicked: { urls in
					_import(urls, into: directory)
				}
			)
			.ignoresSafeArea()
		}
		.sheet(item: $_infoItem) { item in
			FileInfoView(item: item)
		}
		.alert(.localized("New Folder"), isPresented: $_isNewFolderPresenting) {
			TextField(.localized("Folder name"), text: $_newFolderName)
			Button(.localized("Cancel"), role: .cancel) {}
			Button(.localized("Create")) { _createFolder(in: directory) }
		}
		.alert(
			.localized("Delete File"),
			isPresented: Binding(
				get: { _deletingItem != nil },
				set: { if !$0 { _deletingItem = nil } }
			),
			presenting: _deletingItem
		) { item in
			Button(.localized("Delete"), role: .destructive) { _delete(item) }
			Button(.localized("Cancel"), role: .cancel) {}
		} message: { item in
			Text(.localized("Are you sure you want to delete “%@”?", arguments: item.name))
		}
		.confirmationDialog(
			_selectedItem?.name ?? "",
			isPresented: Binding(
				get: { _selectedItem != nil },
				set: { if !$0 { _selectedItem = nil } }
			),
			titleVisibility: .visible,
			presenting: _selectedItem
		) { item in
			if item.isInstallable {
				Button(.localized("Signature"), systemImage: "signature") { _prepare(item, install: false) }
				Button(.localized("Install"), systemImage: "square.and.arrow.down") { _prepare(item, install: true) }
			}
			Button(.localized("Share"), systemImage: "square.and.arrow.up") {
				UIActivityViewController.show(activityItems: [item.url])
			}
			Button(.localized("Info"), systemImage: "info.circle") { _infoItem = item }
			Button(.localized("Delete"), systemImage: "trash", role: .destructive) { _deletingItem = item }
			Button(.localized("Cancel"), role: .cancel) {}
		}
		.alert(
			.localized("Error"),
			isPresented: Binding(
				get: { _errorMessage != nil },
				set: { if !$0 { _errorMessage = nil } }
			)
		) {
			Button(.localized("OK"), role: .cancel) {}
		} message: {
			Text(_errorMessage ?? "")
		}
		.overlay {
			if _isPreparingPackage {
				ZStack {
					Color.black.opacity(0.45).ignoresSafeArea()
					VStack(spacing: 14) {
						ProgressView()
							.tint(.white)
						Text(_preparingText)
							.font(.subheadline)
							.foregroundStyle(.white)
					}
					.padding(24)
					.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
				}
			}
		}
	}
	
	// MARK: Row
	@ViewBuilder
	private func _row(_ item: FileItem) -> some View {
		HStack(spacing: 12) {
			HStack(spacing: 12) {
				Image(systemName: item.icon)
					.font(.system(size: 22, weight: .semibold))
					.foregroundStyle(item.iconColor)
					.frame(width: 42, height: 42)
					.background(item.iconColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
				
				VStack(alignment: .leading, spacing: 3) {
					Text(item.name)
						.font(.system(size: 16, weight: .semibold))
						.lineLimit(1)
					Text(item.subtitle)
						.font(.system(size: 13))
						.foregroundStyle(.secondary)
						.lineLimit(1)
				}
				
				Spacer(minLength: 0)
			}
			.contentShape(Rectangle())
			.onTapGesture {
				if item.isDirectory {
					_path.append(item.url)
				} else {
					_selectedItem = item
				}
			}
			
			Button {
				_infoItem = item
			} label: {
				Image(systemName: "info.circle")
					.font(.system(size: 20))
					.foregroundStyle(Color(hex: "#0A84FF"))
			}
			.buttonStyle(.plain)
		}
		.padding(.vertical, 4)
	}
	
	// MARK: Helpers
	private var _filteredItems: [FileItem] {
		_items.filter {
			_searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(_searchText)
		}
	}
	
	private func _reload(_ directory: URL) {
		let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
		let urls = (try? FileManager.default.contentsOfDirectory(
			at: directory,
			includingPropertiesForKeys: keys,
			options: [.skipsHiddenFiles]
		)) ?? []
		
		let items: [FileItem] = urls.compactMap { url in
			guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
			return FileItem(
				url: url,
				name: url.lastPathComponent,
				isDirectory: values.isDirectory ?? false,
				size: Int64(values.fileSize ?? 0),
				date: values.contentModificationDate
			)
		}
		
		// Hide internal storage folders from the Files browser; they are still
		// reachable through the Apps tab, "View file location", or the Files app.
		let hidden = directory == _root
			? ["Archives", "Certificates", "Signed", "Unsigned"]
			: []
		
		_items = items
			.filter { !hidden.contains($0.name) }
			.sorted {
				if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
				return $0.name.localizedStandardCompare($1.name) == .orderedAscending
			}
	}
	
	private func _import(_ urls: [URL], into directory: URL) {
		guard !urls.isEmpty else { return }
		
		for url in urls {
			let access = url.startAccessingSecurityScopedResource()
			defer { if access { url.stopAccessingSecurityScopedResource() } }
			
			var destination = directory.appendingPathComponent(url.lastPathComponent)
			var attempt = 1
			while FileManager.default.fileExists(atPath: destination.path) {
				let base = url.deletingPathExtension().lastPathComponent
				let ext = url.pathExtension
				let name = ext.isEmpty ? "\(base) \(attempt)" : "\(base) \(attempt).\(ext)"
				destination = directory.appendingPathComponent(name)
				attempt += 1
			}
			
			do {
				try FileManager.default.copyItem(at: url, to: destination)
			} catch {
				_errorMessage = error.localizedDescription
			}
		}
		_reload(directory)
	}
	
	private func _createFolder(in directory: URL) {
		let name = _newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !name.isEmpty else { return }
		
		let url = directory.appendingPathComponent(name, isDirectory: true)
		do {
			try FileManager.default.createDirectoryIfNeeded(at: url)
			_reload(directory)
		} catch {
			_errorMessage = error.localizedDescription
		}
	}
	
	private func _delete(_ item: FileItem) {
		do {
			try FileManager.default.removeItem(at: item.url)
			_deletingItem = nil
			_reload(item.url.deletingLastPathComponent())
		} catch {
			_errorMessage = error.localizedDescription
		}
	}
	
	private func _prepare(_ item: FileItem, install: Bool) {
		_preparingText = install ? .localized("Preparing install…") : .localized("Preparing signature…")
		_isPreparingPackage = true
		_selectedItem = nil
		
		FR.handlePackageFile(item.url) { error in
			DispatchQueue.main.async {
				_isPreparingPackage = false
				
				if let error {
					_errorMessage = error.localizedDescription
					return
				}
				
				let request = NSFetchRequest<Imported>(entityName: "Imported")
				request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
				request.fetchLimit = 1
				
				guard let app = try? Storage.shared.context.fetch(request).first else {
					_errorMessage = .localized("The app could not be imported.")
					return
				}
				
				if install {
					_installApp = AnyApp(base: app)
				} else {
					_signingApp = AnyApp(base: app)
				}
			}
		}
	}
}

// MARK: - File Info
struct FileInfoView: View {
	@Environment(\.dismiss) private var dismiss
	let item: FileItem
	
	var body: some View {
		NBNavigationView(.localized("Details"), displayMode: .inline) {
			List {
				Section {
					VStack(spacing: 10) {
						Image(systemName: item.icon)
							.font(.system(size: 40, weight: .semibold))
							.foregroundStyle(item.iconColor)
						Text(item.name)
							.font(.headline)
							.multilineTextAlignment(.center)
					}
					.frame(maxWidth: .infinity)
					.listRowBackground(EmptyView())
				}
				
				NBSection(.localized("Info")) {
					LabeledContent(.localized("Kind"), value: item.kind)
					LabeledContent(.localized("Size"), value: ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
					if let date = item.date {
						LabeledContent(.localized("Modified"), value: date.formatted())
					}
				}
				
				NBSection(.localized("Location")) {
					Text(item.url.deletingLastPathComponent().path)
						.font(.footnote)
						.foregroundStyle(.secondary)
						.copyableText(item.url.deletingLastPathComponent().path)
				}
			}
			.toolbar {
				NBToolbarButton(role: .close)
			}
		}
	}
}
