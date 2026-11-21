//
//  TabEnum.swift
//  UG Sign
//
//  Based on Feather (GPL-3.0).
//

import SwiftUI
import NimbleViews

enum TabEnum: String, CaseIterable, Hashable {
	case files
	case apps
	case sources
	case downloads
	case settings
	
	var title: String {
		switch self {
		case .files:		return .localized("Files")
		case .apps:			return .localized("Apps")
		case .sources:		return .localized("AppStore")
		case .downloads:	return .localized("Downloads")
		case .settings:		return .localized("Settings")
		}
	}
	
	var icon: String {
		switch self {
		case .files:		return "tray"
		case .apps:			return "square.grid.2x2"
		case .sources:		return "bag"
		case .downloads:	return "arrow.down.to.line"
		case .settings:		return "gearshape"
		}
	}
	
	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
		case .files:		FileListView()
		case .apps:			LibraryView()
		case .sources:		SourcesView()
		case .downloads:	DownloadsView()
		case .settings:		SettingsView()
		}
	}
	
	static var defaultTabs: [TabEnum] {
		return [.files, .apps, .sources, .downloads, .settings]
	}
	
	static var customizableTabs: [TabEnum] {
		return []
	}
}
