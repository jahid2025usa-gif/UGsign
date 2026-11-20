//
//  StorageView.swift
//  UG Sign
//
//  ESign's "The storage space" row: how much space UG Sign's files use.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct StorageView: View {
	struct StorageRow: Identifiable {
		var id: String { name }
		let name: String
		let url: URL
		var size: Int64 = 0
	}
	
	@State private var _rows: [StorageRow] = []
	@State private var _isLoading = true
	
	// MARK: Body
	var body: some View {
		NBList(.localized("The storage space")) {
			if _isLoading {
				ProgressView()
					.frame(maxWidth: .infinity)
			} else {
				NBSection(.localized("Storage")) {
					ForEach(_rows) { row in
						LabeledContent(row.name) {
							Text(_formatted(row.size))
						}
					}
				} footer: {
					Text(.localized("Space used by UG Sign's documents. Archives, Signed, Unsigned and Certificates live inside Documents, so Documents is the total."))
				}
			}
		}
		.task {
			await _loadSizes()
		}
	}
}

// MARK: - Extension: View
extension StorageView {
	private func _loadSizes() async {
		let fileManager = FileManager.default
		
		let rows = [
			StorageRow(name: .localized("Documents"), url: URL.documentsDirectory),
			StorageRow(name: .localized("Archives"), url: fileManager.archives),
			StorageRow(name: .localized("Signed"), url: fileManager.signed),
			StorageRow(name: .localized("Unsigned"), url: fileManager.unsigned),
			StorageRow(name: .localized("Certificates"), url: fileManager.certificates)
		]
		
		let sizedRows = await Task.detached(priority: .userInitiated) {
			rows.map { row in
				StorageRow(name: row.name, url: row.url, size: Self._size(of: row.url))
			}
		}.value
		
		_rows = sizedRows
		_isLoading = false
	}
	
	private static func _size(of url: URL) -> Int64 {
		guard let enumerator = FileManager.default.enumerator(
			at: url,
			includingPropertiesForKeys: [.fileSizeKey],
			options: [.skipsHiddenFiles]
		) else {
			return 0
		}
		
		var total: Int64 = 0
		
		for case let fileURL as URL in enumerator {
			if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
				total += Int64(fileSize)
			}
		}
		
		return total
	}
	
	private func _formatted(_ size: Int64) -> String {
		ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
	}
}
