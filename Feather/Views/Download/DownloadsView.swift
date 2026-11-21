//
//  DownloadsView.swift
//  UG Sign
//
//  eSign-style downloads tab. Shows active downloads and archived IPAs.
//

import SwiftUI
import NimbleViews
import NimbleExtensions
import UniformTypeIdentifiers

// MARK: - View
struct DownloadsView: View {
	@StateObject private var _downloadManager = DownloadManager.shared
	
	@State private var _urlString = ""
	@State private var _isURLPresenting = false
	@State private var _isImportingPresenting = false
	@State private var _archives: [FileItem] = []
	@State private var _deletingArchive: FileItem?
	@State private var _infoArchive: FileItem?
	
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Downloads")) {
			List {
				if !_downloadManager.downloads.isEmpty {
					NBSection(.localized("Downloading")) {
						ForEach(_downloadManager.downloads) { download in
							DownloadRow(download: download)
								.swipeActions {
									Button(role: .destructive) {
										_downloadManager.cancelDownload(download)
									} label: {
										Label(.localized("Cancel"), systemImage: "xmark")
									}
								}
						}
					}
				}
				
				if !_archives.isEmpty {
					NBSection(.localized("Archived"), secondary: _archives.count.description) {
						ForEach(_archives) { item in
							HStack(spacing: 12) {
								Image(systemName: "doc.zipper")
									.font(.system(size: 20, weight: .semibold))
									.foregroundStyle(Color(hex: "#0A84FF"))
									.frame(width: 38, height: 38)
									.background(Color(hex: "#0A84FF").opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
								
								VStack(alignment: .leading, spacing: 3) {
									Text(item.name)
										.font(.system(size: 16, weight: .semibold))
										.lineLimit(1)
									Text(item.subtitle)
										.font(.system(size: 13))
										.foregroundStyle(.secondary)
								}
								
								Spacer()
							}
							.contentShape(Rectangle())
							.onTapGesture {
								UIActivityViewController.show(activityItems: [item.url])
							}
							.swipeActions {
								Button(role: .destructive) {
									_deletingArchive = item
								} label: {
									Label(.localized("Delete"), systemImage: "trash")
								}
								Button {
									_infoArchive = item
								} label: {
									Label(.localized("Info"), systemImage: "info.circle")
								}
							}
						}
					}
				}
				
				if _downloadManager.downloads.isEmpty && _archives.isEmpty {
					Section {
						VStack(spacing: 10) {
							Image(systemName: "arrow.down.circle")
								.font(.system(size: 40))
								.foregroundStyle(.secondary)
							Text(.localized("No Downloads"))
								.font(.headline)
							Text(.localized("Download an app from a repository or import an IPA file."))
								.font(.footnote)
								.foregroundStyle(.secondary)
								.multilineTextAlignment(.center)
						}
						.frame(maxWidth: .infinity)
						.padding(.vertical, 40)
						.listRowBackground(Color.clear)
						.listRowSeparator(.hidden)
					}
				}
			}
			.listStyle(.plain)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Menu {
						Button(.localized("Download from URL"), systemImage: "globe") {
							_urlString = ""
							_isURLPresenting = true
						}
						Button(.localized("Import File"), systemImage: "folder") {
							_isImportingPresenting = true
						}
						Divider()
						Button(.localized("Open Archives"), systemImage: "archivebox") {
							if let url = FileManager.default.archives.toSharedDocumentsURL() {
								UIApplication.open(url)
							}
						}
					} label: {
						Image(systemName: "plus.circle.fill")
							.font(.system(size: 21))
					}
				}
			}
			.alert(.localized("Download from URL"), isPresented: $_isURLPresenting) {
				TextField("https://", text: $_urlString)
					.textInputAutocapitalization(.never)
					.keyboardType(.URL)
				Button(.localized("Cancel"), role: .cancel) {}
				Button(.localized("Download")) { _startDownload() }
			}
			.sheet(isPresented: $_isImportingPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.ipa, .tipa],
					allowsMultipleSelection: true,
					onDocumentsPicked: { urls in
						for url in urls {
							let id = "UGSignManualDownload_\(UUID().uuidString)"
							let download = _downloadManager.startArchive(from: url, id: id)
							try? _downloadManager.handlePachageFile(url: url, dl: download)
						}
					}
				)
				.ignoresSafeArea()
			}
			.sheet(item: $_infoArchive) { item in
				FileInfoView(item: item)
			}
			.alert(
				.localized("Delete File"),
				isPresented: Binding(
					get: { _deletingArchive != nil },
					set: { if !$0 { _deletingArchive = nil } }
				),
				presenting: _deletingArchive
			) { item in
				Button(.localized("Delete"), role: .destructive) { _delete(item) }
				Button(.localized("Cancel"), role: .cancel) {}
			} message: { item in
				Text(.localized("Are you sure you want to delete “%@”?", arguments: item.name))
			}
			.onAppear(perform: _reloadArchives)
			.onChange(of: _downloadManager.downloads.count) { _ in _reloadArchives() }
		}
	}
	
	// MARK: Helpers
	private func _startDownload() {
		guard let url = URL(string: _urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
		_ = _downloadManager.startDownload(from: url, id: "UGSignManualDownload_\(UUID().uuidString)")
	}
	
	private func _reloadArchives() {
		let directory = FileManager.default.archives
		let urls = (try? FileManager.default.contentsOfDirectory(
			at: directory,
			includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
			options: [.skipsHiddenFiles]
		)) ?? []
		
		_archives = urls
			.filter { $0.pathExtension.lowercased() == "ipa" || $0.pathExtension.lowercased() == "tipa" }
			.compactMap { url in
				guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else { return nil }
				return FileItem(
					url: url,
					name: url.lastPathComponent,
					isDirectory: false,
					size: Int64(values.fileSize ?? 0),
					date: values.contentModificationDate
				)
			}
			.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
	}
	
	private func _delete(_ item: FileItem) {
		try? FileManager.default.removeItem(at: item.url)
		_deletingArchive = nil
		_reloadArchives()
	}
}

// MARK: - Row
struct DownloadRow: View {
	let download: Download
	@State private var _progress: Double = 0
	@State private var _bytes: Int64 = 0
	@State private var _total: Int64 = 0
	@State private var _unpackage: Double = 0
	
	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: "arrow.down.circle.fill")
				.font(.system(size: 22, weight: .semibold))
				.foregroundStyle(Color(hex: "#0A84FF"))
				.frame(width: 42, height: 42)
				.background(Color(hex: "#0A84FF").opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
			
			VStack(alignment: .leading, spacing: 5) {
				Text(download.fileName)
					.font(.system(size: 16, weight: .semibold))
					.lineLimit(1)
				
				ProgressView(value: _overallProgress)
					.progressViewStyle(.linear)
					.tint(Color(hex: "#0A84FF"))
				
				HStack {
					Text(verbatim: "\(Int(_overallProgress * 100))%")
					Spacer()
					if _total > 0 {
						Text(verbatim: "\(ByteCountFormatter.string(fromByteCount: _bytes, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: _total, countStyle: .file))")
					}
				}
				.font(.caption)
				.foregroundStyle(.secondary)
			}
		}
		.padding(.vertical, 3)
		.onReceive(download.$progress) { _progress = $0 }
		.onReceive(download.$bytesDownloaded) { _bytes = $0 }
		.onReceive(download.$totalBytes) { _total = $0 }
		.onReceive(download.$unpackageProgress) { _unpackage = $0 }
	}
	
	private var _overallProgress: Double {
		download.onlyArchiving ? _unpackage : (0.3 * _unpackage) + (0.7 * _progress)
	}
}
